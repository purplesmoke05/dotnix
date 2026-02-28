#!/usr/bin/env bash
set -euo pipefail

CONTAINER="${OPENCLAW_CONTAINER:-openclaw}"
SERVICE_UNIT="${OPENCLAW_SERVICE:-podman-${CONTAINER}.service}"
OPENCLAW_CLI_VERSION="${OPENCLAW_CLI_VERSION:-2026.2.26}"
SESSION_KEY="${OPENCLAW_SESSION_KEY:-agent:main:main}"
SESSIONS_JSON="${OPENCLAW_SESSIONS_JSON:-}"
AUTO_PATCH_GEMINI31="${OPENCLAW_AUTO_PATCH_GEMINI31:-1}"
CONTAINER_WAIT_RETRIES="${OPENCLAW_CONTAINER_WAIT_RETRIES:-30}"
CONTAINER_WAIT_SECONDS="${OPENCLAW_CONTAINER_WAIT_SECONDS:-1}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PATCH_GEMINI31_SCRIPT="${SCRIPT_DIR}/patch-openclaw-gemini31-cli-model.sh"
SERVICE_RESTARTED=0

usage() {
  cat <<EOF
Usage: ./scripts/switch-openclaw-model-host.sh <model-id>

Environment overrides:
  OPENCLAW_CONTAINER     Podman container name (default: openclaw)
  OPENCLAW_SERVICE       systemd unit name (default: podman-<container>.service)
  OPENCLAW_CLI_VERSION   openclaw npx version (default: 2026.2.26)
  OPENCLAW_SESSION_KEY   sticky session key to clear (default: agent:main:main)
  OPENCLAW_SESSIONS_JSON explicit sessions.json path
  OPENCLAW_AUTO_PATCH_GEMINI31 auto-patch google-gemini-cli/gemini-3.1-pro-preview (default: 1)
  OPENCLAW_CONTAINER_WAIT_RETRIES wait-loop retries after restart (default: 30)
  OPENCLAW_CONTAINER_WAIT_SECONDS wait-loop sleep seconds (default: 1)
EOF
}

if [[ "${1:-}" == "-h" || "${1:-}" == "--help" ]]; then
  usage
  exit 0
fi

if [[ $# -lt 1 ]]; then
  usage >&2
  exit 1
fi

TARGET_MODEL="$1"

if ! podman container exists "$CONTAINER"; then
  echo "Container \"$CONTAINER\" does not exist." >&2
  exit 1
fi

if [[ "$(podman inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)" != "true" ]]; then
  echo "Container \"$CONTAINER\" is not running." >&2
  echo "Start it with: systemctl start ${SERVICE_UNIT}" >&2
  exit 1
fi

find_sessions_json() {
  local candidates=()
  if [[ -n "$SESSIONS_JSON" ]]; then
    candidates+=("$SESSIONS_JSON")
  fi
  candidates+=(
    "/var/lib/openclaw-rootless/root/.openclaw/agents/main/sessions/sessions.json"
    "/var/lib/openclaw/root/.openclaw/agents/main/sessions/sessions.json"
  )

  local path
  for path in "${candidates[@]}"; do
    if [[ -f "$path" ]]; then
      printf '%s\n' "$path"
      return 0
    fi
    if sudo test -f "$path" >/dev/null 2>&1; then
      printf '%s\n' "$path"
      return 0
    fi
  done
  return 1
}

restart_unit() {
  if systemctl restart "$SERVICE_UNIT" >/dev/null 2>&1; then
    SERVICE_RESTARTED=1
    return 0
  fi
  if sudo -n systemctl restart "$SERVICE_UNIT" >/dev/null 2>&1; then
    SERVICE_RESTARTED=1
    return 0
  fi
  echo "Warning: could not restart ${SERVICE_UNIT} without interactive sudo." >&2
  echo "Run manually if needed: sudo systemctl restart ${SERVICE_UNIT}" >&2
  return 0
}

show_unit_status() {
  if systemctl status --no-pager "$SERVICE_UNIT" >/dev/null 2>&1; then
    systemctl status --no-pager "$SERVICE_UNIT" | sed -n '1,12p'
    return 0
  fi
  if sudo -n systemctl status --no-pager "$SERVICE_UNIT" >/dev/null 2>&1; then
    sudo -n systemctl status --no-pager "$SERVICE_UNIT" | sed -n '1,12p'
    return 0
  fi
  podman ps --filter "name=$CONTAINER" --format 'table {{.Names}}\t{{.Status}}'
}

show_recent_model_log() {
  if journalctl -u "$SERVICE_UNIT" --since '10 min ago' --no-pager >/dev/null 2>&1; then
    journalctl -u "$SERVICE_UNIT" --since '10 min ago' --no-pager | grep -i 'agent model' | tail -n 1 || true
    return 0
  fi
  if sudo -n journalctl -u "$SERVICE_UNIT" --since '10 min ago' --no-pager >/dev/null 2>&1; then
    sudo -n journalctl -u "$SERVICE_UNIT" --since '10 min ago' --no-pager | grep -i 'agent model' | tail -n 1 || true
  fi
}

wait_for_container_running() {
  local i
  for ((i = 0; i < CONTAINER_WAIT_RETRIES; i++)); do
    if [[ "$(podman inspect -f '{{.State.Running}}' "$CONTAINER" 2>/dev/null || true)" == "true" ]]; then
      return 0
    fi
    sleep "$CONTAINER_WAIT_SECONDS"
  done
  return 1
}

echo "Setting default model to: ${TARGET_MODEL}"

if [[ "$AUTO_PATCH_GEMINI31" == "1" && "$TARGET_MODEL" == "google-gemini-cli/gemini-3.1-pro-preview" ]]; then
  if [[ -x "$PATCH_GEMINI31_SCRIPT" ]]; then
    echo "Applying gemini-3.1 catalog patch before models set"
    OPENCLAW_CONTAINER="$CONTAINER" \
      OPENCLAW_CLI_VERSION="$OPENCLAW_CLI_VERSION" \
      "$PATCH_GEMINI31_SCRIPT"
  else
    echo "Warning: patch script missing or not executable: $PATCH_GEMINI31_SCRIPT" >&2
  fi
fi

podman exec "$CONTAINER" \
  npx -y "openclaw@${OPENCLAW_CLI_VERSION}" models set "$TARGET_MODEL"

if ! command -v jq >/dev/null 2>&1; then
  echo "jq is required to clear session overrides." >&2
  exit 1
fi

session_file="$(find_sessions_json || true)"
if [[ -n "$session_file" ]]; then
  backup_path="${session_file}.bak.$(date +%Y%m%d-%H%M%S)"
  tmp_json="$(mktemp)"
  trap 'rm -f "$tmp_json"' EXIT

  if [[ -w "$session_file" ]]; then
    cp -a "$session_file" "$backup_path"
    jq --arg key "$SESSION_KEY" 'del(.[$key])' "$session_file" > "$tmp_json"
    mv "$tmp_json" "$session_file"
  else
    sudo cp -a "$session_file" "$backup_path"
    sudo jq --arg key "$SESSION_KEY" 'del(.[$key])' "$session_file" > "$tmp_json"
    sudo mv "$tmp_json" "$session_file"
    sudo chown --reference="$backup_path" "$session_file"
    sudo chmod --reference="$backup_path" "$session_file"
  fi

  trap - EXIT
  rm -f "$tmp_json"
  echo "Removed sticky session key: ${SESSION_KEY}"
  echo "sessions backup: ${backup_path}"
else
  echo "Warning: sessions.json not found. Skipped sticky session cleanup." >&2
fi

echo "Restarting service: ${SERVICE_UNIT}"
restart_unit
if [[ "$SERVICE_RESTARTED" == "1" ]]; then
  if ! wait_for_container_running; then
    echo "Container \"$CONTAINER\" did not become running after restart." >&2
    exit 1
  fi
fi
show_unit_status

echo "Verifying default model"
if command -v jq >/dev/null 2>&1; then
  podman exec "$CONTAINER" \
    npx -y "openclaw@${OPENCLAW_CLI_VERSION}" models status --json | jq '{defaultModel, resolvedDefault}'
else
  podman exec "$CONTAINER" \
    npx -y "openclaw@${OPENCLAW_CLI_VERSION}" models status --json
fi

show_recent_model_log
