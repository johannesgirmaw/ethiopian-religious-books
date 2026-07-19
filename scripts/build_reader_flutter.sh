#!/usr/bin/env bash
# Release build for apps/reader_flutter on any supported platform.
#
# Usage:
#   ./scripts/build_reader_flutter.sh android
#   ./scripts/build_reader_flutter.sh web
#   ./scripts/build_reader_flutter.sh macos
#   ./scripts/build_reader_flutter.sh linux
#   ./scripts/build_reader_flutter.sh windows   # Windows host only
#   ./scripts/build_reader_flutter.sh ios       # macOS + Xcode only
#
# Android extras (same as build_reader_apk_release.sh):
#   READER_APK_ABI=arm64|x64|all
#   READER_BUILD_FORMAT=apk|appbundle
#
# Override API:
#   API_BASE_URL=https://example.com/v1 ./scripts/build_reader_flutter.sh android
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=flutter_reader_common.sh
source "${SCRIPT_DIR}/flutter_reader_common.sh"

PLATFORM="$(normalize_platform "${1:-}")"
ABI="${READER_APK_ABI:-arm64}"
FORMAT="${READER_BUILD_FORMAT:-apk}"

usage() {
  cat <<EOF
Usage: $0 <platform>

Build a release package for the Flutter reader (defaults to production API).

Platforms:
  android   APK or App Bundle (READER_BUILD_FORMAT=apk|appbundle)
  ios       iOS release (no codesign — use Xcode to sign/archive)
  macos     macOS .app bundle
  web       static web build (build/web/)
  linux     Linux desktop bundle (build on Linux)
  windows   Windows desktop (build on Windows only)

Environment:
  API_BASE_URL              Default: ${PRODUCTION_API_BASE_URL}
  READER_APK_ABI=arm64      android: arm64 (default), x64, or all
  READER_BUILD_FORMAT=apk   android: apk (default) or appbundle
  FLUTTER_CREATE_PLATFORM=1 Create missing web/linux/windows runners (default: 1)

Examples:
  $0 android
  READER_APK_ABI=all $0 android
  READER_BUILD_FORMAT=appbundle $0 android
  API_BASE_URL=http://127.0.0.1:8000/v1 $0 web
EOF
}

if [[ "${PLATFORM}" == "-h" ]] || [[ "${PLATFORM}" == "--help" ]] || [[ -z "${PLATFORM}" ]]; then
  usage
  exit 0
fi

if ! valid_build_platform "${PLATFORM}"; then
  echo "error: platform must be android, ios, macos, web, linux, or windows (got: ${1:-})"
  usage
  exit 1
fi

require_flutter
ensure_host_can_build "${PLATFORM}"
prepare_platform "${PLATFORM}"
flutter_pub_get

API_URL="$(release_api_base_url)"
DART_DEFINE="$(dart_defines_for_url "${API_URL}")"

cd "${APP}"

build_android() {
  case "${ABI}" in
    arm64)
      echo "==> Release APK (android-arm64) → ${API_URL}"
      flutter build apk --release --target-platform android-arm64 "${DART_DEFINE}"
      ;;
    x64)
      echo "==> Release APK (android-x64) → ${API_URL}"
      flutter build apk --release --target-platform android-x64 "${DART_DEFINE}"
      ;;
    all)
      echo "==> Release APK (all ABIs) → ${API_URL}"
      flutter build apk --release "${DART_DEFINE}"
      ;;
    *)
      echo "error: READER_APK_ABI must be arm64, x64, or all (got: ${ABI})"
      exit 1
      ;;
  esac
}

build_android_appbundle() {
  if [[ "${ABI}" != "arm64" ]]; then
    echo "note: App Bundle ignores READER_APK_ABI=${ABI}; Play splits ABIs automatically."
  fi
  echo "==> Release App Bundle → ${API_URL}"
  flutter build appbundle --release "${DART_DEFINE}"
}

build_ios() {
  echo "==> Release iOS (no codesign) → ${API_URL}"
  flutter build ios --release --no-codesign "${DART_DEFINE}"
}

build_macos() {
  echo "==> Release macOS → ${API_URL}"
  flutter build macos --release "${DART_DEFINE}"
}

build_web() {
  echo "==> Release web → ${API_URL}"
  flutter build web --release --pwa-strategy=none "${DART_DEFINE}"
}

build_linux() {
  if ! is_linux; then
    echo "warning: building Linux desktop on $(uname -s). Prefer a Linux CI host or VM."
  fi
  echo "==> Release Linux → ${API_URL}"
  flutter build linux --release "${DART_DEFINE}"
}

build_windows() {
  echo "==> Release Windows → ${API_URL}"
  flutter build windows --release "${DART_DEFINE}"
}

case "${PLATFORM}" in
  android)
    case "${FORMAT}" in
      apk) build_android ;;
      appbundle | aab) build_android_appbundle ;;
      *)
        echo "error: READER_BUILD_FORMAT must be apk or appbundle (got: ${FORMAT})"
        exit 1
        ;;
    esac
    ;;
  ios) build_ios ;;
  macos) build_macos ;;
  web) build_web ;;
  linux) build_linux ;;
  windows) build_windows ;;
esac

print_build_output_hint "${PLATFORM}" "${FORMAT}" "${ABI}"
