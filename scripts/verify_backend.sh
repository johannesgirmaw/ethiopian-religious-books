#!/usr/bin/env bash
# Smoke-test the Django API against a running Compose stack (or start it).
#
# Default host ports in compose are already offset (15432, 16379, 19000, …). If a port is still
# busy, set overrides before running (or add them to infra/.env), e.g.:
#   POSTGRES_PORT=25432 REDIS_PORT=26379 MINIO_API_PORT=29000 API_PORT=18008 ./scripts/verify_backend.sh
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
INFRA="${ROOT}/infra"
COMPOSE_FILE="${INFRA}/docker-compose.yml"
ENV_FILE="${INFRA}/.env"
EXAMPLE="${INFRA}/.env.example"

START_STACK="${VERIFY_START_STACK:-1}"

if [[ ! -f "${COMPOSE_FILE}" ]]; then
  echo "error: missing ${COMPOSE_FILE}"
  exit 1
fi

if [[ ! -f "${ENV_FILE}" ]]; then
  if [[ -f "${EXAMPLE}" ]]; then
    echo "Creating ${ENV_FILE} from .env.example"
    cp "${EXAMPLE}" "${ENV_FILE}"
  else
    echo "error: missing ${ENV_FILE}"
    exit 1
  fi
fi

compose() {
  docker compose -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" "$@"
}

if [[ "${START_STACK}" == "1" ]]; then
  echo "==> Building and starting stack (postgres, redis, minio, mailhog, api)…"
  compose up -d --build postgres redis minio mailhog api
fi

if [[ -n "${VERIFY_API_BASE_URL:-}" ]]; then
  BASE_URL="${VERIFY_API_BASE_URL}"
else
  API_HOST_PORT="$(compose port api 8000 2>/dev/null | sed 's/.*://')"
  BASE_URL="http://127.0.0.1:${API_HOST_PORT:-8000}"
fi

if [[ "${START_STACK}" == "1" ]]; then
  echo "==> Waiting for API at ${BASE_URL}…"
  for _ in $(seq 1 90); do
    if curl -sf "${BASE_URL}/healthz/" >/dev/null 2>&1; then
      break
    fi
    sleep 1
  done
fi

echo "==> Django check + migrate + seed (idempotent)…"
compose exec -T api python manage.py check
compose exec -T api python manage.py migrate --noinput
compose exec -T api python manage.py seed_dev

fail() {
  echo "FAIL: $*"
  exit 1
}

echo "==> HTTP checks against ${BASE_URL}"

curl -sf "${BASE_URL}/healthz/" | grep -q '"status"' || fail "healthz"
curl -sf "${BASE_URL}/api/schema/?format=json" | grep -q '"openapi"' || fail "OpenAPI schema (JSON)"

LOGIN_READER=$(curl -sf -X POST "${BASE_URL}/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"reader@localhost","password":"readerreader"}') || fail "reader login"
echo "${LOGIN_READER}" | grep -q "access_token" || fail "reader login missing access_token"
READER_TOKEN=$(echo "${LOGIN_READER}" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

LOGIN_ADMIN=$(curl -sf -X POST "${BASE_URL}/v1/auth/login" \
  -H "Content-Type: application/json" \
  -d '{"email":"admin@localhost","password":"adminadminadmin"}') || fail "admin login"
ADMIN_TOKEN=$(echo "${LOGIN_ADMIN}" | python3 -c "import sys,json; print(json.load(sys.stdin)['access_token'])")

curl -sf "${BASE_URL}/v1/me" -H "Authorization: Bearer ${READER_TOKEN}" | grep -q "reader@localhost" || fail "/v1/me reader"

curl -sf "${BASE_URL}/v1/legal/documents" | grep -q "terms" || fail "legal documents"

BOOKS=$(curl -sf "${BASE_URL}/v1/books" -H "Authorization: Bearer ${READER_TOKEN}") || fail "GET /v1/books"
BOOK_ID=$(echo "${BOOKS}" | python3 -c "import sys,json; d=json.load(sys.stdin); assert d.get('items'), 'no books'; print(d['items'][0]['id'])")
curl -sfI "${BASE_URL}/v1/books" -H "Authorization: Bearer ${READER_TOKEN}" | grep -qi '^etag:' || fail "books list missing ETag"

curl -sf "${BASE_URL}/v1/sync/catalog" -H "Authorization: Bearer ${READER_TOKEN}" | grep -q "catalog_etag" || fail "sync catalog"

curl -sf "${BASE_URL}/v1/books/${BOOK_ID}" -H "Authorization: Bearer ${READER_TOKEN}" | grep -q "${BOOK_ID}" || fail "book detail"

DOWNLOAD=$(curl -sf "${BASE_URL}/v1/books/${BOOK_ID}/download" -H "Authorization: Bearer ${READER_TOKEN}") || fail "download"
echo "${DOWNLOAD}" | grep -q "manifest_url" || fail "download missing manifest_url"
MANIFEST_URL=$(echo "${DOWNLOAD}" | python3 -c "import sys,json; print(json.load(sys.stdin)['revision']['manifest_url'])")
curl -sf "${MANIFEST_URL}" | grep -q "format" || fail "presigned manifest GET"

code=$(curl -s -o /dev/null -w "%{http_code}" "${BASE_URL}/v1/admin/books" -H "Authorization: Bearer ${READER_TOKEN}")
[[ "${code}" == "403" ]] || fail "reader should get 403 on /v1/admin/books, got ${code}"

curl -sf "${BASE_URL}/v1/admin/books" -H "Authorization: Bearer ${ADMIN_TOKEN}" | grep -q "items" || fail "admin list books"

echo ""
echo "OK — backend smoke tests passed (${BASE_URL})."
