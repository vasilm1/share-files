#!/bin/bash

# Obelion Linux Builder
# This script creates custom AI-focused Linux distribution ISOs for both ARM64 and x86_64

set -e  # Exit on error

# Configuration
WORK_DIR="$HOME/obelion-build"
ISO_DIR="$WORK_DIR/iso"
MOUNT_DIR="$WORK_DIR/mnt"
OUTPUT_DIR="$WORK_DIR/output"

# ISO URLs for both architectures
ARM64_ISO_URL="https://cdimage.ubuntu.com/ubuntu-server/jammy/daily-live/current/jammy-live-server-arm64.iso"
X86_64_ISO_URL="https://releases.ubuntu.com/22.04.3/ubuntu-22.04.3-live-server-amd64.iso"

# Branding
DISTRO_NAME="Obelion"
DISTRO_VERSION="1.0"
DISTRO_CODENAME="ArcticFox"
DISTRO_DESCRIPTION="AI Development Platform"

# Colors for pretty output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print with color
print_status() {
    echo -e "${BLUE}[$DISTRO_NAME]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[Success]${NC} $1"
}

# Function to build ISO for specific architecture
build_iso() {
    local arch=$1
    local iso_url=$2
    local custom_dir="$WORK_DIR/custom-$arch"
    
    print_status "Building $arch version..."
    
    # Create directories
    mkdir -p "$ISO_DIR" "$MOUNT_DIR" "$custom_dir" "$OUTPUT_DIR"
    
    # Download ISO if not present
    local iso_file="$ISO_DIR/ubuntu-server-$arch.iso"
    if [ ! -f "$iso_file" ]; then
        print_status "Downloading Ubuntu Server ISO for $arch..."
        wget -O "$iso_file" "$iso_url"
    fi
    
    # Mount and copy ISO contents
    print_status "Mounting and copying ISO contents for $arch..."
    sudo mount -o loop "$iso_file" "$MOUNT_DIR"
    rsync -av "$MOUNT_DIR/" "$custom_dir/"
    sudo umount "$MOUNT_DIR"
    
    # Create custom package list
    cat > "$custom_dir/packages.list" << EOF
# Desktop Environment
xfce4
xfce4-goodies
lightdm
arc-theme
papirus-icon-theme
plank
rofi

# Development Tools
build-essential
git
curl
wget
python3
python3-pip
python3-venv
nodejs
npm
rustc
cargo
cuda-toolkit
nvidia-driver-latest
docker.io
docker-compose
golang
openjdk-17-jdk

# IDEs and Editors
visual-studio-code
jupyter-notebook
sublime-text
neovim

# AI/ML Libraries
python3-numpy
python3-pandas
python3-scikit-learn
python3-tensorflow
python3-torch
python3-matplotlib
python3-opencv
python3-nltk

# System Tools
htop
neofetch
net-tools
tldr
bat
exa
ripgrep
fd-find
zsh
tmux
EOF

    # Copy post-install script and other files
    cp -r custom-files/* "$custom_dir/"
    
    # Create ISO
    print_status "Creating $arch ISO..."
    cd "$custom_dir"
    
    if [ "$arch" = "arm64" ]; then
        # ARM64-specific ISO creation
        sudo xorriso -as mkisofs -r \
            -V "${DISTRO_NAME}_Linux" \
            -o "$OUTPUT_DIR/${DISTRO_NAME,,}-$DISTRO_VERSION-$arch.iso" \
            -J -l -b isolinux/isolinux.bin \
            -c isolinux/boot.cat \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            -eltorito-alt-boot \
            -e boot/grub/efi.img \
            -no-emul-boot \
            -isohybrid-gpt-basdat \
            -isohybrid-apm-hfsplus \
            .
    else
        # x86_64-specific ISO creation
        sudo xorriso -as mkisofs -r \
            -V "${DISTRO_NAME}_Linux" \
            -o "$OUTPUT_DIR/${DISTRO_NAME,,}-$DISTRO_VERSION-$arch.iso" \
            -b isolinux/isolinux.bin \
            -c isolinux/boot.cat \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            -eltorito-alt-boot \
            -e boot/grub/efi.img \
            -no-emul-boot \
            .
    fi
    
    print_success "$arch ISO has been created!"
}

# Create directory for common files
mkdir -p custom-files
cp -r branding post-install.sh isolinux custom-files/

# Build both architectures
print_status "Starting multi-architecture build..."
build_iso "arm64" "$ARM64_ISO_URL"
build_iso "x86_64" "$X86_64_ISO_URL"

print_success "Build complete! ISOs are available at:"
print_success "ARM64: $OUTPUT_DIR/${DISTRO_NAME,,}-$DISTRO_VERSION-arm64.iso"
print_success "x86_64: $OUTPUT_DIR/${DISTRO_NAME,,}-$DISTRO_VERSION-x86_64.iso"
print_success "You can now burn these ISOs to USB drives using 'dd' or your preferred tool." 
