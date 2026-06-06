#!/usr/bin/env bash
# Seed the Amharic Ethiopian history book (10 chapters × 5 pages).
# Requires the API container from infra/docker compose.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
COMPOSE_FILE="${ROOT}/infra/docker-compose.yml"

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "error: ${COMPOSE_FILE} not found" >&2
  exit 1
fi

cd "${ROOT}/infra"
docker compose exec -T api python manage.py seed_ethiopian_history
