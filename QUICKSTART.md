# Quick Start Guide

Get Lumanode running in 5 minutes.

## Prerequisites

- Raspberry Pi (4GB+ RAM recommended)
- Arduino UNO R4 WiFi connected via USB
- Fresh Raspberry Pi OS install
- SSH access to the Pi

## Fast Setup (5 minutes)

```bash
# 1. Clone repo
cd ~
git clone https://github.com/awtyler/lumanodePiController
cd lumanodePiController

# 2. Run setup
chmod +x setup.sh
./setup.sh

# 3. Start service
docker-compose up -d

# 4. Wait for container to be ready (30 seconds)
sleep 30

# 5. Verify it's running
curl http://localhost:5000/api/health
```

✓ Done! Your Lumanode is ready.

## Add Your First Sketch

```bash
# Copy a sketch into visualizations
cp ~/my_animation.ino visualizations/

# Flash it via CLI
lumanode flash visualizations/my_animation

# Or open web UI
# http://<your-pi-ip>:5000
```

## Common Commands

```bash
# List all sketches
lumanode list

# Flash a sketch
lumanode flash visualizations/sketch_name

# Show status
lumanode status

# View history
lumanode history
```

## Web Interface

Open `http://<your-pi-ip>:5000` in a browser:
- Click a sketch to flash it
- Active sketch has a ● indicator
- "History" shows past flashes
- "Refresh" reloads the sketch list

## Touchscreen Setup (Optional)

If you have a touchscreen:

```bash
chmod +x scripts/setup-kiosk.sh
./scripts/setup-kiosk.sh
```

Then start the kiosk:
```bash
startx
```

## Troubleshooting

**Container won't start?**
```bash
docker-compose logs
```

**Can't find Arduino?**
```bash
# Check if connected
lsusb | grep Arduino

# Fix permissions
sudo usermod -a -G dialout $USER
# Then logout and back in
```

**Web UI won't load?**
```bash
# Check if port 5000 is open
netstat -tlnp | grep 5000

# Or try accessing directly
curl http://localhost:5000
```

## Next Steps

- Read full [README.md](README.md)
- Organize sketches in subfolders: `visualizations/patterns/`, `visualizations/effects/`
- Set up auto-start in systemd
- Configure for different Arduino board in `docker-compose.yml`

## Support

Check logs for detailed error messages:
```bash
docker-compose logs -f
```

All done! 🎉
