#!/usr/bin/env bash
set -euo pipefail
cd /app
python manage.py migrate --noinput
python manage.py ensure_minio_bucket || true
python manage.py ensure_superuser
exec "$@"
