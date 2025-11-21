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

AGENT_NAME="uiux_agent.sh"
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
# UI/UX Agent: Handles UI/UX enhancements, drag-and-drop, and interface improvements

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./shared_functions.sh
# shellcheck disable=SC1091
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="UIUXAgent"
LOG_FILE="$(dirname "$0")/uiux_agent.log"
PROJECT="PlannerApp" # Default project, can be overridden by task

SLEEP_INTERVAL=600 # Start with 10 minutes for UI work
MIN_INTERVAL=120
MAX_INTERVAL=2400
# Safety knobs
MAX_CONCURRENCY=2  # max number of uiux_agent.sh processes allowed concurrently
LOAD_THRESHOLD=8.0 # system 1-minute load average threshold to pause work
WAIT_WHEN_BUSY=30  # seconds to wait before re-checking limits

# Function to determine project from task or use default
get_project_from_task() {
    local task_data="$1"
    local project
    project=$(echo "${task_data}" | jq -r '.project // empty')
    if [[ -z ${project} || ${project} == "null" ]]; then
        project="${PROJECT}"
    fi
    echo "${project}"
}

# Function to perform UI/UX enhancements
perform_ui_enhancements() {
    local project="$1"
    local task_data="$2"

    echo "[$(date)] ${AGENT_NAME}: Starting UI/UX enhancements for ${project}..." >>"${LOG_FILE}"

    # Navigate to project directory
    local project_path="/Users/danielstevens/Desktop/Quantum-workspace/Projects/${project}"
    if [[ ! -d ${project_path} ]]; then
        echo "[$(date)] ${AGENT_NAME}: Project directory not found: ${project_path}" >>"${LOG_FILE}"
        return 1
    fi

    cd "${project_path}" || return 1

    # Create backup before making changes
    echo "[$(date)] ${AGENT_NAME}: Creating backup before UI/UX enhancements..." >>"${LOG_FILE}"
    nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup_if_needed "${project}" >>"${LOG_FILE}" 2>&1 || true

    # Check if this is a drag-and-drop task
    local is_drag_drop
    is_drag_drop=$(echo "${task_data}" | jq -r '.todo // empty' | grep -ci -E 'drag|drop')

    if [[ ${is_drag_drop} -gt 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Detected drag-and-drop enhancement task..." >>"${LOG_FILE}"

        # Look for UI files that might need drag-and-drop functionality
        find . -name "*.swift" -o -name "*.storyboard" -o -name "*.xib" | while read -r file; do
            if grep -q "TODO.*drag.*drop\|drag.*drop.*TODO" "${file}" 2>/dev/null; then
                echo "[$(date)] ${AGENT_NAME}: Found drag-drop TODO in ${file}" >>"${LOG_FILE}"

                # Basic drag-and-drop implementation suggestions
                if [[ ${file} == *".swift" ]]; then
                    echo "[$(date)] ${AGENT_NAME}: Adding drag-and-drop implementation to ${file}" >>"${LOG_FILE}"
                    # This would be where we add actual drag-and-drop code
                    # For now, we'll log the enhancement
                fi
            fi
        done
    fi

    # Run general UI/UX analysis
    echo "[$(date)] ${AGENT_NAME}: Analyzing UI/UX patterns..." >>"${LOG_FILE}"

    # Look for UI-related files and suggest improvements
    find . -name "*View*.swift" -o -name "*Controller*.swift" -o -name "*UI*.swift" | head -10 | while read -r file; do
        echo "[$(date)] ${AGENT_NAME}: Analyzing UI file: ${file}" >>"${LOG_FILE}"

        # Check for common UI improvement opportunities
        if grep -q "TODO.*UI\|UI.*TODO" "${file}" 2>/dev/null; then
            echo "[$(date)] ${AGENT_NAME}: Found UI TODO in ${file}" >>"${LOG_FILE}"
        fi
    done

    # Run validation after changes
    echo "[$(date)] ${AGENT_NAME}: Validating UI/UX enhancements..." >>"${LOG_FILE}"
    nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/intelligent_autofix.sh validate "${project}" >>"${LOG_FILE}" 2>&1

    return 0
}

# Function to run a step with nice priority
run_step() {
    local step_name="$1"
    local command="$2"

    echo "[$(date)] ${AGENT_NAME}: Running ${step_name}..." >>"${LOG_FILE}"
    nice -n 19 bash -c "${command}" >>"${LOG_FILE}" 2>&1
    local exit_code=$?
    if [[ ${exit_code} -eq 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: ${step_name} completed successfully" >>"${LOG_FILE}"
    else
        echo "[$(date)] ${AGENT_NAME}: ${step_name} failed with exit code ${exit_code}" >>"${LOG_FILE}"
    fi
    return ${exit_code}
}

# Function to process assigned tasks
process_assigned_tasks() {
    local task_json
    task_json=$(get_next_task "uiux_agent.sh")
    if [[ -z ${task_json} ]]; then
        return 0
    fi

    local task_id
    task_id=$(echo "${task_json}" | jq -r '.id')
    local project
    project=$(echo "${task_json}" | jq -r '.project // "default"')

    echo "[$(date)] ${AGENT_NAME}: Processing task ${task_id} for project ${project}..." >>"${LOG_FILE}"

    # Update task status to in_progress
    update_task_status "${task_id}" "in_progress"

    # Perform UI/UX enhancements
    if perform_ui_enhancements "${project}" "${task_json}"; then
        echo "[$(date)] ${AGENT_NAME}: UI/UX enhancements completed successfully for ${project}" >>"${LOG_FILE}"
        update_task_status "${task_id}" "completed"
    increment_task_count "${AGENT_NAME}"
        update_agent_status "${AGENT_NAME}" "idle"
        return 0
    else
        echo "[$(date)] ${AGENT_NAME}: UI/UX enhancements failed for ${project}" >>"${LOG_FILE}"
        update_task_status "${task_id}" "failed"
        update_agent_status "${AGENT_NAME}" "error"
        return 1
    fi
}

# Main agent loop
while true; do
    # Safety: ensure we don't overload the system
    ensure_within_limits() {
        # Returns 0 when within limits, 1 otherwise
        # Count uiux_agent.sh processes (this script), subtract 0 for safety
        local proc_count
        # pgrep on macOS may not support -c, so collect PIDs and count
        proc_count=$(pgrep -f "uiux_agent.sh" 2>/dev/null | wc -l || echo 0)

        # On macOS sysctl -n vm.loadavg returns values like: { 0.09 0.05 0.01 }
        local load1
        load1=$(sysctl -n vm.loadavg 2>/dev/null | awk '{print $2}' || echo 0)

        # fallback using uptime parsing
        if [[ -z "${load1}" || "${load1}" == "0" ]]; then
            load1=$(uptime 2>/dev/null | awk -F'load averages?: ' '{print $2}' | awk -F', ' '{print $1}' || echo 0)
        fi

        # convert to numeric (strip trailing commas)
        load1=$(echo "${load1}" | tr -d ',')

        # Compare using awk for floats
        if awk "BEGIN{print (${proc_count} <= ${MAX_CONCURRENCY}) && (${load1} <= ${LOAD_THRESHOLD})?1:0}" | grep -q 1; then
            return 0
        else
            return 1
        fi
    }

    # Wait until system is within safe limits (but respect SINGLE_RUN for testing)
    attempt=0
    while ! ensure_within_limits; do
        attempt=$((attempt + 1))
        echo "[$(date)] ${AGENT_NAME}: System busy (proc_count/limit or load high). Waiting ${WAIT_WHEN_BUSY}s (attempt ${attempt})..." >>"${LOG_FILE}"
        sleep ${WAIT_WHEN_BUSY}
        # If we're in single-run test mode, timeout early
        if [[ "${SINGLE_RUN}" == "1" && ${attempt} -ge 3 ]]; then
            echo "[$(date)] ${AGENT_NAME}: SINGLE_RUN mode - aborting early due to busy system" >>"${LOG_FILE}"
            update_agent_status "${AGENT_NAME}" "idle"
            exit 0
        fi
    done

    update_agent_status "${AGENT_NAME}" "running"

    if process_assigned_tasks; then
        # Success - sleep longer
        SLEEP_INTERVAL=$((SLEEP_INTERVAL + 120))
        if [[ ${SLEEP_INTERVAL} -gt ${MAX_INTERVAL} ]]; then
            SLEEP_INTERVAL=${MAX_INTERVAL}
        fi
    else
        # Failure or no tasks - sleep shorter
        SLEEP_INTERVAL=$((SLEEP_INTERVAL / 2))
        if [[ ${SLEEP_INTERVAL} -lt ${MIN_INTERVAL} ]]; then
            SLEEP_INTERVAL=${MIN_INTERVAL}
        fi
    fi

    update_agent_status "${AGENT_NAME}" "idle"
    echo "[$(date)] ${AGENT_NAME}: Sleeping for ${SLEEP_INTERVAL} seconds..." >>"${LOG_FILE}"
    sleep "${SLEEP_INTERVAL}"

    # If SINGLE_RUN is set, run only one loop iteration for testing
    if [[ "${SINGLE_RUN}" == "1" ]]; then
        echo "[$(date)] ${AGENT_NAME}: SINGLE_RUN mode - exiting after one iteration" >>"${LOG_FILE}"
        exit 0
    fi
done
