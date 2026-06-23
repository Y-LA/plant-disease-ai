from fastapi import FastAPI, File, UploadFile, HTTPException, Request
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from typing import Optional
from pathlib import Path
import torch
import torchvision.transforms as transforms
from PIL import Image
import io
from torchvision import models
from datetime import datetime, timezone

app = FastAPI()

# ─── Serve web dashboard as static files (optional — requires aiofiles) ───────
try:
    from fastapi.staticfiles import StaticFiles
    from fastapi.responses import FileResponse
    WEB_DIR = Path(__file__).parent.parent / "web"
    if WEB_DIR.exists():
        app.mount("/web", StaticFiles(directory=str(WEB_DIR)), name="web")

        @app.get("/dashboard", include_in_schema=False)
        def serve_dashboard():
            """Shortcut: open http://localhost:8000/dashboard"""
            return FileResponse(str(WEB_DIR / "web_dashboard.html"))
except Exception:
    pass  # aiofiles not installed — dashboard only available as a local file

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Model Setup ──────────────────────────────────────────────────────────────

# 43 classes — includes the new "Not_plant" class for non-plant / random images.
# Order MUST match the training order (torchvision ImageFolder sorts folder
# names alphabetically). "Not_plant" sorts between "Grape___healthy" and
# "Orange___..." → index 15.
num_classes = 43

model = models.resnet50(weights=None)
model.fc = torch.nn.Linear(model.fc.in_features, num_classes)
MODEL_PATH = Path(__file__).parent.parent / "models" / "resnet50_43_FINAL_best.pth"

# The new checkpoint is a full training checkpoint (a dict), not a bare
# state_dict. It bundles the weights under "model_state_dict" together with
# metadata such as "class_names" and "label_to_idx". Support both formats so
# the server keeps working with either an old bare state_dict or the new
# checkpoint file.
_checkpoint = torch.load(MODEL_PATH, map_location="cpu")
if isinstance(_checkpoint, dict) and "model_state_dict" in _checkpoint:
    model.load_state_dict(_checkpoint["model_state_dict"])
    _ckpt_classes = _checkpoint.get("class_names")
else:
    model.load_state_dict(_checkpoint)
    _ckpt_classes = None
model.eval()

# Label of the "not a plant" class (random/non-plant images).
NOT_PLANT_CLASS = "Not_plant"

classes = [
    "Apple___Apple_scab",
    "Apple___Black_rot",
    "Apple___Cedar_apple_rust",
    "Apple___healthy",
    "Blueberry___healthy",
    "Cherry_(including_sour)___Powdery_mildew",
    "Cherry_(including_sour)___healthy",
    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot",
    "Corn_(maize)___Common_rust_",
    "Corn_(maize)___Northern_Leaf_Blight",
    "Corn_(maize)___healthy",
    "Grape___Black_rot",
    "Grape___Esca_(Black_Measles)",
    "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)",
    "Grape___healthy",
    "Not_plant",
    "Orange___Haunglongbing_(Citrus_greening)",
    "Peach___Bacterial_spot",
    "Peach___healthy",
    "Pepper,_bell___Bacterial_spot",
    "Pepper,_bell___healthy",
    "Potato___Early_blight",
    "Potato___Late_blight",
    "Potato___healthy",
    "Raspberry___healthy",
    "Rice___Brown_spot",
    "Rice___Healthy",
    "Rice___Hispa",
    "Rice___Leaf_blast",
    "Soybean___healthy",
    "Squash___Powdery_mildew",
    "Strawberry___Leaf_scorch",
    "Strawberry___healthy",
    "Tomato___Bacterial_spot",
    "Tomato___Early_blight",
    "Tomato___Late_blight",
    "Tomato___Leaf_Mold",
    "Tomato___Septoria_leaf_spot",
    "Tomato___Spider_mites Two-spotted_spider_mite",
    "Tomato___Target_Spot",
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus",
    "Tomato___Tomato_mosaic_virus",
    "Tomato___healthy",
]

# Prefer the exact class order stored inside the checkpoint (class_names /
# label_to_idx). This guarantees the index→label mapping always matches how the
# model was trained, even if the training class order ever changes. Falls back
# to the hardcoded list above for old bare-state_dict checkpoints.
if _ckpt_classes and len(_ckpt_classes) == num_classes:
    classes = list(_ckpt_classes)

transform = transforms.Compose([
    transforms.Resize((224, 224)),
    transforms.ToTensor(),
    transforms.Normalize(mean=[0.485, 0.456, 0.406], std=[0.229, 0.224, 0.225])
])

# ─── Sensor State (in-memory, latest reading from ESP32) ─────────────────────

latest_sensor_data: Optional[dict] = None

# ─── Environmental Profiles per Disease ──────────────────────────────────────
# Each disease has:
#   temp_range    : (min, max) °C that favors disease spread
#   humidity_range: (min, max) % that favors disease spread
#   light_sensitive: True if low light worsens the disease
#   env_driven    : True if environment is a primary factor (not virus/insect only)
#   improvement_tips_en / improvement_tips_ar: actionable tips

DISEASE_ENV_PROFILES = {
    "Apple___Apple_scab": {
        "temp_range": (15, 24), "humidity_range": (75, 100),
        "light_sensitive": True, "env_driven": True,
        "improvement_tips_en": [
            "Reduce humidity by improving air circulation around the tree.",
            "Avoid overhead watering — use drip irrigation.",
            "Ensure sufficient sunlight by pruning dense branches.",
        ],
        "improvement_tips_ar": [
            "قلل الرطوبة بتحسين تهوية المنطقة حول الشجرة.",
            "تجنب الري العلوي — استخدم الري بالتنقيط.",
            "تأكد من وصول ضوء الشمس الكافي بتقليم الأغصان الكثيفة.",
        ],
    },
    "Apple___Black_rot": {
        "temp_range": (20, 30), "humidity_range": (70, 100),
        "light_sensitive": False, "env_driven": True,
        "improvement_tips_en": [
            "Lower ambient humidity through better ventilation.",
            "Remove and destroy infected fruit promptly.",
            "Keep temperature below 20°C if possible in storage areas.",
        ],
        "improvement_tips_ar": [
            "خفض رطوبة البيئة المحيطة بتحسين التهوية.",
            "أزل الثمار المصابة فورًا وتخلص منها.",
            "حافظ على درجة حرارة أقل من 20°C في أماكن التخزين.",
        ],
    },
    "Apple___Cedar_apple_rust": {
        "temp_range": (12, 20), "humidity_range": (60, 100),
        "light_sensitive": False, "env_driven": True,
        "improvement_tips_en": [
            "This fungus thrives in wet cool spring conditions — ensure good drainage.",
            "Avoid planting near cedar or juniper trees.",
        ],
        "improvement_tips_ar": [
            "هذا الفطر يزدهر في الظروف الرطبة الباردة — تأكد من صرف المياه جيدًا.",
            "تجنب الزراعة بالقرب من أشجار السرو.",
        ],
    },
    "Cherry_(including_sour)___Powdery_mildew": {
        "temp_range": (18, 28), "humidity_range": (50, 80),
        "light_sensitive": True, "env_driven": True,
        "improvement_tips_en": [
            "Powdery mildew thrives in warm dry conditions with moderate humidity.",
            "Increase air circulation — avoid dense planting.",
            "Ensure plants get direct sunlight for at least 6 hours.",
        ],
        "improvement_tips_ar": [
            "البياض الدقيقي يزدهر في الظروف الدافئة الجافة نسبيًا.",
            "حسّن تدوير الهواء — تجنب الزراعة المتكدسة.",
            "تأكد من حصول النبتة على ضوء شمس مباشر 6 ساعات على الأقل.",
        ],
    },
    "Corn_(maize)___Cercospora_leaf_spot Gray_leaf_spot": {
        "temp_range": (22, 30), "humidity_range": (75, 100),
        "light_sensitive": True, "env_driven": True,
        "improvement_tips_en": [
            "Reduce leaf wetness duration by improving airflow.",
            "Avoid overhead irrigation.",
            "Rotate crops to break the disease cycle.",
        ],
        "improvement_tips_ar": [
            "قلل مدة بلل الأوراق بتحسين تدوير الهواء.",
            "تجنب الري العلوي.",
            "قم بتدوير المحاصيل لكسر دورة المرض.",
        ],
    },
    "Corn_(maize)___Common_rust_": {
        "temp_range": (15, 25), "humidity_range": (70, 100),
        "light_sensitive": False, "env_driven": True,
        "improvement_tips_en": [
            "Cool humid weather promotes rust — improve airflow.",
            "Apply fungicides early when rust pustules appear.",
        ],
        "improvement_tips_ar": [
            "الطقس البارد الرطب يعزز الصدأ — حسّن تدوير الهواء.",
            "طبّق مبيدات الفطريات مبكرًا عند ظهور بثرات الصدأ.",
        ],
    },
    "Corn_(maize)___Northern_Leaf_Blight": {
        "temp_range": (18, 27), "humidity_range": (70, 100),
        "light_sensitive": True, "env_driven": True,
        "improvement_tips_en": [
            "Ensure proper plant spacing for air circulation.",
            "Reduce humidity by avoiding evening irrigation.",
        ],
        "improvement_tips_ar": [
            "تأكد من التباعد المناسب بين النباتات لتدوير الهواء.",
            "قلل الرطوبة بتجنب الري المسائي.",
        ],
    },
    "Grape___Black_rot": {
        "temp_range": (21, 30), "humidity_range": (75, 100),
        "light_sensitive": True, "env_driven": True,
        "improvement_tips_en": [
            "Remove infected leaves and fruit immediately.",
            "Improve canopy airflow by pruning.",
            "Avoid wetting foliage when irrigating.",
        ],
        "improvement_tips_ar": [
            "أزل الأوراق والثمار المصابة فورًا.",
            "حسّن تهوية الغطاء النباتي بالتقليم.",
            "تجنب ترطيب الأوراق أثناء الري.",
        ],
    },
    "Grape___Esca_(Black_Measles)": {
        "temp_range": (25, 35), "humidity_range": (40, 70),
        "light_sensitive": False, "env_driven": False,
        "improvement_tips_en": [
            "This is a wood fungal disease — environmental changes have limited effect.",
            "Avoid large pruning wounds; seal pruning cuts.",
            "Remove severely affected vines.",
        ],
        "improvement_tips_ar": [
            "هذا مرض فطري للخشب — التغييرات البيئية لها تأثير محدود.",
            "تجنب جروح التقليم الكبيرة؛ اغلق قطوع التقليم.",
            "أزل الكروم المصابة بشدة.",
        ],
    },
    "Grape___Leaf_blight_(Isariopsis_Leaf_Spot)": {
        "temp_range": (20, 30), "humidity_range": (70, 100),
        "light_sensitive": True, "env_driven": True,
        "improvement_tips_en": [
            "Reduce leaf wetness and improve air circulation.",
            "Avoid overhead irrigation.",
        ],
        "improvement_tips_ar": [
            "قلل بلل الأوراق وحسّن تدوير الهواء.",
            "تجنب الري العلوي.",
        ],
    },
    "Orange___Haunglongbing_(Citrus_greening)": {
        "temp_range": (25, 35), "humidity_range": (50, 80),
        "light_sensitive": False, "env_driven": False,
        "improvement_tips_en": [
            "This is a bacterial disease spread by the Asian citrus psyllid insect — not directly environmental.",
            "Control psyllid population using appropriate insecticides.",
            "Remove and destroy infected trees to prevent spread.",
        ],
        "improvement_tips_ar": [
            "هذا مرض بكتيري ينتشر عبر حشرة سيلا الحمضيات — ليس بيئيًا مباشرًا.",
            "تحكم في أعداد الحشرة باستخدام مبيدات مناسبة.",
            "أزل الأشجار المصابة وتخلص منها لمنع الانتشار.",
        ],
    },
    "Peach___Bacterial_spot": {
        "temp_range": (24, 32), "humidity_range": (70, 100),
        "light_sensitive": False, "env_driven": True,
        "improvement_tips_en": [
            "Reduce humidity through better spacing and pruning.",
            "Avoid wetting leaves — use drip irrigation.",
            "Apply copper-based bactericides during wet periods.",
        ],
        "improvement_tips_ar": [
            "قلل الرطوبة من خلال التباعد والتقليم الأفضل.",
            "تجنب ترطيب الأوراق — استخدم الري بالتنقيط.",
            "طبّق مبيدات البكتيريا القائمة على النحاس خلال فترات الرطوبة.",
        ],
    },
    "Pepper,_bell___Bacterial_spot": {
        "temp_range": (24, 32), "humidity_range": (70, 100),
        "light_sensitive": False, "env_driven": True,
        "improvement_tips_en": [
            "Maintain lower humidity levels — improve greenhouse or field ventilation.",
            "Avoid overhead watering.",
            "Reduce temperature if possible below 24°C.",
        ],
        "improvement_tips_ar": [
            "حافظ على مستويات رطوبة أقل — حسّن تهوية البيت المحمي أو الحقل.",
            "تجنب الري العلوي.",
            "خفض درجة الحرارة إن أمكن إلى أقل من 24°C.",
        ],
    },
    "Potato___Early_blight": {
        "temp_range": (24, 29), "humidity_range": (70, 100),
        "light_sensitive": True, "env_driven": True,
        "improvement_tips_en": [
            "Avoid water stress — keep soil moisture consistent.",
            "Ensure adequate sunlight to dry foliage quickly.",
            "Improve spacing for better airflow.",
        ],
        "improvement_tips_ar": [
            "تجنب إجهاد المياه — حافظ على رطوبة التربة منتظمة.",
            "تأكد من ضوء الشمس الكافي لتجفيف الأوراق بسرعة.",
            "حسّن التباعد لتدوير هواء أفضل.",
        ],
    },
    "Potato___Late_blight": {
        "temp_range": (10, 20), "humidity_range": (85, 100),
        "light_sensitive": True, "env_driven": True,
        "improvement_tips_en": [
            "Late blight thrives in cool very wet conditions — critical to reduce leaf wetness.",
            "Improve drainage and airflow significantly.",
            "Avoid irrigation in the evening.",
        ],
        "improvement_tips_ar": [
            "اللفحة المتأخرة تزدهر في الظروف الباردة الرطبة جدًا — تقليل بلل الأوراق أمر حاسم.",
            "حسّن الصرف وتدوير الهواء بشكل ملحوظ.",
            "تجنب الري في المساء.",
        ],
    },
    "Rice___Brown_spot": {
        "temp_range": (20, 30), "humidity_range": (80, 100),
        "light_sensitive": True, "env_driven": True,
        "improvement_tips_en": [
            "Ensure proper fertilization — nutrient deficiency worsens brown spot.",
            "Maintain optimal water levels in the paddy.",
            "Improve light penetration by proper plant spacing.",
        ],
        "improvement_tips_ar": [
            "تأكد من التسميد المناسب — نقص المغذيات يفاقم البقعة البنية.",
            "حافظ على مستويات مياه مثلى في الأرز.",
            "حسّن اختراق الضوء بالتباعد المناسب للنباتات.",
        ],
    },
    "Rice___Hispa": {
        "temp_range": (25, 35), "humidity_range": (70, 90),
        "light_sensitive": False, "env_driven": False,
        "improvement_tips_en": [
            "Hispa is an insect pest — environment has indirect effect.",
            "Remove and destroy affected tillers.",
            "Apply appropriate insecticides.",
        ],
        "improvement_tips_ar": [
            "هيسبا آفة حشرية — البيئة لها تأثير غير مباشر.",
            "أزل وأتلف الأفرع المصابة.",
            "طبّق مبيدات الحشرات المناسبة.",
        ],
    },
    "Rice___Leaf_blast": {
        "temp_range": (20, 28), "humidity_range": (85, 100),
        "light_sensitive": True, "env_driven": True,
        "improvement_tips_en": [
            "Reduce leaf wetness duration — avoid evening irrigation.",
            "Maintain balanced nitrogen fertilization (excess N worsens blast).",
            "Ensure good sunlight and airflow.",
        ],
        "improvement_tips_ar": [
            "قلل مدة بلل الأوراق — تجنب الري المسائي.",
            "حافظ على تسميد نيتروجيني متوازن (زيادة N تفاقم الإصابة).",
            "تأكد من ضوء الشمس الجيد وتدوير الهواء.",
        ],
    },
    "Squash___Powdery_mildew": {
        "temp_range": (18, 28), "humidity_range": (50, 80),
        "light_sensitive": True, "env_driven": True,
        "improvement_tips_en": [
            "Reduce humidity — increase spacing between plants.",
            "Ensure at least 6 hours of direct sunlight.",
            "Avoid evening watering.",
        ],
        "improvement_tips_ar": [
            "قلل الرطوبة — زد المسافة بين النباتات.",
            "تأكد من 6 ساعات على الأقل من ضوء الشمس المباشر.",
            "تجنب الري المسائي.",
        ],
    },
    "Strawberry___Leaf_scorch": {
        "temp_range": (20, 30), "humidity_range": (75, 100),
        "light_sensitive": True, "env_driven": True,
        "improvement_tips_en": [
            "Reduce humidity and improve air circulation.",
            "Remove infected leaves promptly.",
            "Avoid overhead irrigation.",
        ],
        "improvement_tips_ar": [
            "قلل الرطوبة وحسّن تدوير الهواء.",
            "أزل الأوراق المصابة فورًا.",
            "تجنب الري العلوي.",
        ],
    },
    "Tomato___Bacterial_spot": {
        "temp_range": (24, 30), "humidity_range": (75, 100),
        "light_sensitive": False, "env_driven": True,
        "improvement_tips_en": [
            "Lower humidity by improving ventilation.",
            "Use drip irrigation instead of overhead watering.",
            "Avoid working with plants when leaves are wet.",
        ],
        "improvement_tips_ar": [
            "خفض الرطوبة بتحسين التهوية.",
            "استخدم الري بالتنقيط بدلاً من الري العلوي.",
            "تجنب العمل مع النباتات عندما تكون الأوراق مبللة.",
        ],
    },
    "Tomato___Early_blight": {
        "temp_range": (24, 29), "humidity_range": (70, 100),
        "light_sensitive": True, "env_driven": True,
        "improvement_tips_en": [
            "Ensure adequate sunlight — remove lower leaves for better airflow.",
            "Use mulch to prevent soil splash onto leaves.",
            "Reduce irrigation frequency slightly.",
        ],
        "improvement_tips_ar": [
            "تأكد من ضوء الشمس الكافي — أزل الأوراق السفلية لتدوير هواء أفضل.",
            "استخدم التغطية لمنع رش التربة على الأوراق.",
            "قلل تكرار الري قليلاً.",
        ],
    },
    "Tomato___Late_blight": {
        "temp_range": (10, 20), "humidity_range": (85, 100),
        "light_sensitive": True, "env_driven": True,
        "improvement_tips_en": [
            "Critical: reduce leaf wetness — avoid any overhead irrigation.",
            "Increase temperature if in a greenhouse above 20°C.",
            "Drastically improve ventilation and drainage.",
        ],
        "improvement_tips_ar": [
            "حاسم: قلل بلل الأوراق — تجنب أي ري علوي.",
            "ارفع درجة الحرارة في البيت المحمي فوق 20°C.",
            "حسّن التهوية والصرف بشكل جذري.",
        ],
    },
    "Tomato___Leaf_Mold": {
        "temp_range": (20, 25), "humidity_range": (85, 100),
        "light_sensitive": True, "env_driven": True,
        "improvement_tips_en": [
            "Leaf mold is highly humidity-driven — reduce to below 80% if possible.",
            "Increase ventilation significantly in greenhouses.",
            "Improve light penetration by pruning dense foliage.",
        ],
        "improvement_tips_ar": [
            "عفن الأوراق مرتبط جدًا بالرطوبة — اخفضها إلى أقل من 80% إن أمكن.",
            "زد التهوية بشكل ملحوظ في البيوت المحمية.",
            "حسّن اختراق الضوء بتقليم الأوراق الكثيفة.",
        ],
    },
    "Tomato___Septoria_leaf_spot": {
        "temp_range": (20, 25), "humidity_range": (75, 100),
        "light_sensitive": True, "env_driven": True,
        "improvement_tips_en": [
            "Remove lower infected leaves and improve airflow.",
            "Avoid wetting leaves — use drip irrigation.",
            "Ensure sunlight reaches lower canopy.",
        ],
        "improvement_tips_ar": [
            "أزل الأوراق السفلية المصابة وحسّن تدوير الهواء.",
            "تجنب ترطيب الأوراق — استخدم الري بالتنقيط.",
            "تأكد من وصول الضوء للغطاء النباتي السفلي.",
        ],
    },
    "Tomato___Spider_mites Two-spotted_spider_mite": {
        "temp_range": (27, 38), "humidity_range": (20, 50),
        "light_sensitive": False, "env_driven": True,
        "improvement_tips_en": [
            "Spider mites thrive in HOT and DRY conditions — increase humidity.",
            "Mist plants regularly to raise humidity above 60%.",
            "Reduce temperature if possible.",
        ],
        "improvement_tips_ar": [
            "عناكب الحمضيات تزدهر في الحرارة والجفاف — زد الرطوبة.",
            "رشّ النباتات بانتظام لرفع الرطوبة فوق 60%.",
            "خفض درجة الحرارة إن أمكن.",
        ],
    },
    "Tomato___Target_Spot": {
        "temp_range": (20, 30), "humidity_range": (75, 100),
        "light_sensitive": True, "env_driven": True,
        "improvement_tips_en": [
            "Improve airflow and reduce leaf wetness.",
            "Remove and destroy infected debris.",
        ],
        "improvement_tips_ar": [
            "حسّن تدوير الهواء وقلل بلل الأوراق.",
            "أزل وأتلف الحطام المصاب.",
        ],
    },
    "Tomato___Tomato_Yellow_Leaf_Curl_Virus": {
        "temp_range": (25, 35), "humidity_range": (40, 70),
        "light_sensitive": False, "env_driven": False,
        "improvement_tips_en": [
            "Viral disease spread by whiteflies — control the insect vector.",
            "Use reflective mulches to repel whiteflies.",
            "Install insect-proof nets in greenhouses.",
        ],
        "improvement_tips_ar": [
            "مرض فيروسي ينتشر عبر الذباب الأبيض — تحكم في الحشرة الناقلة.",
            "استخدم أغطية عاكسة لصرف الذباب الأبيض.",
            "ركّب شبكات واقية من الحشرات في البيوت المحمية.",
        ],
    },
    "Tomato___Tomato_mosaic_virus": {
        "temp_range": (20, 30), "humidity_range": (40, 80),
        "light_sensitive": False, "env_driven": False,
        "improvement_tips_en": [
            "Viral disease — spreads through contact, not primarily environment.",
            "Disinfect tools between plants.",
            "Remove and destroy infected plants.",
        ],
        "improvement_tips_ar": [
            "مرض فيروسي — ينتشر عبر اللمس وليس البيئة أساسًا.",
            "عقّم الأدوات بين النباتات.",
            "أزل النباتات المصابة وتخلص منها.",
        ],
    },
}

# Default profile for any disease not explicitly listed above
DEFAULT_PROFILE = {
    "temp_range": (20, 30), "humidity_range": (70, 90),
    "light_sensitive": True, "env_driven": True,
    "improvement_tips_en": [
        "Maintain good airflow and avoid excess humidity.",
        "Use drip irrigation to keep leaves dry.",
        "Ensure adequate sunlight.",
    ],
    "improvement_tips_ar": [
        "حافظ على تدوير هواء جيد وتجنب الرطوبة الزائدة.",
        "استخدم الري بالتنقيط لإبقاء الأوراق جافة.",
        "تأكد من ضوء الشمس الكافي.",
    ],
}

# Light thresholds — accepts either percentage (0-100) or raw ADC (0-4095)
# Auto-detects: if value <= 100 treat as percentage, else treat as raw ADC
LIGHT_LOW_PCT   = 20   # below 20% = dim/dark
LIGHT_HIGH_PCT  = 68   # above 68% = bright sunlight


# ─── Helpers ──────────────────────────────────────────────────────────────────

def _classify_light(light_val: int) -> str:
    # Auto-detect: percentage (0-100) or raw ADC (0-4095)
    if light_val <= 100:
        pct = light_val
    else:
        pct = round(light_val / 4095 * 100)

    if pct < LIGHT_LOW_PCT:
        return "low"
    elif pct > LIGHT_HIGH_PCT:
        return "high"
    return "normal"


def analyze_environment(disease: str, sensor: dict) -> dict:
    """
    Returns a structured environmental risk analysis for a detected disease
    given the current sensor readings from the ESP32.
    """
    profile = DISEASE_ENV_PROFILES.get(disease, DEFAULT_PROFILE)
    temp     = sensor.get("temperature")
    humidity = sensor.get("humidity")
    light    = sensor.get("light")

    is_healthy = "healthy" in disease.lower()

    if is_healthy:
        return {
            "env_driven": False,
            "is_env_contributing": False,
            "environmental_risk": "none",
            "temperature_status": "normal",
            "humidity_status": "normal",
            "light_status": "normal",
            "can_improve_by_env": False,
            "summary_en": "Plant appears healthy. Keep current environmental conditions.",
            "summary_ar": "النبتة تبدو سليمة. حافظ على الظروف البيئية الحالية.",
            "improvement_tips_en": [],
            "improvement_tips_ar": [],
        }

    t_lo, t_hi = profile["temp_range"]
    h_lo, h_hi = profile["humidity_range"]
    risk_factors = 0

    temp_status = "unknown"
    humidity_status = "unknown"
    light_status = "unknown"

    if temp is not None:
        if t_lo <= temp <= t_hi:
            temp_status = "favorable"
            risk_factors += 1
        elif temp < t_lo:
            temp_status = "low"
        else:
            temp_status = "high"

    if humidity is not None:
        if h_lo <= humidity <= h_hi:
            humidity_status = "favorable"
            risk_factors += 1
        elif humidity < h_lo:
            humidity_status = "low"
        else:
            humidity_status = "high"

    if light is not None:
        lc = _classify_light(int(light))
        if profile["light_sensitive"] and lc == "low":
            light_status = "unfavorable"
            risk_factors += 1
        else:
            light_status = lc

    # Overall environmental risk level
    if risk_factors >= 2:
        env_risk = "high"
    elif risk_factors == 1:
        env_risk = "medium"
    else:
        env_risk = "low"

    is_env_contributing = profile["env_driven"] and risk_factors >= 1
    can_improve = profile["env_driven"] and risk_factors >= 1

    # Build human-readable summary
    factors_en = []
    factors_ar = []
    if temp_status == "favorable" and temp is not None:
        factors_en.append(f"temperature ({temp:.1f}°C is within the {t_lo}-{t_hi}°C disease range)")
        factors_ar.append(f"درجة الحرارة ({temp:.1f}°C ضمن نطاق المرض {t_lo}-{t_hi}°C)")
    if humidity_status == "favorable" and humidity is not None:
        factors_en.append(f"humidity ({humidity:.1f}% is within the {h_lo}-{h_hi}% disease range)")
        factors_ar.append(f"الرطوبة ({humidity:.1f}% ضمن نطاق المرض {h_lo}-{h_hi}%)")
    if light_status == "unfavorable":
        factors_en.append("low light (reduces plant immunity)")
        factors_ar.append("الضوء الخافت (يقلل مناعة النبتة)")

    if factors_en:
        summary_en = (
            f"Current environment is contributing to disease spread. "
            f"Risk factors: {', '.join(factors_en)}."
        )
        summary_ar = (
            f"البيئة الحالية تساهم في انتشار المرض. "
            f"عوامل الخطر: {', '.join(factors_ar)}."
        )
    elif not profile["env_driven"]:
        summary_en = (
            "This disease is primarily spread by pathogens or insects, "
            "not directly by the environment. Focus on vector/pathogen control."
        )
        summary_ar = (
            "هذا المرض ينتشر أساسًا عبر مسببات مرضية أو حشرات، "
            "وليس بشكل مباشر بالبيئة. ركّز على التحكم في الناقل/الممرض."
        )
    else:
        summary_en = "Current environmental conditions are not ideal for this disease to spread. Continue monitoring."
        summary_ar = "الظروف البيئية الحالية ليست مثالية لانتشار هذا المرض. تابع الرصد."

    return {
        "env_driven": profile["env_driven"],
        "is_env_contributing": is_env_contributing,
        "environmental_risk": env_risk,          # "high" | "medium" | "low" | "none"
        "temperature_status": temp_status,        # "favorable" | "low" | "high" | "unknown"
        "humidity_status": humidity_status,
        "light_status": light_status,             # "favorable"/"unfavorable"/"low"/"normal"/"high"/"unknown"
        "can_improve_by_env": can_improve,
        "summary_en": summary_en,
        "summary_ar": summary_ar,
        "improvement_tips_en": profile["improvement_tips_en"] if can_improve else [],
        "improvement_tips_ar": profile["improvement_tips_ar"] if can_improve else [],
    }


# ─── Sensor Data Endpoints ────────────────────────────────────────────────────

class SensorReading(BaseModel):
    temperature: float  # °C
    humidity: float     # %
    light: int          # ESP32 ADC raw value (0-4095)

@app.post("/sensor-data")
def receive_sensor_data(reading: SensorReading):
    global latest_sensor_data
    latest_sensor_data = {
        "temperature": reading.temperature,
        "humidity":    reading.humidity,
        "light":       reading.light,
        "timestamp":   datetime.now(timezone.utc).isoformat(),
    }
    return {"status": "ok", "received": latest_sensor_data}

@app.get("/sensor-data")
def get_sensor_data():
    if latest_sensor_data is None:
        return {"status": "no_data", "message": "No sensor reading received yet from ESP32"}
    return {"status": "ok", "data": latest_sensor_data}


# ─── Predict Endpoint ─────────────────────────────────────────────────────────

@app.get("/")
def home():
    return {"message": "Plant Disease API is running"}

@app.post("/predict")
async def predict(request: Request, file: UploadFile = File(None)):
    try:
        content_type = request.headers.get("content-type", "")
        if "multipart/form-data" in content_type:
            contents = await file.read()
        else:
            contents = await request.body()

        if not contents:
            raise HTTPException(status_code=400, detail="Empty prediction request")

        image = Image.open(io.BytesIO(contents)).convert("RGB")
        img   = transform(image).unsqueeze(0)

        with torch.no_grad():
            outputs       = model(img)
            probabilities = torch.nn.functional.softmax(outputs, dim=1)
            confidence, predicted = torch.max(probabilities, 1)

        class_id = predicted.item()
        disease  = classes[class_id]

        # Top-3 alternative predictions
        top3_probs, top3_ids = torch.topk(probabilities, 3, dim=1)
        top3 = [
            {"disease": classes[i.item()], "confidence": round(p.item(), 4)}
            for p, i in zip(top3_probs[0], top3_ids[0])
        ]

        # ─── Non-plant image ──────────────────────────────────────────────
        # If the model classifies the image as "Not_plant", it is not a plant
        # leaf. Return the result WITHOUT any disease info, treatment, or
        # recommendations (those stay empty), so the app can show a clear
        # "this is not a plant" message.
        is_plant = (disease != NOT_PLANT_CLASS)
        if not is_plant:
            return {
                "class_id":     class_id,
                "disease":      disease,
                "is_plant":     False,
                "confidence":   round(float(confidence.item()), 4),
                "top3":         top3,
                "sensor_data":  latest_sensor_data,
                "env_analysis": None,   # no recommendations for non-plant images
            }

        # Enrich with environmental analysis from latest ESP32 sensor reading
        sensor = latest_sensor_data or {}
        env_analysis = analyze_environment(disease, sensor)

        return {
            "class_id":     class_id,
            "disease":      disease,
            "is_plant":     True,
            "confidence":   round(float(confidence.item()), 4),
            "top3":         top3,
            "sensor_data":  latest_sensor_data,   # null if ESP32 not connected yet
            "env_analysis": env_analysis,
        }

    except Exception as e:
        raise HTTPException(status_code=500, detail=str(e))
