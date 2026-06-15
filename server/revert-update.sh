#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# p2p-talk — manual rollback to the most recent backup taken by update.sh.
# Restores .env + database and resets the repo to the backed-up commit.
#
#   sudo bash revert-update.sh [--backup /var/backups/p2ptalk/<timestamp>]
# ---------------------------------------------------------------------------
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/lib/common.sh"
require_root

SERVER_DIR="${SCRIPT_DIR}"
ENV_FILE="${SERVER_DIR}/.env"
REPO_DIR="$(git -C "${SERVER_DIR}" rev-parse --show-toplevel)"
SERVICE_NAME="p2ptalk-signaling"
VOLUME="p2ptalk_p2ptalk-data"
BACKUP_ROOT="/var/backups/p2ptalk"
STATE_DIR="/var/lib/p2ptalk/update-state"

BACKUP_DIR=""
while [[ $# -gt 0 ]]; do
  case "$1" in
    --backup) BACKUP_DIR="$2"; shift 2 ;;
    *) shift ;;
  esac
done

if [[ -z "${BACKUP_DIR}" ]]; then
  BACKUP_DIR="$(ls -1d "${BACKUP_ROOT}"/*/ 2>/dev/null | sort | tail -1 || true)"
fi
[[ -n "${BACKUP_DIR}" && -d "${BACKUP_DIR}" ]] || fail "No backup found under ${BACKUP_ROOT}"
BACKUP_DIR="${BACKUP_DIR%/}"

banner "p2p-talk revert"
log "Restoring from ${BACKUP_DIR}"

systemctl stop "${SERVICE_NAME}" || true

if [[ -f "${BACKUP_DIR}/commit" ]]; then
  git -C "${REPO_DIR}" reset --hard "$(cat "${BACKUP_DIR}/commit")" || warn "git reset failed"
fi
[[ -f "${BACKUP_DIR}/.env" ]] && cp "${BACKUP_DIR}/.env" "${ENV_FILE}"
if [[ -d "${BACKUP_DIR}/data" ]] && docker volume inspect "${VOLUME}" >/dev/null 2>&1; then
  docker run --rm -v "${VOLUME}:/data" -v "${BACKUP_DIR}/data:/backup" alpine \
    sh -c 'rm -rf /data/* 2>/dev/null; cp -a /backup/. /data/ 2>/dev/null || true' || warn "DB restore failed"
fi

systemctl restart "${SERVICE_NAME}" || fail "Service failed to restart"

PORT_VAL="$(grep -m1 '^PORT=' "${ENV_FILE}" 2>/dev/null | cut -d= -f2 || echo 3000)"; : "${PORT_VAL:=3000}"
mkdir -p "${STATE_DIR}"
n=0; while (( n < 30 )); do curl -fsS "http://127.0.0.1:${PORT_VAL}/health" >/dev/null 2>&1 && break; sleep 2; ((n++)); done
ok "Revert complete. Restored from ${BACKUP_DIR}"
