#!/bin/bash
set -e

echo "=== Lumanode Pi Controller Setup ==="
echo

# Check if running on Raspberry Pi
if ! grep -q "Raspberry" /proc/device-tree/model 2>/dev/null; then
    echo "WARNING: This script is designed for Raspberry Pi"
    read -p "Continue anyway? (y/n) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        exit 1
    fi
fi

echo "Step 1: Update system packages"
sudo apt-get update
sudo apt-get upgrade -y

echo
echo "Step 2: Install Docker"
if ! command -v docker &> /dev/null; then
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    sudo usermod -aG docker $USER
    echo "Docker installed. You may need to log out and back in for group changes."
else
    echo "Docker already installed"
fi

echo
echo "Step 3: Install Docker Compose"
if ! command -v docker-compose &> /dev/null; then
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "Docker Compose installed"
else
    echo "Docker Compose already installed"
fi

echo
echo "Step 4: Install CLI dependencies"
pip3 install requests

echo
echo "Step 5: Setup CLI tool"
sudo cp cli/lumanodesdk.py /usr/local/bin/lumanode
sudo chmod +x /usr/local/bin/lumanode

echo
echo "Step 6: Create visualizations directory"
mkdir -p visualizations
mkdir -p data

echo
echo "Step 7: Configure Arduino CLI"
# Arduino CLI will auto-install on first run
echo "Arduino CLI will be configured in the Docker container"

echo
echo "=== Basic Setup Complete ==="
echo
echo "Next steps:"
echo "1. Add any .ino files to the visualizations/ folder"
echo "2. Run: docker-compose up -d"
echo "3. Access the web UI at: http://$(hostname -I | awk '{print $1}'):5000"
echo "4. Use CLI: lumanode list"
echo
