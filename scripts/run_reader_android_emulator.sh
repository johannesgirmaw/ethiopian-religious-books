#!/usr/bin/env bash
# Start an Android emulator (if needed) and run the Flutter reader on it.
#
# Usage:
#   ./scripts/run_reader_android_emulator.sh
#   ANDROID_AVD=Pixel_8_API_35 ./scripts/run_reader_android_emulator.sh
#   ./scripts/run_reader_android_emulator.sh --no-backend
#
# Requires: Android Studio SDK, at least one AVD, flutter on PATH.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=flutter_reader_common.sh
source "${SCRIPT_DIR}/flutter_reader_common.sh"

START_BACKEND=1
RUN_SEED=1

usage() {
  cat <<EOF
Usage: $0 [options]

Boot the Android emulator (or use one already running), then flutter run.

Options:
  -h, --help       Show this help
  --no-backend     Do not start Docker API (stack must already be running)
  --no-seed        With backend startup, skip migrate + seed_dev

Environment:
  ANDROID_AVD                    AVD name (default: first Pixel/phone, else first AVD)
  ANDROID_EMULATOR_BOOT_TIMEOUT  Seconds to wait for boot (default: 180)
  ANDROID_EMULATOR_FLAGS         Extra emulator flags (e.g. -no-snapshot-load)
  API_BASE_URL                   Override dev API (default: http://10.0.2.2:<API_PORT>/v1/)

Examples:
  $0
  ANDROID_AVD=Pixel_8_API_35 $0
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

require_flutter

if [[ "${START_BACKEND}" == "1" ]]; then
  ensure_local_api_running "${RUN_SEED}"
fi

DEVICE_ID="$(start_android_emulator)"
export FLUTTER_DEVICE_ID="${DEVICE_ID}"

chmod +x "${SCRIPT_DIR}/run_reader_flutter.sh" 2>/dev/null || true
exec "${SCRIPT_DIR}/run_reader_flutter.sh" android
