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
LOG_FILE="/tmp/auto_restart_monitor.log"

SLEEP_INTERVAL=30 # Check every 30 seconds for faster recovery
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

# Failure tracking
FAILURE_TRACKING_FILE="${SCRIPT_DIR}/agent_failure_tracking.txt"
touch "$FAILURE_TRACKING_FILE"

check_resource_usage() {
    local pid="$1"
    local agent_name="$2"
    
    # Get memory usage (KB)
    local memory_kb=$(ps -p "$pid" -o rss= 2>/dev/null | tr -d ' ' || echo "0")
    local memory_mb=$((memory_kb / 1024))
    
    # Get CPU usage
    local cpu=$(ps -p "$pid" -o %cpu= 2>/dev/null | tr -d ' ' || echo "0")
    
    # Check thresholds (from config or defaults)
    local mem_threshold=1024  # 1GB default
    local cpu_threshold=80    # 80% default
    
    if [[ $memory_mb -gt $mem_threshold ]]; then
        echo "[$(date)] ${AGENT_NAME}: WARNING: $agent_name using ${memory_mb}MB memory (threshold: ${mem_threshold}MB)" >> "${LOG_FILE}"
    fi
    
    # CPU threshold check (bash doesn't handle decimals well, so multiply by 10)
    local cpu_int=${cpu%.*}
    if [[ $cpu_int -gt $cpu_threshold ]]; then
        echo "[$(date)] ${AGENT_NAME}: WARNING: $agent_name using ${cpu}% CPU (threshold: ${cpu_threshold}%)" >> "${LOG_FILE}"
    fi
}

check_zombie_processes() {
    # Find zombie processes
    local zombies=$(ps aux | awk '$8 == "Z" && $0 ~ /agent.*\.sh/' || true)
    if [[ -n "$zombies" ]]; then
        echo "[$(date)] ${AGENT_NAME}: WARNING: Detected zombie agent processes" >> "${LOG_FILE}"
        echo "$zombies" >> "${LOG_FILE}"
    fi
}

track_failure() {
    local agent_name="$1"
    local current_time=$(date +%s)
    
    # Add failure timestamp
    echo "${agent_name}:${current_time}" >> "$FAILURE_TRACKING_FILE"
    
    # Clean old entries (older than 1 hour)
    local one_hour_ago=$((current_time - 3600))
    grep -v "^${agent_name}:" "$FAILURE_TRACKING_FILE" > "${FAILURE_TRACKING_FILE}.tmp" || true
    grep "^${agent_name}:" "$FAILURE_TRACKING_FILE" | while read -r line; do
        local timestamp=$(echo "$line" | cut -d: -f2)
        if [[ $timestamp -gt $one_hour_ago ]]; then
            echo "$line" >> "${FAILURE_TRACKING_FILE}.tmp"
        fi
    done
    mv "${FAILURE_TRACKING_FILE}.tmp" "$FAILURE_TRACKING_FILE"
    
    # Count failures in last hour
    local failure_count=$(grep "^${agent_name}:" "$FAILURE_TRACKING_FILE" | wc -l | tr -d ' ')
    
    if [[ $failure_count -ge 3 ]]; then
        echo "[$(date)] ${AGENT_NAME}: ALERT: $agent_name has failed $failure_count times in the last hour" >> "${LOG_FILE}"
        # Could send notification here
    fi
}

while true; do
    update_agent_status "auto_restart_monitor.sh" "running" $$ ""

    echo "[$(date)] ${AGENT_NAME}: Checking agent health..." >> "${LOG_FILE}"
    
    # Check for zombie processes
    check_zombie_processes

    # Get all agents that should auto-restart
    for auto_restart_file in "${SCRIPT_DIR}"/.auto_restart_*.sh; do
        if [[ -f "$auto_restart_file" ]]; then
            agent_name=$(basename "$auto_restart_file" | sed 's/.auto_restart_//')

            # Check if agent is running
            agent_pid=$(pgrep -f "$agent_name" | head -1 || echo "0")
            
            if [[ $agent_pid -eq 0 ]]; then
                echo "[$(date)] ${AGENT_NAME}: Agent $agent_name is not running, attempting restart..." >> "${LOG_FILE}"
                
                # Track failure
                track_failure "$agent_name"

                # Attempt to restart the agent
                if [[ -x "${SCRIPT_DIR}/${agent_name}" ]]; then
                    bash "${SCRIPT_DIR}/${agent_name}" &
                    new_pid=$!
                    echo "[$(date)] ${AGENT_NAME}: Restarted $agent_name with PID $new_pid" >> "${LOG_FILE}"

                    # Update restart count
                    restart_count_file="${SCRIPT_DIR}/agent_restart_count.txt"
                    if [[ -f "$restart_count_file" ]]; then
                        current_count=$(grep "^${agent_name}:" "$restart_count_file" | cut -d: -f2 || echo "0")
                        new_count=$((current_count + 1))
                        sed -i.bak "/^${agent_name}:/d" "$restart_count_file" 2>/dev/null || true
                        echo "${agent_name}:${new_count}" >> "$restart_count_file"
                    else
                        echo "${agent_name}:1" > "$restart_count_file"
                    fi

                    # Log restart event
                    echo "[$(date)] ${AGENT_NAME}: Restarted $agent_name (count: ${new_count:-1})" >> "${SCRIPT_DIR}/agent_last_restart.txt"
                else
                    echo "[$(date)] ${AGENT_NAME}: ERROR: Cannot restart $agent_name - script not executable or missing" >> "${LOG_FILE}"
                fi
            else
                # Agent is running, check resource usage
                check_resource_usage "$agent_pid" "$agent_name"
            fi
        fi
    done

    # Clean up old restart logs (keep last 100 entries)
    if [[ -f "${SCRIPT_DIR}/agent_last_restart.txt" ]]; then
        tail -n 100 "${SCRIPT_DIR}/agent_last_restart.txt" > "${SCRIPT_DIR}/agent_last_restart.txt.tmp" && mv "${SCRIPT_DIR}/agent_last_restart.txt.tmp" "${SCRIPT_DIR}/agent_last_restart.txt"
    fi

    update_agent_status "auto_restart_monitor.sh" "idle" $$ ""
    sleep "${SLEEP_INTERVAL}"
done
