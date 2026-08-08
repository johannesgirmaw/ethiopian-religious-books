#!/usr/bin/env bash
# Regenerate assets/fonts/NotoSansEthiopic.ttf from the upstream variable font.
#
# The upstream file (tools/fonts/NotoSansEthiopic-variable.ttf, 1.1 MB) is a variable
# font: ~590 KB of it is `gvar` variation data and ~380 KB is `GPOS` kerning. The app
# never sets `fontVariations`, so Flutter only ever renders the default (wght 400)
# instance -- the variation data is pure download weight. The font is used solely for
# the brand wordmark, which sets its own `letterSpacing`, so Latin kerning is moot too.
#
# This instantiates a static wght=400 / wdth=100 cut and drops the kern feature,
# keeping full Ethiopic + Latin coverage and mark positioning. 1.1 MB -> ~119 KB.
#
# Requires: pip install fonttools brotli
set -euo pipefail

DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SRC="${DIR}/NotoSansEthiopic-variable.ttf"
OUT="${DIR}/../../assets/fonts/NotoSansEthiopic.ttf"
TMP="$(mktemp -d)"
trap 'rm -rf "${TMP}"' EXIT

# Latin-1 + Latin Extended-A, combining diacritics, punctuation, currency, letterlike,
# Ethiopic + Supplement, Ethiopic Extended, Extended-A, Extended-B.
UNICODES="U+0000-00FF,U+0100-017F,U+0300-036F,U+2000-206F,U+20A0-20BF,U+2100-214F,U+1200-139F,U+2D80-2DDF,U+AB00-AB2F,U+1E7E0-1E7FF"

fonttools varLib.instancer "${SRC}" wght=400 wdth=100 -o "${TMP}/static.ttf"

pyftsubset "${TMP}/static.ttf" \
  --unicodes="${UNICODES}" \
  --layout-features="ccmp,mark,mkmk,locl" \
  --drop-tables+=STAT,vhea,vmtx,VVAR \
  --output-file="${OUT}"

ls -l "${SRC}" "${OUT}"
