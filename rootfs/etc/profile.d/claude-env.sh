# HiDPI environment variables for GTK apps
export GDK_SCALE=2
export GDK_DPI_SCALE=0.5

# Set browser for CLI tools (claude auth login, xdg-open, etc.)
export BROWSER=/usr/local/bin/claude-open-url

# Auto-start X on tty1 login
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec startx
fi
