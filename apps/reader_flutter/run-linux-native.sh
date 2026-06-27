#!/usr/bin/env bash
# Run the reader on Linux desktop with HOT RELOAD, using the system toolchain.
#
# Why this exists: the Flutter *snap* forces its bundled Clang 10 + an old glib
# (via bin/internal/bootstrap.sh), which fails to link against the system
# libsecret (needs glib >= 2.80). We neutralized that bootstrap.sh and run the
# Flutter checkout directly with a clean, system-only environment so the build
# uses Clang 18 + system glib 2.80.
#
# Usage:
#   ./run-linux-native.sh                 # local API (http://127.0.0.1:8000/v1/)
#   API_BASE_URL=https://.../v1/ ./run-linux-native.sh   # override API
#
# In the run, press: r = hot reload, R = hot restart, q = quit.
set -euo pipefail

FLUTTER="$HOME/snap/flutter/common/flutter/bin/flutter"
API="${API_BASE_URL:-http://127.0.0.1:8000/v1/}"

# Clean, system-only environment (no /snap toolchain leakage).
export PATH="/usr/local/sbin:/usr/local/bin:/usr/sbin:/usr/bin:/sbin:/bin"
export CC=/usr/bin/clang
export CXX=/usr/bin/clang++
unset LDFLAGS LIBRARY_PATH CPLUS_INCLUDE_PATH C_INCLUDE_PATH CPATH \
      PKG_CONFIG_PATH PKG_CONFIG_LIBDIR 2>/dev/null || true

cd "$(dirname "${BASH_SOURCE[0]}")"
"$FLUTTER" config --enable-linux-desktop >/dev/null 2>&1 || true

echo "==> flutter run -d linux  (API_BASE_URL=$API, system toolchain)"
exec "$FLUTTER" run -d linux --dart-define=API_BASE_URL="$API"
