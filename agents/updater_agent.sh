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
