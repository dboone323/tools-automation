#!/bin/bash
# Updater Agent: Checks for and applies updates to tools, packages, and dependencies

AGENT_NAME="UpdaterAgent"
LOG_FILE="$(dirname "$0")/updater_agent.log"

SLEEP_INTERVAL=43200 # 12 hours
MIN_INTERVAL=3600
MAX_INTERVAL=86400

# Update agent status with orchestrator
update_agent_status() {
    local status="$1"
    local status_file="$(dirname "$0")/agent_status.json"
    local current_time=$(date +%s)
    
    if command -v jq &> /dev/null && [[ -f "$status_file" ]]; then
        jq --arg agent "updater_agent.sh" --arg status "$status" --arg last_seen "$current_time" \
            '.agents[$agent] = {"status": $status, "last_seen": $last_seen, "tasks_completed": (.agents[$agent].tasks_completed // 0)}' \
            "$status_file" > "$status_file.tmp" && mv "$status_file.tmp" "$status_file"
    fi
}

while true; do
    update_agent_status "active"
    echo "[$(date)] $AGENT_NAME: Checking for system and tool updates..." >> "$LOG_FILE"
    # Homebrew
    brew update && brew upgrade >> "$LOG_FILE" 2>&1
    # Python
    pip3 install --upgrade pip setuptools wheel >> "$LOG_FILE" 2>&1
    # npm (use sudo to avoid EACCES errors)
    sudo npm install -g npm && sudo npm update -g >> "$LOG_FILE" 2>&1
    # macOS software
    softwareupdate --install --all >> "$LOG_FILE" 2>&1
    # Xcode tools
    xcode-select --install >> "$LOG_FILE" 2>&1 || true
    echo "[$(date)] $AGENT_NAME: Update cycle complete." >> "$LOG_FILE"
    SLEEP_INTERVAL=$(( SLEEP_INTERVAL + 3600 ))
    if [[ $SLEEP_INTERVAL -gt $MAX_INTERVAL ]]; then SLEEP_INTERVAL=$MAX_INTERVAL; fi
    echo "[$(date)] $AGENT_NAME: Sleeping for $SLEEP_INTERVAL seconds." >> "$LOG_FILE"
    
    # Send heartbeats during long sleep period
    local heartbeat_interval=300  # 5 minutes
    local slept=0
    while [[ $slept -lt $SLEEP_INTERVAL ]]; do
        sleep $heartbeat_interval
        update_agent_status "active"
        slept=$((slept + heartbeat_interval))
    done
done
