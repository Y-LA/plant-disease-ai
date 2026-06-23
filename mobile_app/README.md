# AI Plant Disease Detection System

An AI-powered mobile and backend system for early plant disease detection from leaf images using deep learning, enriched with real-time environmental sensing via ESP32 hardware.

## Graduation Project

This project was developed as a student graduation project by:

- Yousef Ellawah
- Omar Walid
- Mohamed Emad
- Nour Mohamed
- Menna Mohamed
- Ahmed Abdul Wahab

## Academic Context

- University: Misr University for Science and Technology
- Supervisor: Dr. Heba ELnemr
- Project title used in the graduation book: `Intelligent Plant Disease Detection Using Deep Learning`

---

## Project Overview

Plant diseases are one of the biggest challenges facing agriculture because they reduce crop quality, lower yield, and increase economic losses. In many real-world cases, especially in rural areas, farmers do not have immediate access to plant pathology experts.

This project provides a practical smart agriculture solution: the user captures a plant leaf image through the mobile app, the backend analyzes it using a trained `ResNet50` model, and the system returns the predicted disease with confidence score, detailed bilingual knowledge, and — when an ESP32 sensor node is present — a live environmental risk analysis based on temperature, humidity, and light readings.

---

## System Architecture

```
┌─────────────────┐        HTTP / WiFi        ┌──────────────────────┐
│  Flutter App    │ ◄────────────────────────► │  FastAPI Backend     │
│  (iOS/Android)  │       POST /predict        │  ResNet50 (PyTorch)  │
└─────────────────┘                            └──────────────────────┘
                                                          ▲
                                                          │ POST /sensor-data
                                               ┌──────────────────────┐
                                               │  ESP32-S3 Node       │
                                               │  DHT22 + LDR sensor  │
                                               └──────────────────────┘
```

---

## Features

- Leaf image capture from camera or gallery
- ResNet50 model classifies 42 disease/healthy classes
- Bilingual disease knowledge base (Arabic + English): pathogen, symptoms, causes, treatment, prevention
- Real-time sensor integration via ESP32 (temperature, humidity, light)
- Environmental risk analysis: compares live readings to per-disease favorable conditions
- Scan history stored locally on device
- Firebase Authentication (email/password)
- Full Arabic / English localization with RTL support
- Dark mode / Light mode / System theme

---

## Project Structure

```
plant_mobile_app/
│
├── app.py                        # FastAPI backend — prediction + sensor endpoints
├── requirements.txt              # Python dependencies
├── resnet50_fold3_best.pth       # Trained ResNet50 model weights
├── diseases_database.json        # Bilingual disease knowledge base (42 entries)
├── diseases_database.csv         # Same data in CSV format
├── esp32_sensor_sender.ino       # Arduino sketch for ESP32-S3 sensor node
│
└── mobile_app/
    ├── lib/
    │   ├── main.dart                         # App entry point, theme & locale setup
    │   ├── settings_controller.dart          # Theme + locale state management
    │   ├── data/
    │   │   ├── prediction_api.dart           # HTTP client — calls /predict
    │   │   └── scan_history.dart             # Local scan history store
    │   ├── domain/
    │   │   ├── prediction.dart               # Prediction, SensorData, EnvAnalysis models
    │   │   └── disease_info.dart             # DiseaseCatalog — JSON knowledge base lookup
    │   ├── ui/
    │   │   ├── screens/
    │   │   │   ├── auth_screen.dart          # Firebase login / register
    │   │   │   ├── home_screen.dart          # Main screen with scan buttons + tips
    │   │   │   ├── preview_screen.dart       # Image preview before analysis
    │   │   │   ├── result_screen.dart        # Full diagnosis result + env analysis
    │   │   │   ├── history_screen.dart       # Past scans list with severity badges
    │   │   │   ├── history_detail_screen.dart# Full detail view of a past scan
    │   │   │   └── settings_screen.dart      # Theme, language, profile, logout
    │   │   └── widgets/
    │   │       ├── metric_chip.dart
    │   │       └── primary_button.dart
    │   └── l10n/                             # Arabic + English ARB files
    ├── assets/
    │   └── diseases_database.json
    ├── pubspec.yaml
    └── firebase_options.dart
```

---

## Running the Backend (FastAPI)

> The backend requires a Python virtual environment. Do **not** install packages system-wide on macOS.

### 1 — First-time setup

```bash
cd /Users/<your-username>/Desktop/plant_mobile_app

# Create virtual environment
python3 -m venv venv

# Activate it
source venv/bin/activate

# Install dependencies
pip install -r requirements.txt
```

### 2 — Start the server

```bash
# Activate venv first (every new terminal session)
source venv/bin/activate

# Run FastAPI with auto-reload
python3 -m uvicorn app:app --reload --host 0.0.0.0 --port 8000
```

The server listens on all interfaces so both the simulator (`127.0.0.1`) and a physical device on the same WiFi network can reach it.

### 3 — Find your Mac's local IP (for physical device)

```bash
ipconfig getifaddr en0
```

Use this IP in the Flutter app and the ESP32 sketch (see configuration sections below).

### 4 — Verify the server is running

```bash
curl http://localhost:8000/
```

Expected response:

```json
{ "message": "Plant Disease API is running" }
```

---

## API Endpoints

### `GET /`

Health check.

```json
{ "message": "Plant Disease API is running" }
```

---

### `POST /predict`

Send a leaf image and receive the disease prediction with optional environmental analysis.

**Request:** `multipart/form-data` with a `file` field (JPEG or PNG image).

**Response:**

```json
{
  "class_id": 28,
  "label": "Tomato___Bacterial_spot",
  "confidence": 0.9872,
  "top3": [
    { "label": "Tomato___Bacterial_spot", "confidence": 0.9872 },
    { "label": "Tomato___Early_blight",   "confidence": 0.0098 },
    { "label": "Tomato___healthy",        "confidence": 0.0021 }
  ],
  "sensor_data": {
    "temperature": 26.0,
    "humidity": 55.5,
    "light": 72,
    "timestamp": "2025-05-01T14:32:00"
  },
  "env_analysis": {
    "environmental_risk": "low",
    "temperature_status": "high",
    "humidity_status": "normal",
    "light_status": "normal",
    "is_env_contributing": false,
    "summary_en": "Current conditions are not highly favorable for disease spread.",
    "summary_ar": "الظروف الحالية لا تساعد على انتشار المرض بشكل كبير.",
    "tips_en": [],
    "tips_ar": []
  }
}
```

If no ESP32 data has been received yet, `sensor_data` and `env_analysis` will be `null`.

---

### `POST /sensor-data`

Called by the ESP32 node every 30 seconds to push sensor readings.

**Request body (JSON):**

```json
{
  "temperature": 26.0,
  "humidity": 55.5,
  "light": 72
}
```

The `light` field can be either:
- A **percentage (0–100)** — the ESP32 in this project sends `lightPercent`
- A **raw ADC value (0–4095)** — the backend auto-detects which format is used

**Response:**

```json
{ "status": "ok", "received": { "temperature": 26.0, "humidity": 55.5, "light": 72 } }
```

---

### `GET /sensor-data`

Returns the latest sensor reading stored in memory.

```json
{
  "temperature": 26.0,
  "humidity": 55.5,
  "light": 72,
  "timestamp": "2025-05-01T14:32:00"
}
```

Returns `null` if no reading has been received yet.

---

## Environmental Analysis Logic

Each disease in `DISEASE_ENV_PROFILES` has defined temperature and humidity ranges that **favor its spread**. The backend compares the live ESP32 readings against these ranges:

| Sensor reading vs. disease range | Status label |
|----------------------------------|--------------|
| Within favorable range | `favorable` — aids disease spread |
| Below favorable range | `low` — less favorable |
| Above favorable range | `high` — less favorable |
| Disease is not environment-driven | `normal` |

**Example:** Tomato Late Blight favors 10–20 °C. A reading of 26 °C → status `high` → conditions are actually **less favorable** for this disease (which is a good sign).

The overall `environmental_risk` is:
- `high` — both temperature and humidity are in the favorable range
- `medium` — one of the two is favorable
- `low` — neither is in the favorable range
- `none` — disease profile is not environment-driven

---

## ESP32 Hardware Setup

### Components

| Component | Purpose |
|-----------|---------|
| ESP32-S3 Dev Module | WiFi microcontroller |
| DHT22 | Temperature + humidity |
| LDR (photoresistor) | Light intensity |

### Wiring

| ESP32 Pin | Connected to |
|-----------|-------------|
| GPIO 4 | DHT22 data pin |
| GPIO 34 | LDR analog output |
| 3.3V | DHT22 VCC, LDR pull-up |
| GND | DHT22 GND, LDR GND |

### Required Arduino Libraries

Install via Arduino IDE → Library Manager:

- `DHT sensor library` by Adafruit
- `Adafruit Unified Sensor`
- `ArduinoJson` by Benoit Blanchon (version 7.x)

Also install the ESP32 board package:

- Arduino IDE → Boards Manager → search `esp32 by Espressif Systems` → Install

### Configuration (`esp32_sensor_sender.ino`)

```cpp
const char* WIFI_SSID     = "YOUR_WIFI_SSID";
const char* WIFI_PASSWORD = "YOUR_WIFI_PASSWORD";
const char* SERVER_URL    = "http://192.168.0.101:8000/sensor-data";
// Replace 192.168.0.101 with your Mac's actual local IP
```

The sketch sends sensor data every **30 seconds**. The light value is sent as a **percentage (0–100)** computed from the raw ADC reading.

---

## Flutter App Setup

### 1 — Prerequisites

- Flutter SDK (stable channel)
- Xcode (for iOS simulator)
- Android Studio or a connected Android device

### 2 — Install dependencies

```bash
cd mobile_app
flutter pub get
```

### 3 — Configure backend URL

The URL is set in `lib/ui/screens/preview_screen.dart`:

```dart
final _api = PredictionApi(
  baseUrl: Uri.parse(
    kIsWeb ? 'http://127.0.0.1:8000' : 'http://192.168.0.101:8000',
  ),
);
```

- `127.0.0.1` is used for the iOS simulator and web builds
- Replace `192.168.0.101` with your Mac's local IP for a physical device

### 4 — Run on iOS simulator

```bash
flutter run
```

Or specify a device:

```bash
flutter run -d "iPhone 16"
```

### 5 — Run on physical iOS device

Make sure the device is on the same WiFi network as the Mac running the backend, then:

```bash
flutter run --release
```

---

## Full System Startup Checklist

Follow this order every time you want to run the full system:

```
1.  Open Terminal
2.  cd /Users/<username>/Desktop/plant_mobile_app
3.  source venv/bin/activate
4.  python3 -m uvicorn app:app --reload --host 0.0.0.0 --port 8000
5.  (New terminal) cd mobile_app && flutter run
6.  Power on the ESP32 — it will connect to WiFi and start sending sensor data
7.  Open the app, scan a leaf — results include live environmental analysis
```

---

## Model Summary

| Property | Value |
|----------|-------|
| Architecture | ResNet50 |
| Training strategy | K-Fold Cross Validation |
| Selected checkpoint | Best-performing fold |
| Number of output classes | 42 |
| Input size | 224 × 224 (normalized) |

### Supported Crops

Apple, Blueberry, Cherry, Corn, Grape, Orange, Peach, Pepper, Potato, Raspberry, Rice, Soybean, Squash, Strawberry, Tomato

---

## Technology Stack

### Backend

| Library | Purpose |
|---------|---------|
| FastAPI | REST API server |
| PyTorch + Torchvision | Model inference |
| Pillow | Image preprocessing |
| Uvicorn | ASGI server |
| Python-dotenv | Environment config |

### Mobile App

| Package | Purpose |
|---------|---------|
| Flutter | Cross-platform UI framework |
| image_picker | Camera and gallery access |
| http | HTTP requests to FastAPI |
| firebase_auth | User authentication |
| shared_preferences | Theme and locale persistence |
| intl | Date formatting and localization |
| google_fonts | Custom typography |

### Hardware

| Component | Purpose |
|-----------|---------|
| ESP32-S3 | WiFi microcontroller |
| DHT22 | Temperature + humidity sensor |
| LDR | Light intensity sensor |
| Arduino IDE | Firmware development |
| ArduinoJson | JSON serialization on ESP32 |

---

## Disease Knowledge Base

### `diseases_database.json`

- 42 entries covering all model output classes
- Bilingual: Arabic and English for all descriptive fields

### Columns / Fields

| Field | Description |
|-------|-------------|
| `class_id`, `class_name` | Match model output exactly |
| `crop_en`, `crop_ar` | Plant/crop name |
| `disease_en`, `disease_ar` | Disease common name |
| `status` | `healthy` or `diseased` |
| `pathogen_en`, `pathogen_ar` | Causal agent |
| `symptoms_en`, `symptoms_ar` | Visible symptoms |
| `environmental_factors_en/ar` | Conditions that favor spread |
| `chemical_treatment_en/ar` | Recommended chemical treatments |
| `organic_treatment_en/ar` | Organic / biological alternatives |
| `prevention_en`, `prevention_ar` | Prevention guidance |
| `severity` | `High`, `Medium`, or `Low` |
| `season_en`, `season_ar` | Season of highest risk |
| `source_url` | Trusted agronomic reference |

### Trusted Sources

Cornell CALS, Penn State Extension, University of Minnesota Extension, UC IPM, UF/IFAS Extension, WSU Tree Fruit, Wisconsin Horticulture, Ohio State Ohioline, IRRI Rice Knowledge Bank, APSnet

---

## Research Foundation

1. Schmidt et al. (2022). *An Analysis of the Accuracy of Photo-Based Plant Identification Applications*. Arboriculture & Urban Forestry. https://doi.org/10.48044/jauf.2022.003
2. Siddiqua et al. (2022). *Evaluating Plant Disease Detection Mobile Applications*. Agronomy. https://doi.org/10.3390/agronomy12081869
3. Ibrahim et al. (2025). *AI-IoT based smart agriculture pivot for plant diseases detection and treatment*. Scientific Reports. https://doi.org/10.1038/s41598-025-98454-6
4. Nyakuri et al. (2025). *AI and IoT-powered edge device optimized for crop pest and disease detection*. Scientific Reports. https://doi.org/10.1038/s41598-025-06452-5
5. Khanal et al. (2024). *Paddy Disease detection using Computer Vision techniques*. arXiv. https://arxiv.org/abs/2412.05996
6. Dhaka et al. (2023). *Role of IoT and Deep Learning in Plant Disease Detection*. Sensors. https://doi.org/10.3390/s23187877
7. Ahmed & Reddy (2021). *A Mobile-Based system for detecting plant leaf diseases using deep learning*. AgriEngineering. https://doi.org/10.3390/agriengineering3030032
8. Zhao et al. (2024). *APEIOU Integration for Enhanced YOLOv7: Efficient Plant Disease Detection*. Agriculture. https://doi.org/10.3390/agriculture14060820

---

## Educational Note

This project is developed as a graduation project prototype for Misr University for Science and Technology. It is intended for educational and research purposes.
