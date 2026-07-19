# PedalShare Mobile (Flutter)

Cross-platform iOS & Android app for the PedalShare peer-to-peer bike rental and redistribution platform.

## Getting started

### Prerequisites

- Flutter 3.x SDK: https://docs.flutter.dev/get-started/install
- iOS: Xcode 15+ / Android: Android Studio / SDK 33+

### Setup

```bash
cd mobile
flutter pub get
```

### Configure API base URL

Edit `lib/services/api_service.dart` and update `_base`:

```dart
static const _base = 'https://your-api-server.com';
```

For local development:
- Android emulator: `http://10.0.2.2:8000`
- iOS simulator / physical device on same network: `http://<your-IP>:8000`

### Run

```bash
flutter run                # debug on connected device/simulator
flutter run --release      # release build
flutter build apk          # Android APK
flutter build ios          # iOS archive (requires Mac + Xcode)
```

## App screens

| Screen | Route | Description |
|--------|-------|-------------|
| Splash | `/` | Animated logo; routes to login or home |
| Login / Register | `/login`, `/register` | Email+password auth; ID + selfie upload for KYC |
| Browse Bikes | `/home` | Search available bikes by type, radius, price |
| Bike Detail | `/bike/:id` | Photos, specs, pricing, reviews, book CTA |
| Delivery Jobs | `/delivery` | Open delivery jobs, relay support, accept |
| Profile | `/profile` | Stats, XP/level, active rentals, deliveries, points ledger |
| Rewards Shop | `/shop` | Partner offers, points redemption |

## Architecture

```
lib/
├── main.dart              # App entry, GoRouter, bottom nav shell
├── theme.dart             # Design system (colors, components)
├── services/
│   └── api_service.dart   # HTTP client + auth token management
└── screens/
    ├── splash_screen.dart
    ├── auth_screen.dart
    ├── home_screen.dart
    ├── bike_detail_screen.dart
    ├── delivery_screen.dart
    ├── profile_screen.dart
    └── shop_screen.dart
```

## Key dependencies

| Package | Purpose |
|---------|---------|
| `go_router` | Declarative routing |
| `http` | REST API calls |
| `shared_preferences` | JWT token persistence |
| `image_picker` | ID document & selfie upload |
