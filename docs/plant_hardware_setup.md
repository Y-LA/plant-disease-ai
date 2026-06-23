# Plant Monitoring Hardware Setup

## 1. Project Idea

The hardware part of the project is responsible for collecting environmental data around the plant and sending it to the API / dashboard.

The system measures:

- Temperature
- Humidity
- Light intensity

Basic flow:

```text
DHT22 + LDR → ESP32-S3 → WiFi → Local API / Server → Mobile App or Dashboard
```

---

## 2. Required Components

| Component | Purpose |
|---|---|
| ESP32-S3 Development Board | Main controller, reads sensors and sends data through WiFi |
| DHT22 Sensor | Measures temperature and humidity |
| LDR Sensor | Measures light intensity approximately |
| 10kΩ Resistor | Required with LDR to create a voltage divider circuit |
| Breadboard | For testing connections without soldering |
| Jumper Wires | For wiring components together |
| USB Type-C Cable | To power and program the ESP32-S3 |
| Laptop / MacBook | To write code, upload it to ESP32, and run the local API |

---

## 3. Why These Components Are Used

### ESP32-S3

The ESP32-S3 is used as the main microcontroller because it has:

- WiFi support
- Good performance
- Enough GPIO pins for sensors
- USB Type-C support in many boards
- Future support if a camera is added later

### DHT22

The DHT22 measures:

- Temperature
- Humidity

This helps the system understand if the plant environment is suitable or not.

### LDR

The LDR measures light intensity in a simple way.

It does not give accurate Lux values like BH1750 or TSL2561, but it is enough for a simple prototype.

The LDR reading helps identify whether the plant is receiving low, medium, or strong light.

---

## 4. Wiring Connections

## 4.1 DHT22 Connection

| DHT22 Pin | ESP32-S3 Pin |
|---|---|
| VCC | 3.3V |
| GND | GND |
| DATA | GPIO 4 |

> Note: Some DHT22 modules already include a resistor. If the sensor has 3 pins and is mounted on a small board, it usually works directly.

---

## 4.2 LDR Connection

The LDR must be connected with a 10kΩ resistor using a voltage divider circuit.

### Voltage Divider Diagram

```text
3.3V
 |
[LDR]
 |
 |------> GPIO 34  (Analog Input)
 |
[10kΩ Resistor]
 |
GND
```

### LDR Wiring Table

| Part | Connection |
|---|---|
| First LDR leg | 3.3V |
| Second LDR leg | GPIO 34 |
| 10kΩ resistor | Between GPIO 34 and GND |

---

## 5. Full Wiring Summary

| Component | Pin | ESP32-S3 Connection |
|---|---|---|
| DHT22 | VCC | 3.3V |
| DHT22 | GND | GND |
| DHT22 | DATA | GPIO 4 |
| LDR | Leg 1 | 3.3V |
| LDR | Leg 2 | GPIO 34 |
| 10kΩ Resistor | One side | GPIO 34 |
| 10kΩ Resistor | Other side | GND |

---

## 6. Important Notes

- Use 3.3V, not 5V, for the sensors.
- Make sure all GND connections are common.
- Do not reverse VCC and GND.
- Use a data USB Type-C cable, not a charging-only cable.
- Start by testing the ESP32 alone before connecting sensors.
- After that, test DHT22 alone.
- Then test LDR alone.
- Finally, combine both sensors in one code.

---

## 7. Arduino IDE Setup on Mac

### Step 1: Install Arduino IDE

Download and install Arduino IDE on the Mac.

### Step 2: Add ESP32 Board URL

Open Arduino IDE, then go to:

```text
Arduino IDE → Settings / Preferences
```

Add this URL in **Additional Boards Manager URLs**:

```text
https://raw.githubusercontent.com/espressif/arduino-esp32/gh-pages/package_esp32_index.json
```

### Step 3: Install ESP32 Boards

Go to:

```text
Tools → Board → Boards Manager
```

Search for:

```text
esp32
```

Install:

```text
esp32 by Espressif Systems
```

### Step 4: Select Board

Go to:

```text
Tools → Board
```

Select:

```text
ESP32S3 Dev Module
```

### Step 5: Select Port

Go to:

```text
Tools → Port
```

Choose the port that appears after connecting the ESP32-S3.

It may look like:

```text
/dev/cu.usbmodem...
```

or

```text
/dev/cu.wchusbserial...
```

---

## 8. First Test Code for ESP32-S3

Before connecting the sensors, upload this simple code to make sure the board works.

```cpp
void setup() {
  Serial.begin(115200);
}

void loop() {
  Serial.println("ESP32-S3 is working");
  delay(1000);
}
```

Open Serial Monitor and set baud rate to:

```text
115200
```

If you see the message printed every second, the ESP32-S3 is working correctly.

---

## 9. LDR Test Code

```cpp
int ldrPin = 34;

void setup() {
  Serial.begin(115200);
}

void loop() {
  int lightValue = analogRead(ldrPin);

  Serial.print("Light Value: ");
  Serial.println(lightValue);

  delay(1000);
}
```

### Reading Meaning

| Reading | Meaning |
|---|---|
| Low value | Low light / dark |
| High value | Strong light |

> The exact numbers may change depending on the wiring and the resistor value.

---

## 10. DHT22 + LDR Combined Code

Before uploading this code, install the DHT library from Arduino IDE Library Manager:

Search for:

```text
DHT sensor library by Adafruit
```

Also install:

```text
Adafruit Unified Sensor
```

### Code

```cpp
#include <DHT.h>

#define DHTPIN 4
#define DHTTYPE DHT22
#define LDRPIN 34

DHT dht(DHTPIN, DHTTYPE);

void setup() {
  Serial.begin(115200);
  dht.begin();
}

void loop() {
  float temperature = dht.readTemperature();
  float humidity = dht.readHumidity();
  int lightValue = analogRead(LDRPIN);

  if (isnan(temperature) || isnan(humidity)) {
    Serial.println("Failed to read from DHT22 sensor");
    delay(2000);
    return;
  }

  Serial.println("--------------------");
  Serial.print("Temperature: ");
  Serial.print(temperature);
  Serial.println(" °C");

  Serial.print("Humidity: ");
  Serial.print(humidity);
  Serial.println(" %");

  Serial.print("Light Value: ");
  Serial.println(lightValue);

  delay(2000);
}
```

---

## 11. Local API Connection Idea

After reading the sensors successfully, the next step is sending the data to a local API running on the laptop.

The system will work like this:

```text
ESP32-S3 → WiFi → Laptop Local API → Mobile App / Dashboard
```

Example data sent by ESP32:

```json
{
  "temperature": 28.5,
  "humidity": 60,
  "light": 1850
}
```

---

## 12. Final Prototype Description

This hardware prototype monitors the plant environment using DHT22 and LDR sensors.

The ESP32-S3 reads the sensor values and can send them through WiFi to a local API or dashboard.

This makes the project more useful because it does not only detect plant disease from images, but also provides environmental context such as temperature, humidity, and light conditions.

---

## 13. Future Improvements

Possible future upgrades:

- Add camera for leaf image capture
- Add soil moisture sensor
- Add automatic watering system
- Store data in a database
- Add alerts when temperature, humidity, or light values are abnormal
- Connect the system to a mobile app

