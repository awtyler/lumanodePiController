/*
  Simple Rainbow Animation for Lumanode
  
  Requirements:
  - FastLED library (install via Arduino IDE > Sketch > Include Library > Manage Libraries)
  - 300 WS2812B NeoPixel LEDs on pin 13
  - Arduino UNO R4 WiFi
  
  This creates a smooth rainbow effect that cycles through the LED strip.
*/

#include <FastLED.h>

// Configuration
#define NUM_LEDS 300
#define DATA_PIN 13
#define BRIGHTNESS 204  // 80% of 255 for power safety
#define ANIMATION_SPEED 50  // 1-255, higher = faster

// LED array
CRGB leds[NUM_LEDS];

// Hue value (0-255 represents full color wheel)
uint8_t hue = 0;

void setup() {
  // Initialize FastLED
  FastLED.addLeds<WS2812, DATA_PIN, GRB>(leds, NUM_LEDS);
  FastLED.setBrightness(BRIGHTNESS);
  
  // Clear all LEDs
  fill_solid(leds, NUM_LEDS, CRGB::Black);
  FastLED.show();
  
  delay(100);
}

void loop() {
  // Fill strip with rainbow colors
  for (int i = 0; i < NUM_LEDS; i++) {
    // Calculate hue for this LED based on position and time
    uint8_t led_hue = hue + (i * 256 / NUM_LEDS);
    leds[i] = CHSV(led_hue, 255, 255);
  }
  
  // Display the LEDs
  FastLED.show();
  
  // Move the rainbow
  hue += 1;
  
  // Control animation speed
  delay(255 - ANIMATION_SPEED);
}
