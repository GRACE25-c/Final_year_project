# Expense Trakio

Expense Trakio is a Flutter expense tracker with smart features:
- Firebase backend (Auth / Firestore / Storage)
- OCR bill scanning (review & edit before saving)
- Manual expense entry
- Category auto-detection and duplicate prevention
- Analysis & visualization (category-wise, comparisons)
- Family/Group wallets with shared access
- Smart features: reminders, spending limits, expense health score

Quick start
1. Install Flutter and set up your platforms (Android/iOS). See https://flutter.dev.
2. Create a Firebase project and add Android/iOS apps. Download `google-services.json` / `GoogleService-Info.plist` and follow Firebase setup.
3. From the project root run:

```bash
flutter pub get
flutter run
```

Firebase notes
- Enable Email/Password sign-in in Firebase Auth.
- Create Firestore in production or test mode.
- Storage can be used for bill images.

This repo contains a scaffold with core services and example screens. Customize UI and features as needed.