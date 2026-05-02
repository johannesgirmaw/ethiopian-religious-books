#!/usr/bin/env bash
# Android-first reader. If you omit the platform and no Android device is available, falls back to
# macOS desktop (API on 127.0.0.1) so you can develop before the Android SDK is installed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP="${ROOT}/apps/reader_flutter"

if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  echo "Usage: $0 [android|ios|macos]"
  echo ""
  echo "  $0                 # prefers Android; if none, uses macOS desktop (dev fallback)"
  echo "  $0 android         # Android only (fails if no device / SDK)"
  echo "  $0 macos           # macOS desktop only (localhost API)"
  echo "  $0 ios             # optional; Xcode + INSTALL_READER_IOS=1 setup"
  echo ""
  echo "API_BASE_URL defaults (override with API_BASE_URL=... or API_PORT=...):"
  echo "  android -> http://10.0.2.2:<port>/v1  (port from Docker when api is running, else 8000)"
  echo "  ios|macos -> http://127.0.0.1:<port>/v1"
  echo ""
  echo "Android: install Android Studio + SDK, then emulator or USB device."
  echo "  https://docs.flutter.dev/get-started/install/macos#android-setup"
  echo ""
  echo "Optional: FLUTTER_DEVICE_ID=<id> $0 android"
  exit 0
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter not found. Run: ./scripts/setup_reader_flutter.sh"
  exit 1
fi

cd "${APP}"

pick_device_id() {
  local want="$1"
  flutter devices --machine 2>/dev/null | python3 -c "
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

USER_PLATFORM="${1:-}"
if [[ "${USER_PLATFORM}" == "andriod" ]]; then
  USER_PLATFORM="android"
fi

AUTO_FALLBACK=0
if [[ -z "${USER_PLATFORM}" ]]; then
  AUTO_FALLBACK=1
fi

if [[ -n "${FLUTTER_DEVICE_ID:-}" ]]; then
  DEVICE_ID="${FLUTTER_DEVICE_ID}"
  PLATFORM="${USER_PLATFORM:-android}"
elif [[ "${AUTO_FALLBACK}" == "1" ]]; then
  DEVICE_ID="$(pick_device_id android || true)"
  if [[ -n "${DEVICE_ID}" ]]; then
    PLATFORM="android"
  else
    DEVICE_ID="$(pick_device_id macos || true)"
    if [[ -n "${DEVICE_ID}" ]]; then
      PLATFORM="macos"
      echo "note: No Android device or emulator found — using macOS desktop for this run." >&2
      echo "      Install Android Studio + SDK for Android builds: https://docs.flutter.dev/get-started/install/macos#android-setup" >&2
    else
      PLATFORM="android"
    fi
  fi
else
  PLATFORM="${USER_PLATFORM}"
  DEVICE_ID="$(pick_device_id "${PLATFORM}" || true)"
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
    echo "         Start the API: cd ${ROOT}/infra && docker compose up -d" >&2
    echo "         Or: ${ROOT}/scripts/verify_backend.sh" >&2
  fi
fi

case "${PLATFORM}" in
  android)
    if [[ -n "${API_BASE_URL:-}" ]]; then
      DEF_URL="${API_BASE_URL}"
    else
      DEF_URL="http://10.0.2.2:${API_HOST_PORT}/v1"
    fi
    ;;
  ios|macos)
    if [[ -n "${API_BASE_URL:-}" ]]; then
      DEF_URL="${API_BASE_URL}"
    else
      DEF_URL="http://127.0.0.1:${API_HOST_PORT}/v1"
    fi
    ;;
  *)
    echo "error: platform must be android, ios, or macos (got: ${USER_PLATFORM})"
    exit 1
    ;;
esac

if [[ -z "${DEVICE_ID}" ]]; then
  echo "error: no supported ${PLATFORM} device found."
  echo ""
  if [[ "${PLATFORM}" == "android" ]]; then
    echo "Install Android Studio (or Android SDK), create/start an emulator, or connect a USB device."
    echo "  • https://docs.flutter.dev/get-started/install/macos#android-setup"
    echo "  • flutter doctor --android-licenses"
    echo ""
    echo "Or run without forcing Android — uses macOS if available:"
    echo "  $0"
    echo "  $0 macos"
  elif [[ "${PLATFORM}" == "macos" ]]; then
    echo "Enable macOS desktop: flutter config --enable-macos-desktop && flutter doctor"
  else
    echo "For iOS: open -a Simulator and INSTALL_READER_IOS=1 ./scripts/setup_reader_flutter.sh"
  fi
  echo ""
  echo "Currently Flutter sees:"
  flutter devices || true
  exit 1
fi

echo "==> flutter run -d ${DEVICE_ID} (platform=${PLATFORM}, API_BASE_URL=${DEF_URL})"
if [[ "${PLATFORM}" == "android" ]]; then
  echo "    Tip: Emulator → host API: 10.0.2.2:<API_PORT> (default 8000)."
  echo "    Tip: MinIO presign: AWS_S3_PRESIGN_ENDPOINT_URL=http://10.0.2.2:19000 in infra/.env"
elif [[ "${PLATFORM}" == "ios" ]]; then
  echo "    Tip: If \"Download\" fails with localhost:19000, Django DEBUG + debug app sends X-Dev-S3-Origin."
  echo "    Tip: Release / production builds: set AWS_S3_PRESIGN_ENDPOINT_URL to a LAN URL in infra/.env."
elif [[ "${PLATFORM}" == "macos" ]]; then
  echo "    Tip: macOS uses localhost for API and MinIO (defaults in compose usually work)."
fi
exec flutter run -d "${DEVICE_ID}" --dart-define=API_BASE_URL="${DEF_URL}"
