#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# p2p-talk — one-shot installer.
# Takes a fresh Ubuntu/Debian machine from zero to a running signaling + TURN
# stack. Idempotent: safe to re-run.
#
#   sudo bash install.sh                 # Standard / CloudGate mode (default)
#   sudo NETWORK_MODE=hostnet bash install.sh
#   sudo PUBLIC_HOST=p2p-talk.example.com bash install.sh
# ---------------------------------------------------------------------------
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/lib/common.sh"

SERVER_DIR="${SCRIPT_DIR}"
DOCKER_DIR="${SERVER_DIR}/docker"
ENV_FILE="${SERVER_DIR}/.env"
ENV_EXAMPLE="${SERVER_DIR}/.env.example"
NETWORK_MODE="${NETWORK_MODE:-main}"   # main | hostnet
PUBLIC_HOST="${PUBLIC_HOST:-}"
SERVICE_NAME="p2ptalk-signaling"

require_root
banner "p2p-talk installer"

# --- 1. Prerequisites ------------------------------------------------------
log "Installing prerequisites..."
apt_get update
apt_get install -y ca-certificates curl openssl gnupg gettext-base || fail "Failed to install base packages"

if ! command_exists docker; then
  log "Installing Docker..."
  retry 3 5 sh -c 'curl -fsSL https://get.docker.com | sh' || fail "Docker installation failed"
fi
systemctl enable --now docker >/dev/null 2>&1 || true

compose_cmd >/dev/null 2>&1 || fail "Docker Compose plugin not available after install"
ok "Docker and Compose are available"

# --- 2. Environment + secrets ---------------------------------------------
if [[ ! -f "${ENV_FILE}" ]]; then
  log "Creating .env from .env.example"
  cp "${ENV_EXAMPLE}" "${ENV_FILE}"
fi

# Generate secrets only if not already set (preserve on re-run).
JWT_SECRET_VAL="$(existing_or_generated_secret "${ENV_FILE}" JWT_SECRET)"
TURN_SECRET_VAL="$(existing_or_generated_secret "${ENV_FILE}" TURN_SHARED_SECRET)"
set_env_value "${ENV_FILE}" JWT_SECRET "${JWT_SECRET_VAL}"
set_env_value "${ENV_FILE}" TURN_SHARED_SECRET "${TURN_SECRET_VAL}"
set_env_value "${ENV_FILE}" NODE_ENV production
set_env_value "${ENV_FILE}" DB_PATH /app/data/p2ptalk.db
set_env_value "${ENV_FILE}" TURN_TRANSPORT tls-first

if [[ -n "${PUBLIC_HOST}" ]]; then
  set_env_value "${ENV_FILE}" PUBLIC_HOST "${PUBLIC_HOST}"
  set_env_value "${ENV_FILE}" TURN_HOST "${PUBLIC_HOST}"
fi

# Optional relay/tunnel settings passed via environment (preserved on re-run).
[[ -n "${TURN_MODE:-}" ]]         && set_env_value "${ENV_FILE}" TURN_MODE "${TURN_MODE}"
[[ -n "${CF_TURN_KEY_ID:-}" ]]    && set_env_value "${ENV_FILE}" CF_TURN_KEY_ID "${CF_TURN_KEY_ID}"
[[ -n "${CF_TURN_API_TOKEN:-}" ]] && set_env_value "${ENV_FILE}" CF_TURN_API_TOKEN "${CF_TURN_API_TOKEN}"
[[ -n "${TUNNEL_TOKEN:-}" ]]      && set_env_value "${ENV_FILE}" TUNNEL_TOKEN "${TUNNEL_TOKEN}"

chmod 600 "${ENV_FILE}"
ok "Environment configured (secrets generated where missing)"

# --- 3. Render coturn config ----------------------------------------------
log "Rendering coturn configuration..."
set -a; source "${ENV_FILE}"; set +a
: "${TURN_PORT:=3478}"; : "${TURN_TLS_PORT:=5349}"; : "${TURN_REALM:=p2p-talk}"
export TURN_PORT TURN_TLS_PORT TURN_REALM TURN_SHARED_SECRET
envsubst < "${DOCKER_DIR}/coturn/turnserver.conf.template" > "${DOCKER_DIR}/coturn/turnserver.conf"
ok "coturn configured"

# --- 4. Select compose mode -----------------------------------------------
case "${NETWORK_MODE}" in
  hostnet) ACTIVE_COMPOSE="docker-compose.hostnet.yml" ;;
  *)       ACTIVE_COMPOSE="docker-compose.main.yml" ;;
esac
echo "${ACTIVE_COMPOSE}" > "${DOCKER_DIR}/.active-compose"
log "Network mode: ${NETWORK_MODE} (${ACTIVE_COMPOSE})"

# --- 5. Install dependencies & build --------------------------------------
log "Building and starting the stack (first run may take a while)..."
CMD="$(compose_cmd)"
cd "${DOCKER_DIR}"
PROFILE_ARGS=()
if grep -q '^TUNNEL_TOKEN=.\+' "${ENV_FILE}"; then
  PROFILE_ARGS=(--profile tunnel)
  log "Cloudflare Tunnel enabled (bundled cloudflared container)"
fi
retry 3 20 ${CMD} -f "${ACTIVE_COMPOSE}" --env-file "${ENV_FILE}" "${PROFILE_ARGS[@]}" build
retry 3 10 ${CMD} -f "${ACTIVE_COMPOSE}" --env-file "${ENV_FILE}" "${PROFILE_ARGS[@]}" up -d

# --- 6. systemd registration ----------------------------------------------
log "Installing systemd units..."
for unit in "${SERVER_DIR}"/systemd/*.service "${SERVER_DIR}"/systemd/*.timer; do
  [[ -f "${unit}" ]] || continue
  sed "s#__SERVER_DIR__#${SERVER_DIR}#g" "${unit}" > "/etc/systemd/system/$(basename "${unit}")"
done
systemctl daemon-reload
systemctl enable "${SERVICE_NAME}.service" >/dev/null 2>&1 || true
systemctl enable --now p2ptalk-updater.timer >/dev/null 2>&1 || true
# Hand supervision to systemd (stop the detached compose, let the unit run it).
${CMD} -f "${ACTIVE_COMPOSE}" --env-file "${ENV_FILE}" down >/dev/null 2>&1 || true
systemctl restart "${SERVICE_NAME}.service"
ok "systemd service enabled (survives reboot)"

# --- 7. Health check -------------------------------------------------------
log "Waiting for the server to become healthy..."
PORT_VAL="${PORT:-3000}"
healthy=false
for _ in $(seq 1 20); do
  if curl -fsS "http://127.0.0.1:${PORT_VAL}/health" >/dev/null 2>&1; then
    healthy=true; break
  fi
  sleep 2
done

echo
banner "Installation complete"
if [[ "${healthy}" == true ]]; then
  ok "Signaling server is healthy on 127.0.0.1:${PORT_VAL}"
else
  warn "Health check did not pass yet — check: journalctl -u ${SERVICE_NAME} -n 100"
fi
SERVER_IP="$(hostname -I 2>/dev/null | awk '{print $1}' || echo '<server-ip>')"
echo
echo "  Signaling listens on:  http://${SERVER_IP}:${PORT_VAL}  (health: /health)"
echo "  App server URL:        ws://${PUBLIC_HOST:-<cloudgate-ip>}:${PORT_VAL}"
echo "  Relay mode:            $(grep -m1 '^TURN_MODE=' "${ENV_FILE}" | cut -d= -f2 || echo coturn)"
echo
echo "  CloudGate: point it at this server -> ${SERVER_IP}:${PORT_VAL} (plain HTTP)."
echo "  Then enter in the app onboarding:    ws://${PUBLIC_HOST:-<cloudgate-ip>}:${PORT_VAL}"
echo
echo "  NOTE: plain ws:// is unencrypted on the wire. Media stays end-to-end"
echo "  encrypted (DTLS-SRTP) and calls are MitM-protected, but for token privacy"
echo "  prefer wss:// via a domain when possible (set PUBLIC_HOST + TLS at CloudGate)."
echo
