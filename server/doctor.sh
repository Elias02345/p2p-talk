#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# p2p-talk — health check & repair.
#   sudo bash doctor.sh [--repair]
# Prints [OK]/[ERROR] per check and a final summary.
# ---------------------------------------------------------------------------
set -Eeuo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/scripts/lib/common.sh"

SERVER_DIR="${SCRIPT_DIR}"
ENV_FILE="${SERVER_DIR}/.env"
DOCKER_DIR="${SERVER_DIR}/docker"
SERVICE_NAME="p2ptalk-signaling"
REPAIR=false
[[ "${1:-}" == "--repair" ]] && REPAIR=true

FAILS=0
check() { # check <description> <command...>
  local desc="$1"; shift
  if "$@" >/dev/null 2>&1; then ok "${desc}"; else err "${desc}"; ((FAILS++)); fi
}

banner "p2p-talk doctor"

check "Docker installed"            command_exists docker
check "Docker Compose available"    bash -c 'docker compose version || docker-compose --version'
check "openssl present"             command_exists openssl
check ".env exists"                 test -f "${ENV_FILE}"
check "JWT_SECRET set"              bash -c "grep -q '^JWT_SECRET=.\+' '${ENV_FILE}'"
check "TURN_SHARED_SECRET set"      bash -c "grep -q '^TURN_SHARED_SECRET=.\+' '${ENV_FILE}'"
check "systemd unit installed"      test -f "/etc/systemd/system/${SERVICE_NAME}.service"
check "service enabled"             systemctl is-enabled "${SERVICE_NAME}"
check "service active"              systemctl is-active "${SERVICE_NAME}"

PORT_VAL="$(grep -m1 '^PORT=' "${ENV_FILE}" 2>/dev/null | cut -d= -f2 || echo 3000)"; : "${PORT_VAL:=3000}"
check "health endpoint responds"    curl -fsS "http://127.0.0.1:${PORT_VAL}/health"

# coturn STUN reachability (best effort; needs turnutils_stunclient).
if command_exists turnutils_stunclient; then
  TURN_HOST_VAL="$(grep -m1 '^TURN_HOST=' "${ENV_FILE}" 2>/dev/null | cut -d= -f2 || true)"
  [[ -n "${TURN_HOST_VAL}" ]] && check "coturn STUN reachable" turnutils_stunclient "${TURN_HOST_VAL}"
fi

if [[ "${REPAIR}" == true ]]; then
  banner "Repair"
  log "Reinstalling prerequisites and restarting the stack..."
  apt_get update || true
  apt_get install -y ca-certificates curl openssl gettext-base || true
  systemctl daemon-reload || true
  systemctl restart "${SERVICE_NAME}" || true
  ok "Repair pass complete"
fi

echo
if (( FAILS == 0 )); then
  ok "All checks passed."
  exit 0
else
  err "${FAILS} check(s) failed. Try: sudo bash doctor.sh --repair"
  exit 1
fi
