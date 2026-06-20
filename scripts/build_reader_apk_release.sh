#!/usr/bin/env bash
# Release Android build for apps/reader_flutter (APK or App Bundle).
# Delegates to build_reader_flutter.sh — kept for backward compatibility.
#
# Usage:
#   ./scripts/build_reader_apk_release.sh
#   READER_APK_ABI=all ./scripts/build_reader_apk_release.sh
#   READER_BUILD_FORMAT=appbundle ./scripts/build_reader_apk_release.sh
#   API_BASE_URL=https://example.com/v1 ./scripts/build_reader_apk_release.sh
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

if [[ "${1:-}" == "-h" ]] || [[ "${1:-}" == "--help" ]]; then
  exec "${SCRIPT_DIR}/build_reader_flutter.sh" --help
fi

exec "${SCRIPT_DIR}/build_reader_flutter.sh" android "$@"
