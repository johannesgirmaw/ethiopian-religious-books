#!/usr/bin/env bash
# Flutter reader setup: pub get; iOS CocoaPods only when INSTALL_READER_IOS=1 (Android-first).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${ROOT}/apps/reader_flutter"

if [[ ! -d "${APP}" ]]; then
  echo "error: missing ${APP}"
  exit 1
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "Flutter is not on PATH."
  echo ""
  echo "Install (pick one):"
  echo "  macOS:  brew install --cask flutter"
  echo "  Other:  https://docs.flutter.dev/get-started/install"
  echo ""
  echo "For Android builds on macOS, install Android Studio + SDK:"
  echo "  https://docs.flutter.dev/get-started/install/macos#android-setup"
  echo ""
  echo "Then open a new terminal and run this script again."
  exit 1
fi

cd "${APP}"

is_linux_host() {
  [[ "$(uname -s)" == "Linux" ]]
}

is_windows_host() {
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) return 0 ;;
  esac
  [[ "${OS:-}" == "Windows_NT" ]]
}

if [[ "$(uname -s)" == "Darwin" ]] && [[ -d macos/Runner ]]; then
  echo "==> flutter config --enable-macos-desktop"
  flutter config --enable-macos-desktop
fi

echo "==> flutter config --enable-web"
flutter config --enable-web

if is_linux_host; then
  echo "==> flutter config --enable-linux-desktop"
  flutter config --enable-linux-desktop
else
  echo "==> flutter config --enable-linux-desktop (tooling only; build Linux on a Linux host)"
  flutter config --enable-linux-desktop >/dev/null 2>&1 || true
fi

if is_windows_host; then
  echo "==> flutter config --enable-windows-desktop"
  flutter config --enable-windows-desktop
else
  echo "==> Skipping windows-desktop enable (not on Windows). Build Windows on a Windows machine."
fi

echo "==> flutter pub get"
flutter pub get

if [[ "$(uname -s)" == "Darwin" ]] && [[ -f ios/Podfile ]] && [[ "${INSTALL_READER_IOS:-}" == "1" ]]; then
  if command -v pod >/dev/null 2>&1; then
    echo "==> pod install (iOS — INSTALL_READER_IOS=1)"
    (cd ios && pod install)
  else
    echo "warning: CocoaPods not found (pod). Install: brew install cocoapods"
    echo "         Then: (cd ${APP}/ios && pod install)"
  fi
elif [[ "$(uname -s)" == "Darwin" ]] && [[ -f ios/Podfile ]]; then
  echo "==> Skipping CocoaPods for iOS (Android-first). For iOS Simulator later:"
  echo "    INSTALL_READER_IOS=1 ${ROOT}/scripts/setup_reader_flutter.sh"
fi

if [[ "$(uname -s)" == "Darwin" ]] && [[ -f macos/Podfile ]] && command -v pod >/dev/null 2>&1; then
  echo "==> pod install (macOS runner — needed for desktop fallback without Android SDK)"
  (cd macos && pod install) || echo "warning: macos pod install failed; try: cd ${APP}/macos && pod install"
fi

echo ""
echo "==> flutter doctor -v (summary)"
# Avoid broken pipe from `head` closing early while flutter is still writing.
flutter doctor -v | sed -n '1,40p'

echo ""
echo "Next — start API + seed (if not already):"
echo "  cd ${ROOT}/infra && docker compose up -d --build && docker compose exec api python manage.py seed_dev"
echo ""
echo "Run the app:"
echo "  ${ROOT}/scripts/run_reader_flutter.sh           # Android if available, else macOS desktop"
echo "  ${ROOT}/scripts/run_reader_flutter.sh android   # Android emulator/device"
echo "  ${ROOT}/scripts/run_reader_flutter.sh macos     # macOS desktop"
echo "  ${ROOT}/scripts/run_reader_flutter.sh web       # Chrome"
echo "  ${ROOT}/scripts/run_reader_flutter.sh linux     # Linux desktop"
echo ""
echo "Release builds:"
echo "  ${ROOT}/scripts/build_reader_flutter.sh <platform>   # android|ios|macos|web|linux|windows"
echo "  ${ROOT}/scripts/build_reader_apk_release.sh           # Android APK/AAB shortcut"
echo ""
echo "Optional iOS (after INSTALL_READER_IOS=1 setup):"
echo "  ${ROOT}/scripts/run_reader_flutter.sh ios"
