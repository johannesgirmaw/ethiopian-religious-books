#!/usr/bin/env bash
# Run the reader on the web (Chrome) with HOT RELOAD.
#
# Usage:
#   ./run-web.sh                                  # local API (http://localhost:8000/v1/)
#   API_BASE_URL=https://.../v1/ ./run-web.sh     # override the API base URL
#   WEB_PORT=5000 ./run-web.sh                    # pin the dev-server port
#   DEVICE=web-server ./run-web.sh                # headless server (no Chrome launch)
#
# In the run, press: r = hot reload, R = hot restart, q = quit.
set -euo pipefail

# Prefer the snap Flutter (matches run-linux-native.sh); fall back to PATH.
if [[ -x "$HOME/snap/flutter/common/flutter/bin/flutter" ]]; then
  FLUTTER="$HOME/snap/flutter/common/flutter/bin/flutter"
else
  FLUTTER="$(command -v flutter || true)"
fi
if [[ -z "${FLUTTER:-}" ]]; then
  echo "error: flutter not found (install Flutter or set it on PATH)" >&2
  exit 1
fi

API="${API_BASE_URL:-http://localhost:8000/v1/}"
DEVICE="${DEVICE:-chrome}"

cd "$(dirname "${BASH_SOURCE[0]}")"
"$FLUTTER" config --enable-web >/dev/null 2>&1 || true

echo "==> flutter run -d $DEVICE  (API_BASE_URL=$API)"
exec "$FLUTTER" run -d "$DEVICE" \
  ${WEB_PORT:+--web-port "$WEB_PORT"} \
  --dart-define=API_BASE_URL="$API" \
  "$@"
