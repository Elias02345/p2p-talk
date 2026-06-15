#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# service-start.sh — invoked by the systemd unit to run the compose stack.
# Validates the compose config, builds with retry, then runs attached so
# systemd supervises it. Dumps ps + logs on failure for journalctl.
# ---------------------------------------------------------------------------
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/lib/common.sh"
SERVER_DIR="$(cd "${SCRIPT_DIR}/.." && pwd)"
DOCKER_DIR="${SERVER_DIR}/docker"

ACTIVE="$(cat "${DOCKER_DIR}/.active-compose" 2>/dev/null || echo 'docker-compose.main.yml')"
COMPOSE_FILE="${DOCKER_DIR}/${ACTIVE}"
[[ -f "${COMPOSE_FILE}" ]] || fail "Compose file not found: ${COMPOSE_FILE}"

CMD="$(compose_cmd)" || fail "docker compose is not installed"
cd "${DOCKER_DIR}"

dump_on_failure() {
  err "Stack failed to start — dumping status and logs:"
  ${CMD} -f "${COMPOSE_FILE}" --env-file "${SERVER_DIR}/.env" ps || true
  ${CMD} -f "${COMPOSE_FILE}" --env-file "${SERVER_DIR}/.env" logs --tail 200 || true
}
trap dump_on_failure ERR

log "Validating compose config (${ACTIVE})..."
${CMD} -f "${COMPOSE_FILE}" --env-file "${SERVER_DIR}/.env" config -q

log "Building images (with retry)..."
retry 3 20 ${CMD} -f "${COMPOSE_FILE}" --env-file "${SERVER_DIR}/.env" build

log "Starting stack (attached; systemd supervises)..."
trap - ERR
exec ${CMD} -f "${COMPOSE_FILE}" --env-file "${SERVER_DIR}/.env" up --abort-on-container-exit
