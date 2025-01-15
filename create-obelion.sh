#!/bin/bash

# Obelion Linux Builder
# This script creates a custom AI-focused Linux distribution based on Ubuntu

set -e  # Exit on error

# Configuration
WORK_DIR="$HOME/obelion-build"
ISO_DIR="$WORK_DIR/iso"
MOUNT_DIR="$WORK_DIR/mnt"
CUSTOM_DIR="$WORK_DIR/custom"
OUTPUT_DIR="$WORK_DIR/output"
UBUNTU_ISO_URL="https://releases.ubuntu.com/22.04.3/ubuntu-22.04.3-live-server-amd64.iso"
UBUNTU_ISO="$ISO_DIR/ubuntu-server.iso"

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

# Create required directories
print_status "Creating build directories..."
mkdir -p "$ISO_DIR" "$MOUNT_DIR" "$CUSTOM_DIR" "$OUTPUT_DIR"

# Download Ubuntu Server ISO if not present
if [ ! -f "$UBUNTU_ISO" ]; then
    print_status "Downloading Ubuntu Server ISO..."
    wget -O "$UBUNTU_ISO" "$UBUNTU_ISO_URL"
fi

# Mount the ISO
print_status "Mounting Ubuntu ISO..."
sudo mount -o loop "$UBUNTU_ISO" "$MOUNT_DIR"

# Copy ISO contents
print_status "Copying ISO contents..."
rsync -av "$MOUNT_DIR/" "$CUSTOM_DIR/"

# Unmount the ISO
sudo umount "$MOUNT_DIR"

# Create custom package list
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

# Create custom branding
mkdir -p "$CUSTOM_DIR/custom-branding"
cat > "$CUSTOM_DIR/custom-branding/obelion-logo.txt" << EOF
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

# Clone useful AI/ML repositories
mkdir -p ~/Projects
cd ~/Projects

# Common AI/ML repos
git clone https://github.com/huggingface/transformers.git
git clone https://github.com/pytorch/pytorch.git
git clone https://github.com/tensorflow/tensorflow.git
git clone https://github.com/scikit-learn/scikit-learn.git

# Create welcome message and branding
sudo bash -c 'cat > /etc/motd' << MOTD
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

# Create desktop shortcut for social media
cat > "$HOME/Desktop/ObelionOS-Social.desktop" << EOF
[Desktop Entry]
Version=1.0
Type=Link
Name=Follow ObelionOS
Comment=Follow ObelionOS on X/Twitter
Icon=twitter
URL=https://x.com/ObelionOS
EOF

# Make desktop shortcut executable
chmod +x "$HOME/Desktop/ObelionOS-Social.desktop"

# Add social media links to browser bookmarks
mkdir -p "$HOME/.config/gtk-3.0"
cat >> "$HOME/.config/gtk-3.0/bookmarks" << EOF
https://x.com/ObelionOS ObelionOS on X/Twitter
EOF

# Add to documentation
mkdir -p /usr/share/doc/obelion
cat > /usr/share/doc/obelion/README.md << EOF
# Obelion Linux

Welcome to Obelion Linux, your AI Development Platform!

## Quick Links
- Documentation: /usr/share/doc/obelion
- Issues: https://github.com/obelion/issues
- Twitter/X: https://x.com/ObelionOS

## Getting Started
[Documentation content here]
EOF

# Create About dialog branding
cat > "$HOME/.config/xfce4/panel/about.txt" << EOF
Obelion Linux $DISTRO_VERSION ($DISTRO_CODENAME)
AI Development Platform

Follow us:
🐦 https://x.com/ObelionOS
EOF

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
chmod +x "$CUSTOM_DIR/post-install.sh"

# Create custom isolinux configuration
cat > "$CUSTOM_DIR/isolinux/txt.cfg" << EOF
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

# Create new ISO
print_status "Creating $DISTRO_NAME ISO..."
cd "$CUSTOM_DIR"
sudo xorriso -as mkisofs -r \
    -V "${DISTRO_NAME}_Linux" \
    -o "$OUTPUT_DIR/${DISTRO_NAME,,}-$DISTRO_VERSION.iso" \
    -b isolinux/isolinux.bin \
    -c isolinux/boot.cat \
    -no-emul-boot \
    -boot-load-size 4 \
    -boot-info-table \
    -eltorito-alt-boot \
    -e boot/grub/efi.img \
    -no-emul-boot \
    .

print_success "$DISTRO_NAME Linux ISO has been created!"
print_success "Your ISO is available at: $OUTPUT_DIR/${DISTRO_NAME,,}-$DISTRO_VERSION.iso"
print_success "You can now burn this ISO to a USB drive using 'dd' or your preferred tool." 