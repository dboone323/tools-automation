        #!/usr/bin/env bash

# Dynamic configuration discovery
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./agent_config_discovery.sh
if [[ -f "${SCRIPT_DIR}/agent_config_discovery.sh" ]]; then
    source "${SCRIPT_DIR}/agent_config_discovery.sh"
    WORKSPACE_ROOT=$(get_workspace_root)
    AGENTS_DIR=$(get_agents_dir)
    MCP_URL=$(get_mcp_url)
else
    echo "ERROR: agent_config_discovery.sh not found"
    exit 1
fi
        # Auto-injected health & reliability shim

        DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer shared helpers when available
if [[ -f "$DIR/shared_functions.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/shared_functions.sh"
fi

if [[ -f "$DIR/agent_helpers.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/agent_helpers.sh"
fi

set -euo pipefail

AGENT_NAME="updater_agent.sh"
LOG_FILE="${LOG_FILE:-$DIR/${AGENT_NAME}.log}"
PID=$$

if type update_agent_status >/dev/null 2>&1; then
  trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; exit 0' SIGTERM SIGINT
else
  trap 'exit 0' SIGTERM SIGINT
fi

if [[ "${1-}" == "--health" || "${1-}" == "health" || "${1-}" == "-h" ]]; then
  if type agent_health_check >/dev/null 2>&1; then
    agent_health_check
    exit $?
  fi
  issues=()
  if [[ ! -w "/tmp" ]]; then
    issues+=("tmp_not_writable")
  fi
  if [[ ! -d "$DIR" ]]; then
    issues+=("cwd_missing")
  fi
  if [[ ${#issues[@]} -gt 0 ]]; then
    printf '{"ok":false,"issues":["%s"]}\n' "${issues[*]}"
    exit 2
  fi
  printf '{"ok":true}\n'
  exit 0
fi

# Original agent script continues below
#!/bin/bash
# Updater Agent: Checks for and applies updates to tools, packages, and dependencies

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./shared_functions.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="UpdaterAgent"
LOG_FILE="$(dirname "$0")/updater_agent.log"

SLEEP_INTERVAL=43200 # 12 hours
# shellcheck disable=SC2034  # reserved for future adaptive sleep tuning
MIN_INTERVAL=3600
MAX_INTERVAL=86400

while true; do
    {
        echo "[$(date)] ${AGENT_NAME}: Checking for system and tool updates..."
        # Homebrew
        brew update && brew upgrade
        # Python
        pip3 install --upgrade pip setuptools wheel
        # npm (use sudo to avoid EACCES errors)
        sudo npm install -g npm && sudo npm update -g
        # macOS software
        softwareupdate --install --all
        # Xcode tools
        xcode-select --install || true
        echo "[$(date)] ${AGENT_NAME}: Update cycle complete."
        SLEEP_INTERVAL=$((SLEEP_INTERVAL + 3600))
        if [[ ${SLEEP_INTERVAL} -gt ${MAX_INTERVAL} ]]; then SLEEP_INTERVAL=${MAX_INTERVAL}; fi
        echo "[$(date)] ${AGENT_NAME}: Sleeping for ${SLEEP_INTERVAL} seconds."
    } >>"${LOG_FILE}" 2>&1
    sleep "${SLEEP_INTERVAL}"
done
