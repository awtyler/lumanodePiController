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

# Get the directory where this script is located
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
VENV_DIR="$SCRIPT_DIR/venv"

echo "Step 1: Update system packages"
if sudo apt-get update &>/dev/null; then
    echo "✓ Package lists updated"
else
    echo "⚠ Failed to update package lists"
fi

echo
echo "Step 2: Install Docker"
if command -v docker &>/dev/null; then
    DOCKER_VERSION=$(docker --version)
    echo "✓ Docker already installed: $DOCKER_VERSION"
else
    echo "Installing Docker..."
    curl -fsSL https://get.docker.com -o get-docker.sh
    sudo sh get-docker.sh
    rm get-docker.sh
    echo "✓ Docker installed"
    
    # Add user to docker group
    if ! groups $USER | grep -q docker; then
        sudo usermod -aG docker $USER
        echo "⚠ Docker group added. You may need to log out and back in for group changes."
        echo "  Run: newgrp docker"
    fi
fi

echo
echo "Step 3: Install Docker Compose"
if command -v docker-compose &>/dev/null; then
    DC_VERSION=$(docker-compose --version)
    echo "✓ Docker Compose already installed: $DC_VERSION"
else
    echo "Installing Docker Compose..."
    sudo curl -L "https://github.com/docker/compose/releases/latest/download/docker-compose-$(uname -s)-$(uname -m)" -o /usr/local/bin/docker-compose
    sudo chmod +x /usr/local/bin/docker-compose
    echo "✓ Docker Compose installed"
fi

echo
echo "Step 4: Setup Python virtual environment"
if [ -d "$VENV_DIR" ]; then
    echo "✓ Virtual environment already exists"
    # Verify it's still valid
    if [ ! -f "$VENV_DIR/bin/activate" ]; then
        echo "⚠ Virtual environment corrupted, recreating..."
        rm -rf "$VENV_DIR"
        python3 -m venv "$VENV_DIR"
        echo "✓ Virtual environment recreated"
    fi
else
    echo "Creating virtual environment..."
    python3 -m venv "$VENV_DIR"
    echo "✓ Virtual environment created"
fi

echo
echo "Step 5: Install CLI dependencies"
source "$VENV_DIR/bin/activate"
# Only upgrade pip if needed
if pip list --outdated 2>/dev/null | grep -q pip; then
    echo "Upgrading pip..."
    pip install --upgrade pip 2>&1 | grep -v "already satisfied" || true
fi
# Install/update requests
pip install requests 2>&1 | grep -v "already satisfied" || true
echo "✓ Dependencies ready"
deactivate

echo
echo "Step 6: Setup CLI tool"
CLI_TOOL="/usr/local/bin/lumanode"

if [ -f "$CLI_TOOL" ]; then
    echo "Checking if CLI tool needs updating..."
    # Check if the wrapper points to correct venv
    if grep -q "$SCRIPT_DIR/venv" "$CLI_TOOL"; then
        echo "✓ CLI tool already configured"
    else
        echo "Updating CLI tool..."
        cat > /tmp/lumanode-wrapper.sh <<EOF
#!/bin/bash
source $SCRIPT_DIR/venv/bin/activate
exec python3 $SCRIPT_DIR/cli/lumanodesdk.py "\$@"
EOF
        sudo cp /tmp/lumanode-wrapper.sh "$CLI_TOOL"
        sudo chmod +x "$CLI_TOOL"
        rm /tmp/lumanode-wrapper.sh
        echo "✓ CLI tool updated"
    fi
else
    echo "Installing CLI tool..."
    cat > /tmp/lumanode-wrapper.sh <<EOF
#!/bin/bash
source $SCRIPT_DIR/venv/bin/activate
exec python3 $SCRIPT_DIR/cli/lumanodesdk.py "\$@"
EOF
    sudo cp /tmp/lumanode-wrapper.sh "$CLI_TOOL"
    sudo chmod +x "$CLI_TOOL"
    rm /tmp/lumanode-wrapper.sh
    echo "✓ CLI tool installed at $CLI_TOOL"
fi

echo
echo "Step 7: Create project directories"
mkdir -p visualizations data
echo "✓ Project directories ready"

echo
echo "Step 8: Verify Arduino CLI will be installed"
echo "✓ Arduino CLI will auto-install in Docker container on first run"

echo
echo "=== Setup Complete ==="
echo
if [ ! -f "$SCRIPT_DIR/.env" ]; then
    echo "First time setup:"
    echo "1. (Optional) Copy .env.example → .env and customize"
    echo "2. Add .ino files to visualizations/"
    echo "3. Run: docker-compose up -d"
    echo
fi

echo "Next steps:"
echo "1. Start services: docker-compose up -d"
echo "2. Wait ~30 seconds for container startup"
echo "3. Access web UI: http://$(hostname -I 2>/dev/null | awk '{print $1}' || echo 'your-pi-ip'):5000"
echo "4. Test CLI: lumanode list"
echo
