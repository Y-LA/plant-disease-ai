<div align="center">

# 🌿 AI Plant Disease Detection System

**Graduation Project — Misr University for Science and Technology (MUST)**
Supervisor: **Dr. Heba ELnemr** · 2026

An AI-powered smart-agriculture system for **early plant disease detection** from
leaf images, combined with **real-time environmental monitoring** (temperature,
humidity, light) — turning a simple image classifier into a complete bilingual
diagnostic and treatment-guidance tool.

![Flutter](https://img.shields.io/badge/Flutter-3.4+-02569B?logo=flutter&logoColor=white)
![FastAPI](https://img.shields.io/badge/FastAPI-PyTorch-009688?logo=fastapi&logoColor=white)
![Model](https://img.shields.io/badge/ResNet50-99.61%25%20accuracy-success)
![ESP32](https://img.shields.io/badge/IoT-ESP32--S3-E7352C?logo=espressif&logoColor=white)
![Platforms](https://img.shields.io/badge/Platforms-Android%20·%20iOS%20·%20Web%20·%20Desktop-informational)
![License](https://img.shields.io/badge/License-MIT-yellow)

</div>

---

## 📖 About

This project is an AI-driven agricultural **decision-support system**. It goes
beyond classification: it takes a leaf image, analyzes it with a trained
ResNet50 model, and at the same time reads environmental data from sensors near
the plant. It then merges both signals against a structured disease knowledge
base to explain *likely causes* and give *targeted treatment and prevention* —
all in **Arabic and English**.

The core contribution is **system integration** — connecting deep learning, an
IoT sensor layer, a FastAPI inference backend, a bilingual knowledge base, and a
cross-platform Flutter app into one practical product usable by real farmers and
students, not just a research notebook.

### ✨ Key Features

- 🔬 **Disease detection** — ResNet50 across **43 classes** (42 plant: 38 PlantVillage + 4 Rice) at **99.61% test accuracy**.
- 🛡️ **Non-leaf rejection** — a dedicated `Not_plant` class rejects random / non-plant images.
- 🌡️ **Environmental analysis** — ESP32 sensors (temperature, humidity, light) feed a risk assessment that explains whether the environment is helping the disease spread.
- 📚 **Bilingual knowledge base** — 42 classes with symptoms, treatment, prevention, severity, and trusted sources (Arabic + English).
- 📱 **Cross-platform app** — one Flutter codebase for Android, iOS, Web, and Desktop, with light/dark themes and Firebase auth.
- 📊 **Web dashboard** — standalone results dashboard for monitoring.

---

## 🏗️ System Architecture

```
Plant
 ├── Leaf image ─────────────────────────────────────────┐
 └── Sensors (DHT22 + LDR)                                │
        │                                                 │
        ▼                                                 ▼
     ESP32  ──── WiFi / HTTP POST ────►  FastAPI Backend ◄┘
                                              │
                                     ResNet50 prediction
                                              │
                                     Disease knowledge base
                                              │
                                     Environmental risk analysis
                                              │
                                              ▼
                          Final diagnosis + causes + treatment
                                              │
                                              ▼
                                  Flutter App  /  Web Dashboard
```

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
│       ├── data/         # API client (api_config.dart), scan history
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

> **Firebase setup:** the app uses Firebase Auth. The config files
> (`google-services.json`, `GoogleService-Info.plist`, `firebase_options.dart`)
> are **not committed** to this repo for security. Add your own from the
> [Firebase Console](https://console.firebase.google.com/), or run
> `flutterfire configure`.

### 4 — Hardware (ESP32)

Upload `hardware/esp32_sensor_sender/esp32_sensor_sender.ino` to the ESP32-S3
board. Full wiring guide → [`docs/plant_hardware_setup.md`](docs/plant_hardware_setup.md).

---

## 🧠 Model

| Property | Value |
|---|---|
| Architecture | ResNet50 (pretrained `IMAGENET1K_V2`, Transfer Learning) |
| Classes | **43** — 42 plant (38 PlantVillage + 4 Rice) + a `Not_plant` guard class |
| Input | 224 × 224 px |
| **Test Accuracy** | **99.61%** · Precision 99.53% · Recall 99.54% · F1 99.53% |
| Cross-validation | 5-Fold · Mean **99.26% ± 0.13%** (best Fold 4: 99.37% val) |
| Dataset | **77,809** images · 80% train / 20% held-out test (~15,562 test images) |
| Balancing | 1,200 images / class → 51,600 per training fold |
| Training | AdamW · CosineAnnealingLR · label smoothing 0.05 · Early Stopping · TTA · Google Colab (NVIDIA L4) |
| Datasets | PlantVillage + RiceLeafs_merged_224 |

> Test accuracy (99.61%) is measured on **15,562 held-out images the model never
> saw during training**, with Test-Time Augmentation — and it is *higher* than
> validation accuracy (99.37%), a strong sign the model is not overfitting.

Full training strategy & K-Fold results → [`docs/training_details.md`](docs/training_details.md)
Full evaluation report → [`docs/ResNet50_Plant_Disease_Report.pdf`](docs/ResNet50_Plant_Disease_Report.pdf)

---

## 🔌 API Endpoints

| Method | Endpoint | Description |
|---|---|---|
| `GET` | `/` | Health check |
| `POST` | `/predict` | Leaf image → disease + confidence + top-3 + environmental analysis |
| `POST` | `/sensor-data` | ESP32 pushes temperature, humidity, light |
| `GET` | `/sensor-data` | Get latest sensor reading |

<details>
<summary><b>Example <code>/predict</code> response</b></summary>

```json
{
  "class_id": 34,
  "disease": "Tomato___Early_blight",
  "is_plant": true,
  "confidence": 0.9741,
  "top3": [ { "disease": "...", "confidence": 0.97 } ],
  "sensor_data": { "temperature": 28.5, "humidity": 65, "light": 1850 },
  "env_analysis": {
    "environmental_risk": "high",
    "summary_en": "Current environment is contributing to disease spread.",
    "improvement_tips_en": [ "..." ]
  }
}
```
</details>

---

## 🌾 Supported Crops

Apple · Blueberry · Cherry · Corn · Grape · Orange · Peach · Bell Pepper ·
Potato · Raspberry · **Rice** · Soybean · Squash · Strawberry · Tomato

---

## 🛠️ Tech Stack

**Backend:** FastAPI · PyTorch · Torchvision · Pillow · Uvicorn
**Mobile:** Flutter · Firebase Auth · provider · image_picker · http · google_fonts · share_plus · flutter_localizations
**Hardware:** ESP32-S3 · DHT22 · LDR
**ML:** Python · PyTorch · scikit-learn · Google Colab

---

## 👥 Team

Yousef Ellawah · Omar Walid · Mohamed Emad · Nour Mohamed · Menna Mohamed · Ahmed Abdul-Wahab

Supervisor: **Dr. Heba ELnemr** — Misr University for Science and Technology (MUST), 2026

---

## 📄 License

Released under the [MIT License](LICENSE) — for educational and research purposes.

<div align="center">

*Graduation Project 2026 — Misr University for Science and Technology*

</div>
