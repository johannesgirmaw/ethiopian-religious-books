#!/usr/bin/env bash
# Shared helpers for Flutter reader run/build scripts.
# Source from other scripts:  source "$(dirname "${BASH_SOURCE[0]}")/flutter_reader_common.sh"

if [[ -n "${FLUTTER_READER_COMMON_LOADED:-}" ]]; then
  return 0 2>/dev/null || exit 0
fi
FLUTTER_READER_COMMON_LOADED=1

ROOT="$(cd "$(dirname "${BASH_SOURCE[1]:-${BASH_SOURCE[0]}}")/.." && pwd)"
APP="${ROOT}/apps/reader_flutter"
INFRA="${ROOT}/infra"
ENV_FILE="${INFRA}/.env"

# Keep in sync with apps/reader_flutter/lib/config/app_config.dart
PRODUCTION_API_BASE_URL="${PRODUCTION_API_BASE_URL:-https://religious-books-api-wz6y.onrender.com/v1/}"

is_darwin() {
  [[ "$(uname -s)" == "Darwin" ]]
}

is_linux() {
  [[ "$(uname -s)" == "Linux" ]]
}

is_windows() {
  case "$(uname -s)" in
    MINGW* | MSYS* | CYGWIN*) return 0 ;;
  esac
  [[ "${OS:-}" == "Windows_NT" ]]
}

require_flutter() {
  if ! command -v flutter >/dev/null 2>&1; then
    echo "error: flutter not found. Run: ./scripts/setup_reader_flutter.sh"
    exit 1
  fi
}

normalize_platform() {
  local p="${1:-}"
  case "${p}" in
    andriod) echo "android" ;;
    aab | appbundle) echo "appbundle" ;;
    apk) echo "android" ;;
    darwin | osx) echo "macos" ;;
    *) echo "${p}" ;;
  esac
}

valid_run_platform() {
  case "$(normalize_platform "$1")" in
    android | ios | macos | web | linux | windows) return 0 ;;
    *) return 1 ;;
  esac
}

valid_build_platform() {
  case "$(normalize_platform "$1")" in
    android | ios | macos | web | linux | windows) return 0 ;;
    *) return 1 ;;
  esac
}

platform_runner_dir() {
  case "$(normalize_platform "$1")" in
    android) echo "android" ;;
    ios) echo "ios" ;;
    macos) echo "macos" ;;
    web) echo "web" ;;
    linux) echo "linux" ;;
    windows) echo "windows" ;;
    *) echo "" ;;
  esac
}

platform_runner_present() {
  local dir
  dir="$(platform_runner_dir "$1")"
  [[ -n "${dir}" && -d "${APP}/${dir}" ]]
}

enable_flutter_platform() {
  local platform="$1"
  case "${platform}" in
    macos)
      flutter config --enable-macos-desktop >/dev/null 2>&1 || true
      ;;
    linux)
      flutter config --enable-linux-desktop >/dev/null 2>&1 || true
      ;;
    windows)
      flutter config --enable-windows-desktop >/dev/null 2>&1 || true
      ;;
    web)
      flutter config --enable-web >/dev/null 2>&1 || true
      ;;
  esac
}

ensure_platform_runner() {
  local platform
  platform="$(normalize_platform "$1")"
  local dir
  dir="$(platform_runner_dir "${platform}")"

  if [[ -z "${dir}" ]]; then
    echo "error: unknown platform: ${1}"
    exit 1
  fi

  if platform_runner_present "${platform}"; then
    return 0
  fi

  if [[ "${FLUTTER_CREATE_PLATFORM:-1}" != "1" ]]; then
    echo "error: ${platform} runner missing at ${APP}/${dir}"
    echo "       Run: cd ${APP} && flutter create --platforms=${platform} ."
    echo "       Or:  FLUTTER_CREATE_PLATFORM=1 ./scripts/run_reader_flutter.sh ${platform}"
    exit 1
  fi

  require_flutter
  enable_flutter_platform "${platform}"
  echo "==> Creating ${platform} runner (flutter create --platforms=${platform} .)…" >&2
  (cd "${APP}" && flutter create --platforms="${platform}" .)
}

ensure_host_can_build() {
  local platform
  platform="$(normalize_platform "$1")"
  case "${platform}" in
    macos)
      if ! is_darwin; then
        echo "error: macOS builds require a Mac host."
        exit 1
      fi
      ;;
    ios)
      if ! is_darwin; then
        echo "error: iOS builds require a Mac host with Xcode."
        exit 1
      fi
      ;;
    windows)
      if ! is_windows; then
        echo "error: Windows desktop builds must run on Windows."
        echo "       (Cross-compiling Windows from macOS/Linux is not supported.)"
        exit 1
      fi
      ;;
  esac
}

ensure_macos_pods() {
  if [[ ! -f "${APP}/macos/Podfile" ]]; then
    return 0
  fi
  if ! command -v pod >/dev/null 2>&1; then
    echo "warning: CocoaPods (pod) not found; macOS build may fail." >&2
    return 0
  fi
  if [[ ! -d "${APP}/macos/Pods" ]] || [[ ! -f "${APP}/macos/Podfile.lock" ]]; then
    echo "==> pod install (macOS)…" >&2
    (cd "${APP}/macos" && pod install) || {
      echo "error: macos pod install failed. Run: cd ${APP}/macos && pod install"
      exit 1
    }
  fi
}

ensure_ios_pods() {
  if [[ ! -f "${APP}/ios/Podfile" ]]; then
    return 0
  fi
  if ! command -v pod >/dev/null 2>&1; then
    echo "error: CocoaPods required for iOS. Install: brew install cocoapods"
    exit 1
  fi
  if [[ ! -d "${APP}/ios/Pods" ]] || [[ ! -f "${APP}/ios/Podfile.lock" ]]; then
    echo "==> pod install (iOS)…" >&2
    (cd "${APP}/ios" && pod install) || {
      echo "error: ios pod install failed. Run: INSTALL_READER_IOS=1 ./scripts/setup_reader_flutter.sh"
      exit 1
    }
  fi
}

prepare_platform() {
  local platform
  platform="$(normalize_platform "$1")"
  ensure_platform_runner "${platform}"
  enable_flutter_platform "${platform}"

  case "${platform}" in
    macos) ensure_macos_pods ;;
    ios) ensure_ios_pods ;;
  esac
}

resolve_api_host_port() {
  local port="8000"
  if [[ -f "${ENV_FILE}" ]]; then
    local line val
    line="$(grep -E '^API_PORT=' "${ENV_FILE}" 2>/dev/null | tail -1 || true)"
    if [[ -n "${line}" ]]; then
      val="${line#*=}"
      val="${val%\"}"
      val="${val#\"}"
      val="${val// /}"
      if [[ -n "${val}" ]]; then
        port="${val}"
      fi
    fi
  fi

  local compose=(docker compose -f "${INFRA}/docker-compose.yml")
  if [[ -f "${ENV_FILE}" ]]; then
    compose+=(--env-file "${ENV_FILE}")
  fi
  if "${compose[@]}" ps api --status running --quiet 2>/dev/null | grep -q .; then
    local mapped
    mapped="$("${compose[@]}" port api 8000 2>/dev/null | sed 's/.*://' || true)"
    if [[ -n "${mapped}" ]]; then
      port="${mapped}"
    fi
  fi
  echo "${port}"
}

# Dev API URL for flutter run (debug).
dev_api_base_url_for_platform() {
  local platform host_port base
  platform="$(normalize_platform "$1")"
  host_port="$(resolve_api_host_port)"

  if [[ -n "${API_BASE_URL:-}" ]]; then
    base="${API_BASE_URL}"
  else
    case "${platform}" in
      android) base="http://10.0.2.2:${host_port}/v1" ;;
      web) base="http://localhost:${host_port}/v1" ;;
      ios | macos | linux | windows) base="http://127.0.0.1:${host_port}/v1" ;;
      *)
        echo "error: could not determine API URL for platform ${platform}" >&2
        return 1
        ;;
    esac
  fi

  case "${base}" in
    */) echo "${base}" ;;
    *) echo "${base}/" ;;
  esac
}

# Release API URL for flutter build (defaults to production).
release_api_base_url() {
  local base="${API_BASE_URL:-${PRODUCTION_API_BASE_URL}}"
  case "${base}" in
    */) echo "${base}" ;;
    *) echo "${base}/" ;;
  esac
}

dart_defines_for_url() {
  local url="$1"
  echo "--dart-define=API_BASE_URL=${url}"
}

flutter_pub_get() {
  require_flutter
  echo "==> flutter pub get"
  (cd "${APP}" && flutter pub get)
}

device_id_for_platform() {
  local platform="$1"
  case "${platform}" in
    android) echo "android" ;;
    ios) echo "ios" ;;
    macos) echo "macos" ;;
    web) echo "chrome" ;;
    linux) echo "linux" ;;
    windows) echo "windows" ;;
    *) echo "${platform}" ;;
  esac
}

print_build_output_hint() {
  local platform format abi
  platform="$(normalize_platform "$1")"
  format="${2:-}"
  abi="${3:-}"

  echo ""
  echo "Done. API base: $(release_api_base_url)"
  case "${platform}" in
    android)
      if [[ "${format}" == "appbundle" ]]; then
        local aab="${APP}/build/app/outputs/bundle/release/app-release.aab"
        [[ -f "${aab}" ]] && echo "App Bundle: ${aab}"
      else
        local out="${APP}/build/app/outputs/flutter-apk"
        if [[ -d "${out}" ]]; then
          echo "APK(s):"
          find "${out}" -maxdepth 1 -name '*.apk' -print | sed 's/^/  /'
        fi
      fi
      ;;
    ios)
      echo "iOS archive: open ${APP}/ios/Runner.xcworkspace in Xcode → Product → Archive"
      echo "Or IPA: ${APP}/build/ios/ipa/*.ipa (when built with export options)"
      ;;
    macos)
      local app="${APP}/build/macos/Build/Products/Release/ethiopian_reader.app"
      [[ -d "${app}" ]] && echo "macOS app: ${app}"
      ;;
    web)
      echo "Web build: ${APP}/build/web/"
      ;;
    linux)
      local bin="${APP}/build/linux/x64/release/bundle"
      [[ -d "${bin}" ]] && echo "Linux bundle: ${bin}"
      ;;
    windows)
      local exe="${APP}/build/windows/x64/runner/Release"
      [[ -d "${exe}" ]] && echo "Windows build: ${exe}/"
      ;;
  esac
}

# --- Mobile simulators / emulators -------------------------------------------

find_android_sdk_root() {
  local sdk=""
  for sdk in "${ANDROID_SDK_ROOT:-}" "${ANDROID_HOME:-}" "${HOME}/Library/Android/sdk"; do
    if [[ -n "${sdk}" && -d "${sdk}" ]]; then
      echo "${sdk}"
      return 0
    fi
  done
  return 1
}

android_sdk_executable() {
  local rel="$1"
  local sdk bin
  if sdk="$(find_android_sdk_root)"; then
    bin="${sdk}/${rel}"
    if [[ -x "${bin}" ]]; then
      echo "${bin}"
      return 0
    fi
  fi
  command -v "$(basename "${rel}")" 2>/dev/null || true
}

android_emulator_serial() {
  local adb
  adb="$(android_sdk_executable platform-tools/adb)"
  [[ -z "${adb}" ]] && return 1
  "${adb}" devices 2>/dev/null | awk 'NR > 1 && $2 == "device" { print $1; exit }'
}

android_emulator_ready() {
  local serial boot
  serial="$(android_emulator_serial || true)"
  [[ -z "${serial}" ]] && return 1
  local adb
  adb="$(android_sdk_executable platform-tools/adb)"
  boot="$("${adb}" -s "${serial}" shell getprop sys.boot_completed 2>/dev/null | tr -d '\r')"
  [[ "${boot}" == "1" ]]
}

pick_android_avd() {
  local emulator avd avds
  if [[ -n "${ANDROID_AVD:-}" ]]; then
    echo "${ANDROID_AVD}"
    return 0
  fi
  emulator="$(android_sdk_executable emulator/emulator)"
  if [[ -z "${emulator}" ]]; then
    return 1
  fi
  avds="$("${emulator}" -list-avds 2>/dev/null || true)"
  if [[ -z "${avds}" ]]; then
    return 1
  fi
  avd="$(printf '%s\n' "${avds}" | grep -iE 'pixel|phone' | head -1 || true)"
  if [[ -z "${avd}" ]]; then
    avd="$(printf '%s\n' "${avds}" | head -1)"
  fi
  echo "${avd}"
}

start_android_emulator() {
  local emulator avd serial adb timeout waited=0
  timeout="${ANDROID_EMULATOR_BOOT_TIMEOUT:-180}"

  if android_emulator_ready; then
    serial="$(android_emulator_serial)"
    echo "==> Android emulator already running (${serial})" >&2
    echo "${serial}"
    return 0
  fi

  emulator="$(android_sdk_executable emulator/emulator)"
  if [[ -z "${emulator}" ]]; then
    echo "error: Android emulator not found." >&2
    echo "       Install Android Studio + SDK, then create an AVD (Device Manager)." >&2
    echo "       Set ANDROID_HOME or ANDROID_SDK_ROOT if the SDK is non-standard." >&2
    return 1
  fi

  avd="$(pick_android_avd || true)"
  if [[ -z "${avd}" ]]; then
    echo "error: no Android Virtual Device (AVD) found." >&2
    echo "       Android Studio → Device Manager → Create Virtual Device" >&2
    echo "       Or set ANDROID_AVD=<name> (list: emulator -list-avds)" >&2
    return 1
  fi

  echo "==> Starting Android emulator: ${avd}" >&2
  # shellcheck disable=SC2086
  nohup "${emulator}" -avd "${avd}" ${ANDROID_EMULATOR_FLAGS:-} >/dev/null 2>&1 &
  disown 2>/dev/null || true

  adb="$(android_sdk_executable platform-tools/adb)"
  if [[ -n "${adb}" ]]; then
    "${adb}" wait-for-device >/dev/null 2>&1 || true
  fi

  while [[ "${waited}" -lt "${timeout}" ]]; do
    if android_emulator_ready; then
      serial="$(android_emulator_serial)"
      echo "==> Android emulator ready (${serial})" >&2
      echo "${serial}"
      return 0
    fi
    sleep 2
    waited=$((waited + 2))
  done

  echo "error: Android emulator did not finish booting within ${timeout}s." >&2
  return 1
}

ios_simulator_booted_udid() {
  xcrun simctl list devices booted -j 2>/dev/null | python3 -c "
import json, sys
raw = sys.stdin.read()
if not raw.strip():
    sys.exit(1)
try:
    data = json.loads(raw)
except json.JSONDecodeError:
    sys.exit(1)
for d in data.get('devices', {}).values():
    for dev in d:
        if dev.get('state') == 'Booted':
            print(dev.get('udid', ''))
            sys.exit(0)
sys.exit(1)
" 2>/dev/null || true
}

pick_ios_simulator_udid() {
  if [[ -n "${IOS_SIMULATOR_UDID:-}" ]]; then
    echo "${IOS_SIMULATOR_UDID}"
    return 0
  fi
  xcrun simctl list devices available -j 2>/dev/null | python3 -c "
import json, sys
want = (sys.argv[1] if len(sys.argv) > 1 else '').lower()
data = json.load(sys.stdin)
candidates = []
for runtime, devices in sorted(data.get('devices', {}).items(), reverse=True):
    if 'ios' not in runtime.lower():
        continue
    for d in devices:
        if d.get('isAvailable') is False:
            continue
        name = d.get('name', '')
        if want and want not in name.lower():
            continue
        if 'iPhone' in name or 'iPad' in name:
            candidates.append((runtime, name, d['udid']))
for _, name, udid in candidates:
    if 'iPhone' in name:
        print(udid)
        sys.exit(0)
if candidates:
    print(candidates[0][2])
    sys.exit(0)
sys.exit(1)
" "${IOS_SIMULATOR_DEVICE:-iPhone}"
}

start_ios_simulator() {
  local udid booted timeout waited=0
  timeout="${IOS_SIMULATOR_BOOT_TIMEOUT:-120}"

  if ! is_darwin; then
    echo "error: iOS Simulator requires macOS with Xcode." >&2
    return 1
  fi

  if ! command -v xcrun >/dev/null 2>&1; then
    echo "error: xcrun not found. Install Xcode and run: xcode-select --install" >&2
    return 1
  fi

  booted="$(ios_simulator_booted_udid || true)"
  if [[ -n "${booted}" ]]; then
    echo "==> iOS Simulator already booted (${booted})" >&2
    echo "${booted}"
    return 0
  fi

  udid="$(pick_ios_simulator_udid || true)"
  if [[ -z "${udid}" ]]; then
    echo "error: no iOS Simulator found." >&2
    echo "       Install an iOS runtime in Xcode → Settings → Platforms." >&2
    echo "       Or set IOS_SIMULATOR_UDID or IOS_SIMULATOR_DEVICE='iPhone 16'." >&2
    return 1
  fi

  echo "==> Booting iOS Simulator (${udid})" >&2
  xcrun simctl boot "${udid}" 2>/dev/null || true
  open -a Simulator >/dev/null 2>&1 || true

  while [[ "${waited}" -lt "${timeout}" ]]; do
    booted="$(ios_simulator_booted_udid || true)"
    if [[ -n "${booted}" ]]; then
      echo "==> iOS Simulator ready (${booted})" >&2
      echo "${booted}"
      return 0
    fi
    sleep 2
    waited=$((waited + 2))
  done

  echo "error: iOS Simulator did not boot within ${timeout}s." >&2
  return 1
}

ensure_ios_simulator_setup() {
  if ! is_darwin; then
    echo "error: iOS Simulator requires macOS." >&2
    exit 1
  fi
  prepare_platform ios
  if [[ ! -d "${APP}/ios/Pods" ]] && [[ -f "${APP}/ios/Podfile" ]]; then
    echo "==> iOS CocoaPods missing — run once: INSTALL_READER_IOS=1 ./scripts/setup_reader_flutter.sh" >&2
    if [[ "${INSTALL_READER_IOS:-}" == "1" ]] || [[ "${FLUTTER_IOS_AUTO_POD:-1}" == "1" ]]; then
      ensure_ios_pods
    else
      echo "       Or: FLUTTER_IOS_AUTO_POD=1 $0" >&2
      exit 1
    fi
  fi
}

docker_compose_cmd() {
  local compose=(docker compose -f "${INFRA}/docker-compose.yml")
  if [[ -f "${ENV_FILE}" ]]; then
    compose+=(--env-file "${ENV_FILE}")
  fi
  "${compose[@]}" "$@"
}

local_api_health_url() {
  echo "http://127.0.0.1:$(resolve_api_host_port)/healthz/"
}

local_api_is_healthy() {
  docker_compose_cmd ps api --status running --quiet 2>/dev/null | grep -q . \
    && curl -sf "$(local_api_health_url)" >/dev/null 2>&1
}

# Start Docker API stack if not running. Optional migrate + seed_dev (default: on).
ensure_local_api_running() {
  local run_seed="${1:-1}"

  if local_api_is_healthy; then
    echo "==> API already running at http://127.0.0.1:$(resolve_api_host_port)" >&2
    return 0
  fi

  if [[ ! -f "${INFRA}/docker-compose.yml" ]]; then
    echo "warning: no ${INFRA}/docker-compose.yml — skipping API startup." >&2
    return 0
  fi

  if [[ ! -f "${ENV_FILE}" ]] && [[ -f "${INFRA}/.env.example" ]]; then
    echo "Creating ${ENV_FILE} from .env.example" >&2
    cp "${INFRA}/.env.example" "${ENV_FILE}"
  fi

  echo "==> Starting backend (postgres, redis, minio, mailhog, api)…" >&2
  docker_compose_cmd up -d --build postgres redis minio mailhog api

  echo "==> Waiting for API…" >&2
  for _ in $(seq 1 90); do
    if local_api_is_healthy; then
      break
    fi
    sleep 1
  done

  if ! local_api_is_healthy; then
    echo "error: API did not become healthy at http://127.0.0.1:$(resolve_api_host_port)" >&2
    echo "       Check: docker compose -f ${INFRA}/docker-compose.yml logs api" >&2
    return 1
  fi

  if [[ "${run_seed}" == "1" ]]; then
    echo "==> Django migrate + seed_dev…" >&2
    docker_compose_cmd exec -T api python manage.py migrate --noinput
    docker_compose_cmd exec -T api python manage.py seed_dev
  fi

  echo "==> API ready: http://127.0.0.1:$(resolve_api_host_port)" >&2
}

