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
echo "Step 5: Remove LXDE desktop (not needed for kiosk mode)"

# Check if LXDE is installed
if dpkg -l | grep -q "^ii  lxsession"; then
    echo "Removing LXDE and related packages..."
    sudo apt-get remove -y lxsession lxde-common openbox 2>&1 | grep -v "^Reading\|^Building\|^Selecting" || true
    
    # Also try to remove the metapackage if it exists
    sudo apt-get remove -y lxde 2>/dev/null || true
    
    echo "✓ LXDE removed"
else
    echo "✓ LXDE not installed"
fi

# Backup and disable autostart file as fallback
LXDE_AUTOSTART="$HOME/.config/lxsession/LXDE-pi/autostart"
if [ -f "$LXDE_AUTOSTART" ] && [ ! -f "${LXDE_AUTOSTART}.disabled" ]; then
    mv "$LXDE_AUTOSTART" "${LXDE_AUTOSTART}.disabled" 2>/dev/null || true
fi

echo
echo "=========================================="
echo "Would you like to enable automatic kiosk mode?"
echo "This will:"
echo "  - Auto-login to console on boot"
echo "  - Auto-start X11 and Chromium"
echo "  - Display Lumanode immediately (no manual input needed)"
echo
read -p "Enable automatic kiosk mode on boot? (Y/n) " -n 1 -r
echo

if [[ ! $REPLY =~ ^[Nn]$ ]]; then
    # User said yes (or default)
    ENABLE_AUTOKIOSK=true
    echo "✓ Automatic kiosk mode ENABLED"
else
    # User said no
    ENABLE_AUTOKIOSK=false
    echo "✓ Automatic kiosk mode DISABLED"
    echo "  You can still start kiosk manually with: startx"
fi

echo
if [ "$ENABLE_AUTOKIOSK" = true ]; then
    echo "Step 6: Setup auto-login to console"

    # Create systemd getty override directory
    GETTY_OVERRIDE_DIR="/etc/systemd/system/getty@tty1.service.d"
    GETTY_OVERRIDE_FILE="$GETTY_OVERRIDE_DIR/override.conf"

    if [ -f "$GETTY_OVERRIDE_FILE" ]; then
        if grep -q "autologin" "$GETTY_OVERRIDE_FILE"; then
            echo "✓ Auto-login already configured"
        else
            echo "⚠ getty override exists but doesn't have autologin"
            echo "  Backing up to override.conf.bak and updating..."
            sudo cp "$GETTY_OVERRIDE_FILE" "${GETTY_OVERRIDE_FILE}.bak"
            
            sudo tee "$GETTY_OVERRIDE_FILE" > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $(whoami) --noclear %I \$TERM
Type=idle
EOF
            echo "✓ Auto-login configured"
        fi
    else
        echo "Setting up auto-login..."
        sudo mkdir -p "$GETTY_OVERRIDE_DIR"
        sudo tee "$GETTY_OVERRIDE_FILE" > /dev/null <<EOF
[Service]
ExecStart=
ExecStart=-/sbin/agetty --autologin $(whoami) --noclear %I \$TERM
Type=idle
EOF
        echo "✓ Auto-login configured"
    fi

    echo
    echo "Step 7: Setup X11 auto-start in bash profile"

    # Check if X11 auto-start is already in .bashrc
    BASHRC_FILE="$HOME/.bashrc"
    X11_STARTUP_MARKER="# Auto-start X11 on login (for kiosk mode)"

    if grep -q "$X11_STARTUP_MARKER" "$BASHRC_FILE"; then
        echo "✓ X11 auto-start already in .bashrc"
    else
        echo "Adding X11 auto-start to .bashrc..."
        
        # Create backup
        cp "$BASHRC_FILE" "${BASHRC_FILE}.kiosk.bak"
        
        # Add X11 auto-start code
        cat >> "$BASHRC_FILE" <<'BASHEOF'

# Auto-start X11 on login (for kiosk mode)
if [ -z "$DISPLAY" ] && [ -n "$XDG_VTNR" ] && [ "$XDG_VTNR" = "1" ]; then
    startx
fi
BASHEOF
        
        echo "✓ X11 auto-start added to .bashrc"
    fi

    echo
    echo "Step 8: Reload systemd daemon"

    sudo systemctl daemon-reload
    echo "✓ Systemd daemon reloaded"
else
    echo "Step 6-8: Skipped (automatic kiosk mode disabled)"
fi

echo
echo "=== Kiosk Setup Complete ==="
echo
echo "=== Kiosk Setup Complete ==="
echo
echo "Configuration details:"
echo "  Display: :0 (HDMI/DSI touchscreen)"
echo "  Browser: Chromium in fullscreen kiosk mode"
echo "  URL: $KIOSK_URL"
echo "  Cursor: Hidden after 1 second of inactivity"
echo "  Screensaver: Disabled"
echo "  LXDE Desktop: Removed (clean kiosk-only system)"
echo

if [ "$ENABLE_AUTOKIOSK" = true ]; then
    echo "Auto-start enabled:"
    echo "  Auto-login: Yes (boots directly to kiosk)"
    echo "  X11 auto-start: Yes"
    echo
    echo "After reboot:"
    echo "  1. Pi boots automatically"
    echo "  2. Logs in silently"
    echo "  3. X11 starts"
    echo "  4. Chromium opens fullscreen with Lumanode UI"
    echo
    echo "Ready for production use! Reboot to activate:"
    echo "  sudo reboot"
else
    echo "Auto-start disabled:"
    echo "  Auto-login: No"
    echo "  X11 auto-start: No"
    echo
    echo "To start the kiosk manually:"
    echo "  startx"
    echo "  (Press Alt+F4 or Ctrl+Alt+Backspace to exit)"
    echo
    echo "To enable auto-start later, run setup again:"
    echo "  ./scripts/setup-kiosk.sh"
fi

echo
echo "To test without rebooting:"
echo "  startx"
echo "  (Press Alt+F4 or Ctrl+Alt+Backspace to exit)"
echo
echo "Backup files created (if configs were updated):"
if [ -f "${LXDE_AUTOSTART}.disabled" ]; then
    echo "  - ${LXDE_AUTOSTART}.disabled"
fi
if [ -f "${AUTOSTART_FILE}.bak" ]; then
    echo "  - ${AUTOSTART_FILE}.bak"
fi
if [ -f "${XINITRC_FILE}.bak" ]; then
    echo "  - ${XINITRC_FILE}.bak"
fi
if [ "$ENABLE_AUTOKIOSK" = true ]; then
    if [ -f "${GETTY_OVERRIDE_FILE}.bak" ]; then
        echo "  - ${GETTY_OVERRIDE_FILE}.bak"
    fi
    if [ -f "${BASHRC_FILE}.kiosk.bak" ]; then
        echo "  - ${BASHRC_FILE}.kiosk.bak"
    fi
fi
echo
