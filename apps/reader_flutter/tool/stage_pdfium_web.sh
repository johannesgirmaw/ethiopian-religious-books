#!/usr/bin/env bash
# Copy pdfrx WASM client + wasm next to the range-loading worker in web/pdfium/.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CONFIG="$ROOT/.dart_tool/package_config.json"
if [ ! -f "$CONFIG" ]; then
  (cd "$ROOT" && flutter pub get)
fi
DEST="$ROOT/web/pdfium"
mkdir -p "$DEST"
python3 - "$CONFIG" "$DEST" <<'PY'
import json, pathlib, shutil, sys
config, dest = map(pathlib.Path, sys.argv[1:])
data = json.loads(config.read_text())
pkg = next(p for p in data["packages"] if p["name"] == "pdfrx")
uri = pkg["rootUri"]
if uri.startswith("file://"):
    base = pathlib.Path(uri[7:])
else:
    base = (config.parent / uri).resolve()
assets = base / "assets"
for name in ("pdfium.wasm", "pdfium_client.js"):
    src = assets / name
    if not src.is_file():
        raise SystemExit(f"{name} not found at {src}")
    shutil.copy2(src, dest / name)
    print(f"staged {src} -> {dest / name}")
PY
