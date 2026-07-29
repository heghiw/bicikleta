# PedalShare Mobile

Flutter application for Android and iOS. The UI follows the approved `project.zip` visual reference and uses the versioned `/api/v1` backend contract.

## Prerequisites

- Flutter stable with Dart 3
- Android Studio and a current Android SDK for Android builds
- macOS with Xcode and CocoaPods for iOS builds

Run `flutter doctor -v` before setup and resolve every item required by the target platform.

## Platform projects

The native `android/` and `ios/` projects have been generated with organization identifier `com.pedalshare`. Review their bundle identifiers, minimum OS versions, signing teams, app display names, privacy descriptions, and permissions before store submission. Do not regenerate these folders after native configuration begins.

## API configuration

The client reads its API origin at compile time. Never edit a source constant for each environment.

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000
flutter run --dart-define=API_BASE_URL=http://127.0.0.1:8000
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.com
flutter build ipa --release --dart-define=API_BASE_URL=https://api.example.com
```

- Android emulator reaches the host through `10.0.2.2`.
- iOS Simulator can normally use `127.0.0.1` when the API runs on the same Mac.
- Physical devices need an HTTPS endpoint or a reachable development host.
- Production builds must use HTTPS.

Access tokens are stored with Android Keystore or iOS Keychain through `flutter_secure_storage`.

## Current navigation

| Destination | Route | Purpose |
|---|---|---|
| Home | `/dashboard` | Points, quick actions, nearby bicycles and delivery tasks |
| Explore | `/explore` | Bicycle discovery and rental entry point |
| My Bikes | `/my-bikes` | Owned bicycles and tracker/listing entry points |
| Add Bike | `/my-bikes/add` | Validated bicycle details, main photo, rental pricing and review |
| GPS Tracker | `/my-bikes/:id/tracker` | Register and inspect a tracker pending provider validation |
| Activity | `/activity` | Unified rental and delivery history |
| Profile | `/profile` | Account, verification, statistics and points |

Nested journeys include `/bike/:id`, `/delivery`, and `/shop`.

## Verification commands

```bash
flutter pub get
dart format --output=none --set-exit-if-changed lib test
flutter analyze
flutter test
flutter build appbundle --release --dart-define=API_BASE_URL=https://api.example.com
```

iOS archive verification must run on macOS:

```bash
flutter build ipa --release --dart-define=API_BASE_URL=https://api.example.com
```

## Production milestones

The next implementation milestone is versioned database migrations plus persistent identity-verification states. It is followed by real GPS-provider validation/security alerts, rental checkout/payments, delivery proof/relay, notifications, and store release hardening. Track product gaps in [`../docs/implementation-gap-analysis.md`](../docs/implementation-gap-analysis.md).
