#!/usr/bin/env bash
# Run the Flutter reader on any supported platform.
#
# Usage:
#   ./scripts/run_reader_flutter.sh [platform]
#
# Platforms: android | ios | macos | web | linux | windows
# On macOS with no arg: defaults to macOS desktop (fast; no device scan).
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=flutter_reader_common.sh
source "${SCRIPT_DIR}/flutter_reader_common.sh"

FLUTTER_DEVICES_TIMEOUT="${FLUTTER_DEVICES_TIMEOUT:-45}"
FLUTTER_DEVICES_JSON=""

usage() {
  cat <<EOF
Usage: $0 [platform]

Run the Flutter reader in debug mode against the local API (when running).

Platforms:
  (none)    macOS desktop on Darwin; Android elsewhere / when preferred
  android   Android emulator or USB device
  ios       iOS Simulator (INSTALL_READER_IOS=1 setup)
  macos     macOS desktop
  web       Chrome (creates web/ runner if missing)
  linux     Linux desktop
  windows   Windows desktop

Environment:
  FLUTTER_DEVICE_ID=<id>       Skip device discovery
  FLUTTER_PREFER_ANDROID=1     On macOS, try Android before desktop when no arg
  FLUTTER_DEVICES_TIMEOUT=45   Seconds to wait for flutter devices (android/ios)
  FLUTTER_CREATE_PLATFORM=1    Auto-create missing web/linux/windows runners
  API_BASE_URL                 Override dev API base (with /v1 suffix)

Dev API defaults (when API container is running):
  android  -> http://10.0.2.2:<API_PORT>/v1/
  ios|macos|linux|windows -> http://127.0.0.1:<API_PORT>/v1/
  web      -> http://localhost:<API_PORT>/v1/
EOF
}

if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

require_flutter
cd "${APP}"

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
    if want == 'web' and (tp.startswith('web') or d.get('id') == 'chrome'):
        print(d.get('id', '') or 'chrome')
        sys.exit(0)
    if want == 'linux' and tp.startswith('linux'):
        print(d.get('id', '') or 'linux')
        sys.exit(0)
    if want == 'windows' and tp.startswith('windows'):
        print(d.get('id', '') or 'windows')
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

pick_desktop_or_web_device_id() {
  local want="$1"
  if load_flutter_devices; then
    pick_device_from_json "${want}" && return 0
  fi
  echo "$(device_id_for_platform "${want}")"
}

use_macos_desktop() {
  prepare_platform macos
  DEVICE_ID="macos"
  PLATFORM="macos"
}

USER_PLATFORM="$(normalize_platform "${1:-}")"
DEVICE_ID=""
PLATFORM=""

if [[ -n "${USER_PLATFORM}" ]] && ! valid_run_platform "${USER_PLATFORM}"; then
  echo "error: platform must be android, ios, macos, web, linux, or windows (got: ${1})"
  usage
  exit 1
fi

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
  prepare_platform ios
  PLATFORM="ios"
  echo "==> Looking for iOS Simulator…" >&2
  DEVICE_ID="$(pick_ios_device_id || true)"
elif [[ "${USER_PLATFORM}" == "web" ]]; then
  prepare_platform web
  PLATFORM="web"
  DEVICE_ID="$(pick_desktop_or_web_device_id web)"
elif [[ "${USER_PLATFORM}" == "linux" ]]; then
  prepare_platform linux
  PLATFORM="linux"
  DEVICE_ID="$(pick_desktop_or_web_device_id linux)"
elif [[ "${USER_PLATFORM}" == "windows" ]]; then
  prepare_platform windows
  PLATFORM="windows"
  DEVICE_ID="$(pick_desktop_or_web_device_id windows)"
elif [[ -z "${USER_PLATFORM}" ]]; then
  if is_darwin && platform_runner_present macos && [[ "${FLUTTER_PREFER_ANDROID:-}" != "1" ]]; then
    use_macos_desktop
    echo "note: Using macOS desktop. For Android: $0 android | web: $0 web" >&2
  elif [[ "${FLUTTER_PREFER_ANDROID:-}" == "1" ]] || ! is_darwin; then
    PLATFORM="android"
    echo "==> Looking for Android device or emulator…" >&2
    DEVICE_ID="$(pick_android_device_id || true)"
    if [[ -z "${DEVICE_ID}" ]] && is_darwin && platform_runner_present macos; then
      use_macos_desktop
      echo "note: No Android device — using macOS desktop." >&2
    fi
  else
    PLATFORM="android"
    DEVICE_ID="$(pick_android_device_id || true)"
  fi
fi

if [[ -z "${PLATFORM}" ]]; then
  echo "error: could not determine platform"
  exit 1
fi

DEF_URL="$(dev_api_base_url_for_platform "${PLATFORM}")"

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
    web)
      echo "Install Chrome, then: $0 web"
      ;;
    linux)
      echo "Enable Linux desktop: flutter config --enable-linux-desktop"
      echo "  $0 linux"
      ;;
    windows)
      echo "Enable Windows desktop: flutter config --enable-windows-desktop"
      echo "  $0 windows"
      ;;
  esac
  exit 1
fi

if [[ -z "${API_BASE_URL:-}" ]]; then
  compose=(docker compose -f "${INFRA}/docker-compose.yml")
  if [[ -f "${ENV_FILE}" ]]; then
    compose+=(--env-file "${ENV_FILE}")
  fi
  if ! "${compose[@]}" ps api --status running --quiet 2>/dev/null | grep -q .; then
    echo "warning: no running api container — using host port $(resolve_api_host_port) for --dart-define." >&2
    echo "         Start the API: ${ROOT}/scripts/run_dev.sh --no-seed" >&2
  fi
fi

echo "==> flutter run -d ${DEVICE_ID} (platform=${PLATFORM}, API_BASE_URL=${DEF_URL})"
echo "    First build can take several minutes with little output — this is normal."
case "${PLATFORM}" in
  android)
    echo "    Tip: Emulator → host API: 10.0.2.2:$(resolve_api_host_port)"
    ;;
  macos | linux | windows)
    echo "    Tip: Desktop uses localhost for API and MinIO."
    ;;
  web)
    echo "    Tip: Web uses localhost for API. CORS must allow the dev origin on the API."
    ;;
esac

exec flutter run -d "${DEVICE_ID}" "$(dart_defines_for_url "${DEF_URL}")"
