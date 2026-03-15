# Claudian OS - CLI Tools Reference for Claude

This document lists all CLI tools available on Claudian OS for you to use.

## Desktop Automation & Control

**xdotool** - Simulate keyboard/mouse input and control windows
```bash
xdotool type "Hello World"           # Type text
xdotool key ctrl+c                   # Simulate key combo
xdotool click 1                      # Left click
xdotool mousemove 100 200            # Move mouse
xdotool search --name "Firefox" windowactivate  # Focus window
xdotool getwindowfocus getwindowname # Get active window title
```

**wmctrl** - Window manager control
```bash
wmctrl -l                            # List all windows
wmctrl -r :ACTIVE: -e 0,100,100,800,600  # Move/resize active window
wmctrl -s 2                          # Switch to workspace 2
wmctrl -c "Window Title"             # Close window by title
wmctrl -a "Firefox"                  # Activate window
```

**xclip / xsel** - Clipboard manipulation
```bash
echo "text" | xclip -selection clipboard  # Copy to clipboard
xclip -o                             # Paste from clipboard
xclip -selection primary -o          # Get X11 primary selection
```

**xinput** - Input device control
```bash
xinput list                          # List input devices
xinput set-prop <id> <prop> <val>    # Configure device properties
```

**xautomation (xte)** - Alternative automation
```bash
xte "str Hello World"                # Type string
xte "key Return"                     # Press key
xte "mousemove 100 200"              # Move mouse
```

**scrot** - Screenshots
```bash
scrot screenshot.png                 # Full screen
scrot -s selection.png               # Select area
scrot -u window.png                  # Current window
```

## i3 Window Manager

**i3-msg** - Control i3 directly
```bash
i3-msg focus left                    # Focus left window
i3-msg split h                       # Horizontal split
i3-msg layout tabbed                 # Tabbed layout
i3-msg workspace 2                   # Switch workspace
i3-msg "[class=\"chromium\"] focus"  # Focus by class
i3-msg reload                        # Reload config
```

## Development Tools

**Python**
```bash
python3                              # Python interpreter
pip3 install <package>               # Install package
python3 -m venv myenv                # Create virtual environment
python3 -m http.server 8000          # Quick HTTP server
```

**Node.js**
```bash
node script.js                       # Run JavaScript
npm install <package>                # Install package
npm install -g <package>             # Install globally
npx <command>                        # Execute package binary
```

**Docker**
```bash
docker run -it ubuntu bash           # Run container interactively
docker ps                            # List running containers
docker images                        # List images
docker build -t name .               # Build image
docker-compose up -d                 # Start services
docker exec -it <container> bash     # Exec into container
```

**C/C++ Compilation**
```bash
gcc file.c -o output                 # Compile C
g++ file.cpp -o output               # Compile C++
make                                 # Build with Makefile
```

**SQLite**
```bash
sqlite3 database.db                  # Open database
sqlite3 db.db "SELECT * FROM table"  # Run query
sqlite3 db.db ".schema"              # Show schema
```

## System & DevOps Tools

**htop / btop** - System monitoring
```bash
htop                                 # Interactive process viewer
btop                                 # Modern system monitor
```

**tmux** - Terminal multiplexer
```bash
tmux                                 # Start new session
tmux ls                              # List sessions
tmux attach -t <name>                # Attach to session
tmux new -s <name>                   # Named session
# Inside tmux: Ctrl+b then command (%, ", c, n, etc.)
```

**jq** - JSON processing
```bash
echo '{"key":"value"}' | jq .        # Pretty print
cat data.json | jq '.items[]'        # Query
jq '.[] | select(.age > 30)' data.json  # Filter
```

**yq** - YAML processing
```bash
yq eval '.key' file.yaml             # Query YAML
yq eval '.key = "value"' -i file.yaml  # Edit in place
```

**ripgrep (rg)** - Fast search
```bash
rg "pattern" .                       # Search recursively
rg -i "pattern"                      # Case insensitive
rg -t py "import"                    # Search Python files only
rg -A 3 -B 3 "pattern"               # Context lines
```

**fd** - Fast find alternative
```bash
fd pattern                           # Find files/dirs
fd -e py                             # Find by extension
fd -t f                              # Files only
fd -t d                              # Directories only
```

**bat** - Cat with syntax highlighting
```bash
bat file.py                          # View with highlighting
bat -n file.txt                      # Show line numbers
bat --style=plain file.txt           # Plain output
```

**tree** - Directory tree viewer
```bash
tree                                 # Show directory tree
tree -L 2                            # Max depth 2
tree -a                              # Include hidden files
tree -I 'node_modules|.git'          # Ignore patterns
```

**ncdu** - Disk usage analyzer
```bash
ncdu                                 # Analyze current dir
ncdu /path                           # Analyze specific path
```

**strace** - System call tracing
```bash
strace command                       # Trace system calls
strace -p <pid>                      # Attach to process
```

**tcpdump** - Network packet capture
```bash
tcpdump -i eth0                      # Capture on interface
tcpdump -i eth0 port 80              # Filter by port
tcpdump -w capture.pcap              # Write to file
```

## Text & Document Processing

**pandoc** - Universal document converter
```bash
pandoc input.md -o output.html       # Markdown to HTML
pandoc input.md -o output.docx       # Markdown to Word
pandoc input.docx -o output.md       # Word to Markdown
# Note: PDF generation requires LaTeX (install: sudo apt install texlive-latex-base)
```

**ImageMagick (convert, identify)** - Image manipulation
```bash
convert input.jpg -resize 50% output.jpg  # Resize
convert input.jpg -rotate 90 output.jpg   # Rotate
convert a.jpg b.jpg c.jpg out.pdf         # Images to PDF
identify image.jpg                        # Image info
```

**ffmpeg** - Video/audio processing
```bash
ffmpeg -i input.mp4 output.avi       # Convert format
ffmpeg -i video.mp4 -vf scale=1280:720 output.mp4  # Resize
ffmpeg -i video.mp4 -ss 00:01:00 -t 00:00:10 clip.mp4  # Cut clip
ffmpeg -i audio.mp3 -ac 2 -ab 128k output.mp3  # Re-encode audio
```

**poppler-utils** - PDF utilities
```bash
pdftotext file.pdf output.txt        # Extract text
pdfinfo file.pdf                     # PDF metadata
pdftoppm file.pdf output -png        # PDF to images
```

**Ghostscript (gs)** - PostScript/PDF processing
```bash
gs -sDEVICE=pdfwrite -o out.pdf in1.pdf in2.pdf  # Merge PDFs
```

## Networking & Web

**curl** - HTTP client
```bash
curl https://api.example.com         # GET request
curl -X POST -d "data" url           # POST data
curl -H "Header: value" url          # Custom header
curl -o file.zip url                 # Download file
```

**wget** - File downloader
```bash
wget url                             # Download file
wget -r -np url                      # Recursive download
wget -c url                          # Resume download
```

**nmap** - Network scanning
```bash
nmap 192.168.1.0/24                  # Scan network
nmap -p 80,443 host                  # Scan specific ports
nmap -sV host                        # Service version detection
```

**netcat (nc)** - Network utility
```bash
nc -l 8080                           # Listen on port
nc host port                         # Connect to port
echo "data" | nc host port           # Send data
```

**aria2** - Advanced downloader
```bash
aria2c url                           # Download file
aria2c -x 16 url                     # 16 connections
aria2c -i urls.txt                   # Download from list
```

**mtr** - Network diagnostic (traceroute + ping)
```bash
mtr google.com                       # Interactive network trace
```

**ssh** - Secure shell
```bash
ssh user@host                        # Connect to host
ssh -L 8080:localhost:80 user@host   # Port forwarding
scp file user@host:/path             # Copy file
```

## File & Archive Tools

**zip / unzip**
```bash
zip archive.zip file1 file2          # Create zip
zip -r archive.zip directory/        # Recursive
unzip archive.zip                    # Extract
unzip -l archive.zip                 # List contents
```

**p7zip (7z)**
```bash
7z a archive.7z files                # Create archive
7z x archive.7z                      # Extract
7z l archive.7z                      # List contents
```

**rsync** - File synchronization
```bash
rsync -av source/ dest/              # Sync directories
rsync -av --delete source/ dest/     # Sync with deletion
rsync -av -e ssh source/ user@host:dest/  # Remote sync
```

**rclone** - Cloud storage sync
```bash
rclone config                        # Configure remotes
rclone copy local remote:path        # Upload
rclone sync local remote:path        # Sync
rclone ls remote:path                # List remote files
```

## Graphics & Media

**mpv** - Media player
```bash
mpv video.mp4                        # Play video
mpv --no-video audio.mp3             # Audio only
mpv --screenshot-directory=. video.mp4  # Configure screenshots
```

**feh** - Image viewer
```bash
feh image.jpg                        # View image
feh -F image.jpg                     # Fullscreen
feh -r directory/                    # View all in dir
```

## AI/ML & Data Science

**Python Data Science Tools**
```bash
python3 -c "import numpy as np; print(np.array([1,2,3]))"
python3 -c "import pandas as pd; df = pd.read_csv('data.csv')"
python3 -c "import matplotlib.pyplot as plt"
# Note: For Jupyter notebooks: sudo apt install jupyter-notebook
```

**gnuplot** - Plotting tool
```bash
gnuplot                              # Interactive mode
gnuplot -e "plot sin(x); pause -1"   # Quick plot
```

**Additional tools** (install as needed)
```bash
sudo apt install jupyter-notebook    # Interactive Python notebooks
sudo apt install r-base              # R statistical computing
sudo apt install texlive-latex-base  # LaTeX for document generation
sudo apt install gimp                # Image editing
sudo apt install inkscape            # Vector graphics
```

## Version Control & Collaboration

**git**
```bash
git clone url                        # Clone repository
git status                           # Check status
git add .                            # Stage changes
git commit -m "message"              # Commit
git push                             # Push changes
git pull                             # Pull changes
git log --oneline                    # View history
```

**git-lfs** - Large file storage
```bash
git lfs install                      # Setup LFS
git lfs track "*.psd"                # Track file type
```

**gh** - GitHub CLI
```bash
gh auth login                        # Authenticate
gh repo create                       # Create repository
gh pr create                         # Create pull request
gh issue list                        # List issues
gh repo clone owner/repo             # Clone repo
```

**tig** - Git terminal UI
```bash
tig                                  # Browse repository
tig blame file.txt                   # Blame view
tig show commit-hash                 # Show commit
```

## Security & Privacy

**gnupg (gpg)** - Encryption
```bash
gpg --gen-key                        # Generate key pair
gpg --encrypt --recipient user file  # Encrypt file
gpg --decrypt file.gpg               # Decrypt file
gpg --sign file                      # Sign file
```

**pass** - Password manager
```bash
pass init gpg-id                     # Initialize store
pass insert service/account          # Add password
pass service/account                 # Retrieve password
pass generate service/account 20     # Generate password
```

**openssl** - Crypto toolkit
```bash
openssl rand -base64 32              # Generate random bytes
openssl enc -aes-256-cbc -in file -out file.enc  # Encrypt
openssl req -new -x509 -days 365 -out cert.pem   # Generate cert
```

## CLI Enhancement

**fzf** - Fuzzy finder
```bash
fzf                                  # Interactive finder
ls | fzf                             # Find from list
vim $(fzf)                           # Open file with fuzzy search
# Ctrl+R - Search history (if configured)
```

**zsh** - Alternative shell
```bash
zsh                                  # Start zsh
chsh -s /usr/bin/zsh                 # Set as default shell
```

**fish** - Friendly shell
```bash
fish                                 # Start fish
chsh -s /usr/bin/fish                # Set as default shell
```

## Claudian-Specific Tools

**MCP Server Tools** - Available via MCP interface
- `shell_exec` - Execute shell commands
- `i3_command` - Control i3 window manager
- `browser_cdp` - Chrome DevTools Protocol commands
- `file_read` - Read files
- `file_write` - Write files
- `list_windows` - List i3 windows with metadata

**claude-open** - Open URLs/files from Claude
```bash
/usr/local/bin/claude-open https://example.com
/usr/local/bin/claude-open /path/to/file.pdf
```

**Partition Management**
```bash
/usr/local/bin/claudian-expand-partition auto    # Expand to fill disk
/usr/local/bin/claudian-expand-partition 50G     # Expand to 50GB
/usr/local/bin/claudian-expand-partition skip    # Skip expansion
```

## Environment Variables

- `ANTHROPIC_API_KEY` - Your API key (set in /etc/environment)
- `CLAUDE_WM_TOOL` - Path to claude-open script
- `CLAUDE_CMD` - Claude Code command configuration

## Configuration Files

- `~/.config/claude/mcp.json` - MCP server configuration
- `~/.config/claude/settings.json` - Claude Code settings
- `~/.config/i3/config` - i3 window manager config
- `~/.config/kitty/kitty.conf` - Kitty terminal config
- `/etc/environment` - Global environment variables

## Tips & Tricks

1. **Combine tools with pipes**: `cat data.json | jq . | bat`
2. **Use fzf for interactive selection**: `kill $(ps aux | fzf | awk '{print $2}')`
3. **Background tasks**: `long-running-command &` then `jobs`, `fg %1`
4. **Screen capture workflow**: `scrot -s | xclip -selection clipboard -t image/png`
5. **Quick HTTP server**: `python3 -m http.server 8000`
6. **Docker for databases**: `docker run -d -p 5432:5432 postgres`
7. **Process monitoring**: `htop` or `btop` for interactive view
8. **Network debugging**: `mtr` combines ping and traceroute
9. **Find files fast**: `fd pattern` instead of `find -name pattern`
10. **Search code fast**: `rg pattern` instead of `grep -r pattern`

## Getting Help

Most commands support `--help` or `-h` flags:
```bash
command --help
man command                          # Manual page
tldr command                         # Simplified examples (if installed)
```

---

**Note**: This is Claudian OS, where you (Claude) are the primary operator.
Use these tools to explore, create, automate, and control the entire system.
The desktop, browser, and all applications are yours to command.
