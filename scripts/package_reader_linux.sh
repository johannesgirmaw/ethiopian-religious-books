#!/usr/bin/env bash
# Package the Flutter Linux release bundle into distributable formats.
#
# Usage: ./scripts/package_reader_linux.sh [deb|appimage|rpm|flatpak|all]...
#        (no arguments = deb only)
#
# AppImage generation is disabled for now — it is NOT part of the default set
# and is excluded from `all`. The generator below is kept intact and working;
# pass `appimage` explicitly to run it. To re-enable by default, add it back to
# the default FORMATS and to the `all` case.
#
# Artifacts land in dist/downloads/ (git-ignored), the same directory
# scripts/deploy-prod.sh downloads uploads to /downloads/.
#
# Runs `make reader-build-linux` first unless the bundle already exists and
# --no-build is passed.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
READER="${ROOT}/apps/reader_flutter"
PKG="${READER}/linux/packaging"
BUNDLE="${READER}/build/linux/x64/release/bundle"
OUT="${ROOT}/dist/downloads"
WORK="${ROOT}/dist/.linux-pkg"
ICON="${READER}/web/icons/Icon-512.png"

# App identity — keep in sync with windows/packaging/felege_metsahft.iss.
APP_ID="com.felegemetsahft.Reader"
PKG_NAME="felege-metsahft"
BIN_NAME="ethiopian_reader"

NO_BUILD=0
FORMATS=()

for arg in "$@"; do
  case "${arg}" in
    --no-build) NO_BUILD=1 ;;
    # `appimage` is intentionally omitted here — disabled for now, opt-in only.
    all) FORMATS+=(deb rpm flatpak) ;;
    deb|appimage|rpm|flatpak) FORMATS+=("${arg}") ;;
    -h|--help)
      sed -n '2,16p' "${BASH_SOURCE[0]}" | sed 's/^# \?//'
      exit 0
      ;;
    *) echo "error: unknown argument '${arg}'" >&2; exit 2 ;;
  esac
done

# Default is deb only. AppImage is disabled for now (opt in with `appimage`).
[[ ${#FORMATS[@]} -eq 0 ]] && FORMATS=(deb)

# Version from pubspec: "1.0.0+1" -> "1.0.0" (package versions have no build id).
VERSION="$(grep -m1 '^version:' "${READER}/pubspec.yaml" | sed 's/^version: *//' | cut -d+ -f1)"
[[ -z "${VERSION}" ]] && { echo "error: could not read version from pubspec.yaml" >&2; exit 1; }

echo "==> Felege Metsahft ${VERSION} — packaging: ${FORMATS[*]}"

if [[ ${NO_BUILD} -eq 0 ]]; then
  echo "==> Building Linux release bundle"
  make -C "${ROOT}" reader-build-linux
fi

[[ -x "${BUNDLE}/${BIN_NAME}" ]] || {
  echo "error: no release bundle at ${BUNDLE} — run 'make reader-build-linux'" >&2
  exit 1
}

# A real release build is AOT-compiled into lib/libapp.so. Without it we would
# be packaging a debug bundle, which is both slower and much larger.
[[ -f "${BUNDLE}/lib/libapp.so" ]] || {
  echo "error: ${BUNDLE} has no lib/libapp.so — that is not a release build." >&2
  echo "       run 'flutter clean' in apps/reader_flutter, then rebuild." >&2
  exit 1
}

mkdir -p "${OUT}"
rm -rf "${WORK}"
mkdir -p "${WORK}"

# Build a standard FHS install tree once; every format installs from it.
#   /usr/lib/felege-metsahft/   the Flutter bundle (runner + data/ + lib/)
#   /usr/bin/felege-metsahft    symlink to the runner
stage_fhs() {
  local root="$1" libdir="$2"
  mkdir -p "${root}${libdir}/${PKG_NAME}" "${root}/usr/bin" \
           "${root}/usr/share/applications" \
           "${root}/usr/share/icons/hicolor/512x512/apps"
  cp -a "${BUNDLE}/." "${root}${libdir}/${PKG_NAME}/"

  # `flutter build` does not purge the bundle dir between builds, so a previous
  # debug/JIT build can leave artifacts behind that a release package must not
  # ship. Release runs AOT from lib/libapp.so; kernel_blob.bin is JIT-only and
  # is ~95MB of dead weight. Prune it from the staged copy (never the build dir).
  local blob="${root}${libdir}/${PKG_NAME}/data/flutter_assets/kernel_blob.bin"
  if [[ -f "${blob}" ]]; then
    echo "  note: pruning stale debug artifact kernel_blob.bin ($(du -h "${blob}" | cut -f1))"
    rm -f "${blob}"
  fi
  ln -sf "${libdir}/${PKG_NAME}/${BIN_NAME}" "${root}/usr/bin/${PKG_NAME}"
  install -Dm644 "${PKG}/common/${APP_ID}.desktop" \
    "${root}/usr/share/applications/${APP_ID}.desktop"
  install -Dm644 "${ICON}" \
    "${root}/usr/share/icons/hicolor/512x512/apps/${APP_ID}.png"
}

build_deb() {
  echo "==> deb"
  command -v dpkg-deb >/dev/null || { echo "  skip: dpkg-deb not installed (apt install dpkg-dev)" >&2; return 1; }
  local root="${WORK}/deb"
  stage_fhs "${root}" /usr/lib
  mkdir -p "${root}/DEBIAN"

  local size
  size="$(du -sk "${root}" | cut -f1)"
  sed -e "s/@VERSION@/${VERSION}/" -e "s/@INSTALLED_SIZE@/${size}/" \
    "${PKG}/deb/control.in" > "${root}/DEBIAN/control"

  # Refresh the desktop/icon caches so the launcher entry appears immediately.
  cat > "${root}/DEBIAN/postinst" <<'EOF'
#!/bin/sh
set -e
if [ -x /usr/bin/update-desktop-database ]; then
  update-desktop-database -q /usr/share/applications || true
fi
if [ -x /usr/bin/gtk-update-icon-cache ]; then
  gtk-update-icon-cache -qtf /usr/share/icons/hicolor || true
fi
EOF
  cp "${root}/DEBIAN/postinst" "${root}/DEBIAN/postrm"
  chmod 755 "${root}/DEBIAN/postinst" "${root}/DEBIAN/postrm"

  local deb="${OUT}/${PKG_NAME}_${VERSION}_amd64.deb"
  if command -v fakeroot >/dev/null; then
    fakeroot dpkg-deb --build --root-owner-group "${root}" "${deb}" >/dev/null
  else
    dpkg-deb --build --root-owner-group "${root}" "${deb}" >/dev/null
  fi
  echo "  -> ${deb}"
}

build_appimage() {
  echo "==> AppImage"
  local tool
  tool="$(command -v appimagetool || true)"
  if [[ -z "${tool}" ]]; then
    # Fetch appimagetool into dist/ rather than installing it system-wide.
    tool="${ROOT}/dist/appimagetool-x86_64.AppImage"
    if [[ ! -x "${tool}" ]]; then
      echo "  fetching appimagetool"
      curl -fsSL -o "${tool}" \
        https://github.com/AppImage/AppImageKit/releases/download/continuous/appimagetool-x86_64.AppImage \
        || { echo "  skip: could not download appimagetool" >&2; return 1; }
      chmod +x "${tool}"
    fi
  fi

  local dir="${WORK}/AppDir"
  stage_fhs "${dir}" /usr/lib
  install -Dm755 "${PKG}/appimage/AppRun" "${dir}/AppRun"
  # appimagetool wants the desktop entry and icon at the AppDir root too.
  cp "${PKG}/common/${APP_ID}.desktop" "${dir}/${APP_ID}.desktop"
  cp "${ICON}" "${dir}/${APP_ID}.png"

  local img="${OUT}/${PKG_NAME}-${VERSION}-x86_64.AppImage"
  # --appimage-extract-and-run avoids needing FUSE in the build environment.
  if ! ARCH=x86_64 "${tool}" --appimage-extract-and-run "${dir}" "${img}" >/dev/null 2>&1; then
    ARCH=x86_64 "${tool}" "${dir}" "${img}" >/dev/null || {
      echo "  skip: appimagetool failed" >&2; return 1; }
  fi
  echo "  -> ${img}"
}

build_rpm() {
  echo "==> rpm"
  command -v rpmbuild >/dev/null || {
    echo "  skip: rpmbuild not installed (apt install rpm)" >&2; return 1; }
  local root="${WORK}/rpm-stage"
  stage_fhs "${root}" /usr/lib

  local spec="${WORK}/${PKG_NAME}.spec"
  sed -e "s/@VERSION@/${VERSION}/" -e "s|@STAGEDIR@|${root}|" \
    "${PKG}/rpm/${PKG_NAME}.spec.in" > "${spec}"

  rpmbuild -bb "${spec}" \
    --define "_topdir ${WORK}/rpmbuild" \
    --define "_rpmdir ${WORK}/rpmbuild/RPMS" >/dev/null
  local rpm
  rpm="$(find "${WORK}/rpmbuild/RPMS" -name '*.rpm' -type f | head -1)"
  [[ -n "${rpm}" ]] || { echo "  skip: rpmbuild produced no package" >&2; return 1; }
  cp "${rpm}" "${OUT}/"
  echo "  -> ${OUT}/$(basename "${rpm}")"
}

build_flatpak() {
  echo "==> flatpak"
  command -v flatpak-builder >/dev/null || {
    echo "  skip: flatpak-builder not installed (apt install flatpak-builder)" >&2; return 1; }
  local ctx="${WORK}/flatpak"
  mkdir -p "${ctx}/bundle"
  cp -a "${BUNDLE}/." "${ctx}/bundle/"
  cp "${PKG}/common/${APP_ID}.desktop" "${ctx}/"
  cp "${ICON}" "${ctx}/${APP_ID}.png"
  cp "${PKG}/flatpak/${APP_ID}.yml" "${ctx}/"

  flatpak-builder --force-clean --repo="${WORK}/flatpak-repo" \
    "${ctx}/build" "${ctx}/${APP_ID}.yml" >/dev/null || {
    echo "  skip: flatpak-builder failed (is the org.freedesktop.Sdk//24.08 runtime installed?)" >&2
    return 1; }

  local bundle_out="${OUT}/${PKG_NAME}-${VERSION}.flatpak"
  flatpak build-bundle "${WORK}/flatpak-repo" "${bundle_out}" "${APP_ID}" >/dev/null || {
    echo "  skip: flatpak build-bundle failed" >&2; return 1; }
  echo "  -> ${bundle_out}"
}

FAILED=()
for fmt in "${FORMATS[@]}"; do
  "build_${fmt}" || FAILED+=("${fmt}")
done

echo
echo "==> Artifacts in ${OUT}:"
ls -lh "${OUT}" 2>/dev/null | tail -n +2 | awk '{printf "    %-52s %s\n", $9, $5}'

if [[ ${#FAILED[@]} -gt 0 ]]; then
  echo
  echo "==> Not built: ${FAILED[*]} (see skip reasons above)"
  exit 1
fi
