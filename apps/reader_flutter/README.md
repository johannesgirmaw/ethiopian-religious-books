# Ethiopian Reader (Flutter)

**Android-first** reader against the Django API in `services/django_api`. **iOS** is supported by the same codebase but **not** the v1 local-dev focus (no CocoaPods in default setup).

## Prerequisites (Android)

- [Flutter](https://docs.flutter.dev/get-started/install) 3.22+ (Dart 3.4+)
- **Android Studio** (or Android SDK + cmdline-tools) so `flutter doctor` can find the **Android SDK**
- Accept licenses: `flutter doctor --android-licenses`
- Backend running (repo root `SETUP.md`, `infra/docker-compose.yml`)

## Fast path (from repo root)

Default **product** target is **Android** (`10.0.2.2` → host API in code and when you pass `android`). Match **`API_PORT`** in `infra/.env` (default **8000**).

**No Android SDK yet?** `./scripts/run_reader_flutter.sh` with **no arguments** will use **macOS desktop** automatically and talk to the API at **`http://127.0.0.1:8000/v1`**. Run `./scripts/setup_reader_flutter.sh` once so **`macos`** gets `pod install`.

```bash
./scripts/setup_reader_flutter.sh

# Prefer Android; if no emulator/device, opens macOS app instead:
./scripts/run_reader_flutter.sh

# Force targets:
./scripts/run_reader_flutter.sh android
./scripts/run_reader_flutter.sh macos
```

Or: **`make reader-setup`**, **`make reader-run`**, **`make reader-run-android`**, **`make reader-run-macos`**.

## Release APK (why it is slow, and a faster build)

The first **`flutter build apk --release`** on a laptop often takes **10–20+ minutes**. Gradle must download the Android plugin stack and dependencies; Flutter then builds native code for **several CPU ABIs** in one “fat” APK. That is expected—**let the first run finish** so caches populate; canceling mid-way often forces a full redo.

**Faster default for real devices (arm64 only):**

```bash
# from repo root
./scripts/build_reader_apk_release.sh
# or: make reader-build-apk-release
```

APK path: **`apps/reader_flutter/build/app/outputs/flutter-apk/app-release.apk`**.

- **x86_64 Android emulator (common on Intel Macs):** `READER_APK_ABI=x64 ./scripts/build_reader_apk_release.sh`
- **Fat APK, all ABIs (slowest):** `READER_APK_ABI=all ./scripts/build_reader_apk_release.sh`

Later rebuilds are usually much quicker (Gradle daemon + build cache).

## Optional: iOS (later / not default)

CocoaPods is **skipped** unless you opt in:

```bash
INSTALL_READER_IOS=1 ./scripts/setup_reader_flutter.sh
open -a Simulator
./scripts/run_reader_flutter.sh ios
```

`make reader-run-ios` still runs the iOS path when you are ready.

## Manual setup

```bash
cd apps/reader_flutter
flutter pub get
```

Only if building for **iOS**: `cd ios && pod install` (after `INSTALL_READER_IOS=1` flow or installing CocoaPods).

## API base URL (`dart-define`)

| Target | Typical `API_BASE_URL` |
|--------|-------------------------|
| **Release / profile** (no override) | `https://religious-books-api.onrender.com/v1/` (`AppConfig`) |
| **Android emulator** (default in `lib/config/app_config.dart`) | `http://10.0.2.2:8000/v1` |
| Physical Android device | `http://<your-LAN-IP>:8000/v1` |
| iOS Simulator | `http://127.0.0.1:8000/v1` |

```bash
flutter run --dart-define=API_BASE_URL=http://10.0.2.2:8000/v1
```

## Presigned MinIO URLs (downloads on emulator)

Set in `infra/.env` (then restart `api`):

```bash
AWS_S3_PRESIGN_ENDPOINT_URL=http://10.0.2.2:19000
```

## Features in this MVP

- Secure token storage (`flutter_secure_storage`)
- Login / register → JWT session
- Library (published books), pull-to-refresh
- Book detail + **download** manifest and package parts (presigned GET with `Dio`)
- Account + sign out (`/v1/auth/logout` with refresh token)
- Access-token **refresh** on `401` via `/v1/auth/refresh`

## Not implemented yet

See `README-IMPLEMENTATION.md`: Drift offline catalog, ETag sync, legal WebView reader, `FLAG_SECURE`, full encryption UX.

## Tests

```bash
flutter test
```

## macOS: debug vs release signing

**`flutter run -d macos`** (Debug) uses [`macos/Runner/DebugProfile.entitlements`](macos/Runner/DebugProfile.entitlements) with **no App Sandbox** and only **`com.apple.security.cs.allow-jit`**, so you can build from the CLI **without** opening Xcode or choosing an Apple **Team** (avoids “entitlements that require signing with a development certificate” during local dev).

**Release / notarized builds** still use [`macos/Runner/Release.entitlements`](macos/Runner/Release.entitlements) (sandbox + `keychain-access-groups`). For those you must set **Signing & Capabilities** in Xcode and use a **Development** or **Distribution** identity.

## macOS: `PlatformException` / Keychain `-34018`

[`lib/storage/token_storage.dart`](lib/storage/token_storage.dart) uses **`MacOsOptions(useDataProtectionKeyChain: false)`** on macOS so tokens store without the data-protection keychain path that often triggers **-34018** in unsigned / low-entitlement debug builds.

If it still appears, Debug builds use minimal entitlements; **Release** keeps `keychain-access-groups` in `Release.entitlements`. Add **Keychain Sharing** in Xcode for distribution builds if needed.

## Project IDs

- **Android:** `com.ethiopianreligious.reader`
- **iOS** (when enabled): `com.ethiopianreligious.reader` in Xcode project
