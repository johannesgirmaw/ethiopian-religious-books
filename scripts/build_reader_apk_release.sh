#!/usr/bin/env bash
# Release Android build for apps/reader_flutter (APK or App Bundle).
#
# Production API (Render): https://religious-books-api.onrender.com/v1/
#   - Same default as AppConfig in lib/config/app_config.dart
#   - Health: https://religious-books-api.onrender.com/healthz/
#   - Swagger: https://religious-books-api.onrender.com/api/docs/
#
# Release builds point at that URL unless you override API_BASE_URL.
#
# Usage:
#   ./scripts/build_reader_apk_release.sh
#   READER_APK_ABI=all ./scripts/build_reader_apk_release.sh
#   READER_BUILD_FORMAT=appbundle ./scripts/build_reader_apk_release.sh
#   API_BASE_URL=https://example.com/v1 ./scripts/build_reader_apk_release.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${ROOT}/apps/reader_flutter"

# Keep in sync with apps/reader_flutter/lib/config/app_config.dart
PRODUCTION_API_BASE_URL="${PRODUCTION_API_BASE_URL:-https://religious-books-api.onrender.com/v1/}"
API_BASE_URL="${API_BASE_URL:-${PRODUCTION_API_BASE_URL}}"

ABI="${READER_APK_ABI:-arm64}"
FORMAT="${READER_BUILD_FORMAT:-apk}"

if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  cat <<EOF
Usage: $0

Build a release Android package wired to the remote Django API.

  Production API (default): ${PRODUCTION_API_BASE_URL}
  Override:                 API_BASE_URL=https://your-host/v1 $0

  READER_APK_ABI=arm64 (default) — fastest; typical physical phones
  READER_APK_ABI=x64              — x86_64 Android emulators (Intel Mac)
  READER_APK_ABI=all              — universal APK (slowest)

  READER_BUILD_FORMAT=apk (default) — outputs app-*-release.apk
  READER_BUILD_FORMAT=appbundle     — outputs app-release.aab (Play Store)

Output (apk, arm64):  apps/reader_flutter/build/app/outputs/flutter-apk/app-arm64-v8a-release.apk
                      or app-release.apk when READER_APK_ABI=all
Output (appbundle):   apps/reader_flutter/build/app/outputs/bundle/release/app-release.aab
EOF
  exit 0
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter not found. Run: ./scripts/setup_reader_flutter.sh"
  exit 1
fi

cd "${APP}"

echo "==> flutter pub get"
flutter pub get

DART_DEFINES=(--dart-define="API_BASE_URL=${API_BASE_URL}")

build_apk() {
  local platform_flags=()
  case "${ABI}" in
    arm64)
      echo "==> Release APK (android-arm64) → ${API_BASE_URL}"
      platform_flags=(--target-platform android-arm64)
      ;;
    x64)
      echo "==> Release APK (android-x64) → ${API_BASE_URL}"
      platform_flags=(--target-platform android-x64)
      ;;
    all)
      echo "==> Release APK (all ABIs) → ${API_BASE_URL}"
      ;;
    *)
      echo "error: READER_APK_ABI must be arm64, x64, or all (got: ${ABI})"
      exit 1
      ;;
  esac
  flutter build apk --release "${platform_flags[@]}" "${DART_DEFINES[@]}"
}

build_appbundle() {
  if [[ "${ABI}" != "arm64" ]]; then
    echo "note: App Bundle ignores READER_APK_ABI=${ABI}; Play splits ABIs automatically."
  fi
  echo "==> Release App Bundle → ${API_BASE_URL}"
  flutter build appbundle --release "${DART_DEFINES[@]}"
}

case "${FORMAT}" in
  apk) build_apk ;;
  appbundle | aab) build_appbundle ;;
  *)
    echo "error: READER_BUILD_FORMAT must be apk or appbundle (got: ${FORMAT})"
    exit 1
    ;;
esac

echo ""
echo "Done. API base: ${API_BASE_URL}"
case "${FORMAT}" in
  apk)
    OUT_DIR="${APP}/build/app/outputs/flutter-apk"
    if [[ -d "${OUT_DIR}" ]]; then
      echo "APK(s):"
      find "${OUT_DIR}" -maxdepth 1 -name '*.apk' -print | sed 's/^/  /'
    fi
    ;;
  appbundle | aab)
    AAB="${APP}/build/app/outputs/bundle/release/app-release.aab"
    if [[ -f "${AAB}" ]]; then
      echo "App Bundle: ${AAB}"
    fi
    ;;
esac
