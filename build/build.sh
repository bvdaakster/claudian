#!/bin/bash
set -e

#==============================================================================
# Claudian Build Script
# Builds a minimal Debian-based distro for Claude Code to operate the machine
#==============================================================================

# --- Configuration ---
DEBIAN_RELEASE="bookworm"  # Debian 12 stable
BUILD_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$BUILD_DIR")"
ROOTFS_OVERLAY="$PROJECT_ROOT/rootfs"
DEBIAN_ROOT="$BUILD_DIR/debian-root"
PACKAGES_FILE="$BUILD_DIR/base-packages.txt"
MCP_DIR="/opt/claudian/mcp"
DISK_IMAGE="$BUILD_DIR/claudian.img"
CREATE_DISK_IMAGE="${CREATE_DISK_IMAGE:-yes}"  # Set to 'no' to skip image creation
INCLUDE_NONFREE_FIRMWARE="${INCLUDE_NONFREE_FIRMWARE:-no}"  # Set to 'yes' to include WiFi/hardware firmware
# ANTHROPIC_API_KEY - Optional: Include API key in build (skips onboarding)

# Colors for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[Claudian]${NC} $1"
}

success() {
    echo -e "${GREEN}[✓]${NC} $1"
}

error() {
    echo -e "${RED}[✗]${NC} $1"
    exit 1
}

# --- Cleanup trap ---
# Ensures all mounts and loop devices are cleaned up on exit, error, or Ctrl+C
cleanup() {
    local exit_code=$?
    log "Cleaning up mounts and loop devices..."

    # Unmount disk image mount point
    MOUNT_POINT="$BUILD_DIR/mnt"
    umount "$MOUNT_POINT/dev/pts" 2>/dev/null || true
    umount "$MOUNT_POINT/dev" 2>/dev/null || true
    umount "$MOUNT_POINT/sys" 2>/dev/null || true
    umount "$MOUNT_POINT/proc" 2>/dev/null || true
    umount "$MOUNT_POINT/boot/efi" 2>/dev/null || true
    umount "$MOUNT_POINT" 2>/dev/null || true

    # Unmount chroot filesystems
    umount "$DEBIAN_ROOT/dev/pts" 2>/dev/null || true
    umount "$DEBIAN_ROOT/dev" 2>/dev/null || true
    umount "$DEBIAN_ROOT/sys" 2>/dev/null || true
    umount "$DEBIAN_ROOT/proc" 2>/dev/null || true

    # Detach loop devices associated with our image
    if [ -n "$LOOP_DEV" ]; then
        kpartx -d "$LOOP_DEV" 2>/dev/null || true
        losetup -d "$LOOP_DEV" 2>/dev/null || true
    fi

    if [ $exit_code -ne 0 ]; then
        echo ""
        error "Build failed! All mounts have been cleaned up safely."
    fi
}
trap cleanup EXIT

# Check if running as root
if [ "$EUID" -ne 0 ]; then
    error "Please run as root (required for debootstrap and chroot)"
fi

# Check and install required tools
log "Checking for required tools..."
command -v rsync >/dev/null 2>&1 || {
    log "Installing rsync..."
    apt-get update && apt-get install -y rsync
}
command -v debootstrap >/dev/null 2>&1 || {
    log "Installing debootstrap..."
    apt-get install -y debootstrap
}

# --- Phase 1: Debootstrap ---
log "Phase 1: Creating minimal Debian base system..."
if [ -d "$DEBIAN_ROOT" ]; then
    log "Debian root already exists. Skipping debootstrap."
else
    log "Running debootstrap for $DEBIAN_RELEASE..."
    debootstrap --arch=amd64 "$DEBIAN_RELEASE" "$DEBIAN_ROOT" http://deb.debian.org/debian/
    success "Debootstrap completed"
fi

# Enable non-free-firmware repo for WiFi/hardware firmware
if [ "$INCLUDE_NONFREE_FIRMWARE" = "yes" ]; then
    log "Enabling non-free-firmware repository for hardware support..."
    cat > "$DEBIAN_ROOT/etc/apt/sources.list" <<EOF
deb http://deb.debian.org/debian $DEBIAN_RELEASE main contrib non-free-firmware
deb http://deb.debian.org/debian $DEBIAN_RELEASE-updates main contrib non-free-firmware
deb http://security.debian.org/debian-security $DEBIAN_RELEASE-security main contrib non-free-firmware
EOF
    success "Non-free firmware repository enabled"
fi

# --- Phase 2: Copy rootfs overlay ---
log "Phase 2: Copying configuration overlay..."
# Use -rlptD instead of -a to avoid copying host user ownership (-a = -rlptgoD)
# Since build runs as root, all overlay files will be owned by root:root
rsync -rlptD --exclude='.gitkeep' "$ROOTFS_OVERLAY/" "$DEBIAN_ROOT/"

# Copy extra packages list for onboarding installation
mkdir -p "$DEBIAN_ROOT/opt/claudian"
cp "$BUILD_DIR/extra-packages.txt" "$DEBIAN_ROOT/opt/claudian/"
success "Configuration overlay applied"

# Copy MCP server files
log "Copying MCP server to /opt/claudian/mcp..."
mkdir -p "$DEBIAN_ROOT$MCP_DIR"
cp -r "$PROJECT_ROOT/mcp/"* "$DEBIAN_ROOT$MCP_DIR/"
success "MCP server files copied"

# --- Phase 3: Install base packages ---
log "Phase 3: Installing base packages..."

# Mount necessary filesystems for chroot
mount -t proc none "$DEBIAN_ROOT/proc" 2>/dev/null || true
mount -t sysfs none "$DEBIAN_ROOT/sys" 2>/dev/null || true
mount -o bind /dev "$DEBIAN_ROOT/dev" 2>/dev/null || true
mount -o bind /dev/pts "$DEBIAN_ROOT/dev/pts" 2>/dev/null || true

# Create package install script
cat > "$DEBIAN_ROOT/tmp/install-packages.sh" <<'EOF'
#!/bin/bash
set -e

# Update package lists
apt-get update

# Read packages from file (skip comments and empty lines)
PACKAGES=$(grep -v '^#' /tmp/base-packages.txt | grep -v '^$' | tr '\n' ' ')

# Install packages
DEBIAN_FRONTEND=noninteractive apt-get install -y $PACKAGES

# Clean up
apt-get clean
EOF

chmod +x "$DEBIAN_ROOT/tmp/install-packages.sh"
cp "$PACKAGES_FILE" "$DEBIAN_ROOT/tmp/base-packages.txt"

chroot "$DEBIAN_ROOT" /tmp/install-packages.sh
success "Base packages installed"

# Install non-free firmware if enabled
if [ "$INCLUDE_NONFREE_FIRMWARE" = "yes" ]; then
    log "Installing WiFi and hardware firmware..."
    chroot "$DEBIAN_ROOT" apt-get install -y firmware-iwlwifi firmware-realtek firmware-atheros wireless-regdb
    success "Non-free firmware installed"
fi

# --- Phase 4: Install Chromium ---
log "Phase 4: Chromium should be installed via base packages"
success "Chromium configuration complete"

# --- Phase 5: Install Node.js 22 LTS ---
log "Phase 5: Installing Node.js 22 LTS via NodeSource..."
cat > "$DEBIAN_ROOT/tmp/install-node.sh" <<'EOF'
#!/bin/bash
set -e

# Remove Debian's older Node.js if installed
apt-get remove -y nodejs npm 2>/dev/null || true

# Install Node.js 22 LTS from NodeSource
curl -fsSL https://deb.nodesource.com/setup_22.x | bash -
apt-get install -y nodejs

# Verify installation
node --version
npm --version
EOF

chmod +x "$DEBIAN_ROOT/tmp/install-node.sh"
chroot "$DEBIAN_ROOT" /tmp/install-node.sh
success "Node.js installed"

# --- Phase 6: Install Claude Code ---
log "Phase 6: Installing Claude Code globally..."
cat > "$DEBIAN_ROOT/tmp/install-claude.sh" <<'EOF'
#!/bin/bash
set -e

# Install Claude Code globally
npm install -g @anthropic-ai/claude-code

# Verify installation
claude --version || echo "Claude Code installed (version check may fail without API key)"
EOF

chmod +x "$DEBIAN_ROOT/tmp/install-claude.sh"
chroot "$DEBIAN_ROOT" /tmp/install-claude.sh
success "Claude Code installed"

# --- Phase 7: Install MCP dependencies ---
log "Phase 7: Installing MCP server dependencies..."
cat > "$DEBIAN_ROOT/tmp/install-mcp.sh" <<EOF
#!/bin/bash
set -e

cd $MCP_DIR
npm install

# Make server executable
chmod +x server.js
EOF

chmod +x "$DEBIAN_ROOT/tmp/install-mcp.sh"
chroot "$DEBIAN_ROOT" /tmp/install-mcp.sh
success "MCP dependencies installed"

# --- Phase 8: Enable services ---
log "Phase 8: Enabling systemd services..."
cat > "$DEBIAN_ROOT/tmp/enable-services.sh" <<'EOF'
#!/bin/bash
set -e

# Enable NetworkManager
systemctl enable NetworkManager

# Enable SSH server
systemctl enable ssh

echo "Services enabled"
EOF

chmod +x "$DEBIAN_ROOT/tmp/enable-services.sh"
chroot "$DEBIAN_ROOT" /tmp/enable-services.sh
success "Services enabled"

# --- Phase 9: Set root password ---
log "Phase 9: Setting root password..."
log "You can set a custom password or press Enter to set 'claudian' as default"
read -sp "Enter root password (or press Enter for default): " ROOT_PASSWORD
echo

if [ -z "$ROOT_PASSWORD" ]; then
    ROOT_PASSWORD="claudian"
    log "Using default password: claudian"
fi

echo "root:$ROOT_PASSWORD" | chroot "$DEBIAN_ROOT" chpasswd
success "Root password set"

# --- Create claude user ---
log "Creating claude user..."

cat > "$DEBIAN_ROOT/tmp/create-claude-user.sh" <<'EOF'
#!/bin/bash
set -e

# Create claude user with home directory (skip if already exists)
if id claude &>/dev/null; then
    echo "Claude user already exists, skipping creation"
else
    useradd -m -s /bin/bash -G sudo claude
fi

# Add to docker group if it exists (docker may be installed later)
groupadd -f docker 2>/dev/null || true
usermod -aG docker claude 2>/dev/null || true

# Set proper permissions on sudoers file (will be configured during onboarding)
if [ -f /etc/sudoers.d/claude ]; then
    chmod 0440 /etc/sudoers.d/claude
fi

echo "Claude user created"
EOF

chmod +x "$DEBIAN_ROOT/tmp/create-claude-user.sh"
chroot "$DEBIAN_ROOT" /tmp/create-claude-user.sh
success "Claude user created (sudo will be configured during onboarding)"

# --- Phase 10: Create bootable image ---
log "Phase 10: Finalizing build..."

# Set hostname
echo "claudian" > "$DEBIAN_ROOT/etc/hostname"

# Create /etc/hosts
cat > "$DEBIAN_ROOT/etc/hosts" <<EOF
127.0.0.1       localhost
127.0.1.1       claudian

::1             localhost ip6-localhost ip6-loopback
ff02::1         ip6-allnodes
ff02::2         ip6-allrouters
EOF

# Create fstab (basic version - will be updated with UUIDs for disk image)
cat > "$DEBIAN_ROOT/etc/fstab" <<EOF
# Claudian fstab
/dev/sda2    /           ext4    errors=remount-ro    0    1
/dev/sda1    /boot/efi   vfat    umask=0077           0    1
proc         /proc       proc    defaults             0    0
sysfs        /sys        sysfs   defaults             0    0
devpts       /dev/pts    devpts  defaults             0    0
tmpfs        /tmp        tmpfs   defaults             0    0
EOF

# Create environment file for ANTHROPIC_API_KEY and CLAUDE_CMD
if [ "$BUILD_WITH_BYPASS" = "yes" ]; then
    log "Configuring with FULL PERMISSION BYPASS mode"
    cat > "$DEBIAN_ROOT/etc/environment" <<'EOF'
# Claudian environment variables
# API key will be configured during first-boot onboarding
# Or you can set it manually here:
# ANTHROPIC_API_KEY=your_key_here

# Claude command with FULL PERMISSION BYPASS (configured during build)
CLAUDE_CMD="claude --allow-dangerously-skip-permissions --permission-mode bypassPermissions --mcp-config ~/.config/claude/mcp.json"
EOF
else
    cat > "$DEBIAN_ROOT/etc/environment" <<'EOF'
# Claudian environment variables
# API key will be configured during first-boot onboarding
# Or you can set it manually here:
# ANTHROPIC_API_KEY=your_key_here

# Configure Claude command flags:
# Default: claude --mcp-config ~/.config/claude/mcp.json
# Bypass permissions: claude --allow-dangerously-skip-permissions --permission-mode bypassPermissions
# CLAUDE_CMD="claude --allow-dangerously-skip-permissions --permission-mode bypassPermissions --mcp-config ~/.config/claude/mcp.json"
EOF
fi

# If API key provided during build, add it and skip onboarding
if [ -n "$ANTHROPIC_API_KEY" ]; then
    log "Including API key in build (onboarding will be skipped)"
    echo "ANTHROPIC_API_KEY=$ANTHROPIC_API_KEY" >> "$DEBIAN_ROOT/etc/environment"
    # Mark onboarding as complete so it doesn't run on first boot
    touch "$DEBIAN_ROOT/home/claude/.claudian-onboarding-complete"
    success "API key included in build"
fi

success "Build configuration complete"

# --- Fix all file permissions inside the chroot ---
# This is critical: rsync from the host copies files with the host user's UID.
# We must fix ownership INSIDE the chroot where the user database is correct.
log "Fixing file permissions inside chroot..."
cat > "$DEBIAN_ROOT/tmp/fix-permissions.sh" <<'EOF'
#!/bin/bash
set -e

# Fix sudoers (must be root:root with strict permissions)
chown root:root /etc/sudoers.d/
chmod 0755 /etc/sudoers.d/
if [ -f /etc/sudoers.d/claude ]; then
    chown root:root /etc/sudoers.d/claude
    chmod 0440 /etc/sudoers.d/claude
fi

# Verify sudo binary has setuid bit
chmod 4755 /usr/bin/sudo

# Claude's home directory must be owned by claude user
if id claude &>/dev/null; then
    chown -R claude:claude /home/claude/
fi

echo "Permissions fixed"
EOF

chmod +x "$DEBIAN_ROOT/tmp/fix-permissions.sh"
chroot "$DEBIAN_ROOT" /tmp/fix-permissions.sh
success "File permissions fixed"

# Unmount chroot filesystems before creating disk image
log "Unmounting chroot filesystems..."
umount "$DEBIAN_ROOT/dev/pts" 2>/dev/null || true
umount "$DEBIAN_ROOT/dev" 2>/dev/null || true
umount "$DEBIAN_ROOT/sys" 2>/dev/null || true
umount "$DEBIAN_ROOT/proc" 2>/dev/null || true

# --- Phase 11: Create bootable disk image ---
if [ "$CREATE_DISK_IMAGE" = "yes" ]; then
    log "Phase 11: Creating bootable disk image..."

    # Check for required tools
    command -v parted >/dev/null 2>&1 || apt-get install -y parted
    command -v kpartx >/dev/null 2>&1 || apt-get install -y kpartx

    # Remove old image if exists
    if [ -f "$DISK_IMAGE" ]; then
        log "Removing existing disk image..."
        rm -f "$DISK_IMAGE"
    fi

    # Calculate required disk size (actual size + 1GB overhead for filesystem + bootloader)
    log "Calculating required disk size..."
    ROOTFS_SIZE=$(du -sb "$DEBIAN_ROOT" | cut -f1)
    OVERHEAD_BYTES=$((2 * 1024 * 1024 * 1024))  # 2GB overhead (includes 512MB EFI partition)
    TOTAL_BYTES=$((ROOTFS_SIZE + OVERHEAD_BYTES))
    TOTAL_MB=$((TOTAL_BYTES / 1024 / 1024))

    log "Root filesystem size: $(du -sh "$DEBIAN_ROOT" | cut -f1)"
    log "Creating ${TOTAL_MB}MB disk image (will auto-expand on first boot)..."

    # Create disk image
    fallocate -l "${TOTAL_MB}M" "$DISK_IMAGE" || dd if=/dev/zero of="$DISK_IMAGE" bs=1M count="$TOTAL_MB"

    # Set up loop device
    log "Setting up loop device..."
    LOOP_DEV=$(losetup -f)
    losetup "$LOOP_DEV" "$DISK_IMAGE"

    # Partition the disk with GPT for UEFI boot
    # Partition 1: EFI System Partition (512MB, FAT32)
    # Partition 2: Root filesystem (ext4, rest of disk)
    log "Partitioning disk (GPT/UEFI)..."
    parted -s "$LOOP_DEV" mklabel gpt
    parted -s "$LOOP_DEV" mkpart ESP fat32 1MiB 513MiB
    parted -s "$LOOP_DEV" set 1 esp on
    parted -s "$LOOP_DEV" mkpart root ext4 513MiB 100%

    # Inform kernel of partition changes
    partprobe "$LOOP_DEV" 2>/dev/null || true
    sleep 1

    # Map partitions
    kpartx -a "$LOOP_DEV"
    sleep 1

    # Find the partition devices
    LOOP_NAME=$(basename "$LOOP_DEV")
    EFI_DEV="/dev/mapper/${LOOP_NAME}p1"
    ROOT_DEV="/dev/mapper/${LOOP_NAME}p2"

    # Wait for partition devices to appear
    for i in {1..10}; do
        if [ -b "$EFI_DEV" ] && [ -b "$ROOT_DEV" ]; then
            break
        fi
        sleep 1
    done

    if [ ! -b "$ROOT_DEV" ]; then
        error "Partition device $ROOT_DEV not found"
    fi

    # Format partitions
    log "Formatting partitions..."
    mkfs.fat -F32 "$EFI_DEV"
    mkfs.ext4 -F "$ROOT_DEV"

    # Mount root partition
    MOUNT_POINT="$BUILD_DIR/mnt"
    mkdir -p "$MOUNT_POINT"
    mount "$ROOT_DEV" "$MOUNT_POINT"

    # Mount EFI partition
    mkdir -p "$MOUNT_POINT/boot/efi"
    mount "$EFI_DEV" "$MOUNT_POINT/boot/efi"

    # Copy rootfs to disk
    log "Copying root filesystem to disk (this may take a while)..."
    rsync -aAX --info=progress2 "$DEBIAN_ROOT/" "$MOUNT_POINT/"

    # Update fstab for the disk image (use UUIDs for reliability)
    ROOT_UUID=$(blkid -s UUID -o value "$ROOT_DEV")
    EFI_UUID=$(blkid -s UUID -o value "$EFI_DEV")

    cat > "$MOUNT_POINT/etc/fstab" <<EOF
# Claudian fstab for disk image
UUID=$ROOT_UUID    /           ext4    errors=remount-ro    0    1
UUID=$EFI_UUID     /boot/efi   vfat    umask=0077           0    1
proc               /proc       proc    defaults             0    0
sysfs              /sys        sysfs   defaults             0    0
devpts             /dev/pts    devpts  defaults             0    0
tmpfs              /tmp        tmpfs   defaults             0    0
EOF

    # Mount necessary filesystems for GRUB installation
    mount -t proc none "$MOUNT_POINT/proc"
    mount -t sysfs none "$MOUNT_POINT/sys"
    mount -o bind /dev "$MOUNT_POINT/dev"
    mount -o bind /dev/pts "$MOUNT_POINT/dev/pts"

    # Install GRUB EFI bootloader
    log "Installing GRUB EFI bootloader..."
    cat > "$MOUNT_POINT/tmp/install-grub.sh" <<'EOF'
#!/bin/bash
set -e

# Install grub EFI packages if not already installed
apt-get update
DEBIAN_FRONTEND=noninteractive apt-get install -y grub-efi-amd64 efibootmgr linux-image-amd64 dosfstools

# Install GRUB for EFI (removable flag makes it work on any UEFI system without NVRAM entry)
grub-install --target=x86_64-efi --efi-directory=/boot/efi --bootloader-id=claudian --removable --no-nvram

# Generate GRUB config
update-grub

echo "GRUB EFI installed successfully"
EOF

    chmod +x "$MOUNT_POINT/tmp/install-grub.sh"
    chroot "$MOUNT_POINT" /tmp/install-grub.sh

    # Cleanup disk image mounts (trap will also catch these if we fail)
    log "Cleaning up disk image mounts..."
    sync
    umount "$MOUNT_POINT/dev/pts" 2>/dev/null || true
    umount "$MOUNT_POINT/dev" 2>/dev/null || true
    umount "$MOUNT_POINT/sys" 2>/dev/null || true
    umount "$MOUNT_POINT/proc" 2>/dev/null || true
    umount "$MOUNT_POINT/boot/efi" 2>/dev/null || true
    umount "$MOUNT_POINT" 2>/dev/null || true
    kpartx -d "$LOOP_DEV" 2>/dev/null || true
    losetup -d "$LOOP_DEV" 2>/dev/null || true
    LOOP_DEV=""  # Clear so trap doesn't try again
    rmdir "$MOUNT_POINT" 2>/dev/null || true

    success "Bootable disk image created: $DISK_IMAGE"
    log "You can write this to a USB drive with: sudo dd if=$DISK_IMAGE of=/dev/sdX bs=4M status=progress"
else
    log "Skipping disk image creation (CREATE_DISK_IMAGE=no)"
fi

success "Claudian build complete!"
echo ""
log "Build location: $DEBIAN_ROOT"
if [ "$CREATE_DISK_IMAGE" = "yes" ]; then
    log "Bootable image: $DISK_IMAGE ($(du -h "$DISK_IMAGE" | cut -f1))"
fi
echo ""
log "Next steps:"
if [ "$CREATE_DISK_IMAGE" = "yes" ]; then
    echo "  1. Write to USB: sudo dd if=$DISK_IMAGE of=/dev/sdX bs=4M status=progress"
    echo "     (Replace /dev/sdX with your USB device - check with 'lsblk')"
    echo ""
    echo "  2. Boot from the USB drive"
    echo "     - First boot will run interactive onboarding wizard"
    echo "     - Configure network, partition, security, and authentication"
else
    echo "  1. Deploy to VM or create bootable image"
    echo "     - Or tar it up: cd $DEBIAN_ROOT && tar czf ../claudian-rootfs.tar.gz ."
    echo ""
    echo "  2. On first boot, onboarding will guide you through setup"
    echo "     - Configure network, partition, security, and authentication"
fi
echo ""
log "Users:"
echo "  - root: password '${ROOT_PASSWORD}'"
echo "  - claude: autologin enabled, sudo will be configured during onboarding"
echo ""
if [ -n "$ANTHROPIC_API_KEY" ]; then
    log "Authentication: API key included in build (onboarding skipped)"
else
    log "Authentication: Will be configured via first-boot onboarding"
fi
echo ""
log "First boot onboarding will configure:"
echo "  1. Network connectivity (WiFi setup or skip for ethernet)"
echo "  2. Partition size (auto-expand, custom size, or keep current)"
echo "  3. Extra packages (install dev tools, CLI utils, etc.)"
echo "  4. Sudo access (passwordless or password-required)"
echo "  5. Anthropic authentication (browser sign-in or API key)"
if [ "$BUILD_WITH_BYPASS" = "yes" ]; then
    echo ""
    log "⚠️  PERMISSION BYPASS MODE ENABLED - Claude will run with full automation"
fi
echo ""
log "Build options:"
echo "  - Include API key: ANTHROPIC_API_KEY=sk-ant-... sudo -E ./build.sh"
echo "  - Skip disk image: CREATE_DISK_IMAGE=no sudo ./build.sh"
echo "  - Permission bypass: BUILD_WITH_BYPASS=yes sudo ./build.sh"
echo "  - WiFi firmware: INCLUDE_NONFREE_FIRMWARE=yes sudo ./build.sh"
