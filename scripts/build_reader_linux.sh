#!/usr/bin/env bash
# Release Linux desktop build (run on Linux).
exec "$(dirname "${BASH_SOURCE[0]}")/build_reader_flutter.sh" linux "$@"
