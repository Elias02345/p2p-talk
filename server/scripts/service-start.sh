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

# --- Pre-flight: a broken .env is the #1 cause of a dead origin ------------
ENV_FILE="${SERVER_DIR}/.env"
[[ -f "${ENV_FILE}" ]] || fail ".env not found at ${ENV_FILE} — run install.sh first"
grep -q '^JWT_SECRET=.\+' "${ENV_FILE}" || fail "JWT_SECRET is empty in .env — re-run install.sh"

# TURN mode decides whether the (optional) coturn relay runs at all.
TURN_MODE_VAL="$(grep -m1 '^TURN_MODE=' "${ENV_FILE}" | cut -d= -f2- || echo coturn)"
if [[ "${TURN_MODE_VAL}" == "coturn" ]]; then
  grep -q '^TURN_SHARED_SECRET=.\+' "${ENV_FILE}" || fail "TURN_MODE=coturn but TURN_SHARED_SECRET is empty"
fi

cd "${DOCKER_DIR}"

# Compose profiles: coturn (relay) only when self-hosting TURN; cloudflared
# (tunnel) only when a token is set. This is what keeps a dead coturn from
# taking the signaling server down.
PROFILE_ARGS=()
if [[ "${TURN_MODE_VAL}" == "coturn" ]]; then
  PROFILE_ARGS+=(--profile relay)
  log "Self-hosted coturn relay enabled (TURN_MODE=coturn)"
fi
if grep -q '^TUNNEL_TOKEN=.\+' "${ENV_FILE}" 2>/dev/null; then
  PROFILE_ARGS+=(--profile tunnel)
  log "Cloudflare Tunnel enabled (bundled cloudflared)"
fi

dump_on_failure() {
  err "Stack failed to start — dumping status and logs:"
  ${CMD} -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" ps || true
  ${CMD} -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" logs --tail 200 || true
}
trap dump_on_failure ERR

log "Validating compose config (${ACTIVE})..."
${CMD} -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" "${PROFILE_ARGS[@]}" config -q

log "Building images (with retry)..."
retry 3 20 ${CMD} -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" "${PROFILE_ARGS[@]}" build

log "Starting stack (attached; systemd supervises)..."
trap - ERR
# NOTE: no --abort-on-container-exit. Each service has its own restart policy;
# a coturn/cloudflared hiccup must never take the signaling container down.
exec ${CMD} -f "${COMPOSE_FILE}" --env-file "${ENV_FILE}" "${PROFILE_ARGS[@]}" up
