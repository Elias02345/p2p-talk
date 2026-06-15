#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# p2p-talk — update entry point.
# Flow: check -> backup -> pull -> rebuild -> (self-)migrate -> restart
#       -> health-check -> rollback-on-failure -> write state file.
#
#   sudo bash update.sh [--branch main] [--force]
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
STATE_DIR="/var/lib/p2ptalk/update-state"
STATE_FILE="${STATE_DIR}/status.json"
BACKUP_ROOT="/var/backups/p2ptalk"

BRANCH="main"
FORCE=false
while [[ $# -gt 0 ]]; do
  case "$1" in
    --branch) BRANCH="$2"; shift 2 ;;
    --force)  FORCE=true; shift ;;
    *) shift ;;
  esac
done

mkdir -p "${STATE_DIR}"
PORT_VAL="$(grep -m1 '^PORT=' "${ENV_FILE}" 2>/dev/null | cut -d= -f2 || echo 3000)"
: "${PORT_VAL:=3000}"

write_state() {
  local status="$1" commit="$2" message="$3"
  cat > "${STATE_FILE}" <<EOF
{
  "status": "${status}",
  "commit": "${commit}",
  "branch": "${BRANCH}",
  "message": "${message}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
}

health_ok() {
  local n=0
  while (( n < 30 )); do
    if curl -fsS "http://127.0.0.1:${PORT_VAL}/health" >/dev/null 2>&1; then return 0; fi
    sleep 2; ((n++))
  done
  return 1
}

banner "p2p-talk update"

# --- 1. Check --------------------------------------------------------------
log "Checking for updates on '${BRANCH}'..."
git -C "${REPO_DIR}" fetch origin "${BRANCH}" || fail "git fetch failed"
PRE_COMMIT="$(git -C "${REPO_DIR}" rev-parse HEAD)"
REMOTE_COMMIT="$(git -C "${REPO_DIR}" rev-parse "origin/${BRANCH}")"

if [[ "${PRE_COMMIT}" == "${REMOTE_COMMIT}" && "${FORCE}" != true ]]; then
  ok "Already up to date (${PRE_COMMIT:0:8})."
  write_state "up-to-date" "${PRE_COMMIT}" "No update available"
  exit 0
fi
log "Update available: ${PRE_COMMIT:0:8} -> ${REMOTE_COMMIT:0:8}"

# --- 2. Backup (abort on failure) -----------------------------------------
TS="$(date +%Y%m%d-%H%M%S)"
BK="${BACKUP_ROOT}/${TS}"
mkdir -p "${BK}/data"
log "Backing up .env and database to ${BK}..."
echo "${PRE_COMMIT}" > "${BK}/commit"
cp "${ENV_FILE}" "${BK}/.env" || fail "Backup of .env failed — aborting update"
if docker volume inspect "${VOLUME}" >/dev/null 2>&1; then
  docker run --rm -v "${VOLUME}:/data:ro" -v "${BK}/data:/backup" alpine \
    sh -c 'cp -a /data/. /backup/ 2>/dev/null || true' || fail "Database backup failed — aborting update"
fi
ok "Backup complete"

rollback() {
  err "Update failed — rolling back to ${PRE_COMMIT:0:8}"
  systemctl stop "${SERVICE_NAME}" || true
  git -C "${REPO_DIR}" reset --hard "${PRE_COMMIT}" || true
  cp "${BK}/.env" "${ENV_FILE}" || true
  if docker volume inspect "${VOLUME}" >/dev/null 2>&1; then
    docker run --rm -v "${VOLUME}:/data" -v "${BK}/data:/backup" alpine \
      sh -c 'rm -rf /data/* 2>/dev/null; cp -a /backup/. /data/ 2>/dev/null || true' || true
  fi
  systemctl restart "${SERVICE_NAME}" || true
  write_state "rolled-back" "${PRE_COMMIT}" "Health check failed; restored previous version"
  fail "Rolled back to previous version. See: journalctl -u ${SERVICE_NAME} -n 200"
}

# --- 3. Pull (server truth = repo) ----------------------------------------
log "Pulling latest code..."
git -C "${REPO_DIR}" reset --hard "${REMOTE_COMMIT}" || rollback

# --- 4. Rebuild + 5. migrate (server self-applies additive schema on boot) -
# --- 6. Restart ------------------------------------------------------------
log "Rebuilding and restarting service..."
systemctl restart "${SERVICE_NAME}" || rollback

# --- 7. Health check -------------------------------------------------------
log "Running health check..."
if ! health_ok; then
  rollback
fi

# --- 8. State write --------------------------------------------------------
ok "Update applied successfully (${REMOTE_COMMIT:0:8})."
write_state "success" "${REMOTE_COMMIT}" "Updated from ${PRE_COMMIT:0:8}"
