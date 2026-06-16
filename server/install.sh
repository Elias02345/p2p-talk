#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# p2p-talk — one-shot installer.
# Takes a fresh Ubuntu/Debian machine from zero to a running signaling + TURN
# stack. Idempotent: safe to re-run. Everything is optional.
#
#   sudo bash install.sh
#   sudo bash install.sh --public-host p2p-talk.example.com
#   sudo bash install.sh --public-host p2p-talk.example.com --turn-mode cloudflare \
#        --cf-turn-key-id <id> --cf-turn-api-token <token>
#
# --public-host is the hostname the APP connects to (e.g. via CloudGate/Cloudflare
# Tunnel, which gives you https/wss for free). In CloudGate you map that hostname
# to this server's http://<server-ip>:<PORT>. It is NOT a "CloudGate IP".
# ---------------------------------------------------------------------------
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/lib/common.sh"

SERVER_DIR="${SCRIPT_DIR}"
DOCKER_DIR="${SERVER_DIR}/docker"
ENV_FILE="${SERVER_DIR}/.env"
ENV_EXAMPLE="${SERVER_DIR}/.env.example"
# Defaults (overridable by flags or environment).
NETWORK_MODE="${NETWORK_MODE:-main}"   # main | hostnet
PUBLIC_HOST="${PUBLIC_HOST:-}"
SERVICE_NAME="p2ptalk-signaling"

# --- CLI flags (robust through sudo; all optional) -------------------------
while [[ $# -gt 0 ]]; do
  case "$1" in
    --public-host)       PUBLIC_HOST="$2"; shift 2 ;;
    --network-mode)      NETWORK_MODE="$2"; shift 2 ;;
    --bind)              SIGNALING_BIND="$2"; shift 2 ;;
    --turn-mode)         TURN_MODE="$2"; shift 2 ;;
    --cf-turn-key-id)    CF_TURN_KEY_ID="$2"; shift 2 ;;
    --cf-turn-api-token) CF_TURN_API_TOKEN="$2"; shift 2 ;;
    --tunnel-token)      TUNNEL_TOKEN="$2"; shift 2 ;;
    -h|--help)
      cat <<'USAGE'
Usage: sudo bash install.sh [options]   (all optional)
  --public-host <host>      Hostname the app connects to, e.g. p2p-talk.example.com
                            (in CloudGate you map it to http://<server-ip>:<port>)
  --network-mode <mode>     main (default) | hostnet
  --bind <addr>             Interface to publish the signaling port on (default 0.0.0.0)
  --turn-mode <mode>        coturn | cloudflare | static | none
  --cf-turn-key-id <id>     Cloudflare TURN key id   (with --turn-mode cloudflare)
  --cf-turn-api-token <t>   Cloudflare TURN API token
  --tunnel-token <token>    Bundled cloudflared tunnel token (optional)
Re-running is safe and preserves existing secrets.
USAGE
      exit 0 ;;
    *) warn "Unknown option: $1"; shift ;;
  esac
done

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

# Optional relay/tunnel settings (flags or environment; preserved on re-run).
[[ -n "${SIGNALING_BIND:-}" ]]    && set_env_value "${ENV_FILE}" SIGNALING_BIND "${SIGNALING_BIND}"
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
TURN_MODE_VAL="$(grep -m1 '^TURN_MODE=' "${ENV_FILE}" | cut -d= -f2 || echo coturn)"
echo
echo "  This server listens on:  http://${SERVER_IP}:${PORT_VAL}   (health: /health)"
echo
echo "  In CloudGate, publish a hostname for THIS service:"
echo "      hostname:  ${PUBLIC_HOST:-p2p-talk.<your-domain>}"
echo "      service :  http://${SERVER_IP}:${PORT_VAL}"
echo
echo "  Then enter in the app onboarding:"
echo "      https://${PUBLIC_HOST:-p2p-talk.<your-domain>}"
echo "  (Signaling now runs over plain HTTP long-poll — works through CloudGate;"
echo "   CloudGate / Cloudflare provides TLS automatically, no port, no cert.)"
echo
echo "  Relay mode: ${TURN_MODE_VAL}"
if [[ "${TURN_MODE_VAL}" == "coturn" ]]; then
  echo "  NOTE: self-hosted coturn is NOT reachable through a Cloudflare Tunnel."
  echo "        Behind CloudGate use --turn-mode cloudflare (managed TURN) or none."
fi
echo
