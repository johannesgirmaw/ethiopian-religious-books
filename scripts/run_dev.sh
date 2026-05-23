#!/usr/bin/env bash
# Start the Docker backend (API + data services) and run the Flutter reader app.
#
# Backend stays up after you quit Flutter unless you pass --down.
# Flutter platform args are forwarded to ./scripts/run_reader_flutter.sh
# (android | ios | macos, or omit for Android-with-macos fallback).
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA="${ROOT}/infra"
COMPOSE_FILE="${INFRA}/docker-compose.yml"
ENV_FILE="${INFRA}/.env"
EXAMPLE="${INFRA}/.env.example"
RUN_FLUTTER="${ROOT}/scripts/run_reader_flutter.sh"

DOWN_ON_EXIT=0
SKIP_BACKEND=0
SKIP_SEED=0
FLUTTER_ARGS=()

usage() {
  cat <<'EOF'
Usage: ./scripts/run_dev.sh [options] [android|ios|macos]

Starts the local API stack (Docker Compose), waits until /healthz/ responds,
runs migrations and seed_dev (idempotent), then launches the Flutter reader.

Options:
  -h, --help       Show this help
  --down           Stop Docker Compose services when the Flutter process exits
  --no-backend     Skip starting Docker (use when the stack is already running)
  --no-seed        Skip migrate + seed_dev after the API is up

Examples:
  ./scripts/run_dev.sh
  ./scripts/run_dev.sh android
  ./scripts/run_dev.sh macos --down
  ./scripts/run_dev.sh --no-backend macos

See also: ./scripts/dev.sh (foreground compose only), ./scripts/verify_backend.sh (smoke test)
EOF
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    -h|--help)
      usage
      exit 0
      ;;
    --down)
      DOWN_ON_EXIT=1
      shift
      ;;
    --no-backend)
      SKIP_BACKEND=1
      shift
      ;;
    --no-seed)
      SKIP_SEED=1
      shift
      ;;
    *)
      FLUTTER_ARGS+=("$1")
      shift
      ;;
  esac
done

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "error: missing ${COMPOSE_FILE}"
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ -f "${EXAMPLE}" ]]; then
    echo "Creating ${ENV_FILE} from .env.example — please review values."
    cp "${EXAMPLE}" "${ENV_FILE}"
  else
    echo "error: missing ${ENV_FILE}"
    exit 1
  fi
fi

compose() {
  docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" "$@"
}

read_env_port() {
  local var_name="$1"
  local default="$2"
  if [[ -f "${ENV_FILE}" ]]; then
    local line val
    line="$(grep -E "^${var_name}=" "${ENV_FILE}" 2>/dev/null | tail -1 || true)"
    if [[ -n "${line}" ]]; then
      val="${line#*=}"
      val="${val%\"}"
      val="${val#\"}"
      val="${val// /}"
      if [[ -n "${val}" ]]; then
        echo "${val}"
        return
      fi
    fi
  fi
  echo "${default}"
}

port_in_use() {
  lsof -nP -iTCP:"$1" -sTCP:LISTEN >/dev/null 2>&1
}

free_host_port() {
  local port="$1"
  if ! port_in_use "${port}"; then
    return 0
  fi

  echo "==> Port ${port} is in use; freeing it…"

  local cid name
  while IFS= read -r cid; do
    [[ -z "${cid}" ]] && continue
    name="$(docker inspect -f '{{.Name}}' "${cid}" 2>/dev/null | sed 's|^/||' || echo "${cid}")"
    echo "    stopping container: ${name}"
    docker stop "${cid}" >/dev/null 2>&1 || true
  done < <(docker ps -q --filter "publish=${port}" 2>/dev/null || true)

  if compose ps -a api --quiet 2>/dev/null | grep -q .; then
    compose stop api >/dev/null 2>&1 || true
    compose rm -f api >/dev/null 2>&1 || true
  fi

  sleep 1

  local pid comm
  while IFS= read -r pid; do
    [[ -z "${pid}" ]] && continue
    comm="$(ps -p "${pid}" -o comm= 2>/dev/null | xargs || echo "?")"
    case "${comm}" in
      com.docker*|docker*|Docker*)
        continue
        ;;
    esac
    echo "    killing PID ${pid} (${comm})"
    kill "${pid}" 2>/dev/null || kill -9 "${pid}" 2>/dev/null || true
  done < <(lsof -nP -tiTCP:"${port}" -sTCP:LISTEN 2>/dev/null || true)

  sleep 1
  if port_in_use "${port}"; then
    echo "error: port ${port} is still in use:"
    lsof -nP -iTCP:"${port}" -sTCP:LISTEN 2>/dev/null || true
    echo "       Set another API_PORT in ${ENV_FILE} or stop the process manually."
    exit 1
  fi
  echo "    port ${port} is free"
}

api_already_healthy() {
  compose ps api --status running --quiet 2>/dev/null | grep -q . \
    && curl -sf "$(api_base_url)/healthz/" >/dev/null 2>&1
}

api_base_url() {
  local port
  port="$(compose port api 8000 2>/dev/null | sed 's/.*://' || true)"
  echo "http://127.0.0.1:${port:-8000}"
}

cleanup() {
  local code=$?
  if [[ "${DOWN_ON_EXIT}" == "1" ]]; then
    echo ""
    echo "==> Stopping Docker Compose stack…"
    compose down
  fi
  exit "${code}"
}
trap cleanup EXIT INT TERM

if [[ "${SKIP_BACKEND}" == "0" ]]; then
  API_HOST_PORT="$(read_env_port API_PORT 8000)"

  if api_already_healthy; then
    echo "==> API already healthy at $(api_base_url)"
  else
    free_host_port "${API_HOST_PORT}"
    echo "==> Starting backend (postgres, redis, minio, mailhog, api)…"
    compose up -d --build postgres redis minio mailhog api

    BASE_URL="$(api_base_url)"
    echo "==> Waiting for API at ${BASE_URL}…"
    for _ in $(seq 1 90); do
      if curl -sf "${BASE_URL}/healthz/" >/dev/null 2>&1; then
        break
      fi
      sleep 1
    done
    if ! curl -sf "${BASE_URL}/healthz/" >/dev/null 2>&1; then
      echo "error: API did not become healthy at ${BASE_URL}"
      echo "       Check logs: docker compose -f ${COMPOSE_FILE} --env-file ${ENV_FILE} logs api"
      exit 1
    fi
  fi

  BASE_URL="$(api_base_url)"

  if [[ "${SKIP_SEED}" == "0" ]]; then
    echo "==> Django migrate + seed_dev…"
    compose exec -T api python manage.py migrate --noinput
    compose exec -T api python manage.py seed_dev
  fi

  echo ""
  echo "Backend ready:"
  echo "  API:     ${BASE_URL}"
  echo "  Swagger: ${BASE_URL}/api/docs/"
  echo "  MinIO:   http://localhost:${MINIO_API_PORT:-19000} (console :${MINIO_CONSOLE_PORT:-19001})"
  echo ""
else
  if ! compose ps api --status running --quiet 2>/dev/null | grep -q .; then
    echo "error: --no-backend set but api container is not running"
    echo "       Start it: cd ${INFRA} && docker compose up -d"
    exit 1
  fi
  echo "==> Using existing backend at $(api_base_url)"
  echo ""
fi

if ! command -v flutter >/dev/null 2>&1; then
  echo "error: flutter not found. Run: ./scripts/setup_reader_flutter.sh"
  exit 1
fi

if [[ ! -x "${RUN_FLUTTER}" ]]; then
  chmod +x "${RUN_FLUTTER}" 2>/dev/null || true
fi

echo "==> Starting Flutter reader (Ctrl+C stops the app; backend keeps running)"
if [[ "${DOWN_ON_EXIT}" == "1" ]]; then
  echo "    (--down: Compose stack will stop when Flutter exits)"
fi
if [[ ${#FLUTTER_ARGS[@]} -eq 0 ]] && [[ "$(uname -s)" == "Darwin" ]]; then
  echo "    Target: macOS desktop (pass 'android' for emulator)"
fi
echo ""

"${RUN_FLUTTER}" "${FLUTTER_ARGS[@]+"${FLUTTER_ARGS[@]}"}"
