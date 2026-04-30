#!/usr/bin/env bash
# Print the browser base URL for the Django API (respects API_PORT in infra/.env).
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA="${ROOT}/infra"
ENV_FILE="${INFRA}/.env"
COMPOSE=(docker compose -f "${INFRA}/docker-compose.yml")
if [[ -f "${ENV_FILE}" ]]; then
  COMPOSE+=(--env-file "${ENV_FILE}")
fi
if ! "${COMPOSE[@]}" ps api --status running --quiet 2>/dev/null | grep -q .; then
  echo "error: api container is not running. From ${INFRA}: docker compose up -d" >&2
  exit 1
fi
HOST_PORT="$("${COMPOSE[@]}" port api 8000 2>/dev/null | sed 's/.*://')"
if [[ -z "${HOST_PORT}" ]]; then
  echo "error: could not read published port for api:8000" >&2
  exit 1
fi
echo "http://127.0.0.1:${HOST_PORT}"
echo ""
echo "Open in browser:"
echo "  Swagger:  http://127.0.0.1:${HOST_PORT}/api/docs/"
echo "  Health:   http://127.0.0.1:${HOST_PORT}/healthz/"
