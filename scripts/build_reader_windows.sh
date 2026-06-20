#!/usr/bin/env bash
# Release Windows desktop build (Windows host only).
exec "$(dirname "${BASH_SOURCE[0]}")/build_reader_flutter.sh" windows "$@"
