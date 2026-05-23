#!/usr/bin/env bash
# Run the Flutter reader. On macOS, defaults to the macOS desktop target (no slow `flutter devices`).
# Pass `android` when you have an emulator or device; Android discovery uses adb first, then Flutter.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${ROOT}/apps/reader_flutter"

if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [android|ios|macos]"
  echo ""
  echo "  $0                 # macOS desktop on Darwin; Android elsewhere / when preferred"
  echo "  $0 macos           # macOS desktop (localhost API)"
  echo "  $0 android         # Android emulator or USB device"
  echo "  $0 ios             # iOS Simulator (INSTALL_READER_IOS=1 setup)"
  echo ""
  echo "Environment:"
  echo "  FLUTTER_DEVICE_ID=<id>     Skip device discovery"
  echo "  FLUTTER_PREFER_ANDROID=1   On macOS, try Android before desktop when no arg"
  echo "  FLUTTER_DEVICES_TIMEOUT=45 Seconds to wait for flutter devices (android/ios only)"
  echo ""
  echo "API_BASE_URL defaults:"
  echo "  android -> http://10.0.2.2:<API_PORT>/v1"
  echo "  ios|macos -> http://127.0.0.1:<API_PORT>/v1"
  exit 0
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter not found. Run: ./scripts/setup_reader_flutter.sh"
  exit 1
fi

cd "${APP}"

FLUTTER_DEVICES_TIMEOUT="${FLUTTER_DEVICES_TIMEOUT:-45}"
FLUTTER_DEVICES_JSON=""

is_darwin() {
  [[ "$(uname -s)" == "Darwin" ]]
}

macos_runner_present() {
  [[ -d "${APP}/macos/Runner" ]]
}

ensure_macos_desktop() {
  if ! macos_runner_present; then
    echo "error: macOS runner missing at ${APP}/macos/Runner"
    echo "       Run: ./scripts/setup_reader_flutter.sh"
    exit 1
  fi
  if ! flutter config --enable-macos-desktop >/dev/null 2>&1; then
    echo "error: failed to enable macOS desktop (flutter config --enable-macos-desktop)"
    exit 1
  fi
  if [[ -f macos/Podfile ]] && command -v pod >/dev/null 2>&1; then
    if [[ ! -d macos/Pods ]] || [[ ! -f macos/Podfile.lock ]]; then
      echo "==> pod install (macOS)…" >&2
      (cd macos && pod install) || {
        echo "error: macos pod install failed. Run: cd ${APP}/macos && pod install"
        exit 1
      }
    fi
  fi
}

use_macos_desktop() {
  ensure_macos_desktop
  DEVICE_ID="macos"
  PLATFORM="macos"
}

flutter_devices_machine() {
  local tmp pid waited=0
  tmp="$(mktemp "${TMPDIR:-/tmp}/flutter-devices.XXXXXX")"
  flutter devices --machine >"${tmp}" 2>/dev/null &
  pid=$!
  while kill -0 "${pid}" 2>/dev/null && [[ "${waited}" -lt "${FLUTTER_DEVICES_TIMEOUT}" ]]; do
    sleep 1
    waited=$((waited + 1))
  done
  if kill -0 "${pid}" 2>/dev/null; then
    kill "${pid}" 2>/dev/null || true
    wait "${pid}" 2>/dev/null || true
    rm -f "${tmp}"
    return 1
  fi
  wait "${pid}" 2>/dev/null || true
  cat "${tmp}"
  rm -f "${tmp}"
}

load_flutter_devices() {
  if [[ -n "${FLUTTER_DEVICES_JSON}" ]]; then
    return 0
  fi
  echo "==> Querying Flutter devices (up to ${FLUTTER_DEVICES_TIMEOUT}s)…" >&2
  if ! FLUTTER_DEVICES_JSON="$(flutter_devices_machine)"; then
    FLUTTER_DEVICES_JSON="[]"
    return 1
  fi
  return 0
}

pick_device_from_json() {
  local want="$1"
  printf '%s' "${FLUTTER_DEVICES_JSON}" | python3 -c "
import json, sys
want = sys.argv[1]
raw = sys.stdin.read()
if not raw.strip():
    sys.exit(1)
try:
    devices = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(1)
for d in devices:
    if d.get('isSupported') is False:
        continue
    tp = d.get('targetPlatform') or ''
    if want == 'android' and tp.startswith('android'):
        print(d.get('id', ''))
        sys.exit(0)
    if want == 'ios' and tp.startswith('ios'):
        print(d.get('id', ''))
        sys.exit(0)
    if want == 'macos':
        if d.get('id') == 'macos':
            print('macos')
            sys.exit(0)
        if tp.startswith('darwin'):
            print(d.get('id', '') or 'macos')
            sys.exit(0)
sys.exit(1)
" "${want}"
}

pick_android_device_id() {
  if command -v adb >/dev/null 2>&1; then
    local serial
    serial="$(
      adb devices 2>/dev/null | awk 'NR > 1 && $2 == "device" { print $1; exit }'
    )"
    if [[ -n "${serial}" ]]; then
      echo "${serial}"
      return 0
    fi
  fi
  if load_flutter_devices; then
    pick_device_from_json android && return 0
  fi
  return 1
}

pick_ios_device_id() {
  if load_flutter_devices; then
    pick_device_from_json ios && return 0
  fi
  return 1
}

USER_PLATFORM="${1:-}"
if [[ "${USER_PLATFORM}" == "andriod" ]]; then
  USER_PLATFORM="android"
fi

DEVICE_ID=""
PLATFORM=""

if [[ -n "${FLUTTER_DEVICE_ID:-}" ]]; then
  case "${FLUTTER_DEVICE_ID}" in
    macos)
      use_macos_desktop
      ;;
    *)
      DEVICE_ID="${FLUTTER_DEVICE_ID}"
      PLATFORM="${USER_PLATFORM:-android}"
      ;;
  esac
elif [[ "${USER_PLATFORM}" == "macos" ]]; then
  use_macos_desktop
elif [[ "${USER_PLATFORM}" == "android" ]]; then
  PLATFORM="android"
  echo "==> Looking for Android device or emulator…" >&2
  DEVICE_ID="$(pick_android_device_id || true)"
elif [[ "${USER_PLATFORM}" == "ios" ]]; then
  PLATFORM="ios"
  echo "==> Looking for iOS Simulator…" >&2
  DEVICE_ID="$(pick_ios_device_id || true)"
elif [[ -z "${USER_PLATFORM}" ]]; then
  if is_darwin && macos_runner_present && [[ "${FLUTTER_PREFER_ANDROID:-}" != "1" ]]; then
    use_macos_desktop
    echo "note: Using macOS desktop. For Android: $0 android or FLUTTER_PREFER_ANDROID=1 $0" >&2
  elif [[ "${FLUTTER_PREFER_ANDROID:-}" == "1" ]] || ! is_darwin; then
    PLATFORM="android"
    echo "==> Looking for Android device or emulator…" >&2
    DEVICE_ID="$(pick_android_device_id || true)"
    if [[ -z "${DEVICE_ID}" ]] && is_darwin && macos_runner_present; then
      use_macos_desktop
      echo "note: No Android device — using macOS desktop." >&2
    fi
  else
    PLATFORM="android"
    DEVICE_ID="$(pick_android_device_id || true)"
  fi
else
  echo "error: platform must be android, ios, or macos (got: ${USER_PLATFORM})"
  exit 1
fi

# When API_BASE_URL is unset, match the host port Docker publishes for api:8000 (see infra/.env API_PORT).
API_HOST_PORT="8000"
if [[ -z "${API_BASE_URL:-}" ]]; then
  INFRA="${ROOT}/infra"
  ENV_FILE="${INFRA}/.env"
  COMPOSE=(docker compose -f "${INFRA}/docker-compose.yml")
  if [[ -f "${ENV_FILE}" ]]; then
    COMPOSE+=(--env-file "${ENV_FILE}")
  fi
  if "${COMPOSE[@]}" ps api --status running --quiet 2>/dev/null | grep -q .; then
    p="$("${COMPOSE[@]}" port api 8000 2>/dev/null | sed 's/.*://' || true)"
    if [[ -n "${p}" ]]; then
      API_HOST_PORT="${p}"
    fi
  else
    echo "warning: no running api container — using host port ${API_HOST_PORT} for --dart-define." >&2
    echo "         Start the API: ${ROOT}/scripts/run_dev.sh --no-seed" >&2
  fi
fi

case "${PLATFORM}" in
  android)
    DEF_URL="${API_BASE_URL:-http://10.0.2.2:${API_HOST_PORT}/v1}"
    ;;
  ios|macos)
    DEF_URL="${API_BASE_URL:-http://127.0.0.1:${API_HOST_PORT}/v1}"
    ;;
  *)
    echo "error: could not determine platform"
    exit 1
    ;;
esac

if [[ -z "${DEVICE_ID}" ]]; then
  echo "error: no supported ${PLATFORM} device found."
  echo ""
  case "${PLATFORM}" in
    android)
      echo "Start an emulator (Android Studio → Device Manager) or connect USB, then:"
      echo "  $0 android"
      echo "  flutter doctor --android-licenses"
      ;;
    macos)
      echo "Run setup, then retry:"
      echo "  ./scripts/setup_reader_flutter.sh"
      echo "  $0 macos"
      ;;
    ios)
      echo "Open Simulator and run: INSTALL_READER_IOS=1 ./scripts/setup_reader_flutter.sh"
      echo "  $0 ios"
      ;;
  esac
  exit 1
fi

echo "==> flutter run -d ${DEVICE_ID} (platform=${PLATFORM}, API_BASE_URL=${DEF_URL})"
echo "    First build can take several minutes with little output — this is normal."
case "${PLATFORM}" in
  android)
    echo "    Tip: Emulator → host API: 10.0.2.2:${API_HOST_PORT}"
    ;;
  macos)
    echo "    Tip: macOS uses localhost for API and MinIO."
    ;;
esac

exec flutter run -d "${DEVICE_ID}" --dart-define=API_BASE_URL="${DEF_URL}"
