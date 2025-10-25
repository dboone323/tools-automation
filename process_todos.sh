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
