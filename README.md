# Claudian

> A minimal Linux distribution where Claude Code operates as the primary interface to the machine.

## What is Claudian?

Claudian is a Debian-based operating system designed from the ground up for Claude Code to run as the machine's operator. Instead of the user directly interacting with the OS, they interact **through** Claude, who has complete system control via MCP (Model Context Protocol) tools.

On boot, you see:
- **Left half**: Claude Code running in a terminal as the `claude` user
- **Right half**: Chromium browser, remote-debuggable by Claude
- Claude can open windows, run shell commands, control the browser, and manage the filesystem
- The human interacts through Claude -- not around it

## Quick Start

### Prerequisites

- A Debian/Ubuntu-based system for building
- Root access (for debootstrap and chroot)
- At least 10GB free disk space
- Anthropic API key or account (configured during first boot)

### Build

```bash
cd claudeos
sudo ./build/build.sh
```

The build creates a minimal UEFI-bootable disk image (`claudian.img`) sized to fit the system.

### Build Options

All options are passed as environment variables. Use `sudo -E` to preserve them:

```bash
# Standard build
sudo ./build/build.sh

# Include WiFi/hardware firmware (Intel, Realtek, Atheros)
sudo INCLUDE_NONFREE_FIRMWARE=yes ./build.sh

# Include API key (skips auth step in onboarding)
ANTHROPIC_API_KEY=sk-ant-... sudo -E ./build.sh

# Full permission bypass (Claude runs without any prompts)
sudo BUILD_WITH_BYPASS=yes ./build.sh

# Skip disk image creation (rootfs only)
sudo CREATE_DISK_IMAGE=no ./build.sh

# Combine options
ANTHROPIC_API_KEY=sk-ant-key sudo -E INCLUDE_NONFREE_FIRMWARE=yes ./build.sh
```

Or use the bypass wrapper:
```bash
sudo ./build/build-with-full-bypass.sh
```

### Deploy to USB

```bash
# Find your USB device
lsblk

# Write the image (replace /dev/sdX with your USB device)
sudo dd if=build/claudian.img of=/dev/sdX bs=16M status=progress oflag=direct

# Sync to ensure all data is written
sync
```

Boot from the USB drive. The image uses UEFI/GPT boot with a fallback EFI path, so it should work on any modern UEFI system.

### First Boot Onboarding

On first boot, Claudian auto-logs in as the `claude` user, starts X11 + i3, and launches the onboarding wizard:

**Step 1: Network Configuration**
- Auto-detects existing connection
- WiFi setup via NetworkManager (scan, select SSID, enter password)
- Skip option for ethernet users

**Step 2: Package Installation**
- Installs extra packages over the network (dev tools, CLI utilities, etc.)
- Can be skipped and run later

**Step 3: Partition Configuration**
- Auto-expand to fill the entire drive (recommended)
- Set a custom size (e.g., 20G, 50G)
- Keep current minimal size

**Step 4: Security Configuration**
- Passwordless sudo (recommended for automation)
- Password-required sudo

**Step 5: Authentication**
- Sign in with browser (`claude auth login`)
- Enter API key manually

After onboarding, Claude Code launches and takes over.

## Architecture

### System Stack

| Component | Technology |
|-----------|-----------|
| Base OS | Debian 12 (Bookworm) |
| Boot | UEFI/GPT with GRUB |
| User | `claude` with configurable sudo |
| Display | X11 |
| Window Manager | i3 (tiling) |
| Terminal | Kitty |
| Browser | Chromium (CDP on port 9222) |
| Runtime | Node.js 22 LTS |
| AI | Claude Code with MCP server |

### MCP Tools

Claude has access to six MCP tools via the server at `/opt/claudian/mcp/server.js`:

1. **shell_exec** - Execute shell commands
2. **i3_command** - Control i3 window manager
3. **browser_cdp** - Control Chromium via Chrome DevTools Protocol
4. **file_read** - Read files
5. **file_write** - Write/append to files
6. **list_windows** - List all i3 windows with metadata

### Boot Sequence

```
UEFI -> GRUB -> systemd -> getty autologin (claude) -> startx -> i3
  |
  +-> Left pane:  kitty -> claude-launch -> onboarding -> MCP server -> Claude Code
  +-> Right pane: Chromium with CDP on :9222
```

### Package Architecture

Packages are split into two groups to minimize the USB image size:

**Base packages** (in the image, ~3-4GB):
- Boot essentials (kernel, GRUB, systemd)
- Networking (NetworkManager, SSH)
- Desktop (X11, i3, kitty, Chromium)
- Node.js 22 LTS, Claude Code
- Fonts and basic tools

**Extra packages** (installed during onboarding over network):
- Desktop automation (xdotool, wmctrl, xclip)
- Development (Python, C/C++, Docker, SQLite)
- System tools (htop, tmux, jq, ripgrep, bat, fd, fzf)
- Media processing (ffmpeg, imagemagick, pandoc)
- Networking tools (nmap, netcat, mtr)
- And more (see `build/extra-packages.txt`)

### File Structure

```
claudeos/
+-- build/
|   +-- base-packages.txt    # Minimal packages for the image
|   +-- extra-packages.txt   # Packages installed during onboarding
|   +-- build.sh             # Main build script
|   +-- build-with-full-bypass.sh
|   +-- debian-root/         # Generated rootfs
|   +-- claudian.img         # Generated disk image
+-- rootfs/                  # Configuration overlay
|   +-- etc/                 # System configs (sudoers, autologin, etc.)
|   +-- home/claude/         # Claude user configs (i3, kitty, CLAUDE.md)
|   +-- usr/local/bin/       # Scripts (claude-launch, onboarding, etc.)
+-- mcp/
|   +-- server.js            # MCP server implementation
|   +-- package.json
+-- docs/
    +-- architecture.md
```

## Configuration

### Claude Command

The `claude-launch` script reads `CLAUDE_CMD` from `/etc/environment`:

```bash
# Default (prompts for permissions):
CLAUDE_CMD="claude --mcp-config ~/.config/claude/mcp.json"

# Bypass permissions (full automation):
CLAUDE_CMD="claude --allow-dangerously-skip-permissions --permission-mode bypassPermissions --mcp-config ~/.config/claude/mcp.json"
```

### HiDPI Displays

Adjust scaling in these files under `/home/claude/`:

1. `.Xresources` - X11 DPI (default: 192 for 2x)
2. `.xinitrc` - xrandr DPI
3. `.config/i3/config` - Chromium `--force-device-scale-factor`
4. `/etc/profile.d/claude-env.sh` - GTK scaling

Common values: 96 DPI (1080p), 144 DPI (1440p), 192 DPI (4K)

### SSH Access

SSH is enabled by default with password authentication.

For key-based auth:
1. Edit `rootfs/etc/ssh/sshd_config.d/claudian.conf`
2. Change to: `PermitRootLogin prohibit-password`
3. Add your public key to `/home/claude/.ssh/authorized_keys`

## Troubleshooting

### Build fails with leftover mounts
The build script has a cleanup trap, but if something goes wrong:
```bash
sudo umount -l build/debian-root/dev/pts build/debian-root/dev build/debian-root/sys build/debian-root/proc 2>/dev/null
sudo rm -rf build/debian-root build/claudian.img
```

### WiFi not detected on live USB
Build with firmware support:
```bash
sudo INCLUDE_NONFREE_FIRMWARE=yes ./build.sh
```

### sudo not working (permission errors)
Usually caused by incorrect file ownership. Rebuild with a clean build:
```bash
sudo rm -rf build/debian-root build/claudian.img
sudo ./build.sh
```

### USB not booting
Claudian uses UEFI/GPT boot. Ensure your BIOS is set to UEFI mode (not Legacy/CSM).

### MCP server not connecting
- Check if running: `ps aux | grep mcp`
- Check `/opt/claudian/mcp/node_modules` exists
- Test manually: `node /opt/claudian/mcp/server.js`

## Security

- Claudian runs as the `claude` user with configurable sudo access
- Never expose Claudian directly to untrusted networks
- SSH is enabled by default - change to key-based auth for production
- API key is stored in `/etc/environment`
- WiFi firmware is optional (`INCLUDE_NONFREE_FIRMWARE`)
- This is designed for a **dedicated machine** controlled by Claude

## Credits

Built by Bas van den Aakster for Claude Code to operate machines autonomously.
