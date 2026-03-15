#!/usr/bin/env node
/**
 * Claudian MCP Server
 * Provides system control tools for Claude to operate the machine
 */

import { Server } from "@modelcontextprotocol/sdk/server/index.js";
import { StdioServerTransport } from "@modelcontextprotocol/sdk/server/stdio.js";
import {
  CallToolRequestSchema,
  ListToolsRequestSchema,
} from "@modelcontextprotocol/sdk/types.js";
import { exec } from "child_process";
import { promisify } from "util";
import { readFile, writeFile } from "fs/promises";
import WebSocket from "ws";

const execAsync = promisify(exec);

class ClaudianMCPServer {
  constructor() {
    this.server = new Server(
      {
        name: "claudian",
        version: "1.0.0",
      },
      {
        capabilities: {
          tools: {},
        },
      }
    );

    this.setupToolHandlers();
    this.cdpWs = null;
    this.cdpTarget = null;
  }

  setupToolHandlers() {
    // List available tools
    this.server.setRequestHandler(ListToolsRequestSchema, async () => ({
      tools: [
        {
          name: "shell_exec",
          description:
            "Execute a shell command as root. Returns stdout, stderr, and exit code. Use this for any system operations, package management, file operations, etc.",
          inputSchema: {
            type: "object",
            properties: {
              command: {
                type: "string",
                description: "The shell command to execute",
              },
              cwd: {
                type: "string",
                description: "Working directory (optional)",
              },
            },
            required: ["command"],
          },
        },
        {
          name: "i3_command",
          description:
            "Send a command to i3 window manager. Examples: 'split h', 'workspace 2', 'focus left', 'kill'. Returns i3's JSON response.",
          inputSchema: {
            type: "object",
            properties: {
              command: {
                type: "string",
                description: "The i3 command to execute",
              },
            },
            required: ["command"],
          },
        },
        {
          name: "browser_cdp",
          description:
            "Send a Chrome DevTools Protocol command to the browser. Allows navigation, DOM manipulation, JavaScript execution, etc.",
          inputSchema: {
            type: "object",
            properties: {
              method: {
                type: "string",
                description: "CDP method (e.g., 'Page.navigate', 'Runtime.evaluate')",
              },
              params: {
                type: "object",
                description: "Method parameters (optional)",
              },
            },
            required: ["method"],
          },
        },
        {
          name: "file_read",
          description: "Read a file from the filesystem",
          inputSchema: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "Absolute path to the file",
              },
            },
            required: ["path"],
          },
        },
        {
          name: "file_write",
          description: "Write content to a file",
          inputSchema: {
            type: "object",
            properties: {
              path: {
                type: "string",
                description: "Absolute path to the file",
              },
              content: {
                type: "string",
                description: "Content to write",
              },
              append: {
                type: "boolean",
                description: "Append to file instead of overwriting (optional)",
              },
            },
            required: ["path", "content"],
          },
        },
        {
          name: "list_windows",
          description:
            "List all windows in i3. Returns array of windows with id, name, class, and focus status.",
          inputSchema: {
            type: "object",
            properties: {},
          },
        },
      ],
    }));

    // Handle tool calls
    this.server.setRequestHandler(CallToolRequestSchema, async (request) => {
      try {
        switch (request.params.name) {
          case "shell_exec":
            return await this.handleShellExec(request.params.arguments);
          case "i3_command":
            return await this.handleI3Command(request.params.arguments);
          case "browser_cdp":
            return await this.handleBrowserCdp(request.params.arguments);
          case "file_read":
            return await this.handleFileRead(request.params.arguments);
          case "file_write":
            return await this.handleFileWrite(request.params.arguments);
          case "list_windows":
            return await this.handleListWindows();
          default:
            throw new Error(`Unknown tool: ${request.params.name}`);
        }
      } catch (error) {
        return {
          content: [
            {
              type: "text",
              text: `Error: ${error.message}`,
            },
          ],
        };
      }
    });
  }

  async handleShellExec(args) {
    const { command, cwd } = args;
    try {
      const { stdout, stderr } = await execAsync(command, {
        cwd: cwd || process.cwd(),
        shell: "/bin/bash",
      });
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              {
                stdout: stdout || "",
                stderr: stderr || "",
                exit_code: 0,
              },
              null,
              2
            ),
          },
        ],
      };
    } catch (error) {
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(
              {
                stdout: error.stdout || "",
                stderr: error.stderr || error.message,
                exit_code: error.code || 1,
              },
              null,
              2
            ),
          },
        ],
      };
    }
  }

  async handleI3Command(args) {
    const { command } = args;
    try {
      const { stdout } = await execAsync(`i3-msg '${command}'`);
      return {
        content: [
          {
            type: "text",
            text: stdout,
          },
        ],
      };
    } catch (error) {
      throw new Error(`i3-msg failed: ${error.message}`);
    }
  }

  async handleBrowserCdp(args) {
    const { method, params = {} } = args;

    // Connect to CDP if not already connected
    if (!this.cdpWs) {
      await this.connectToCDP();
    }

    return new Promise((resolve, reject) => {
      const id = Date.now();
      const message = JSON.stringify({
        id,
        method,
        params,
      });

      const timeout = setTimeout(() => {
        reject(new Error("CDP command timeout"));
      }, 10000);

      const messageHandler = (data) => {
        const response = JSON.parse(data.toString());
        if (response.id === id) {
          clearTimeout(timeout);
          this.cdpWs.off("message", messageHandler);
          if (response.error) {
            reject(new Error(JSON.stringify(response.error)));
          } else {
            resolve({
              content: [
                {
                  type: "text",
                  text: JSON.stringify(response.result, null, 2),
                },
              ],
            });
          }
        }
      };

      this.cdpWs.on("message", messageHandler);
      this.cdpWs.send(message);
    });
  }

  async connectToCDP() {
    try {
      // Get CDP endpoint
      const response = await fetch("http://localhost:9222/json/version");
      const info = await response.json();
      const wsUrl = info.webSocketDebuggerUrl;

      // Connect via WebSocket
      this.cdpWs = new WebSocket(wsUrl);

      return new Promise((resolve, reject) => {
        this.cdpWs.on("open", () => {
          resolve();
        });
        this.cdpWs.on("error", (error) => {
          reject(error);
        });
      });
    } catch (error) {
      throw new Error(`Failed to connect to CDP: ${error.message}`);
    }
  }

  async handleFileRead(args) {
    const { path } = args;
    try {
      const content = await readFile(path, "utf-8");
      return {
        content: [
          {
            type: "text",
            text: content,
          },
        ],
      };
    } catch (error) {
      throw new Error(`Failed to read file: ${error.message}`);
    }
  }

  async handleFileWrite(args) {
    const { path, content, append = false } = args;
    try {
      if (append) {
        const existing = await readFile(path, "utf-8").catch(() => "");
        await writeFile(path, existing + content, "utf-8");
      } else {
        await writeFile(path, content, "utf-8");
      }
      return {
        content: [
          {
            type: "text",
            text: JSON.stringify({ success: true }),
          },
        ],
      };
    } catch (error) {
      throw new Error(`Failed to write file: ${error.message}`);
    }
  }

  async handleListWindows() {
    try {
      const { stdout } = await execAsync("i3-msg -t get_tree");
      const tree = JSON.parse(stdout);

      const windows = [];
      const traverse = (node) => {
        if (node.window && node.name) {
          windows.push({
            id: node.window,
            name: node.name,
            class: node.window_properties?.class || "unknown",
            focused: node.focused,
          });
        }
        if (node.nodes) {
          node.nodes.forEach(traverse);
        }
        if (node.floating_nodes) {
          node.floating_nodes.forEach(traverse);
        }
      };
      traverse(tree);

      return {
        content: [
          {
            type: "text",
            text: JSON.stringify(windows, null, 2),
          },
        ],
      };
    } catch (error) {
      throw new Error(`Failed to list windows: ${error.message}`);
    }
  }

  async run() {
    const transport = new StdioServerTransport();
    await this.server.connect(transport);
    console.error("Claudian MCP server running on stdio");
  }
}

// Start the server
const server = new ClaudianMCPServer();
server.run().catch(console.error);
