#!/bin/bash
set -e

echo "=== Lumanode Kiosk Mode Setup ==="
echo

# Get hostname
HOSTNAME=$(hostname -I | awk '{print $1}')
KIOSK_URL="http://$HOSTNAME:5000"

echo "Setting up kiosk mode for: $KIOSK_URL"
echo

# Install required packages
echo "Installing display server and browser..."
sudo apt-get install -y \
    xserver-xorg \
    xinit \
    chromium-browser \
    unclutter \
    x11-xserver-utils

echo
echo "Creating kiosk startup scripts..."

# Create xinitrc for kiosk
mkdir -p ~/.config/lxsession/LXDE-pi

cat > ~/.config/lxsession/LXDE-pi/autostart <<EOF
@xset s off
@xset -dpms
@xset s noblank
@unclutter -idle 1 -root &
@chromium-browser --kiosk --no-first-run --no-default-browser-check --disable-translate --disable-default-apps --no-pings --disable-popup-blocking "$KIOSK_URL"
EOF

echo "Kiosk autostart configured"

echo
echo "Creating systemd user service..."

cat > ~/.config/systemd/user/lumanode-kiosk.service <<EOF
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

mkdir -p ~/.config/systemd/user

# Enable and start the service
systemctl --user daemon-reload
systemctl --user enable lumanode-kiosk.service

echo
echo "Creating X11 startx configuration..."

cat > ~/.xinitrc <<'EOF'
#!/bin/bash
# Disable screensaver and DPMS
xset s off
xset -dpms
xset s noblank

# Hide cursor
unclutter -idle 1 -root &

# Get local IP
HOSTNAME=$(hostname -I | awk '{print $1}')
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
EOF

chmod +x ~/.xinitrc

echo
echo "=== Kiosk Setup Complete ==="
echo
echo "Configuration details:"
echo "- Display: :0 (HDMI/DSI touchscreen)"
echo "- Browser: Chromium in fullscreen kiosk mode"
echo "- URL: $KIOSK_URL"
echo "- Cursor: Hidden after 1 second of inactivity"
echo "- Screensaver: Disabled"
echo
echo "To start the kiosk manually:"
echo "  startx"
echo
echo "To enable auto-start at boot:"
echo "  sudo systemctl enable getty@tty1.service"
echo "  sudo mkdir -p /etc/systemd/system/getty@tty1.service.d"
echo "  (Add custom override to auto-login and start X)"
echo
