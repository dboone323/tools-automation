#!/bin/bash
# Simple 1-minute supervisor watch loop
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}"
LOG_FILE="${LOG_DIR}/agent_supervision_watch.log"

while true; do
    "${SCRIPT_DIR}/monitor_agents.sh" >>"${LOG_FILE}" 2>&1
    sleep 60
done
