#!/bin/bash
set -e

echo "=== Lumanode Kiosk Mode Setup ==="
echo

# Get the directory where this script is located (parent is the project root)
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

# Get hostname
HOSTNAME=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
KIOSK_URL="http://$HOSTNAME:5000"

echo "Setting up kiosk mode for: $KIOSK_URL"
echo

# Step 1: Check and install required packages
echo "Step 1: Install display server and browser"
PACKAGES_TO_INSTALL=""

for pkg in xserver-xorg xinit chromium-browser unclutter x11-xserver-utils; do
    if ! dpkg -l | grep -q "^ii  $pkg"; then
        PACKAGES_TO_INSTALL="$PACKAGES_TO_INSTALL $pkg"
    fi
done

if [ -n "$PACKAGES_TO_INSTALL" ]; then
    echo "Installing:$PACKAGES_TO_INSTALL"
    sudo apt-get install -y $PACKAGES_TO_INSTALL
    echo "✓ Display packages installed"
else
    echo "✓ All display packages already installed"
fi

echo
echo "Step 2: Create kiosk configuration files"

# Create config directories if needed
mkdir -p ~/.config/lxsession/LXDE-pi
mkdir -p ~/.config/systemd/user

# Check if autostart file exists and needs updating
AUTOSTART_FILE="$HOME/.config/lxsession/LXDE-pi/autostart"
if [ -f "$AUTOSTART_FILE" ]; then
    if grep -q "lumanode" "$AUTOSTART_FILE" 2>/dev/null; then
        echo "✓ LXDE autostart already configured for Lumanode"
    else
        echo "⚠ LXDE autostart exists but doesn't reference Lumanode"
        echo "  Backing up to autostart.bak and creating new config"
        cp "$AUTOSTART_FILE" "${AUTOSTART_FILE}.bak"
        
        cat > "$AUTOSTART_FILE" <<EOF
@xset s off
@xset -dpms
@xset s noblank
@unclutter -idle 1 -root &
@chromium-browser --kiosk --no-first-run --no-default-browser-check --disable-translate --disable-default-apps --no-pings --disable-popup-blocking "$KIOSK_URL"
EOF
        echo "✓ LXDE autostart configured"
    fi
else
    echo "Creating LXDE autostart..."
    cat > "$AUTOSTART_FILE" <<EOF
@xset s off
@xset -dpms
@xset s noblank
@unclutter -idle 1 -root &
@chromium-browser --kiosk --no-first-run --no-default-browser-check --disable-translate --disable-default-apps --no-pings --disable-popup-blocking "$KIOSK_URL"
EOF
    echo "✓ LXDE autostart created"
fi

echo
echo "Step 3: Create systemd user service"

SERVICE_FILE="$HOME/.config/systemd/user/lumanode-kiosk.service"
if [ -f "$SERVICE_FILE" ]; then
    echo "✓ Kiosk systemd service already exists"
else
    echo "Creating systemd user service..."
    cat > "$SERVICE_FILE" <<EOF
[Unit]
Description=Lumanode Kiosk Display
After=network-online.target
Wants=network-online.target

[Service]
Type=simple
Environment="DISPLAY=:0"
ExecStart=/usr/bin/startx -- :0 -nocursor vt7
Restart=unless-stopped
RestartSec=5

[Install]
WantedBy=default.target
EOF
    echo "✓ Systemd service created"
fi

# Reload systemd user daemon
echo "Reloading systemd user daemon..."
systemctl --user daemon-reload 2>/dev/null || echo "  (systemd --user may not be available on this system)"

echo
echo "Step 4: Create X11 startup configuration"

XINITRC_FILE="$HOME/.xinitrc"
if [ -f "$XINITRC_FILE" ]; then
    if grep -q "lumanode" "$XINITRC_FILE" 2>/dev/null; then
        echo "✓ .xinitrc already configured for Lumanode"
    else
        echo "⚠ .xinitrc exists but doesn't reference Lumanode"
        echo "  Backing up to .xinitrc.bak and creating new config"
        cp "$XINITRC_FILE" "${XINITRC_FILE}.bak"
        
        cat > "$XINITRC_FILE" <<'XEOF'
#!/bin/bash
# Disable screensaver and DPMS
xset s off
xset -dpms
xset s noblank

# Hide cursor
unclutter -idle 1 -root &

# Get local IP
HOSTNAME=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
KIOSK_URL="http://$HOSTNAME:5000"

# Start Chromium in kiosk mode
exec /usr/bin/chromium-browser \
    --kiosk \
    --no-first-run \
    --no-default-browser-check \
    --disable-translate \
    --disable-default-apps \
    --no-pings \
    --disable-popup-blocking \
    --disable-session-crashed-bubble \
    --disable-infobars \
    "$KIOSK_URL"
XEOF
        chmod +x "$XINITRC_FILE"
        echo "✓ .xinitrc configured"
    fi
else
    echo "Creating .xinitrc..."
    cat > "$XINITRC_FILE" <<'XEOF'
#!/bin/bash
# Disable screensaver and DPMS
xset s off
xset -dpms
xset s noblank

# Hide cursor
unclutter -idle 1 -root &

# Get local IP
HOSTNAME=$(hostname -I 2>/dev/null | awk '{print $1}' || echo "localhost")
KIOSK_URL="http://$HOSTNAME:5000"

# Start Chromium in kiosk mode
exec /usr/bin/chromium-browser \
    --kiosk \
    --no-first-run \
    --no-default-browser-check \
    --disable-translate \
    --disable-default-apps \
    --no-pings \
    --disable-popup-blocking \
    --disable-session-crashed-bubble \
    --disable-infobars \
    "$KIOSK_URL"
XEOF
    chmod +x "$XINITRC_FILE"
    echo "✓ .xinitrc created"
fi

echo
echo "=== Kiosk Setup Complete ==="
echo
echo "Configuration details:"
echo "  Display: :0 (HDMI/DSI touchscreen)"
echo "  Browser: Chromium in fullscreen kiosk mode"
echo "  URL: $KIOSK_URL"
echo "  Cursor: Hidden after 1 second of inactivity"
echo "  Screensaver: Disabled"
echo
echo "To start the kiosk manually:"
echo "  startx"
echo
echo "To enable auto-start at boot (requires additional setup):"
echo "  See README.md for systemd autologin configuration"
echo
echo "Backup files created:"
if [ -f "${AUTOSTART_FILE}.bak" ]; then
    echo "  - ${AUTOSTART_FILE}.bak"
fi
if [ -f "${XINITRC_FILE}.bak" ]; then
    echo "  - ${XINITRC_FILE}.bak"
fi
echo
