# Hardware & Configuration Guide

## Arduino Board Setup

### Supported Boards

The system supports any Arduino board. Configure in `docker-compose.yml`:

```yaml
environment:
  - ARDUINO_BOARD=arduino:renesas_uno:uno_r4_wifi
```

#### Popular Boards

| Board | FQBN |
|-------|------|
| Arduino UNO R3 | `arduino:avr:uno` |
| Arduino UNO R4 WiFi | `arduino:renesas_uno:uno_r4_wifi` |
| Arduino Nano | `arduino:avr:nano` |
| Arduino Mega | `arduino:avr:mega` |
| Arduino Leonardo | `arduino:avr:leonardo` |
| Raspberry Pi Pico | `rp2040:rp2040:rpipico` |

### Finding Your Board

```bash
# Check connected boards
docker exec lumanode-controller arduino-cli board list

# Search for available boards
docker exec lumanode-controller arduino-cli board search uno
```

## Serial Port Configuration

### Default Setup

The system assumes your Arduino appears at `/dev/ttyACM0` on Linux. This is typical for Arduino boards.

### Verify Connection

```bash
# Check if Arduino is connected
lsusb

# Look for "Arduino" in the output

# Find the serial port
ls /dev/tty*ACM* 
# or
ls /dev/tty*USB*
```

### Change Serial Port

If your board appears on a different port (e.g., `/dev/ttyUSB0`):

1. Edit `docker-compose.yml`
2. Find the `SERIAL_PORT` variable
3. Update it:

```yaml
environment:
  - SERIAL_PORT=/dev/ttyUSB0
```

4. Restart: `docker-compose restart`

### Fix Permissions

If you get "permission denied" errors:

```bash
# One-time fix (requires logout/login)
sudo usermod -a -G dialout $USER

# Or temporary fix
sudo chmod 666 /dev/ttyACM0
```

## NeoPixel Configuration

### FastLED Setup

For NeoPixel strips using FastLED library:

```cpp
#include <FastLED.h>

#define NUM_LEDS 300
#define DATA_PIN 13
#define BRIGHTNESS 204  // 80% of 255

CRGB leds[NUM_LEDS];

void setup() {
  FastLED.addLeds<WS2812, DATA_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(BRIGHTNESS);
}

void loop() {
  // Your animation code here
  FastLED.show();
}
```

### Power Considerations

Your LED strip: **300 LEDs, DC 12V, max 60W**

**At 80% brightness:**
- Estimated draw: ~48W
- Safe with 12V 8.5A (102W) supply ✓

**At 100% brightness:**
- Estimated draw: ~60W
- Marginal with 12V 8.5A supply
- Recommended: Keep at 80% max

### Pin Configuration

The system uses **pin 13** by default, but you can use any digital pin:

```cpp
#define DATA_PIN 13  // Change to any pin: 0-13, except 0,1 (serial)
```

## Power Supply

### Recommended Configuration

| Component | Power | Notes |
|-----------|-------|-------|
| Raspberry Pi 5 | 25W | Dedicated USB-C supply |
| Arduino UNO R4 | 1W | Via USB from Pi |
| NeoPixel (300x, 80%) | 48W | Dedicated 12V supply |
| **Total** | **74W** | With headroom |

### Single Supply Option

Your 12V 8.5A (102W) supply can power everything:

```
12V 102W supply
├── Arduino + Pi via buck converter → ~30W at 5V
└── NeoPixels → 60W at 12V
```

**Requirements:**
- Buck converter: 12V → 5V, ≥6A capacity (~$15)
- Common grounds between 12V and 5V systems
- Wires sized for current (14 AWG minimum for long runs)

### Voltage Drop

For 300 LEDs without power injection:

- 5-meter strip: minimal voltage drop
- Long runs (>10m): Add power injection at 1/2 distance

## USB Connection

### Detection

```bash
# Arduino appears after connected
$ lsusb
Bus 001 Device 005: ID 2341:0058 Arduino SA UNO R4

# Serial port
$ ls -la /dev/ttyACM0
crw-rw---- 1 root dialout 166, 0 Jun 30 14:23 /dev/ttyACM0
```

### Troubleshooting

**Arduino won't flash:**
```bash
# Restart Arduino (toggle DTR)
sudo bash -c 'echo -ne "\x00" > /dev/ttyACM0; sleep 1'

# Or use avrdude directly to test
docker exec lumanode-controller avrdude -c serial -p m4809 -P /dev/ttyACM0 -b 115200 -v
```

**Permission denied:**
```bash
# Add user to dialout group
sudo usermod -a -G dialout $USER
newgrp dialout  # Switch to new group
```

**Port not found:**
```bash
# Install driver
sudo apt-get install arduino  # Installs CH340/PL2303 drivers

# Or manually load USB driver
sudo modprobe ch341
```

## Network Configuration

### Pi to Sketch Upload

If you want to upload sketches over network (not USB):

```bash
# Find Arduino IP on network
arp-scan -l | grep Arduino

# Or configure static IP in sketch
IPAddress ip(192, 168, 1, 100);
```

## Testing

### Verify Setup

```bash
# Check Arduino CLI inside container
docker exec lumanode-controller arduino-cli version

# List boards
docker exec lumanode-controller arduino-cli board list

# Test compilation
docker exec lumanode-controller arduino-cli compile --fqbn arduino:renesas_uno:uno_r4_wifi /sketches/visualizations/test
```

## Advanced Configuration

### Custom Arduino Core

If using a custom Arduino core:

1. Update Dockerfile to install the core
2. Modify ARDUINO_BOARD FQBN
3. Rebuild: `docker-compose build`

### Offline Compilation

Pre-download boards in Dockerfile:

```dockerfile
RUN arduino-cli core install arduino:renesas_uno
RUN arduino-cli core install arduino:avr
```

## Diagnostics

### Full debug output

```bash
# Enable verbose logging in Flask
docker-compose up  # (remove -d flag)

# Watch compilation in real-time
docker exec -it lumanode-controller bash
cd /tmp/arduino_build
ls -la
```

### Check file system

```bash
# View mounted volumes
docker inspect lumanode-controller | grep -A 10 Mounts

# Test sketch access
docker exec lumanode-controller ls -la /sketches/visualizations
```
