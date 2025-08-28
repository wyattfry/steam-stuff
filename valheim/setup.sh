#!/bin/bash
# Valheim Server Setup Script
# Run this after cloning the repo on a fresh Debian/Ubuntu system

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

print_status() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_info() { echo -e "${BLUE}ℹ️  $1${NC}"; }

echo "🎮 Valheim Dedicated Server Setup"
echo "=================================="
echo ""

# Check if running as root
if [[ $EUID -eq 0 ]]; then
   print_error "Don't run this script as root! Run as a regular user."
   exit 1
fi

# Update system packages
print_info "Updating system packages..."
sudo apt update

# Install required packages
print_info "Installing required packages..."
sudo apt install -y curl wget tar gzip

# Add 32-bit architecture for SteamCMD
print_info "Adding 32-bit architecture support..."
sudo dpkg --add-architecture i386
sudo apt update

# Install 32-bit libraries for SteamCMD
print_info "Installing 32-bit libraries..."
sudo apt install -y libc6:i386 libstdc++6:i386

# Install SteamCMD
print_info "Installing SteamCMD..."
if [[ ! -d "$HOME/steamcmd" ]]; then
    mkdir -p ~/steamcmd
    cd ~/steamcmd
    curl -sqL "https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz" | tar zxvf -
    print_status "SteamCMD installed"
else
    print_warning "SteamCMD already exists"
fi

# Return to script directory
cd "$(dirname "${BASH_SOURCE[0]}")"

# Create config file from example
if [[ ! -f "valheim-server.conf" ]]; then
    cp valheim-server.conf.example valheim-server.conf
    print_status "Created valheim-server.conf from example"
    print_warning "IMPORTANT: Edit valheim-server.conf to customize your server settings!"
else
    print_warning "valheim-server.conf already exists"
fi

# Create directories
mkdir -p ~/valheim-backups
print_status "Created backup directory"

# Install/Update Valheim server
print_info "Installing/Updating Valheim server..."
cd ~/steamcmd
./steamcmd.sh +force_install_dir "$HOME/Steam/steamapps/common/Valheim dedicated server" +login anonymous +app_update 896660 validate +quit

# Return to script directory
cd "$(dirname "${BASH_SOURCE[0]}")"

print_status "Setup completed successfully!"
echo ""
print_info "Next steps:"
echo "  1. Edit valheim-server.conf to set your server name, password, etc."
echo "  2. Run: ./valheim-server.sh start"
echo "  3. Check status: ./valheim-server.sh status"
echo "  4. View logs: ./valheim-server.sh logs"
echo ""
print_info "Optional: Install as systemd service:"
echo "  sudo ./install-service.sh"
echo ""
print_warning "Remember: Server password must be at least 5 characters!"
