/*
 * ESP32-S3 — Plant Disease Monitor
 * Reads DHT22 (temperature + humidity) and LDR (light)
 * Sends data to FastAPI /sensor-data endpoint every 15 seconds via WiFi
 *
 * Required libraries (install via Arduino Library Manager):
 *   - DHT sensor library by Adafruit
 *   - Adafruit Unified Sensor
 *   - ArduinoJson (by Benoit Blanchon) — version 7.x
 */

#include <WiFi.h>
#include <HTTPClient.h>
#include <ArduinoJson.h>
#include <DHT.h>

// ─── Configuration ────────────────────────────────────────────────────────────

// WiFi credentials
const char* WIFI_SSID     = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";

// FastAPI server URL — use your Mac's local IP (run `ipconfig getifaddr en0` in Terminal)
// Example: "http://192.168.1.100:8000/sensor-data"
const char* SERVER_URL = "http://192.168.0.101:8000/sensor-data";

// Pins
#define DHTPIN    4       // DHT22 data pin → GPIO 4
#define DHTTYPE   DHT22
#define LDRPIN    34      // LDR analog input → GPIO 34

// How often to send data (milliseconds)
const unsigned long SEND_INTERVAL_MS = 15000; // 15 seconds

// ─── Globals ──────────────────────────────────────────────────────────────────

DHT dht(DHTPIN, DHTTYPE);
unsigned long lastSendTime = 0;

// ─── Setup ────────────────────────────────────────────────────────────────────

void setup() {
  Serial.begin(115200);
  delay(500);

  Serial.println("\n=== Plant Disease Monitor ===");

  // Init DHT22
  dht.begin();

  // Connect to WiFi
  Serial.print("Connecting to WiFi: ");
  Serial.println(WIFI_SSID);
  WiFi.begin(WIFI_SSID, WIFI_PASSWORD);

  int attempts = 0;
  while (WiFi.status() != WL_CONNECTED && attempts < 20) {
    delay(500);
    Serial.print(".");
    attempts++;
  }

  if (WiFi.status() == WL_CONNECTED) {
    Serial.println("\nWiFi Connected!");
    Serial.print("IP Address: ");
    Serial.println(WiFi.localIP());
  } else {
    Serial.println("\nWiFi connection FAILED. Will retry in loop.");
  }
}

// ─── Read Sensors ─────────────────────────────────────────────────────────────

struct SensorData {
  float temperature;
  float humidity;
  int   light;
  bool  valid;
};

SensorData readSensors() {
  SensorData data;

  data.temperature = dht.readTemperature();
  data.humidity    = dht.readHumidity();
  data.light       = analogRead(LDRPIN);

  // Validate DHT22 reading
  if (isnan(data.temperature) || isnan(data.humidity)) {
    Serial.println("[ERROR] Failed to read from DHT22 sensor!");
    data.valid = false;
  } else {
    data.valid = true;
  }

  return data;
}

// ─── Send to API ──────────────────────────────────────────────────────────────

void sendToAPI(SensorData& data) {
  if (WiFi.status() != WL_CONNECTED) {
    Serial.println("[WARN] WiFi disconnected. Reconnecting...");
    WiFi.reconnect();
    delay(3000);
    if (WiFi.status() != WL_CONNECTED) {
      Serial.println("[ERROR] Reconnection failed. Skipping this reading.");
      return;
    }
  }

  HTTPClient http;
  http.begin(SERVER_URL);
  http.addHeader("Content-Type", "application/json");

  // Build JSON body
  JsonDocument doc;
  doc["temperature"] = round(data.temperature * 10.0) / 10.0;  // 1 decimal place
  doc["humidity"]    = round(data.humidity * 10.0) / 10.0;
  doc["light"]       = data.light;

  String jsonBody;
  serializeJson(doc, jsonBody);

  Serial.println("[HTTP] Sending sensor data...");
  Serial.println("  Body: " + jsonBody);

  int httpCode = http.POST(jsonBody);

  if (httpCode == HTTP_CODE_OK || httpCode == 200) {
    String response = http.getString();
    Serial.println("[HTTP] Success! Response: " + response);
  } else {
    Serial.printf("[HTTP] Error: %d\n", httpCode);
    Serial.println("[HTTP] " + http.errorToString(httpCode));
  }

  http.end();
}

// ─── Main Loop ────────────────────────────────────────────────────────────────

void loop() {
  unsigned long now = millis();

  if (now - lastSendTime >= SEND_INTERVAL_MS || lastSendTime == 0) {
    lastSendTime = now;

    // Read sensors
    SensorData data = readSensors();

    // Print to Serial Monitor
    Serial.println("────────────────────────────");
    if (data.valid) {
      Serial.printf("Temperature : %.1f °C\n", data.temperature);
      Serial.printf("Humidity    : %.1f %%\n",  data.humidity);
      Serial.printf("Light (ADC) : %d\n",       data.light);

      // Send to API
      sendToAPI(data);
    } else {
      Serial.println("Skipping API call — invalid sensor reading.");
    }
    Serial.println("────────────────────────────");
  }

  delay(100);
}
