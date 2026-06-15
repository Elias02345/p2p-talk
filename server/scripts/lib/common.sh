#!/usr/bin/env bash
# ---------------------------------------------------------------------------
# common.sh — shared helpers for the p2p-talk server scripts.
# Source this from install.sh / update.sh / doctor.sh etc.
# ---------------------------------------------------------------------------

# Colours (only when attached to a TTY)
if [[ -t 1 ]]; then
  C_CYAN=$'\033[36m'; C_GREEN=$'\033[32m'; C_YELLOW=$'\033[33m'
  C_RED=$'\033[31m'; C_BOLD=$'\033[1m'; C_RESET=$'\033[0m'
else
  C_CYAN=''; C_GREEN=''; C_YELLOW=''; C_RED=''; C_BOLD=''; C_RESET=''
fi

log()    { echo "${C_CYAN}[INFO]${C_RESET} $*"; }
ok()     { echo "${C_GREEN}[OK]${C_RESET} $*"; }
warn()   { echo "${C_YELLOW}[WARN]${C_RESET} $*" >&2; }
err()    { echo "${C_RED}[ERROR]${C_RESET} $*" >&2; }
fail()   { echo "${C_RED}[FATAL]${C_RESET} $*" >&2; exit 1; }
banner() { echo "${C_BOLD}${C_CYAN}━━━ $* ━━━${C_RESET}"; }

require_root() {
  if [[ "${EUID:-$(id -u)}" -ne 0 ]]; then
    fail "This script must be run as root (use sudo)."
  fi
}

command_exists() { command -v "$1" >/dev/null 2>&1; }

# Generic retry: retry <attempts> <delay_seconds> <command...>
retry() {
  local attempts="$1" delay="$2"; shift 2
  local n=1
  until "$@"; do
    if (( n >= attempts )); then
      return 1
    fi
    warn "Attempt ${n}/${attempts} failed; retrying in ${delay}s: $*"
    sleep "${delay}"
    ((n++))
  done
}

# apt-get with a retry loop and a lock timeout.
apt_get() {
  retry 3 5 env DEBIAN_FRONTEND=noninteractive apt-get \
    -o DPkg::Lock::Timeout=120 "$@"
}

# Generate a URL-safe secret.
generate_secret() {
  if command_exists openssl; then
    openssl rand -base64 48 | tr -d '\n=+/' | cut -c1-48
  else
    head -c 36 /dev/urandom | base64 | tr -d '\n=+/' | cut -c1-48
  fi
}

# Read an existing value for KEY from an env file, or generate a new secret.
# Usage: existing_or_generated_secret <env_file> <KEY>
existing_or_generated_secret() {
  local file="$1" key="$2" existing=""
  if [[ -f "${file}" ]]; then
    existing="$(grep -m1 "^${key}=" "${file}" 2>/dev/null | cut -d= -f2- || true)"
  fi
  if [[ -n "${existing}" ]]; then
    printf '%s' "${existing}"
  else
    generate_secret
  fi
}

# Set KEY=VALUE in an env file (replace existing line or append).
set_env_value() {
  local file="$1" key="$2" value="$3"
  if grep -q "^${key}=" "${file}" 2>/dev/null; then
    # Use a temp file to avoid sed delimiter issues with arbitrary values.
    grep -v "^${key}=" "${file}" > "${file}.tmp" || true
    printf '%s=%s\n' "${key}" "${value}" >> "${file}.tmp"
    mv "${file}.tmp" "${file}"
  else
    printf '%s=%s\n' "${key}" "${value}" >> "${file}"
  fi
}

# Resolve the docker compose command (plugin or legacy binary).
compose_cmd() {
  if docker compose version >/dev/null 2>&1; then
    echo "docker compose"
  elif command_exists docker-compose; then
    echo "docker-compose"
  else
    return 1
  fi
}
