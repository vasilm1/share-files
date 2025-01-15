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
ARM64_ISO_URL="https://cdimage.ubuntu.com/releases/22.04.3/release/ubuntu-22.04.3-live-server-arm64.iso"
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
    if [ ! -f "$iso_file" ] || [ ! -s "$iso_file" ]; then
        print_status "Downloading Ubuntu Server ISO for $arch..."
        rm -f "$iso_file"
        wget --progress=bar:force:noscroll -O "$iso_file" "$iso_url"
        
        # Verify download
        if [ ! -s "$iso_file" ]; then
            echo "Error: Downloaded ISO file is empty or corrupted"
            exit 1
        fi
        
        # Check file size (should be at least 500MB)
        local size=$(stat -f%z "$iso_file" 2>/dev/null || stat -c%s "$iso_file")
        if [ "$size" -lt 524288000 ]; then
            echo "Error: Downloaded ISO file is too small (${size} bytes)"
            echo "Expected size should be at least 500MB"
            rm -f "$iso_file"
            exit 1
        fi
    fi
    
    print_status "Verifying ISO file..."
    if ! file "$iso_file" | grep -q "ISO 9660"; then
        echo "Error: File is not a valid ISO image"
        echo "File details: $(file "$iso_file")"
        rm -f "$iso_file"
        exit 1
    fi
    
    # Mount and copy ISO contents
    print_status "Mounting and copying ISO contents for $arch..."
    
    # Prepare mount point
    sudo rm -rf "$MOUNT_DIR"
    mkdir -p "$MOUNT_DIR"
    
    # Create loop device and mount
    LOOP_DEVICE=$(sudo losetup -f)
    sudo losetup "$LOOP_DEVICE" "$iso_file"
    sudo mount "$LOOP_DEVICE" "$MOUNT_DIR" || {
        echo "Mount failed, trying with -o loop..."
        sudo losetup -d "$LOOP_DEVICE"
        sudo mount -o loop "$iso_file" "$MOUNT_DIR"
    }
    
    rsync -av "$MOUNT_DIR/" "$custom_dir/"
    sudo umount "$MOUNT_DIR" || sudo umount -f "$MOUNT_DIR"
    sudo losetup -d "$LOOP_DEVICE" 2>/dev/null || true
    
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
mkdir -p custom-files/branding
mkdir -p custom-files/isolinux

# Create branding files
cat > custom-files/branding/obelion-logo.txt << EOF
   ____  _          _ _             
  / __ \| |        | (_)            
 | |  | | |__   ___| |_  ___  _ __  
 | |  | | '_ \ / _ \ | |/ _ \| '_ \ 
 | |__| | |_) |  __/ | | (_) | | | |
  \____/|_.__/ \___|_|_|\___/|_| |_|
                                    
     $DISTRO_NAME $DISTRO_VERSION ($DISTRO_CODENAME)
     $DISTRO_DESCRIPTION
EOF

# Create post-install script
cat > custom-files/post-install.sh << 'EOF'
#!/bin/bash

# Set up AI development environment
pip3 install --upgrade pip
pip3 install jupyter torch tensorflow transformers huggingface_hub \
    pandas numpy matplotlib seaborn scikit-learn opencv-python \
    pytest black flake8 mypy poetry

# Install Node.js LTS and global packages
curl -fsSL https://deb.nodesource.com/setup_lts.x | sudo -E bash -
sudo apt-get install -y nodejs
npm install -g typescript ts-node nodemon prettier eslint

# Install Rust and cargo packages
curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y
source $HOME/.cargo/env
cargo install tokei ripgrep fd-find bat exa

# Install Oh My Zsh and plugins
sh -c "$(curl -fsSL https://raw.githubusercontent.com/ohmyzsh/ohmyzsh/master/tools/install.sh)" "" --unattended
git clone https://github.com/zsh-users/zsh-autosuggestions ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-autosuggestions
git clone https://github.com/zsh-users/zsh-syntax-highlighting ${ZSH_CUSTOM:-~/.oh-my-zsh/custom}/plugins/zsh-syntax-highlighting

# Configure XFCE with modern dark theme
xfconf-query -c xsettings -p /Net/ThemeName -s "Arc-Dark"
xfconf-query -c xfwm4 -p /general/theme -s "Arc-Dark"
xfconf-query -c xsettings -p /Net/IconThemeName -s "Papirus-Dark"

# Set up VS Code with extensions
code --install-extension ms-python.python
code --install-extension rust-lang.rust-analyzer
code --install-extension vadimcn.vscode-lldb
code --install-extension ms-toolsai.jupyter
code --install-extension dracula-theme.theme-dracula
code --install-extension PKief.material-icon-theme
code --install-extension esbenp.prettier-vscode
code --install-extension dbaeumer.vscode-eslint
code --install-extension ms-azuretools.vscode-docker
code --install-extension GitHub.copilot

# Create welcome message
cat > /etc/motd << MOTD
Welcome to Obelion Linux - Your AI Development Platform
Version: $DISTRO_VERSION ($DISTRO_CODENAME)

🚀 Quick Start:
- VS Code: code
- Jupyter: jupyter notebook
- System Monitor: htop
- File Explorer: thunar

📚 Documentation: /usr/share/doc/obelion
🐛 Report issues: https://github.com/obelion/issues
🐦 Follow us: https://x.com/ObelionOS
MOTD

# Set up GPU support
ubuntu-drivers autoinstall

# Configure Docker
sudo usermod -aG docker $USER
sudo systemctl enable docker
sudo systemctl start docker

# Create useful aliases
cat >> ~/.zshrc << 'ALIASES'
# Development
alias py='python3'
alias ipy='ipython'
alias jn='jupyter notebook'
alias pip='pip3'
alias g='git'
alias d='docker'
alias dc='docker-compose'

# Modern CLI tools
alias ls='exa'
alias ll='exa -l'
alias la='exa -la'
alias cat='bat'
alias find='fd'
alias grep='rg'
ALIASES

# Create development workspace
mkdir -p ~/workspace/{python,rust,node,go,data}
EOF

# Make post-install script executable
chmod +x custom-files/post-install.sh

# Create isolinux configuration
cat > custom-files/isolinux/txt.cfg << EOF
default install
label install
  menu label ^Install $DISTRO_NAME Linux $DISTRO_VERSION
  kernel /casper/vmlinuz
  append  file=/cdrom/preseed/ubuntu.seed boot=casper initrd=/casper/initrd quiet splash ---
label check
  menu label ^Check disc for defects
  kernel /casper/vmlinuz
  append  boot=casper integrity-check initrd=/casper/initrd quiet splash ---
label memtest
  menu label Test ^memory
  kernel /install/mt86plus
label hd
  menu label ^Boot from first hard disk
  localboot 0x80
EOF

# Build both architectures
print_status "Starting multi-architecture build..."
build_iso "arm64" "$ARM64_ISO_URL"
build_iso "x86_64" "$X86_64_ISO_URL"

print_success "Build complete! ISOs are available at:"
print_success "ARM64: $OUTPUT_DIR/${DISTRO_NAME,,}-$DISTRO_VERSION-arm64.iso"
print_success "x86_64: $OUTPUT_DIR/${DISTRO_NAME,,}-$DISTRO_VERSION-x86_64.iso"
print_success "You can now burn these ISOs to USB drives using 'dd' or your preferred tool." 
