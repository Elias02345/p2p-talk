#!/usr/bin/env bash
# Convenience wrapper so you can run the updater from the repo root:
#   sudo ./update.sh            (stable)
#   sudo ./update.sh --branch dev
# It just delegates to server/update.sh.
set -Eeuo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec bash "${SCRIPT_DIR}/server/update.sh" "$@"
