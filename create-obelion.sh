#!/bin/bash

# Obelion Linux Builder
# This script creates custom AI-focused Linux distribution ISOs

set -e  # Exit on error

# Configuration
WORK_DIR="$HOME/obelion-build"
ISO_DIR="$WORK_DIR/iso"
MOUNT_DIR="$WORK_DIR/mnt"
OUTPUT_DIR="$WORK_DIR/output"

# ISO URL - using stable release URL
ISO_URL="https://releases.ubuntu.com/22.04.3/ubuntu-22.04.3-live-server-amd64.iso"

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

# Create directories
mkdir -p "$ISO_DIR" "$MOUNT_DIR" "$OUTPUT_DIR"

# Download ISO if not present
ISO_FILE="$ISO_DIR/ubuntu-server.iso"
if [ ! -f "$ISO_FILE" ] || [ ! -s "$ISO_FILE" ]; then
    print_status "Downloading Ubuntu Server ISO..."
    wget --progress=bar:force:noscroll -O "$ISO_FILE" "$ISO_URL"
    
    # Verify download
    if [ ! -s "$ISO_FILE" ]; then
        echo "Error: Download failed"
        exit 1
    fi
fi

print_status "Verifying ISO file..."
if ! file "$ISO_FILE" | grep -q "ISO 9660"; then
    echo "Error: Not a valid ISO image"
    rm -f "$ISO_FILE"
    exit 1
fi

# Create working directory for customization
CUSTOM_DIR="$WORK_DIR/custom"
rm -rf "$CUSTOM_DIR"
mkdir -p "$CUSTOM_DIR"

print_status "Installing required packages..."
sudo apt-get update
sudo apt-get install -y xorriso isolinux syslinux syslinux-common

print_status "Mounting and copying ISO contents..."
sudo mount -o loop "$ISO_FILE" "$MOUNT_DIR"

# Copy all files preserving attributes
rsync -av "$MOUNT_DIR/" "$CUSTOM_DIR/"

# Ensure boot files are copied and have correct permissions
sudo cp -r "$MOUNT_DIR/boot" "$CUSTOM_DIR/"
sudo cp -r "$MOUNT_DIR/EFI" "$CUSTOM_DIR/"
[ -d "$MOUNT_DIR/.disk" ] && sudo cp -r "$MOUNT_DIR/.disk" "$CUSTOM_DIR/"

# Copy isolinux files
sudo mkdir -p "$CUSTOM_DIR/isolinux"
sudo cp /usr/lib/ISOLINUX/isolinux.bin "$CUSTOM_DIR/isolinux/"
sudo cp /usr/lib/syslinux/modules/bios/* "$CUSTOM_DIR/isolinux/"

sudo umount "$MOUNT_DIR"

# Ensure correct permissions
sudo chmod -R 755 "$CUSTOM_DIR"

# Create package list
print_status "Creating package list..."
cat > "$CUSTOM_DIR/packages.list" << EOF
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

# Create post-install script
print_status "Creating post-install configuration..."
cat > "$CUSTOM_DIR/post-install.sh" << 'EOF'
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

chmod +x "$CUSTOM_DIR/post-install.sh"

# Create custom ISO
print_status "Creating custom ISO..."
cd "$CUSTOM_DIR"

# Convert distro name to lowercase for filename
DISTRO_NAME_LOWER=$(echo "$DISTRO_NAME" | tr '[:upper:]' '[:lower:]')

# Check if xorriso is installed
if ! command -v xorriso >/dev/null 2>&1; then
    echo "Error: xorriso is not installed. Installing now..."
    sudo apt-get update && sudo apt-get install -y xorriso
fi

# Check if required boot files exist
if [ ! -f "isolinux/isolinux.bin" ]; then
    echo "Error: isolinux.bin not found. Installing syslinux-common..."
    sudo apt-get update && sudo apt-get install -y syslinux-common
fi

# Create the ISO with error handling
sudo xorriso -as mkisofs \
    -iso-level 3 \
    -full-iso9660-filenames \
    -volid "Obelion_Linux" \
    -output "$OUTPUT_DIR/$DISTRO_NAME_LOWER-$DISTRO_VERSION.iso" \
    -eltorito-boot isolinux/isolinux.bin \
    -eltorito-catalog isolinux/boot.cat \
    -no-emul-boot -boot-load-size 4 -boot-info-table \
    -isohybrid-mbr /usr/lib/ISOLINUX/isohdpfx.bin \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    -isohybrid-gpt-basdat \
    "$CUSTOM_DIR" || {
        echo "Error: ISO creation failed"
        exit 1
    }

print_success "Build complete! ISO is available at:"
print_success "$OUTPUT_DIR/$DISTRO_NAME_LOWER-$DISTRO_VERSION.iso"
print_success "You can now burn this ISO to a USB drive using 'dd' or your preferred tool." 
