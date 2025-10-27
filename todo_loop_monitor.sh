#!/bin/bash
# todo_loop_monitor.sh - Monitors agent status and automatically triggers TODO generation when agents are idle

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_STATUS_FILE="${SCRIPT_DIR}/agents/agent_status.json"
LOG_FILE="${WORKSPACE_DIR}/Tools/Automation/todo_loop_monitor.log"
PROCESS_TODOS_SCRIPT="${SCRIPT_DIR}/process_todos.sh"

# Configuration
MONITOR_INTERVAL=60 # Check every 60 seconds
MIN_IDLE_TIME=300   # Agents must be idle for at least 5 minutes before triggering
LAST_TRIGGER_FILE="${SCRIPT_DIR}/last_todo_trigger.txt"

# Centralized throttling configuration for TODO monitoring
MAX_CONCURRENCY="${MAX_CONCURRENCY:-2}"    # Maximum concurrent monitor instances
LOAD_THRESHOLD="${LOAD_THRESHOLD:-4.0}"    # System load threshold (1.0 = 100% on single core)
WAIT_WHEN_BUSY="${WAIT_WHEN_BUSY:-30}"     # Seconds to wait when system is busy
GLOBAL_AGENT_CAP="${GLOBAL_AGENT_CAP:-10}" # Maximum total agents that can be assigned tasks

# Function to check if we should proceed with monitoring
ensure_within_limits() {
    local script_name="todo_loop_monitor.sh"

    # Check concurrent instances of monitoring
    local running_count
    running_count=$(pgrep -f "${script_name}" | wc -l)
    if [[ ${running_count} -gt ${MAX_CONCURRENCY} ]]; then
        echo "[$(date)] TODO Monitor: Too many concurrent instances (${running_count}/${MAX_CONCURRENCY}). Waiting..." >>"${LOG_FILE}"
        return 1
    fi

    # Check system load (macOS compatible)
    local load_avg
    if command -v sysctl >/dev/null 2>&1; then
        # macOS: use sysctl vm.loadavg
        load_avg=$(sysctl -n vm.loadavg | awk '{print $2}')
    else
        # Fallback: use uptime
        load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')
    fi

    # Compare load as float
    if (($(echo "${load_avg} >= ${LOAD_THRESHOLD}" | bc -l 2>/dev/null || echo "0"))); then
        echo "[$(date)] TODO Monitor: System load too high (${load_avg} >= ${LOAD_THRESHOLD}). Waiting..." >>"${LOG_FILE}"
        return 1
    fi

    return 0
}

echo "[$(date)] TODO Loop Monitor started - PID: $$" >>"${LOG_FILE}"

# Function to check if all agents are idle
are_agents_idle() {
    local status_file="$1"
    local min_idle_time="$2"

    if [[ ! -f "$status_file" ]]; then
        echo "false"
        return
    fi

    # Use Python to check agent status
    python3 -c "
import json
import time
import sys

try:
    status_file = sys.argv[1]
    min_idle_time = int(sys.argv[2])
    current_time = time.time()

    with open(status_file, 'r') as f:
        data = json.load(f)

    agents = data.get('agents', {})

    # If no agents, consider idle
    if not agents:
        print('true')
        sys.exit(0)

    all_idle = True
    for agent_name, agent_data in agents.items():
        status = agent_data.get('status', 'unknown')
        last_seen = agent_data.get('last_seen', 0)

        # If agent is running or busy, not idle
        if status in ['running', 'busy']:
            all_idle = False
            break

        # If agent was recently active, not idle
        if current_time - last_seen < min_idle_time:
            all_idle = False
            break

    print(str(all_idle).lower())
except Exception as e:
    print('false')
" "$status_file" "$min_idle_time"
}

# Function to check if we should trigger TODO generation
should_trigger_todos() {
    local last_trigger_file="$1"
    local cooldown_period=600 # 10 minutes cooldown between triggers

    if [[ ! -f "$last_trigger_file" ]]; then
        echo "true"
        return
    fi

    local last_trigger
    last_trigger=$(cat "$last_trigger_file" 2>/dev/null || echo "0")
    local current_time
    current_time=$(date +%s)
    local time_diff=$((current_time - last_trigger))

    if [[ $time_diff -gt $cooldown_period ]]; then
        echo "true"
    else
        echo "false"
    fi
}

# Function to trigger TODO generation
trigger_todo_generation() {
    local script_path="$1"
    local last_trigger_file="$2"
    local log_file="$3"

    echo "[$(date)] Triggering TODO generation..." >>"${log_file}"

    # Run the process_todos.sh script
    if cd "$(dirname "$script_path")" && bash "$script_path" >>"${log_file}" 2>&1; then
        echo "[$(date)] TODO generation completed successfully" >>"${log_file}"
        # Update last trigger time
        date +%s >"$last_trigger_file"
        return 0
    else
        echo "[$(date)] TODO generation failed" >>"${log_file}"
        return 1
    fi
}

# Main monitoring loop
while true; do
    # Check if we should proceed with monitoring (throttling)
    if ! ensure_within_limits; then
        # Wait when busy, with exponential backoff
        wait_time=${WAIT_WHEN_BUSY}
        attempts=0
        while ! ensure_within_limits && [[ ${attempts} -lt 10 ]]; do
            echo "[$(date)] TODO Monitor: Waiting ${wait_time}s before retry (attempt $((attempts + 1))/10)" >>"${LOG_FILE}"
            sleep "${wait_time}"
            wait_time=$((wait_time * 2))                          # Exponential backoff
            if [[ ${wait_time} -gt 300 ]]; then wait_time=300; fi # Cap at 5 minutes
            ((attempts++))
        done

        # If still busy after retries, skip this cycle
        if ! ensure_within_limits; then
            echo "[$(date)] TODO Monitor: System still busy after retries. Skipping cycle." >>"${LOG_FILE}"
            sleep 60
            continue
        fi
    fi

    echo "[$(date)] Checking agent status..." >>"${LOG_FILE}"

    # Check if all agents are idle
    if [[ "$(are_agents_idle "$AGENT_STATUS_FILE" "$MIN_IDLE_TIME")" == "true" ]]; then
        echo "[$(date)] All agents are idle" >>"${LOG_FILE}"

        # Check if we should trigger TODO generation (cooldown check)
        if [[ "$(should_trigger_todos "$LAST_TRIGGER_FILE")" == "true" ]]; then
            echo "[$(date)] Cooldown period passed, triggering TODO generation" >>"${LOG_FILE}"
            trigger_todo_generation "$PROCESS_TODOS_SCRIPT" "$LAST_TRIGGER_FILE" "$LOG_FILE"
        else
            echo "[$(date)] Cooldown period not passed, skipping TODO generation" >>"${LOG_FILE}"
        fi
    else
        echo "[$(date)] Agents are still active, continuing to monitor" >>"${LOG_FILE}"
    fi

    # Wait before next check
    sleep "$MONITOR_INTERVAL"
done
