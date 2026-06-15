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

# Enable the bundled Cloudflare Tunnel only when a token is configured.
PROFILE_ARGS=()
if grep -q '^TUNNEL_TOKEN=.\+' "${SERVER_DIR}/.env" 2>/dev/null; then
  PROFILE_ARGS=(--profile tunnel)
  log "Cloudflare Tunnel enabled (bundled cloudflared)"
fi

dump_on_failure() {
  err "Stack failed to start — dumping status and logs:"
  ${CMD} -f "${COMPOSE_FILE}" --env-file "${SERVER_DIR}/.env" ps || true
  ${CMD} -f "${COMPOSE_FILE}" --env-file "${SERVER_DIR}/.env" logs --tail 200 || true
}
trap dump_on_failure ERR

log "Validating compose config (${ACTIVE})..."
${CMD} -f "${COMPOSE_FILE}" --env-file "${SERVER_DIR}/.env" "${PROFILE_ARGS[@]}" config -q

log "Building images (with retry)..."
retry 3 20 ${CMD} -f "${COMPOSE_FILE}" --env-file "${SERVER_DIR}/.env" "${PROFILE_ARGS[@]}" build

log "Starting stack (attached; systemd supervises)..."
trap - ERR
exec ${CMD} -f "${COMPOSE_FILE}" --env-file "${SERVER_DIR}/.env" "${PROFILE_ARGS[@]}" up --abort-on-container-exit
