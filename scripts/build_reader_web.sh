#!/usr/bin/env bash
# Release web build → build/web/
exec "$(dirname "${BASH_SOURCE[0]}")/build_reader_flutter.sh" web "$@"
