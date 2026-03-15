# HiDPI environment variables for GTK apps
export GDK_SCALE=2
export GDK_DPI_SCALE=0.5

# Auto-start X on tty1 login
if [ -z "$DISPLAY" ] && [ "$(tty)" = "/dev/tty1" ]; then
  exec startx
fi
