<div align="center">

# 🌿 AI Plant Disease Detection System

**Graduation Project — Misr University for Science and Technology (MUST)**
Supervisor: **Dr. Heba ELnemr** · 2026

An AI-powered system for early plant disease detection from leaf images using
deep learning, combined with real-time environmental monitoring via IoT sensors.

![Flutter](https://img.shields.io/badge/Flutter-3.4+-02569B?logo=flutter&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-PyTorch-009688?logo=fastapi&logoColor=white)
![Model](https://img.shields.io/badge/ResNet50-98.85%25%20accuracy-success)
![ESP32](https://img.shields.io/badge/Hardware-ESP32--S3-E7352C?logo=espressif&logoColor=white)
![License](https://img.shields.io/badge/License-MIT-yellow)

</div>

---

## 👥 Team

Yousef Ellawah · Omar Walid · Mohamed Emad · Nour Mohamed · Menna Mohamed · Ahmed Abdul-Wahab

---

## 📂 Project Structure

```
plant-disease-ai/
│
├── backend/          # FastAPI prediction server
│   ├── app.py            # API: /predict, /sensor-data endpoints
│   └── requirements.txt  # Python dependencies
│
├── mobile_app/       # Flutter app (Android · iOS · Web · Desktop)
│   └── lib/
│       ├── main.dart     # App entry point
│       ├── data/         # API client, scan history
│       ├── domain/       # Prediction model, disease info
│       ├── ui/           # Screens & reusable widgets
│       ├── theme/        # Light / Dark theme
│       └── l10n/         # Arabic / English localization
│
├── web/              # Web dashboard (standalone HTML/JS)
│   ├── web_dashboard.html
│   └── legacy/           # Earlier web frontend (js/ css/)
│
├── hardware/         # IoT / ESP32 firmware
│   └── esp32_sensor_sender/  # DHT22 + LDR → POST /sensor-data
│
├── ml/               # Machine learning
│   ├── notebooks/        # ResNet50 K-Fold training & evaluation
│   └── scripts/          # Report / dataset utility scripts
│
├── models/           # Trained weights (downloaded separately — see models/README.md)
│
├── data/             # Disease knowledge base (42 classes · bilingual)
│   ├── diseases_database.json   # used by the Flutter app
│   ├── diseases_database.csv
│   └── diseases_database.xlsx
│
├── docs/             # Reports, diagrams, screenshots
└── assets/           # Team photos & shared images
```

---

## 🚀 Quick Start

### 1 — Get the model weights

The trained model (~91 MB) is **not** in the repo. Download it and place it at
`models/resnet50_43_FINAL_best.pth` — see [`models/README.md`](models/README.md).

### 2 — Backend (AI Server)

```bash
python3 -m venv venv
source venv/bin/activate          # Windows: venv\Scripts\activate
pip install -r backend/requirements.txt
cd backend
uvicorn app:app --host 0.0.0.0 --port 8000 --reload
```

Verify at `http://localhost:8000` → `{ "message": "Plant Disease API is running" }`

### 3 — Flutter App

```bash
cd mobile_app
flutter pub get
flutter run
```

For a **physical device**, set your server IP in `mobile_app/lib/data/api_config.dart`.

### 4 — Hardware (ESP32)

Upload `hardware/esp32_sensor_sender/esp32_sensor_sender.ino` to the ESP32-S3
board. Full wiring guide → [`docs/plant_hardware_setup.md`](docs/plant_hardware_setup.md).

---

## 🧠 Model

| Property | Value |
|---|---|
| Architecture | ResNet50 (pretrained `IMAGENET1K_V2`) |
| Classes | 43 (38 PlantVillage + 4 Rice + 1 "Not_plant") |
| Input | 224 × 224 px |
| Test Accuracy | **98.85%** · Macro F1: 98.85% |
| Total Images | 50,400 (balanced · 1,200 / class) |
| Training | 5-Fold CV · AdamW · CosineAnnealingLR · Google Colab (NVIDIA L4) |

Full training strategy & K-Fold results → [`docs/training_details.md`](docs/training_details.md)
Full evaluation report → [`docs/ResNet50_Plant_Disease_Report.pdf`](docs/ResNet50_Plant_Disease_Report.pdf)

---

## 🔌 API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/` | Health check |
| `POST` | `/predict` | Leaf image → disease + confidence + env analysis |
| `POST` | `/sensor-data` | ESP32 pushes temperature, humidity, light |
| `GET` | `/sensor-data` | Get latest sensor reading |

---

## 🌾 Supported Crops

Apple · Blueberry · Cherry · Corn · Grape · Orange · Peach · Bell Pepper ·
Potato · Raspberry · **Rice** · Soybean · Squash · Strawberry · Tomato

---

## 🛠️ Tech Stack

**Backend:** FastAPI · PyTorch · Torchvision · Pillow · Uvicorn
**Mobile:** Flutter · Firebase Auth · image_picker · http · provider · flutter_localizations
**Hardware:** ESP32-S3 · DHT22 · LDR

---

## ⚠️ Configuration Note

This repository includes Firebase client config files
(`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`).
These contain **client-side** Firebase keys (safe to ship inside an app, and
protected by Firebase Security Rules). If you prefer to keep them private,
remove them and uncomment the matching lines in `.gitignore`.

---

<div align="center">

*For educational and research purposes — Graduation Project 2026*

</div>
