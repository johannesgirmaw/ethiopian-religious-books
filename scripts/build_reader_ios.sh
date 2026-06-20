#!/usr/bin/env bash
# Release iOS build (macOS + Xcode; no codesign — archive in Xcode).
exec "$(dirname "${BASH_SOURCE[0]}")/build_reader_flutter.sh" ios "$@"
