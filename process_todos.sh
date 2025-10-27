#!/bin/bash
# Tools/Automation/process_todos.sh
# Process exported todo-tree-output.json and take action on TODOs
# Actions: generate issues, assign agents, or trigger workflows based on TODOs
# Now includes MD file scanning for actionable items
# Added --loop flag to automatically monitor and regenerate TODOs when agents are idle

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
echo "[DEBUG] WORKSPACE_DIR is: ${WORKSPACE_DIR}" >&2
TODO_JSON="${WORKSPACE_DIR}/Projects/todo-tree-output.json"
LOG_FILE="${WORKSPACE_DIR}/Tools/Automation/process_todos.log" # Corrected LOG_FILE path
MONITOR_SCRIPT="$(dirname "$0")/todo_loop_monitor.sh"

# Centralized throttling configuration for TODO processing
MAX_CONCURRENCY="${MAX_CONCURRENCY:-3}"    # Maximum concurrent TODO processing instances
LOAD_THRESHOLD="${LOAD_THRESHOLD:-4.0}"    # System load threshold (1.0 = 100% on single core)
WAIT_WHEN_BUSY="${WAIT_WHEN_BUSY:-30}"     # Seconds to wait when system is busy
GLOBAL_AGENT_CAP="${GLOBAL_AGENT_CAP:-10}" # Maximum total agents that can be assigned tasks

# Function to check if we should proceed with TODO processing
ensure_within_limits() {
    local script_name="process_todos.sh"

    # Check concurrent instances of TODO processing
    local running_count
    running_count=$(pgrep -f "${script_name}" | wc -l)
    if [[ ${running_count} -gt ${MAX_CONCURRENCY} ]]; then
        echo "[$(date)] TODO Processor: Too many concurrent instances (${running_count}/${MAX_CONCURRENCY}). Waiting..." | tee -a "${LOG_FILE}"
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
        echo "[$(date)] TODO Processor: System load too high (${load_avg} >= ${LOAD_THRESHOLD}). Waiting..." | tee -a "${LOG_FILE}"
        return 1
    fi

    # Check global agent assignment cap
    local active_assignments
    active_assignments=$(grep -r "assigned_agent" "${WORKSPACE_DIR}/Tools/Automation/agents/task_queue.json" 2>/dev/null | wc -l || echo "0")
    if [[ ${active_assignments} -gt ${GLOBAL_AGENT_CAP} ]]; then
        echo "[$(date)] TODO Processor: Too many active agent assignments (${active_assignments}/${GLOBAL_AGENT_CAP}). Waiting..." | tee -a "${LOG_FILE}"
        return 1
    fi

    return 0
}

# Check for flags
LOOP_MODE=false
STOP_MODE=false
case "$1" in
--loop)
    LOOP_MODE=true
    echo "[$(date)] Starting in loop mode - will monitor agents and auto-regenerate TODOs" | tee -a "${LOG_FILE}"
    ;;
--stop)
    STOP_MODE=true
    echo "[$(date)] Stopping TODO loop monitor" | tee -a "${LOG_FILE}"
    ;;
--status)
    # Show monitor status
    MONITOR_PID_FILE="${WORKSPACE_DIR}/Tools/Automation/todo_loop_monitor.pid"
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        MONITOR_PID=$(cat "$MONITOR_PID_FILE")
        if kill -0 "$MONITOR_PID" 2>/dev/null; then
            echo "[$(date)] TODO loop monitor is running (PID: $MONITOR_PID)" | tee -a "${LOG_FILE}"
        else
            echo "[$(date)] TODO loop monitor PID file exists but process is not running" | tee -a "${LOG_FILE}"
            rm -f "$MONITOR_PID_FILE"
        fi
    else
        echo "[$(date)] TODO loop monitor is not running" | tee -a "${LOG_FILE}"
    fi
    exit 0
    ;;
*)
    # Normal mode - just process TODOs once
    ;;
esac

# Handle stop command
if [[ "$STOP_MODE" == "true" ]]; then
    MONITOR_PID_FILE="${WORKSPACE_DIR}/Tools/Automation/todo_loop_monitor.pid"
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        MONITOR_PID=$(cat "$MONITOR_PID_FILE")
        if kill -0 "$MONITOR_PID" 2>/dev/null; then
            echo "[$(date)] Stopping TODO loop monitor (PID: $MONITOR_PID)" | tee -a "${LOG_FILE}"
            kill "$MONITOR_PID"
            sleep 2
            if kill -0 "$MONITOR_PID" 2>/dev/null; then
                echo "[$(date)] Force killing monitor" | tee -a "${LOG_FILE}"
                kill -9 "$MONITOR_PID"
            fi
        else
            echo "[$(date)] Monitor process not running" | tee -a "${LOG_FILE}"
        fi
        rm -f "$MONITOR_PID_FILE"
        echo "[$(date)] TODO loop monitor stopped" | tee -a "${LOG_FILE}"
    else
        echo "[$(date)] No monitor PID file found" | tee -a "${LOG_FILE}"
    fi
    exit 0
fi

if [[ ! -f ${TODO_JSON} ]]; then
    mkdir -p "$(dirname \""${LOG_FILE}"\")" # Ensure the directory for LOG_FILE exists
    echo "❌ TODO JSON file not found: ${TODO_JSON}" | tee -a "${LOG_FILE}"
    exit 1
fi

# Check if we should proceed with TODO processing (centralized throttling)
if ! ensure_within_limits; then
    # Wait when busy, with exponential backoff
    wait_time=${WAIT_WHEN_BUSY}
    attempts=0
    while ! ensure_within_limits && [[ ${attempts} -lt 10 ]]; do
        echo "[$(date)] TODO Processor: Waiting ${wait_time}s before retry (attempt $((attempts + 1))/10)" | tee -a "${LOG_FILE}"
        sleep "${wait_time}"
        wait_time=$((wait_time * 2))                          # Exponential backoff
        if [[ ${wait_time} -gt 300 ]]; then wait_time=300; fi # Cap at 5 minutes
        ((attempts++))
    done

    # If still busy after retries, exit
    if ! ensure_within_limits; then
        echo "[$(date)] TODO Processor: System still busy after retries. Exiting." | tee -a "${LOG_FILE}"
        exit 1
    fi
fi

echo "🔍 Processing TODOs from ${TODO_JSON}..." | tee -a "${LOG_FILE}"

# First, scan MD files for actionable items and add them to todos
echo "📄 Scanning MD files for additional todos..." | tee -a "${LOG_FILE}"
"$(dirname "$0")/scan_md_for_todos.sh" | tee -a "${LOG_FILE}"

# Example: For each TODO, print details and (optionally) trigger further automation
jq -c '.[]' "${TODO_JSON}" | while read -r todo; do
    file=$(echo "${todo}" | jq -r '.file')
    line=$(echo "${todo}" | jq -r '.line')
    text=$(echo "${todo}" | jq -r '.text')
    source=$(echo "${todo}" | jq -r '.source // "code"')
    echo "➡️  TODO [${source}] in ${file} at line ${line}: ${text}" | tee -a "${LOG_FILE}"
    # Create a local issue for this TODO
    "$(dirname "$0")/create_issue.sh" "${file}" "${line}" "${text}" | tee -a "${LOG_FILE}"
    # Assign an agent to this TODO/issue
    "$(dirname "$0")/assign_agent.sh" "${file}" "${line}" "${text}" | tee -a "${LOG_FILE}"
done

echo "✅ TODO processing complete." | tee -a "${LOG_FILE}"

# If in loop mode, start the monitoring script in the background
if [[ "$LOOP_MODE" == "true" ]]; then
    echo "[$(date)] Starting TODO loop monitor in background..." | tee -a "${LOG_FILE}"

    # Check if monitor is already running
    MONITOR_PID_FILE="${WORKSPACE_DIR}/Tools/Automation/todo_loop_monitor.pid"
    if [[ -f "$MONITOR_PID_FILE" ]]; then
        OLD_PID=$(cat "$MONITOR_PID_FILE")
        if kill -0 "$OLD_PID" 2>/dev/null; then
            echo "[$(date)] Monitor already running (PID: $OLD_PID), not starting new instance" | tee -a "${LOG_FILE}"
        else
            echo "[$(date)] Removing stale PID file" | tee -a "${LOG_FILE}"
            rm -f "$MONITOR_PID_FILE"
            # Start new monitor
            nohup "$MONITOR_SCRIPT" >"${WORKSPACE_DIR}/Tools/Automation/todo_loop_monitor.out" 2>&1 &
            MONITOR_PID=$!
            echo $MONITOR_PID >"$MONITOR_PID_FILE"
            echo "[$(date)] Started new TODO loop monitor (PID: $MONITOR_PID)" | tee -a "${LOG_FILE}"
        fi
    else
        # Start monitor
        nohup "$MONITOR_SCRIPT" >"${WORKSPACE_DIR}/Tools/Automation/todo_loop_monitor.out" 2>&1 &
        MONITOR_PID=$!
        echo $MONITOR_PID >"$MONITOR_PID_FILE"
        echo "[$(date)] Started TODO loop monitor (PID: $MONITOR_PID)" | tee -a "${LOG_FILE}"
    fi

    echo "[$(date)] Loop mode active - monitor will automatically regenerate TODOs when agents become idle" | tee -a "${LOG_FILE}"
fi
