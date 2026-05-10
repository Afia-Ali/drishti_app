
---

# 👁️ Drishti Vision

**Drishti** (Sanskrit for "Vision" or "Sight") is an AI-powered assistive mobile application built with Flutter. It is designed to empower visually impaired individuals through real-time object detection and bilingual voice feedback, while providing peace of mind to their loved ones through a secure caregiver dashboard.

## 🚀 Key Features

Drishti utilizes a unique **Dual-Role Architecture**, allowing users to sign up as either a Vision User or a Caregiver, with entirely different experiences tailored to their needs.

### 🧑‍🦯 For Vision Users

* **Real-Time Object Detection:** Runs a custom YOLO (You Only Look Once) model completely on-device. No internet connection is required for inference, ensuring zero latency and maximum privacy.
* **Bilingual Voice Feedback:** Supports both English and Bengali (বাংলা). Uses a custom chunking algorithm connected to Google Translate TTS for high-quality native Bengali pronunciation, alongside standard on-device TTS.
* **Smart Journaling:** Automatically logs detected objects and session durations. Uses a 30-second deduplication window to save battery life and reduce cloud read/writes.
* **High-Contrast UI:** Designed specifically for low-vision accessibility with large touch targets, pulsing indicators, and full Dark/Light mode support.

### 🫂 For Caregivers

* **Secure Linking:** Connect with a Vision User using a secure, dynamically generated 4-character code (e.g., `DRISHTI-A1B2`).
* **Remote Monitoring Dashboard:** View the Vision User's daily activity, total sessions, and most frequently encountered objects.
* **Algorithmic Empathy:** Instead of sterile data tables, the app generates warm, natural-language daily summaries (e.g., *"John had an active day today. Chairs and cups were the most familiar sights."*).

## 🛠️ Tech Stack & Architecture

* **Frontend:** Flutter & Dart
* **Backend:** Firebase (Auth, Firestore Database, Storage)
* **Machine Learning:** TensorFlow Lite (`tflite_flutter`)
* **State Management:** `ChangeNotifier` (Settings) & Stream Builders

### Under the Hood: The ML Pipeline

To prevent the UI from freezing during matrix math, Drishti processes the camera feed using a dedicated **Dart Isolate**.

1. The camera captures a frame.
2. It is sent to the isolate where it is resized and converted to a Float32 Tensor `[1, 640, 640, 3]`.
3. The TFLite interpreter runs the YOLO model (detecting 21 custom classes).
4. Custom Non-Max Suppression (NMS) filters overlapping bounding boxes.
5. The result is shipped back to the main thread for UI rendering at 60 FPS.

## 📂 Project Structure

```text
drishti_app/
├── assets/                            # Static files (must be defined in pubspec.yaml)
│   ├── images/
│   │   └── drishti_logo.png           # App logo
│   └── models/
│       ├── drishti_labels.txt         # YOLO class labels
│       └── drishti_unified.tflite     # Compiled TFLite object detection model
├── lib/                               # Primary Dart codebase
│   ├── screens/                       # UI Views
│   │   ├── camera_screen.dart         # Main ML inference UI & Camera feed
│   │   ├── caregiver_home_screen.dart # Caregiver dashboard
│   │   ├── caregiver_journal_screen.dart
│   │   ├── home_screen.dart           # Vision User dashboard
│   │   ├── journal_screen.dart        # Activity history calendar
│   │   ├── login_screen.dart
│   │   ├── settings_screen.dart
│   │   ├── signup_screen.dart
│   │   └── welcome_screen.dart
│   ├── services/                      # Business Logic & APIs
│   │   ├── app_settings.dart          # Local device preferences (SharedPreferences)
│   │   ├── auth_service.dart          # Firebase Auth & Linking Code generation
│   │   ├── bangla_tts.dart            # Custom Bengali TTS implementation
│   │   ├── inference_isolate.dart     # Multi-threaded TFLite runner
│   │   ├── journal_service.dart       # Smart Firestore logging & deduplication
│   │   ├── linking_service.dart       # Dual-role connection handshake
│   │   ├── role_router.dart           # Route director post-login
│   │   └── user_role.dart             # Role enums
│   ├── firebase_options.dart          # Auto-generated Firebase config
│   └── main.dart                      # App entry point & AuthGate
├── android/                           # Android-specific native code and permissions
├── ios/                               # iOS-specific native code and permissions
├── analysis_options.yaml              # Dart linting and formatting rules
├── firebase.json                      # Firebase CLI configuration
├── pubspec.yaml                       # Package dependencies and asset declarations
└── README.md
```

## ⚙️ Getting Started

### Prerequisites

* Flutter SDK (`>=3.0.0`)
* Android Studio / Xcode
* A Firebase Project

### Installation

1. Clone the repository:
```bash
git clone https://github.com/yourusername/drishti_app.git
cd drishti_app
```


2. Install dependencies:
```bash
flutter pub get
```


3. **Important Note on Firebase:** This repository contains a `firebase_options.dart` file linked to the original development database. If you are forking this project, you **must** connect it to your own Firebase project:
* Install the [FlutterFire CLI](https://firebase.google.com/docs/flutter/setup).
* Run `flutterfire configure` in the root directory to generate a new `firebase_options.dart`.


4. **Add the ML Model:**
* Ensure `drishti_unified.tflite` and `drishti_labels.txt` are placed in the `assets/models/` directory. *(Note: These files may not be included in the repository by default due to file size limits).*


5. Run the app:
```bash
flutter run
```



## 🔒 Security Note

If deploying this to production, ensure that your Firebase API keys in the Google Cloud Console are heavily restricted to your specific Android SHA-1 fingerprint and iOS Bundle ID to prevent unauthorized database access and usage limits.

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

---

*Built with ❤️ to make the world more accessible.*