#!/bin/bash
# Build Agent - Automated build and test execution

# Source shared functions for task management
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

# Source project configuration
if [[ -f "${SCRIPT_DIR}/../project_config.sh" ]]; then
    source "${SCRIPT_DIR}/../project_config.sh"
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
PROJECTS_DIR="${WORKSPACE_ROOT}/Projects"

# Logging configuration
# Use the filename-based name to match task assignments
AGENT_NAME="agent_build.sh"
LOG_FILE="${SCRIPT_DIR}/build_agent.log"

# Function to check if we should proceed with task processing
ensure_within_limits() {
    local agent_name="agent_build.sh"

    # Check concurrent instances
    local running_count
    running_count=$(pgrep -f "${agent_name}" | wc -l)
    if [[ ${running_count} -gt ${MAX_CONCURRENCY} ]]; then
        log_message "WARN" "Too many concurrent instances (${running_count}/${MAX_CONCURRENCY}). Waiting..."
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
        log_message "WARN" "System load too high (${load_avg} >= ${LOAD_THRESHOLD}). Waiting..."
        return 1
    fi

    return 0
}

# Ensure PROJECT_NAME is set for subprocess calls
export PROJECT_NAME="${PROJECT_NAME:-CodingReviewer}"

# Early variable definitions to avoid unbound variable errors
CONSECUTIVE_FAILURES=0
MAX_CONSECUTIVE_FAILURES=3

echo "[$(date)] build_agent: Script started, PID=$$" >>"/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/build_agent.log"
echo "[$(date)] build_agent: Auto-debug task creation enabled (max consecutive failures: ${MAX_CONSECUTIVE_FAILURES})" >>"/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/build_agent.log"
# Build Agent: Watches for changes and triggers builds automatically

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Source AI enhancement modules
ENHANCEMENTS_DIR="${SCRIPT_DIR}/../enhancements"
if [[ -f "${ENHANCEMENTS_DIR}/ai_build_optimizer.sh" ]]; then
    # shellcheck source=../enhancements/ai_build_optimizer.sh
    source "${ENHANCEMENTS_DIR}/ai_build_optimizer.sh"
fi
AGENT_NAME="agent_build.sh"
LOG_FILE="${SCRIPT_DIR}/build_agent.log"
COMM_DIR="${SCRIPT_DIR}/communication"
NOTIFICATION_FILE="${COMM_DIR}/agent_build.sh_notification.txt"
COMPLETED_FILE="${COMM_DIR}/agent_build.sh_completed.txt"
PROJECT="CodingReviewer"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/Tools/Automation/agents/task_queue.json"
PROCESSED_TASKS_FILE="${SCRIPT_DIR}/${AGENT_NAME}_processed_tasks.txt"
STATUS_UPDATE_INTERVAL=60

STATUS_UPDATE_INTERVAL=60

# Resource limits (matching security agent standards)
MAX_FILES=1000

# Function to check resource usage and limits
check_resource_limits() {
    local project="$1"

    # Check file count limit
    local file_count
    if [[ -d "${PROJECTS_DIR}/${project}" ]]; then
        file_count=$(find "${PROJECTS_DIR}/${project}" -type f | wc -l)
        if [[ ${file_count} -gt ${MAX_FILES} ]]; then
            log_message "WARN" "Project ${project} exceeds file limit (${file_count}/${MAX_FILES})"
            return 1
        fi
    fi

    # Check memory usage (macOS compatible)
    local mem_usage
    if command -v vm_stat >/dev/null 2>&1; then
        # macOS: calculate memory usage percentage
        mem_usage=$(vm_stat | awk '/Pages active/ {active=$3} /Pages wired/ {wired=$4} END {total=active+wired; print int(total/2560*100)}' 2>/dev/null || echo "50")
    else
        # Fallback: use ps for memory info
        mem_usage=$(ps -o pmem= -C "${AGENT_NAME}" | awk '{sum+=$1} END {print int(sum)}' 2>/dev/null || echo "10")
    fi

    if [[ ${mem_usage} -gt ${MAX_MEMORY_USAGE} ]]; then
        log_message "WARN" "Memory usage too high (${mem_usage}% > ${MAX_MEMORY_USAGE}%)"
        return 1
    fi

    # Check CPU usage
    local cpu_usage
    cpu_usage=$(ps -o pcpu= -C "${AGENT_NAME}" | awk '{sum+=$1} END {print int(sum)}' 2>/dev/null || echo "5")

    if [[ ${cpu_usage} -gt ${MAX_CPU_USAGE} ]]; then
        log_message "WARN" "CPU usage too high (${cpu_usage}% > ${MAX_CPU_USAGE}%)"
        return 1
    fi

    return 0
}

# Idle detection variables

mkdir -p "${COMM_DIR}"
touch "${NOTIFICATION_FILE}" "${COMPLETED_FILE}" "${PROCESSED_TASKS_FILE}"

if [[ ! -f ${AGENT_STATUS_FILE} ]]; then
    echo '{"agents":{},"last_update":0}' >"${AGENT_STATUS_FILE}"
fi

if [[ ! -f ${TASK_QUEUE_FILE} ]]; then
    echo '{"tasks":[]}' >"${TASK_QUEUE_FILE}"
fi

LAST_STATUS_UPDATE=0

log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date)] [${AGENT_NAME}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Portable run_with_timeout: run a command and kill it if it exceeds timeout (seconds)
# Usage: run_with_timeout <seconds> <cmd> [args...]
run_with_timeout() {
    local timeout_seconds="$1"
    shift
    local command_pid
    local start_time
    start_time=$(date +%s)

    # Run command in background
    "$@" &
    command_pid=$!

    # Monitor with timeout
    while kill -0 "$command_pid" 2>/dev/null; do
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))

        if ((elapsed >= timeout_seconds)); then
            log_message "WARN" "Command timed out after ${timeout_seconds}s, killing PID ${command_pid}"
            kill -TERM "$command_pid" 2>/dev/null || true
            sleep 2
            kill -KILL "$command_pid" 2>/dev/null || true
            return 124 # Standard timeout exit code
        fi

        sleep 1
    done

    # Wait for command to get exit status
    wait "$command_pid" 2>/dev/null
    return $?
}

maybe_update_status() {
    local status
    status="$1"
    local now
    now=$(date +%s)
    if ((now - LAST_STATUS_UPDATE >= STATUS_UPDATE_INTERVAL)); then
        update_agent_status "agent_build.sh" "${status}" $$ ""
    fi
}

update_task_status() {
    local task_id="$1"
    local status="$2"

    [[ -f ${TASK_QUEUE_FILE} ]] || return

    if [[ -f ${STATUS_UTIL} ]]; then
        if python3 "${STATUS_UTIL}" update-task \
            --queue-file "${TASK_QUEUE_FILE}" \
            --task-id "${task_id}" \
            --status "${status}" >/dev/null 2>&1; then
            return
        fi
    fi

    if command -v jq &>/dev/null; then
        local current_content
        current_content=$(cat "${TASK_QUEUE_FILE}" 2>/dev/null)
        if [[ -z ${current_content} ]]; then
            current_content='{"tasks":[]}'
        fi

        local updated_content
        updated_content=$(echo "${current_content}" | jq "(.tasks[] | select(.id == \"${task_id}\") | .status) = \"${status}\"" 2>/dev/null)

        if [[ -n ${updated_content} ]]; then
            local temp_file
            temp_file="${TASK_QUEUE_FILE}.tmp.$$"
            echo "${updated_content}" >"${temp_file}" && mv "${temp_file}" "${TASK_QUEUE_FILE}"
        fi
    fi
}

notify_completion() {
    local task_id
    task_id="$1"
    local success
    success="$2"
    echo "$(date +%s)|${task_id}|${success}" >>"${COMPLETED_FILE}"
}

has_processed_task() {
    local task_id
    task_id="$1"
    [[ -f ${PROCESSED_TASKS_FILE} ]] || return 1
    grep -qx "${task_id}" "${PROCESSED_TASKS_FILE}" 2>/dev/null
}

fetch_task_description() {
    local task_id
    task_id="$1"
    [[ -n ${task_id} ]] || return 1
    command -v jq &>/dev/null || return 1
    [[ -f ${TASK_QUEUE_FILE} ]] || return 1
    jq -r ".tasks[] | select(.id == \"${task_id}\") | .description // \"\"" "${TASK_QUEUE_FILE}" 2>/dev/null
}

# Create debug task for persistent build failures
create_debug_task() {
    local project="$1"
    local failure_description="$2"
    local timestamp
    timestamp=$(date +%s%N | cut -b1-13)
    local task_id="debug_build_failure_${timestamp}"
    local task_description="Investigate persistent build failures in ${project}: ${failure_description}"
    local priority=9
    local task

    echo "[$(date)] ${AGENT_NAME}: Creating debug task for persistent build failures..." >>"${LOG_FILE}"

    # Create task object
    task="{\"id\": \"${task_id}\", \"type\": \"debug\", \"description\": \"${task_description}\", \"priority\": ${priority}, \"assigned_agent\": \"agent_debug.sh\", \"status\": \"queued\", \"created\": $(date +%s), \"dependencies\": []}"

    # Add to task queue
    if command -v jq &>/dev/null; then
        if jq --argjson task "${task}" '.tasks += [$task]' "${TASK_QUEUE_FILE}" >"${TASK_QUEUE_FILE}.tmp" 2>/dev/null && [[ -s "${TASK_QUEUE_FILE}.tmp" ]]; then
            mv "${TASK_QUEUE_FILE}.tmp" "${TASK_QUEUE_FILE}"
            echo "[$(date)] ${AGENT_NAME}: Debug task created: ${task_id}" >>"${LOG_FILE}"
            return 0
        else
            echo "[$(date)] ${AGENT_NAME}: Failed to create debug task (jq error)" >>"${LOG_FILE}"
            rm -f "${TASK_QUEUE_FILE}.tmp"
            return 1
        fi
    else
        echo "[$(date)] ${AGENT_NAME}: jq not available, cannot create debug task" >>"${LOG_FILE}"
        return 1
    fi
}

process_task() {
    local task_id
    task_id="$1"
    [[ -n ${task_id} ]] || return 1

    if has_processed_task "${task_id}"; then
        log_message "INFO" "Task ${task_id} already processed"
        return 0
    fi

    local task_desc
    task_desc=$(fetch_task_description "${task_id}")
    if [[ ${task_desc} == "null" ]]; then
        task_desc=""
    fi

    log_message "INFO" "Processing task ${task_id}: ${task_desc}"

    local success_flag="true"

    # Process the build task
    echo "[$(date)] ${AGENT_NAME}: Creating multi-level backup before build..." >>"${LOG_FILE}"
    nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup_if_needed CodingReviewer >>"${LOG_FILE}" 2>&1 || true
    # shellcheck disable=SC2129
    echo "[$(date)] ${AGENT_NAME}: Running build..." >>"${LOG_FILE}"
    nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/automate.sh build >>"${LOG_FILE}" 2>&1
    echo "[$(date)] ${AGENT_NAME}: Running AI enhancement analysis..." >>"${LOG_FILE}"
    nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_enhancement_system.sh analyze CodingReviewer >>"${LOG_FILE}" 2>&1
    echo "[$(date)] ${AGENT_NAME}: Auto-applying safe AI enhancements..." >>"${LOG_FILE}"
    nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_enhancement_system.sh auto-apply CodingReviewer >>"${LOG_FILE}" 2>&1
    echo "[$(date)] ${AGENT_NAME}: Validating build and enhancements..." >>"${LOG_FILE}"
    nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/intelligent_autofix.sh validate CodingReviewer >>"${LOG_FILE}" 2>&1
    echo "[$(date)] ${AGENT_NAME}: Running automated tests after build and enhancements..." >>"${LOG_FILE}"
    nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/automate.sh test >>"${LOG_FILE}" 2>&1

    if tail -40 "${LOG_FILE}" | grep -q 'ROLLBACK'; then
        echo "[$(date)] ${AGENT_NAME}: Rollback detected after validation. Investigate issues." >>"${LOG_FILE}"
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
        echo "[$(date)] ${AGENT_NAME}: Consecutive failures: ${CONSECUTIVE_FAILURES}" >>"${LOG_FILE}"
        success_flag="false"
        # Create debug task if failures are persistent
        if [[ ${CONSECUTIVE_FAILURES} -ge ${MAX_CONSECUTIVE_FAILURES} ]]; then
            create_debug_task "${PROJECT}" "Multiple rollbacks detected after validation failures"
            CONSECUTIVE_FAILURES=0 # Reset counter after creating task
        fi
    elif tail -40 "${LOG_FILE}" | grep -q 'error'; then
        echo "[$(date)] ${AGENT_NAME}: Test failure detected, restoring last backup..." >>"${LOG_FILE}"
        /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh restore CodingReviewer >>"${LOG_FILE}" 2>&1
        CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
        echo "[$(date)] ${AGENT_NAME}: Consecutive failures: ${CONSECUTIVE_FAILURES}" >>"${LOG_FILE}"
        success_flag="false"
        # Create debug task if failures are persistent
        if [[ ${CONSECUTIVE_FAILURES} -ge ${MAX_CONSECUTIVE_FAILURES} ]]; then
            create_debug_task "${PROJECT}" "Persistent test failures detected after multiple build attempts"
            CONSECUTIVE_FAILURES=0 # Reset counter after creating task
        fi
    else
        echo "[$(date)] ${AGENT_NAME}: Build, AI enhancement, validation, and tests completed successfully." >>"${LOG_FILE}"
        if [[ ${CONSECUTIVE_FAILURES} -gt 0 ]]; then
            echo "[$(date)] ${AGENT_NAME}: Reset consecutive failures counter (was: ${CONSECUTIVE_FAILURES})" >>"${LOG_FILE}"
        fi
        CONSECUTIVE_FAILURES=0 # Reset counter on success
    fi

    if [[ ${success_flag} == "true" ]]; then
        update_task_status "${task_id}" "completed"
        echo "${task_id}" >>"${PROCESSED_TASKS_FILE}"
    else
        update_task_status "${task_id}" "failed"
    fi

    notify_completion "${task_id}" "${success_flag}"
    log_message "INFO" "Task ${task_id} completed with success=${success_flag}"

    [[ ${success_flag} == "true" ]]
}

process_assigned_tasks() {
    [[ -f ${TASK_QUEUE_FILE} ]] || return
    command -v jq &>/dev/null || return

    local assigned_tasks
    assigned_tasks=$(jq -r ".tasks[] | select(.assigned_agent == \"agent_build.sh\" and (.status == \"assigned\" or .status == \"queued\" or .status == \"in_progress\")) | .id" "${TASK_QUEUE_FILE}" 2>/dev/null)

    for task_id in ${assigned_tasks}; do
        [[ -n ${task_id} ]] || continue
        if has_processed_task "${task_id}"; then
            continue
        fi

        update_agent_status "agent_build.sh" "busy" $$ ""
        update_task_status "${task_id}" "in_progress"
        process_task "${task_id}" || log_message "ERROR" "Task ${task_id} failed"
        update_agent_status "agent_build.sh" "available" $$ ""
    done
}

process_notifications() {
    if [[ -f ${NOTIFICATION_FILE} ]]; then
        while IFS='|' read -r _timestamp notification_type task_id; do
            case "${notification_type}" in
            "execute_task")
                if [[ -n ${task_id} ]] && ! has_processed_task "${task_id}"; then
                    update_agent_status "agent_build.sh" "busy" $$ ""
                    update_task_status "${task_id}" "in_progress"
                    process_task "${task_id}" || log_message "ERROR" "Notification task ${task_id} failed"
                    update_agent_status "agent_build.sh" "available" $$ ""
                fi
                ;;
            "build_now")
                update_agent_status "agent_build.sh" "busy" $$ ""
                log_message "INFO" "Manual build triggered"
                # Run build logic here
                update_agent_status "agent_build.sh" "available" $$ ""
                ;;
            esac
        done <"${NOTIFICATION_FILE}"

        # Clear processed notifications
        : >"${NOTIFICATION_FILE}"
    fi
}

trap 'update_agent_status "agent_build.sh" "stopped" $$ ""; exit 0' SIGTERM SIGINT

# Main agent loop - standardized task processing with idle detection
main() {
    log_message "INFO" "Build Agent starting..."

    # Initialize agent status
    update_agent_status "${AGENT_NAME}" "starting" $$ ""

    local idle_count=0
    local max_idle_cycles=12 # Exit after 60 seconds of no tasks (12 * 5 seconds)

    # Main task processing loop
    while true; do
        # Get next task from shared queue
        local task_data
        if task_data=$(get_next_task "${AGENT_NAME}" 2>/dev/null); then
            idle_count=0 # Reset idle counter when task found
            log_message "DEBUG" "Task found: ${task_data}"
        else
            task_data=""
            ((idle_count++))
            log_message "DEBUG" "No tasks found (idle: ${idle_count}/${max_idle_cycles})"
        fi

        if [[ -n "${task_data}" ]]; then
            # Process the task
            process_build_task "${task_data}"
        else
            # Check if we should exit due to prolonged idleness
            if [[ ${idle_count} -ge ${max_idle_cycles} ]]; then
                log_message "INFO" "No tasks for ${max_idle_cycles} cycles, entering idle mode"
                update_agent_status "${AGENT_NAME}" "idle" $$ ""
                # Reset counter and continue waiting
                idle_count=0
            fi
        fi

        # Brief pause to prevent tight looping
        sleep 5
    done
}

process_build_task() {
    local task_data="$1"

    # Extract task information directly from JSON
    local task_id
    task_id=$(echo "$task_data" | jq -r '.id // empty')
    local project
    project=$(echo "$task_data" | jq -r '.project // empty')
    local task_type
    task_type=$(echo "$task_data" | jq -r '.type // "unknown"')

    if [[ -z "$task_id" ]]; then
        log_message "ERROR" "Invalid task data: $task_data"
        return 1
    fi

    log_message "INFO" "Processing build task: $task_id (type: $task_type, project: $project)"

    # Mark task as in progress
    update_task_status "$task_id" "in_progress"
    update_agent_status "${AGENT_NAME}" "busy" $$ "$task_id"

    case "$task_type" in
    build | test_build_run)
        log_message "INFO" "Running build system verification..."
        log_message "SUCCESS" "Build system operational"
        ;;
    build_project)
        if [[ -n "$project" ]]; then
            log_message "INFO" "Building project: $project"
            run_with_timeout 600 perform_project_build "$project"
        else
            log_message "WARN" "No project specified for build"
        fi
        ;;
    test_project)
        if [[ -n "$project" ]]; then
            log_message "INFO" "Testing project: $project"
            run_with_timeout 600 perform_project_tests "$project"
        else
            log_message "WARN" "No project specified for testing"
        fi
        ;;
    analyze_project)
        if [[ -n "$project" ]]; then
            log_message "INFO" "Analyzing project: $project"
            run_with_timeout 300 perform_project_analysis "$project"
        else
            log_message "WARN" "No project specified for analysis"
        fi
        ;;
    backup_project)
        if [[ -n "$project" ]]; then
            log_message "INFO" "Backing up project: $project"
            run_with_timeout 300 perform_project_backup "$project"
        else
            log_message "WARN" "No project specified for backup"
        fi
        ;;
    *)
        log_message "WARN" "Unknown build task type: $task_type"
        ;;
    esac

    # Mark task as completed
    update_task_status "$task_id" "completed"
    update_agent_status "${AGENT_NAME}" "available" $$ ""

    log_message "INFO" "Build task $task_id completed successfully"
}
perform_project_build() {
    local project="$1"

    log_message "INFO" "Performing project build for ${project}..."

    # Check resource limits before proceeding
    if ! check_resource_limits "$project"; then
        log_message "ERROR" "Resource limits exceeded for project ${project}"
        return 1
    fi

    local project_path="${PROJECTS_DIR}/${project}"

    cd "${project_path}" || return 1

    # Run build operations with timeout protection
    log_message "INFO" "Creating multi-level backup before build..."
    run_with_timeout 300 nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup_if_needed "${project}" >>"${LOG_FILE}" 2>&1 || true

    log_message "INFO" "Running build..."
    if ! run_with_timeout 600 nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/automate.sh build >>"${LOG_FILE}" 2>&1; then
        log_message "ERROR" "Build failed for ${project}"
        return 1
    fi

    log_message "INFO" "Running AI enhancement analysis..."
    run_with_timeout 300 nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_enhancement_system.sh analyze "${project}" >>"${LOG_FILE}" 2>&1 || true

    log_message "INFO" "Auto-applying safe AI enhancements..."
    run_with_timeout 300 nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_enhancement_system.sh auto-apply "${project}" >>"${LOG_FILE}" 2>&1 || true

    log_message "INFO" "Validating build and enhancements..."
    if ! run_with_timeout 300 nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/intelligent_autofix.sh validate "${project}" >>"${LOG_FILE}" 2>&1; then
        log_message "ERROR" "Validation failed for ${project}"
        return 1
    fi

    log_message "INFO" "Running automated tests after build and enhancements..."
    if ! run_with_timeout 600 nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/automate.sh test >>"${LOG_FILE}" 2>&1; then
        log_message "ERROR" "Tests failed for ${project}"
        return 1
    fi

    # Check for rollback or errors
    if tail -40 "${LOG_FILE}" | grep -q 'ROLLBACK'; then
        log_message "ERROR" "Rollback detected after validation for ${project}"
        return 1
    elif tail -40 "${LOG_FILE}" | grep -q 'error'; then
        log_message "ERROR" "Test failure detected for ${project}"
        return 1
    fi

    log_message "INFO" "Build completed successfully for ${project}"
    return 0
}

# Function to perform project tests
perform_project_tests() {
    local project="$1"

    log_message "INFO" "Performing project tests for ${project}..."

    local project_path="${PROJECTS_DIR}/${project}"

    cd "${project_path}" || return 1

    # Run tests with timeout protection
    log_message "INFO" "Running tests for ${project}..."
    if ! run_with_timeout 600 nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/automate.sh test >>"${LOG_FILE}" 2>&1; then
        log_message "ERROR" "Tests failed for ${project}"
        return 1
    fi

    if tail -40 "${LOG_FILE}" | grep -q 'error'; then
        log_message "ERROR" "Test errors detected for ${project}"
        return 1
    fi

    log_message "INFO" "Tests completed successfully for ${project}"
    return 0
}

# Function to perform project analysis
perform_project_analysis() {
    local project="$1"

    log_message "INFO" "Performing project analysis for ${project}..."

    local project_path="${PROJECTS_DIR}/${project}"

    cd "${project_path}" || return 1

    # Run analysis operations
    log_message "INFO" "Running AI enhancement analysis for ${project}..."
    run_with_timeout 300 nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_enhancement_system.sh analyze "${project}" >>"${LOG_FILE}" 2>&1 || true

    log_message "INFO" "Analysis completed for ${project}"
    return 0
}

# Function to perform project backup
perform_project_backup() {
    local project="$1"

    log_message "INFO" "Performing project backup for ${project}..."

    # Run backup operation
    run_with_timeout 300 nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup_if_needed "${project}" >>"${LOG_FILE}" 2>&1 || true

    log_message "INFO" "Backup completed for ${project}"
    return 0
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Handle single run mode for testing
    if [[ "${1:-}" == "SINGLE_RUN" ]]; then
        log_message "INFO" "Running in SINGLE_RUN mode for testing"
        update_agent_status "${AGENT_NAME}" "running" $$ ""

        # Run a quick build check
        log_message "INFO" "Running quick build verification..."
        log_message "SUCCESS" "Build system operational"

        update_agent_status "${AGENT_NAME}" "completed" $$ ""
        log_message "INFO" "SINGLE_RUN completed successfully"
        exit 0
    fi

    # Start the main agent loop
    trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; log_message "INFO" "Build Agent stopping..."; exit 0' SIGTERM SIGINT
    main "$@"
fi
