#!/bin/bash

# Auto-Restart Monitor Agent: Monitors all agents and restarts failed ones

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

# Source project configuration
if [[ -f "${SCRIPT_DIR}/../project_config.sh" ]]; then
    source "${SCRIPT_DIR}/../project_config.sh"
fi

# Set task queue file path
export TASK_QUEUE_FILE="${SCRIPT_DIR}/../task_queue.json"

# Ensure PROJECT_NAME is set for subprocess calls
export PROJECT_NAME="${PROJECT_NAME:-CodingReviewer}"

AGENT_NAME="AutoRestartMonitor"
LOG_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/auto_restart_monitor.log"

SLEEP_INTERVAL=60 # Check every minute
MIN_INTERVAL=30
MAX_INTERVAL=300

STATUS_FILE="$(dirname "$0")/agent_status.json"
TASK_QUEUE="$(dirname "$0")/task_queue.json"
PID=$$

# Export variables for shared functions
export STATUS_FILE
export TASK_QUEUE

echo "[$(date)] ${AGENT_NAME}: Auto-restart monitor started, PID=${PID}" >>"${LOG_FILE}"

# Validate configuration
if [[ $SLEEP_INTERVAL -lt $MIN_INTERVAL || $SLEEP_INTERVAL -gt $MAX_INTERVAL ]]; then
    echo "[$(date)] ${AGENT_NAME}: WARNING: SLEEP_INTERVAL ($SLEEP_INTERVAL) outside recommended range [$MIN_INTERVAL, $MAX_INTERVAL]" >>"${LOG_FILE}"
fi

# Register with MCP server
register_with_mcp "auto_restart_monitor.sh" "monitoring,restart,health-check"

while true; do
    update_agent_status "auto_restart_monitor.sh" "running" $$ ""

    echo "[$(date)] ${AGENT_NAME}: Checking agent health..." >>"${LOG_FILE}"

    # Get all agents that should auto-restart
    for auto_restart_file in "${SCRIPT_DIR}"/.auto_restart_*.sh; do
        if [[ -f "$auto_restart_file" ]]; then
            agent_name=$(basename "$auto_restart_file" | sed 's/.auto_restart_//')

            # Check if agent is running
            if ! pgrep -f "$agent_name" >/dev/null; then
                echo "[$(date)] ${AGENT_NAME}: Agent $agent_name is not running, attempting restart..." >>"${LOG_FILE}"

                # Attempt to restart the agent
                if [[ -x "${SCRIPT_DIR}/${agent_name}" ]]; then
                    bash "${SCRIPT_DIR}/${agent_name}" &
                    new_pid=$!
                    echo "[$(date)] ${AGENT_NAME}: Restarted $agent_name with PID $new_pid" >>"${LOG_FILE}"

                    # Update restart count
                    restart_count_file="${SCRIPT_DIR}/agent_restart_count.txt"
                    if [[ -f "$restart_count_file" ]]; then
                        current_count=$(grep "^${agent_name}:" "$restart_count_file" | cut -d: -f2 || echo "0")
                        new_count=$((current_count + 1))
                        sed -i.bak "/^${agent_name}:/d" "$restart_count_file" 2>/dev/null || true
                        echo "${agent_name}:${new_count}" >>"$restart_count_file"
                    else
                        echo "${agent_name}:1" >"$restart_count_file"
                    fi

                    # Log restart event
                    echo "[$(date)] ${AGENT_NAME}: Restarted $agent_name (count: ${new_count:-1})" >>"${SCRIPT_DIR}/agent_last_restart.txt"
                else
                    echo "[$(date)] ${AGENT_NAME}: ERROR: Cannot restart $agent_name - script not executable or missing" >>"${LOG_FILE}"
                fi
            fi
        fi
    done

    # Clean up old restart logs (keep last 100 entries)
    if [[ -f "${SCRIPT_DIR}/agent_last_restart.txt" ]]; then
        tail -n 100 "${SCRIPT_DIR}/agent_last_restart.txt" >"${SCRIPT_DIR}/agent_last_restart.txt.tmp" && mv "${SCRIPT_DIR}/agent_last_restart.txt.tmp" "${SCRIPT_DIR}/agent_last_restart.txt"
    fi

    update_agent_status "auto_restart_monitor.sh" "idle" $$ ""
    sleep "${SLEEP_INTERVAL}"
done
