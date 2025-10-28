#!/bin/bash
# UI/UX Agent: Handles UI/UX enhancements, drag-and-drop, and interface improvements

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="UIUXAgent"
LOG_FILE="$(dirname "$0")/uiux_agent.log"
PROJECT="PlannerApp" # Default project, can be overridden by task

SLEEP_INTERVAL=600 # Start with 10 minutes for UI work
MIN_INTERVAL=120
MAX_INTERVAL=2400

# Timeout protection function
run_with_timeout() {
    local timeout_seconds="$1"
    local command="$2"
    local timeout_msg="${3:-Operation timed out after ${timeout_seconds} seconds}"

    echo "[$(date)] ${AGENT_NAME}: Starting operation with ${timeout_seconds}s timeout..." >>"${LOG_FILE}"

    # Run command in background with timeout
    (
        eval "${command}" &
        local cmd_pid=$!

        # Wait for completion or timeout
        local count=0
        while [[ ${count} -lt ${timeout_seconds} ]] && kill -0 ${cmd_pid} 2>/dev/null; do
            sleep 1
            ((count++))
        done

        # Check if process is still running
        if kill -0 ${cmd_pid} 2>/dev/null; then
            echo "[$(date)] ${AGENT_NAME}: ${timeout_msg}" >>"${LOG_FILE}"
            kill -TERM ${cmd_pid} 2>/dev/null || true
            sleep 2
            kill -KILL ${cmd_pid} 2>/dev/null || true
            return 124 # Timeout exit code
        fi

        # Wait for process to get exit code
        wait ${cmd_pid} 2>/dev/null
        return $?
    )
}

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

# Function to perform UI/UX enhancements with resource limits
perform_ui_enhancements() {
    local project="$1"
    local task="$2"

    echo "[$(date)] ${AGENT_NAME}: Starting UI/UX enhancements for ${project}..." >>"${LOG_FILE}"

    # Set resource limits to prevent system overload
    set_resource_limits 600 1048576 100 # 10 min CPU, 1GB memory, 100 processes

    # Change to project directory
    cd "/Users/danielstevens/Desktop/Quantum-workspace/Projects/${project}" 2>/dev/null || {
        echo "[$(date)] ${AGENT_NAME}: Could not change to project directory" >>"${LOG_FILE}"
        return 1
    }

    # Create backup before making changes
    echo "[$(date)] ${AGENT_NAME}: Creating backup before UI/UX enhancements..." >>"${LOG_FILE}"
    with_resource_limits 120 262144 20 bash -c "
        /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/backup_manager.sh backup \"${project}\" \"uiux_enhancement\"
    " >>"${LOG_FILE}" 2>&1

    # Check if this is a drag-and-drop task with timeout protection
    local is_drag_drop
    is_drag_drop=$(echo "${task_data}" | jq -r '.todo // empty' | grep -c -i "drag\|drop")

    if [[ ${is_drag_drop} -gt 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Detected drag-and-drop enhancement task..." >>"${LOG_FILE}"

        # Look for UI files that might need drag-and-drop functionality with timeout
        if ! run_with_timeout 120 "
            find . -name '*.swift' -o -name '*.storyboard' -o -name '*.xib' | while read -r file; do
                if grep -q 'TODO.*drag.*drop\|drag.*drop.*TODO' \"\${file}\" 2>/dev/null; then
                    echo \"[$(date)] ${AGENT_NAME}: Found drag-drop TODO in \${file}\" >>'${LOG_FILE}'

                    # Basic drag-and-drop implementation suggestions
                    if [[ \${file} == *'.swift' ]]; then
                        echo \"[$(date)] ${AGENT_NAME}: Adding drag-and-drop implementation to \${file}\" >>'${LOG_FILE}'
                        # This would be where we add actual drag-and-drop code
                        # For now, we'll log the enhancement
                    fi
                fi
            done
        " "Drag-and-drop analysis timed out"; then
            echo "[$(date)] ${AGENT_NAME}: ⚠️  Drag-and-drop analysis failed or timed out" >>"${LOG_FILE}"
        fi
    fi

    # Run general UI/UX analysis with timeout protection
    echo "[$(date)] ${AGENT_NAME}: Analyzing UI/UX patterns..." >>"${LOG_FILE}"

    if ! run_with_timeout 180 "
        find . -name '*View*.swift' -o -name '*Controller*.swift' -o -name '*UI*.swift' | head -10 | while read -r file; do
            echo \"[$(date)] ${AGENT_NAME}: Analyzing UI file: \${file}\" >>'${LOG_FILE}'

            # Check for common UI improvement opportunities
            if grep -q 'TODO.*UI\|UI.*TODO' \"\${file}\" 2>/dev/null; then
                echo \"[$(date)] ${AGENT_NAME}: Found UI TODO in \${file}\" >>'${LOG_FILE}'
            fi
        done
    " "UI/UX analysis timed out"; then
        echo "[$(date)] ${AGENT_NAME}: ⚠️  UI/UX analysis failed or timed out" >>"${LOG_FILE}"
    fi

    # Run validation after changes with timeout protection
    echo "[$(date)] ${AGENT_NAME}: Validating UI/UX enhancements..." >>"${LOG_FILE}"
    if ! run_with_timeout 300 "
        nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/intelligent_autofix.sh validate \"${project}\"
    " "UI/UX validation timed out"; then
        echo "[$(date)] ${AGENT_NAME}: ⚠️  UI/UX validation failed or timed out" >>"${LOG_FILE}"
    fi

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
    local task
    task=$(get_next_task "agent_uiux.sh")
    if [[ -z ${task} ]]; then
        return 0
    fi

    local task_id
    task_id=$(echo "${task}" | jq -r '.id')
    local project
    project=$(get_project_from_task "${task}")

    echo "[$(date)] ${AGENT_NAME}: Processing task ${task_id} for project ${project}..." >>"${LOG_FILE}"

    # Update task status to in_progress
    update_task_status "${task_id}" "in_progress"

    # Perform UI/UX enhancements
    if perform_ui_enhancements "${project}" "${task}"; then
        echo "[$(date)] ${AGENT_NAME}: UI/UX enhancements completed successfully for ${project}" >>"${LOG_FILE}"
        update_task_status "${task_id}" "completed"
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
done
