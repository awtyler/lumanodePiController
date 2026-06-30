# Lumanode Pi Controller

A complete web-based and CLI system for managing Arduino sketch uploads to a UNO R4 WiFi running NeoPixel visualizations. Features Docker-based compilation, touchscreen kiosk interface, and SSH command-line tools.

## Features

- 🐳 **Docker-based compilation** - Arduino CLI runs in container, no local dependencies
- 🎨 **Touchscreen web UI** - Optimized for 130mm+ displays, large touch targets
- 💻 **CLI tools** - Full SSH command-line control via `lumanode` command
- 📦 **Sketch organization** - Organize visualizations in folders and subfolders
- ⚡ **Hot compilation** - Compile and flash without disconnecting Arduino
- 📊 **History tracking** - View all flashed sketches and timestamps
- 🔄 **Auto-restart** - Service auto-starts on Pi reboot
- 🌐 **REST API** - Full API for automation and scripting

## Hardware Requirements

- Raspberry Pi 4/5 (or any Pi with 2GB+ RAM)
- Arduino UNO R4 WiFi connected via USB
- Optional: 130mm+ touchscreen (7-10 inches recommended)
- 12V power supply (tested with 12V 8.5A, 102W)

## Installation

### 1. Fresh Raspberry Pi Setup

Start with a clean Raspberry Pi OS installation (Lite or Desktop):

```bash
# SSH into your Pi or use the terminal
cd ~
git clone https://github.com/awtyler/lumanodePiController
cd lumanodePiController
```

### 2. Run Setup Script

```bash
chmod +x setup.sh
./setup.sh
```

This installs:
- Docker & Docker Compose
- Python dependencies
- CLI tool

### 3. (Optional) Setup Touchscreen Kiosk

If you have a touchscreen display:

```bash
chmod +x scripts/setup-kiosk.sh
./scripts/setup-kiosk.sh
```

This configures:
- X11 and Chromium browser
- Fullscreen kiosk mode
- Auto-hidden cursor
- Systemd autostart

### 4. Add Your Sketches

Create your visualization folder structure:

```bash
# Create some folders
mkdir -p visualizations/patterns
mkdir -p visualizations/effects

# Copy your .ino files
cp myvisualization.ino visualizations/
cp animation.ino visualizations/patterns/
```

Sketches can be nested in any folder structure:
```
visualizations/
├── simple.ino
├── patterns/
│   ├── animation.ino
│   └── chase.ino
└── effects/
    ├── rainbow.ino
    └── sparkle.ino
```

### 5. Start the Service

```bash
# One-time startup
docker-compose up -d

# Check logs
docker-compose logs -f

# Verify it's running
curl http://localhost:5000/api/health
```

Visit the web UI: `http://<your-pi-ip>:5000`

## Usage

### Web Interface

1. Open http://`<your-pi-ip>`:5000 on a browser or touchscreen
2. Click any visualization to compile and flash it
3. The active sketch has a ● indicator
4. Check history with the "History" button

### Command Line

```bash
# List all sketches
lumanode list

# Flash a sketch
lumanode flash visualizations/patterns/animation

# Compile only (don't flash)
lumanode compile visualizations/mysketch

# Upload a new sketch
lumanode upload mysketch.ino --folder patterns

# Show status
lumanode status

# View flash history
lumanode history --limit 20
```

### API

All functionality is exposed via REST API:

```bash
# List sketches
curl http://localhost:5000/api/sketches

# Get current state
curl http://localhost:5000/api/state

# Flash a sketch (POST)
curl -X POST http://localhost:5000/api/flash/visualizations/mysketch

# Get history
curl http://localhost:5000/api/history
```

## Configuration

### Environment Variables

Edit `docker-compose.yml` to customize:

```yaml
environment:
  - SKETCHES_DIR=/sketches/visualizations     # Sketch folder
  - BUILD_DIR=/tmp/arduino_build              # Build output
  - ARDUINO_BOARD=arduino:renesas_uno:uno_r4_wifi
  - SERIAL_PORT=/dev/ttyACM0                  # USB port
  - SERIAL_SPEED=115200                       # Serial baud rate
```

### Different Arduino Board

Change the `ARDUINO_BOARD` for other boards:
- **Arduino UNO R3**: `arduino:avr:uno`
- **Arduino Nano**: `arduino:avr:nano`
- **Arduino Mega**: `arduino:avr:mega`
- **Raspberry Pi Pico**: `rp2040:rp2040:rpipico`

### Custom Serial Port

If your Arduino appears on a different port:

```bash
# Find the port
ls /dev/tty*

# Update docker-compose.yml
services:
  lumanode:
    environment:
      - SERIAL_PORT=/dev/ttyUSB0
```

## Troubleshooting

### Docker won't start

```bash
# Check if Docker is running
sudo systemctl status docker

# Start Docker
sudo systemctl start docker

# Add user to docker group (requires logout/login)
sudo usermod -aG docker $USER
```

### Cannot connect to Arduino

```bash
# Check USB connection
lsusb

# Check serial port permissions
ls -la /dev/ttyACM0

# Grant permissions (one-time)
sudo usermod -a -G dialout $USER  # requires logout/login
```

### Compilation timeout

If sketches take a long time to compile, increase the timeout in `app/app.py`:

```python
# Change from 120 to 300 (seconds)
result = subprocess.run(..., timeout=300)
```

### Port already in use

If port 5000 is taken:

```bash
# Change port in docker-compose.yml
ports:
  - "8080:5000"  # Access via :8080 instead
```

## Auto-start on Boot

### Option 1: Systemd Service (Recommended)

```bash
# Copy service file
mkdir -p ~/.config/systemd/user
cp systemd/lumanode.service ~/.config/systemd/user/

# Enable it
systemctl --user enable lumanode.service
systemctl --user start lumanode.service

# Check status
systemctl --user status lumanode.service
```

### Option 2: Crontab

```bash
crontab -e

# Add this line
@reboot cd ~/lumanodePiController && docker-compose up -d
```

## File Structure

```
lumanodePiController/
├── app/                          # Flask application
│   ├── app.py                   # Main server
│   ├── templates/
│   │   └── index.html           # Web UI
│   ├── static/
│   │   ├── style.css            # Touchscreen CSS
│   │   └── app.js               # Frontend logic
│   └── requirements.txt          # Python deps
├── docker/
│   └── Dockerfile               # Container image
├── cli/
│   └── lumanodesdk.py          # CLI tool
├── visualizations/              # Your .ino files here
│   └── .gitkeep
├── data/
│   └── metadata.json            # Active sketch tracking
├── scripts/
│   └── setup-kiosk.sh          # Kiosk mode setup
├── systemd/
│   └── lumanode.service        # Auto-start service
├── docker-compose.yml
├── setup.sh
└── README.md
```

## Development

### Building from source

```bash
# Rebuild Docker image
docker-compose build

# Development mode (logs in foreground)
docker-compose up

# Stop containers
docker-compose down
```

### Viewing logs

```bash
# All services
docker-compose logs

# Tail in real-time
docker-compose logs -f

# Single service
docker-compose logs lumanode
```

## Tips & Tricks

### Safe NeoPixel brightness

Set max brightness to 80% in your sketches to avoid power issues:

```cpp
FastLED.setBrightness(255 * 0.8);  // 80% brightness
```

### Organize by type

```bash
mkdir -p visualizations/{patterns,effects,tests}
# patterns/ - repeating animations
# effects/  - interactive effects
# tests/    - debugging sketches
```

### Batch upload sketches

```bash
# Upload all .ino files from a folder
for file in ~/sketches/*.ino; do
    lumanode upload "$file" --folder patterns
done
```

### Monitor compilation

```bash
# Watch for changes and auto-compile
watch -n 1 'lumanode status'
```

## Performance

- **Compilation**: ~30-45 seconds (first run with Arduino CLI setup)
- **Flashing**: ~5-10 seconds
- **Web UI response**: <100ms
- **Total flash cycle**: ~40-60 seconds

## Limitations

- Arduino UNO R4 WiFi only supports one USB sketch upload at a time
- Touchscreen browser requires 700MB+ free disk space
- Docker requires consistent power (no Raspberry Pi safe shutdown in kiosk mode)

## Future Enhancements

- [ ] Wireless sketch upload (no USB required)
- [ ] Preview window (render animation preview in web UI)
- [ ] Sketch editor with syntax highlighting
- [ ] OTA firmware updates
- [ ] Multi-device support (multiple Arduinos)

## License

MIT - See LICENSE file

## Support

Issues? Questions?

1. Check logs: `docker-compose logs -f`
2. Try serial connection test: `lumanode status`
3. Verify Arduino board selection in docker-compose.yml
4. Ensure Arduino is connected via USB and powered

## Credits

Built for managing Lumanode LED visualization projects on Raspberry Pi.
