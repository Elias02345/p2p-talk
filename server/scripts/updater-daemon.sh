#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# updater-daemon.sh — headless auto-update tick (invoked by the systemd timer).
# Checks the configured branch and installs any update via update.sh, which
# backs up, rebuilds, health-checks and rolls back on failure.
# ---------------------------------------------------------------------------
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
SERVER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"

BRANCH="$(grep -m1 '^UPDATE_BRANCH=' "${SERVER_DIR}/.env" 2>/dev/null | cut -d= -f2 || true)"
: "${BRANCH:=main}"

log "Headless auto-update check (branch: ${BRANCH})"
bash "${SERVER_DIR}/update.sh" --branch "${BRANCH}" || warn "Auto-update run reported a failure"
