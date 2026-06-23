# 🚀 دليل رفع المشروع على GitHub

> المجلد ده (`plant-disease-ai`) مجهّز ومرتب وجاهز للرفع.
> اتبع الخطوات بالترتيب من **Terminal** على الماك.

---

## الخطوة 0 — افتح Terminal على المجلد

```bash
cd ~/Desktop/plant_mobile_app/plant-disease-ai
```

---

## الخطوة 1 — ابدأ Git نضيف

في نسخة Git مبدئية اتعملت أثناء التجهيز فيها ملفات قفل عالقة، فالأنضف نبدأ من الأول:

```bash
rm -rf .git
git init
git add -A
git commit -m "Initial commit: Plant Disease AI (Flutter + FastAPI + ResNet50 + ESP32)"
```

> لو ظهرت رسالة عن `user.name` / `user.email`، نفّذ مرة واحدة:
> ```bash
> git config --global user.name "Yousef Ellawah"
> git config --global user.email "yousef.lawah@gmail.com"
> ```

---

## الخطوة 2 — أنشئ Repository على GitHub

### الطريقة الأسهل (GitHub CLI)
لو عندك `gh` متثبّت:

```bash
gh auth login          # مرة واحدة بس
gh repo create plant-disease-ai --public --source=. --remote=origin --push
```

خلصت ✅ — اقفز للخطوة 4.

### الطريقة اليدوية
1. روح [github.com/new](https://github.com/new)
2. **Repository name:** `plant-disease-ai`
3. اختار **Public** (أو Private لو عايز)
4. **ماتختارش** "Add a README" ولا .gitignore ولا License (موجودين خلاص)
5. اضغط **Create repository**

---

## الخطوة 3 — اربط واتفع (للطريقة اليدوية)

انسخ الأوامر من صفحة GitHub، أو استخدم دي (غيّر `USERNAME` باسمك):

```bash
git branch -M main
git remote add origin https://github.com/USERNAME/plant-disease-ai.git
git push -u origin main
```

> هيطلب منك تسجيل دخول. استخدم **Personal Access Token** بدل الباسورد:
> Settings → Developer settings → Personal access tokens → Generate new token (scope: `repo`).

---

## الخطوة 4 — ارفع ملف الموديل (اختياري لكن مهم)

ملف الموديل `resnet50_43_FINAL_best.pth` (~91 ميجا) **مش متضمّن** في الريبو عشان كبير.
ارفعه كـ **Release asset**:

1. في صفحة الريبو → **Releases** → **Create a new release**
2. Tag: `v1.0` · Title: `Trained model weights`
3. اسحب ملف `.pth` في خانة **Attach binaries**
4. **Publish release**

كده أي حد يقدر ينزّل الموديل ويحطه في `models/`.

---

## ✅ بعد الرفع — تشيك سريع

- افتح الريبو على GitHub، الـ README المفروض يظهر بشكل منسّق.
- اتأكد إن مفيش مجلدات `build/` أو `node_modules/` أو `.dart_tool/` اترفعت.
- اتأكد إن مفيش ملف `.pth` اترفع (المفروض متشالش بفضل `.gitignore`).

---

## 🔁 لو عدّلت حاجة بعد كده

```bash
git add -A
git commit -m "وصف التعديل"
git push
```

---

## ⚠️ ملاحظة عن Firebase

ملفات إعداد Firebase (`google-services.json`، `GoogleService-Info.plist`،
`firebase_options.dart`) **مستبعدة** من الريبو عن طريق `.gitignore` للأمان.
أي حد ينزّل المشروع لازم يضيف نسخته الخاصة من
[Firebase Console](https://console.firebase.google.com/) أو يشغّل
`flutterfire configure`.
