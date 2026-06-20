#!/usr/bin/env bash
# Boot the iOS Simulator (if needed) and run the Flutter reader on it.
#
# Usage:
#   ./scripts/run_reader_ios_simulator.sh
#   IOS_SIMULATOR_DEVICE="iPhone 16" ./scripts/run_reader_ios_simulator.sh
#   ./scripts/run_reader_ios_simulator.sh --no-backend
#
# First-time setup:
#   INSTALL_READER_IOS=1 ./scripts/setup_reader_flutter.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=flutter_reader_common.sh
source "${SCRIPT_DIR}/flutter_reader_common.sh"

START_BACKEND=1
RUN_SEED=1

usage() {
  cat <<EOF
Usage: $0 [options]

Boot the iOS Simulator (or use one already running), then flutter run.

Options:
  -h, --help       Show this help
  --no-backend     Do not start Docker API (stack must already be running)
  --no-seed        With backend startup, skip migrate + seed_dev

Environment:
  IOS_SIMULATOR_UDID             Simulator device UDID (auto-picked if unset)
  IOS_SIMULATOR_DEVICE           Name substring, e.g. "iPhone 16" (default: iPhone)
  IOS_SIMULATOR_BOOT_TIMEOUT     Seconds to wait for boot (default: 120)
  FLUTTER_IOS_AUTO_POD=1         Run pod install if Pods/ missing (default: 1)
  API_BASE_URL                   Override dev API (default: http://127.0.0.1:<API_PORT>/v1/)

First-time iOS setup:
  INSTALL_READER_IOS=1 ./scripts/setup_reader_flutter.sh

Examples:
  $0
  IOS_SIMULATOR_DEVICE="iPhone 16 Pro" $0
  $0 --no-backend
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --no-backend)
      START_BACKEND=0
      shift
      ;;
    --no-seed)
      RUN_SEED=0
      shift
      ;;
    *)
      echo "error: unknown option: $1" >&2
      usage
      exit 1
      ;;
  esac
done

if ! is_darwin; then
  echo "error: iOS Simulator requires macOS with Xcode."
  exit 1
fi

require_flutter
ensure_ios_simulator_setup

if [[ "${START_BACKEND}" == "1" ]]; then
  ensure_local_api_running "${RUN_SEED}"
fi

DEVICE_ID="$(start_ios_simulator)"
export FLUTTER_DEVICE_ID="${DEVICE_ID}"

chmod +x "${SCRIPT_DIR}/run_reader_flutter.sh" 2>/dev/null || true
exec "${SCRIPT_DIR}/run_reader_flutter.sh" ios
