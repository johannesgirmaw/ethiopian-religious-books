#!/usr/bin/env bash
# Run Flutter reader in Chrome (web).
exec "$(dirname "${BASH_SOURCE[0]}")/run_reader_flutter.sh" web "$@"
