#!/usr/bin/env bash
# Deploy the API and/or web to the felegemetsahft.com production VPS.
#
# Usage:
#   scripts/deploy-prod.sh            # deploy api + web + landing
#   scripts/deploy-prod.sh api        # only the Django API (rsync + rebuild + restart)
#   scripts/deploy-prod.sh web        # only the Flutter web app (app.felegemetsahft.com)
#   scripts/deploy-prod.sh landing    # only the Next.js landing (felegemetsahft.com)
#
# Prereqs: SSH alias `felegemetsahft` (see ~/.ssh/config), flutter, node/npm, rsync.
set -euo pipefail

SSH_HOST="felegemetsahft"
REMOTE_APP="/opt/felegemetsahft"
API_BASE_URL="https://api.felegemetsahft.com/v1/"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

target="${1:-all}"

deploy_api() {
  echo "==> Syncing Django source"
  rsync -az --delete \
    --exclude '__pycache__' --exclude '*.pyc' --exclude '.venv' --exclude 'venv' \
    --exclude 'db.sqlite3' --exclude 'staticfiles' --exclude 'media' \
    "$REPO_ROOT/services/django_api/" "$SSH_HOST:$REMOTE_APP/django_api/"

  echo "==> Rebuilding + restarting api + celery (migrations run on container start)"
  ssh "$SSH_HOST" "cd $REMOTE_APP/prod && docker compose -f docker-compose.prod.yml up -d --build api celery_worker"
}

deploy_web() {
  echo "==> Building Flutter web (API_BASE_URL=$API_BASE_URL)"
  ( cd "$REPO_ROOT/apps/reader_flutter" && \
    flutter build web --release --dart-define=API_BASE_URL="$API_BASE_URL" )

  echo "==> Syncing web build"
  rsync -az --delete "$REPO_ROOT/apps/reader_flutter/build/web/" "$SSH_HOST:/var/www/felegemetsahft/web/"
  ssh "$SSH_HOST" "chown -R www-data:www-data /var/www/felegemetsahft/web"
}

deploy_landing() {
  echo "==> Building Next.js landing (static export)"
  ( cd "$REPO_ROOT/apps/landing" && npm install --no-audit --no-fund && npm run build )

  echo "==> Syncing landing build"
  rsync -az --delete "$REPO_ROOT/apps/landing/out/" "$SSH_HOST:/var/www/felegemetsahft/landing/"
  ssh "$SSH_HOST" "chown -R www-data:www-data /var/www/felegemetsahft/landing"
}

case "$target" in
  api) deploy_api ;;
  web) deploy_web ;;
  landing) deploy_landing ;;
  all) deploy_api; deploy_web; deploy_landing ;;
  *) echo "Unknown target: $target (use: api | web | landing | all)"; exit 1 ;;
esac

echo "==> Post-deploy health checks"
curl -fsS -o /dev/null -w "landing HTTP %{http_code}\n" https://felegemetsahft.com/
curl -fsS -o /dev/null -w "app     HTTP %{http_code}\n" https://app.felegemetsahft.com/ || true
curl -fsS -o /dev/null -w "api     HTTP %{http_code}\n" https://api.felegemetsahft.com/healthz/
curl -fsS -o /dev/null -w "files   HTTP %{http_code}\n" https://files.felegemetsahft.com/minio/health/live
echo "==> Done."
