#!/usr/bin/env bash
# Start full Docker Compose stack from repo root.
# Requires infra/docker-compose.yml to define all services you use (add api/celery when ready).

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA="${ROOT}/infra"
ENV_FILE="${INFRA}/.env"
EXAMPLE="${INFRA}/.env.example"

cd "${ROOT}"

if [[ ! -f "${INFRA}/docker-compose.yml" ]]; then
  echo "error: missing ${INFRA}/docker-compose.yml"
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ -f "${EXAMPLE}" ]]; then
    echo "Creating ${ENV_FILE} from .env.example — please review values."
    cp "${EXAMPLE}" "${ENV_FILE}"
  else
    echo "error: missing ${ENV_FILE} and no .env.example to copy"
    exit 1
  fi
fi

echo "==> Docker Compose (infra/)"
docker compose -f "${INFRA}/docker-compose.yml" --env-file "${ENV_FILE}" up --build "$@"

echo ""
echo "Local URLs (infra services):"
echo "  PostgreSQL   localhost:\${POSTGRES_PORT:-15432}"
echo "  Redis        localhost:\${REDIS_PORT:-16379}"
echo "  MinIO API    http://localhost:\${MINIO_API_PORT:-19000}"
echo "  MinIO UI     http://localhost:\${MINIO_CONSOLE_PORT:-19001}"
echo "  Mailhog      http://localhost:\${MAILHOG_UI_PORT:-18025}"
echo ""
echo "Flutter reader (Android-first):"
echo "  ./scripts/run_reader_flutter.sh"
echo "  API default in app: http://10.0.2.2:8000/v1 (emulator)"
echo "  Optional iOS Sim: --dart-define=API_BASE_URL=http://127.0.0.1:8000/v1"
echo ""
echo "See SETUP.md for Django hot reload, seeds, and pre-commit."
