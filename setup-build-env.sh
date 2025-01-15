#!/bin/bash

# Exit on error
set -e

# Colors for pretty output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Print with color
print_status() {
    echo -e "${BLUE}[Setup]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[Success]${NC} $1"
}

# Check if running on macOS
if [[ "$OSTYPE" == "darwin"* ]]; then
    print_status "Setting up build environment for macOS..."
    print_status "Installing VirtualBox for building the ISO..."
    
    # Check if Homebrew is installed
    if ! command -v brew &> /dev/null; then
        print_status "Installing Homebrew..."
        /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
    fi
    
    # Install VirtualBox
    brew install --cask virtualbox
    
    # Download Ubuntu Server ISO for VM
    UBUNTU_ISO_URL="https://releases.ubuntu.com/22.04.3/ubuntu-22.04.3-live-server-amd64.iso"
    UBUNTU_ISO="$HOME/Downloads/ubuntu-server.iso"
    
    if [ ! -f "$UBUNTU_ISO" ]; then
        print_status "Downloading Ubuntu Server ISO..."
        curl -L "$UBUNTU_ISO_URL" -o "$UBUNTU_ISO"
    fi
    
    print_status "Creating VirtualBox VM..."
    VM_NAME="ObelionBuild"
    
    # Create VM if it doesn't exist
    if ! VBoxManage showvminfo "$VM_NAME" &> /dev/null; then
        VBoxManage createvm --name "$VM_NAME" --ostype Ubuntu_64 --register
        VBoxManage modifyvm "$VM_NAME" --memory 4096 --cpus 2
        VBoxManage createhd --filename "$HOME/VirtualBox VMs/$VM_NAME/$VM_NAME.vdi" --size 50000
        VBoxManage storagectl "$VM_NAME" --name "SATA Controller" --add sata --controller IntelAhci
        VBoxManage storageattach "$VM_NAME" --storagectl "SATA Controller" --port 0 --device 0 --type hdd --medium "$HOME/VirtualBox VMs/$VM_NAME/$VM_NAME.vdi"
        VBoxManage storagectl "$VM_NAME" --name "IDE Controller" --add ide
        VBoxManage storageattach "$VM_NAME" --storagectl "IDE Controller" --port 0 --device 0 --type dvddrive --medium "$UBUNTU_ISO"
    fi
    
    print_success "VirtualBox VM setup complete!"
    print_status "Please:"
    echo "1. Start the VM: VBoxManage startvm \"$VM_NAME\""
    echo "2. Install Ubuntu Server"
    echo "3. After installation, copy create-obelion.sh to the VM"
    echo "4. Inside the VM, run: ./create-obelion.sh"

else
    # Running on Linux
    print_status "Setting up build environment for Linux..."
    
    # Add universe repository and enable all package sources
    print_status "Adding required repositories..."
    sudo add-apt-repository universe
    sudo add-apt-repository multiverse
    sudo sed -i 's/# deb/deb/g' /etc/apt/sources.list
    
    # Update package list
    print_status "Updating package list..."
    sudo apt-get update
    
    # Install required packages
    print_status "Installing required packages..."
    sudo apt-get install -y \
        xorriso \
        wget \
        rsync \
        genisoimage \
        squashfs-tools \
        syslinux-common \
        syslinux-utils \
        isolinux \
        binutils \
        grub-common \
        grub-gfxpayload-lists \
        grub-pc-bin \
        grub-efi-amd64-signed \
        mtools \
        dosfstools \
        python3 \
        python3-pip \
        git \
        curl \
        build-essential \
        zstd \
        debootstrap
    
    # Create work directory
    WORK_DIR="$HOME/obelion-build"
    mkdir -p "$WORK_DIR"
    
    print_success "Build environment setup complete!"
    print_status "You can now run ./create-obelion.sh to build Obelion Linux"
fi 
