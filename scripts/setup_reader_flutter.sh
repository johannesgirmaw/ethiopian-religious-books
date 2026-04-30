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
flutter doctor -v | head -40

echo ""
echo "Next — start API + seed (if not already):"
echo "  cd ${ROOT}/infra && docker compose up -d --build && docker compose exec api python manage.py seed_dev"
echo ""
echo "Run the app:"
echo "  ${ROOT}/scripts/run_reader_flutter.sh           # Android if available, else macOS desktop"
echo "  ${ROOT}/scripts/run_reader_flutter.sh android   # Android only"
echo "  ${ROOT}/scripts/run_reader_flutter.sh macos     # macOS desktop only"
echo ""
echo "Optional iOS (after INSTALL_READER_IOS=1 setup):"
echo "  ${ROOT}/scripts/run_reader_flutter.sh ios"
