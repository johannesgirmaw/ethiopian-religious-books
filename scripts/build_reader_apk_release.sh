#!/usr/bin/env bash
# Fast release APK for Android (arm64 only by default).
#
# Default `flutter build apk --release` builds all ABIs (arm64 + arm32 + x86_64) → slow first time.
# Most phones are arm64; building only that ABI cuts native compile work sharply.
#
# Usage:
#   ./scripts/build_reader_apk_release.sh           # arm64 → typical physical device
#   READER_APK_ABI=all ./scripts/build_reader_apk_release.sh   # universal APK (slowest)
#   READER_APK_ABI=x64 ./scripts/build_reader_apk_release.sh   # x86_64 emulator APK
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${ROOT}/apps/reader_flutter"
ABI="${READER_APK_ABI:-arm64}"

if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0"
  echo ""
  echo "  READER_APK_ABI=arm64 (default) — fastest; install on arm64 phones / arm64 system images"
  echo "  READER_APK_ABI=x64          — for classic x86_64 Android emulators on Intel Mac"
  echo "  READER_APK_ABI=all          — one APK with every ABI (slowest, matches bare flutter build apk)"
  exit 0
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter not found"
  exit 1
fi

cd "${APP}"

case "${ABI}" in
  arm64)
    echo "==> Release APK (android-arm64 only — fastest common choice)"
    exec flutter build apk --release --target-platform android-arm64
    ;;
  x64)
    echo "==> Release APK (android-x64 — many Intel Mac emulators)"
    exec flutter build apk --release --target-platform android-x64
    ;;
  all)
    echo "==> Release APK (all ABIs — slow)"
    exec flutter build apk --release
    ;;
  *)
    echo "error: READER_APK_ABI must be arm64, x64, or all (got: ${ABI})"
    exit 1
    ;;
esac
