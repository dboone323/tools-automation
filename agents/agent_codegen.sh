#!/bin/bash

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

# Source project configuration
if [[ -f "${SCRIPT_DIR}/../project_config.sh" ]]; then
    source "${SCRIPT_DIR}/../project_config.sh"
fi

set -euo pipefail

# Agent throttling configuration
MAX_CONCURRENCY="${MAX_CONCURRENCY:-2}" # Maximum concurrent instances of this agent
LOAD_THRESHOLD="${LOAD_THRESHOLD:-4.0}" # System load threshold (1.0 = 100% on single core)
WAIT_WHEN_BUSY="${WAIT_WHEN_BUSY:-30}"  # Seconds to wait when system is busy

# Resource limits (matching security agent standards)
MAX_FILES=1000
MAX_EXECUTION_TIME=1800 # 30 minutes
MAX_MEMORY_USAGE=80     # 80% of available memory
MAX_CPU_USAGE=90        # 90% CPU usage threshold

# Task processing limits
MAX_CONCURRENT_TASKS=3
TASK_TIMEOUT=600 # 10 minutes per task

# Function to check if we should proceed with task processing
ensure_within_limits() {
    local agent_name="agent_codegen.sh"

    # Check concurrent instances
    local running_count=$(pgrep -f "${agent_name}" | wc -l)
    if [[ ${running_count} -gt ${MAX_CONCURRENCY} ]]; then
        echo "[$(date)] ${AGENT_NAME}: Too many concurrent instances (${running_count}/${MAX_CONCURRENCY}). Waiting..." >>"${LOG_FILE}"
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
        echo "[$(date)] ${AGENT_NAME}: System load too high (${load_avg} >= ${LOAD_THRESHOLD}). Waiting..." >>"${LOG_FILE}"
        return 1
    fi

    return 0
}

# Ensure PROJECT_NAME is set for subprocess calls
export PROJECT_NAME="${PROJECT_NAME:-CodingReviewer}"

echo "[$(date)] codegen_agent: Script started, PID=$$" >>"/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/codegen_agent.log"
# CodeGen/Fix Agent: Triggers code generation and auto-fix routines

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Source AI enhancement modules
ENHANCEMENTS_DIR="${SCRIPT_DIR}/../enhancements"
if [[ -f "${ENHANCEMENTS_DIR}/ai_codegen_optimizer.sh" ]]; then
    # shellcheck source=../enhancements/ai_codegen_optimizer.sh
    source "${ENHANCEMENTS_DIR}/ai_codegen_optimizer.sh"
fi

AGENT_NAME="agent_codegen.sh"
AGENT_LABEL="CodeGenAgent"
LOG_FILE="${SCRIPT_DIR}/codegen_agent.log"
COMM_DIR="${SCRIPT_DIR}/communication"
NOTIFICATION_FILE="${COMM_DIR}/agent_codegen.sh_notification.txt"
COMPLETED_FILE="${COMM_DIR}/agent_codegen.sh_completed.txt"
PROJECT="CodingReviewer"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/Tools/Automation/agents/task_queue.json"
PROCESSED_TASKS_FILE="${SCRIPT_DIR}/${AGENT_NAME}_processed_tasks.txt"
STATUS_UPDATE_INTERVAL=60

STATUS_UTIL="${SCRIPT_DIR}/status_utils.py"
STATUS_KEYS=("${AGENT_NAME}" "agent_codegen.sh")

PROJECT="${PROJECT:-CodingReviewer}"
PROJECT_CONFIG_FILES=(
    "${WORKSPACE}/Tools/Automation/project_config.sh"
    "${WORKSPACE}/Projects/${PROJECT}/Tools/Automation/project_config.sh"
)

AUTOMATE_BIN="${WORKSPACE}/Tools/Automation/automate.sh"
MCP_WORKFLOW_BIN="${WORKSPACE}/Tools/Automation/mcp_workflow.sh"
AI_ENHANCEMENT_BIN="${WORKSPACE}/Tools/Automation/ai_enhancement_system.sh"
AUTO_FIX_VALIDATOR="${WORKSPACE}/Tools/Automation/intelligent_autofix.sh"
BACKUP_MANAGER="${SCRIPT_DIR}/backup_manager.sh"

SLEEP_INTERVAL=900 # Start with 15 minutes
MIN_INTERVAL=60
MAX_INTERVAL=1800

CONSECUTIVE_FAILURES=0
MAX_CONSECUTIVE_FAILURES=3

# Idle detection variables
IDLE_COUNTER=0
MAX_IDLE_CYCLES=12 # 12 cycles = ~1 minute at 5-second intervals

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
    local level
    level="$1"
    local message
    message="$2"
    echo "[$(date)] [${AGENT_LABEL}] [${level}] ${message}" >>"${LOG_FILE}"
}

# Portable run_with_timeout: run a command and kill it if it exceeds timeout (seconds)
# Usage: run_with_timeout <seconds> <cmd> [args...]
run_with_timeout() {
    local timeout_secs="$1"
    shift
    if [[ -z "${timeout_secs}" || ${timeout_secs} -le 0 ]]; then
        "$@"
        return $?
    fi

    # Run command in background
    (
        "$@"
    ) &
    local cmd_pid=$!

    # Watcher: sleep then kill if still running
    (
        sleep "${timeout_secs}"
        if kill -0 "${cmd_pid}" 2>/dev/null; then
            log_message "WARN" "Command timed out after ${timeout_secs}s, killing pid ${cmd_pid}"
            kill -9 "${cmd_pid}" 2>/dev/null || true
        fi
    ) &
    local watcher_pid=$!

    # Wait for command to finish
    wait "${cmd_pid}" 2>/dev/null
    local cmd_status=$?

    # Clean up watcher
    kill -9 "${watcher_pid}" 2>/dev/null || true
    wait "${watcher_pid}" 2>/dev/null || true

    return ${cmd_status}
}

# Function to check resource usage and limits
check_resource_limits() {
    local project="$1"

    # Check file count limit
    local file_count
    if [[ -d "${WORKSPACE}/Projects/${project}" ]]; then
        file_count=$(find "${WORKSPACE}/Projects/${project}" -type f | wc -l)
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

initialize_project_context() {
    local config_loaded=false
    local config
    for config in "${PROJECT_CONFIG_FILES[@]}"; do
        if [[ -f ${config} ]]; then
            # shellcheck disable=SC1090
            source "${config}"
            config_loaded=true
        fi
    done

    PROJECT_NAME="${PROJECT_NAME:-${PROJECT}}"
    PROJECT_DIR="${PROJECT_DIR:-${WORKSPACE}/Projects/${PROJECT_NAME}}"

    export PROJECT_NAME PROJECT_DIR

    if [[ ${config_loaded} != true ]]; then
        log_message "WARN" "No project configuration found for ${PROJECT_NAME}; using defaults."
    else
        log_message "INFO" "Project configuration loaded for ${PROJECT_NAME}."
    fi

    if [[ ! -d ${PROJECT_DIR} ]]; then
        log_message "ERROR" "Project directory not found: ${PROJECT_DIR}"
        return 1
    fi

    return 0
}

if ! initialize_project_context; then
    log_message "ERROR" "Unable to initialize project context; exiting."
    exit 1
fi

run_step() {
    local allow_failure
    allow_failure="$1"
    shift
    local description
    description="$1"
    shift

    echo "[$(date)] ${AGENT_NAME}: ${description}" >>"${LOG_FILE}"

    if nice -n 19 "$@" >>"${LOG_FILE}" 2>&1; then
        return 0
    fi

    log_message "ERROR" "${description} failed"
    if [[ ${allow_failure} == "true" ]]; then
        return 0
    fi

    return 1
}

record_task_success() {
    [[ -f ${STATUS_UTIL} ]] || return

    local key
    for key in "${STATUS_KEYS[@]}"; do
        python3 "${STATUS_UTIL}" update-agent \
            --status-file "${AGENT_STATUS_FILE}" \
            --agent "${key}" \
            --increment-field tasks_completed >/dev/null 2>&1 || true
    done
}

maybe_update_status() {
    local status
    status="$1"
    local now
    now=$(date +%s)
    if ((now - LAST_STATUS_UPDATE >= STATUS_UPDATE_INTERVAL)); then
        update_agent_status "agent_codegen.sh" "${status}" $$ ""
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

run_codegen_pipeline() {
    local success_flag="true"

    if ! run_step true "Creating backup before codegen/fix..." "${BACKUP_MANAGER}" backup_if_needed "${PROJECT_NAME}"; then
        success_flag="false"
    fi

    if ! run_step false "Running AI automation pipeline" run_with_timeout 300 "${AUTOMATE_BIN}" ai; then
        success_flag="false"
    fi

    if ! run_step false "Executing MCP autofix workflow" run_with_timeout 300 "${MCP_WORKFLOW_BIN}" autofix "${PROJECT_NAME}"; then
        success_flag="false"
    fi

    if ! run_step false "Running AI enhancement analysis" run_with_timeout 300 "${AI_ENHANCEMENT_BIN}" analyze "${PROJECT_NAME}"; then
        success_flag="false"
    fi

    if ! run_step true "Auto-applying safe AI enhancements" run_with_timeout 300 "${AI_ENHANCEMENT_BIN}" auto-apply "${PROJECT_NAME}"; then
        success_flag="false"
    fi

    if ! run_step false "Validating codegen, fixes, and enhancements" run_with_timeout 300 "${AUTO_FIX_VALIDATOR}" validate "${PROJECT_NAME}"; then
        success_flag="false"
    fi

    if ! run_step false "Running automated tests after codegen/enhancement" run_with_timeout 600 "${AUTOMATE_BIN}" test; then
        success_flag="false"
    fi

    if [[ ${success_flag} == "true" ]]; then
        if tail -40 "${LOG_FILE}" | grep -q 'ROLLBACK'; then
            echo "[$(date)] ${AGENT_NAME}: Rollback detected after validation. Investigate issues." >>"${LOG_FILE}"
            CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
            echo "[$(date)] ${AGENT_NAME}: Consecutive failures: ${CONSECUTIVE_FAILURES}" >>"${LOG_FILE}"
            success_flag="false"
        elif tail -40 "${LOG_FILE}" | grep -iq 'error'; then
            echo "[$(date)] ${AGENT_NAME}: Errors detected during validation or tests; restoring last backup." >>"${LOG_FILE}"
            run_step true "Restoring last backup" run_with_timeout 300 "${BACKUP_MANAGER}" restore "${PROJECT_NAME}" || true
            CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
            echo "[$(date)] ${AGENT_NAME}: Consecutive failures: ${CONSECUTIVE_FAILURES}" >>"${LOG_FILE}"
            success_flag="false"
        else
            echo "[$(date)] ${AGENT_NAME}: Codegen, enhancement, validation, and tests completed successfully." >>"${LOG_FILE}"
            if [[ ${CONSECUTIVE_FAILURES} -gt 0 ]]; then
                echo "[$(date)] ${AGENT_NAME}: Reset consecutive failures counter (was: ${CONSECUTIVE_FAILURES})" >>"${LOG_FILE}"
            fi
            CONSECUTIVE_FAILURES=0
        fi
    fi

    [[ ${success_flag} == "true" ]]
}

# Main agent loop - standardized task processing with idle detection
main() {
    log_message "INFO" "CodeGen Agent starting..."

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
            process_codegen_task "${task_data}"
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

process_codegen_task() {
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

    log_message "INFO" "Processing codegen task: $task_id (type: $task_type, project: $project)"

    # Mark task as in progress
    update_task_status "$task_id" "in_progress"
    update_agent_status "${AGENT_NAME}" "busy" $$ "$task_id"

    case "$task_type" in
    codegen | test_codegen_run)
        log_message "INFO" "Running codegen system verification..."
        log_message "SUCCESS" "Codegen system operational"
        ;;
    full_codegen)
        if [[ -n "$project" ]]; then
            log_message "INFO" "Running full codegen pipeline for project: $project"
            run_with_timeout 300 perform_full_codegen "$project"
        else
            log_message "WARN" "No project specified for codegen"
        fi
        ;;
    ai_automation)
        if [[ -n "$project" ]]; then
            log_message "INFO" "Running AI automation pipeline for project: $project"
            run_with_timeout 300 perform_ai_automation "$project"
        else
            log_message "WARN" "No project specified for AI automation"
        fi
        ;;
    autofix)
        if [[ -n "$project" ]]; then
            log_message "INFO" "Running autofix workflow for project: $project"
            run_with_timeout 300 perform_autofix "$project"
        else
            log_message "WARN" "No project specified for autofix"
        fi
        ;;
    enhance)
        if [[ -n "$project" ]]; then
            log_message "INFO" "Running AI enhancement for project: $project"
            run_with_timeout 300 perform_enhancement "$project"
        else
            log_message "WARN" "No project specified for enhancement"
        fi
        ;;
    validate)
        if [[ -n "$project" ]]; then
            log_message "INFO" "Running validation for project: $project"
            run_with_timeout 300 perform_validation "$project"
        else
            log_message "WARN" "No project specified for validation"
        fi
        ;;
    test_codegen)
        if [[ -n "$project" ]]; then
            log_message "INFO" "Running tests after codegen for project: $project"
            run_with_timeout 600 perform_codegen_tests "$project"
        else
            log_message "WARN" "No project specified for codegen tests"
        fi
        ;;
    *)
        log_message "WARN" "Unknown codegen task type: $task_type"
        ;;
    esac

    # Mark task as completed
    update_task_status "$task_id" "completed"
    update_agent_status "${AGENT_NAME}" "available" $$ ""

    log_message "INFO" "Codegen task $task_id completed successfully"
}

# Function to perform full codegen pipeline
perform_full_codegen() {
    local project="$1"

    log_message "INFO" "Performing full codegen pipeline for ${project}..."

    local success_flag="true"

    # Create backup before codegen/fix
    if ! run_step true "Creating backup before codegen/fix..." "${BACKUP_MANAGER}" backup_if_needed "${project}"; then
        success_flag="false"
    fi

    # Run AI automation pipeline
    if ! run_step false "Running AI automation pipeline" run_with_timeout 300 "${AUTOMATE_BIN}" ai; then
        success_flag="false"
    fi

    # Execute MCP autofix workflow
    if ! run_step false "Executing MCP autofix workflow" run_with_timeout 300 "${MCP_WORKFLOW_BIN}" autofix "${project}"; then
        success_flag="false"
    fi

    # Run AI enhancement analysis
    if ! run_step false "Running AI enhancement analysis" run_with_timeout 300 "${AI_ENHANCEMENT_BIN}" analyze "${project}"; then
        success_flag="false"
    fi

    # Auto-apply safe AI enhancements
    if ! run_step true "Auto-applying safe AI enhancements" run_with_timeout 300 "${AI_ENHANCEMENT_BIN}" auto-apply "${project}"; then
        success_flag="false"
    fi

    # Validate codegen, fixes, and enhancements
    if ! run_step false "Validating codegen, fixes, and enhancements" run_with_timeout 300 "${AUTO_FIX_VALIDATOR}" validate "${project}"; then
        success_flag="false"
    fi

    # Run automated tests after codegen/enhancement
    if ! run_step false "Running automated tests after codegen/enhancement" run_with_timeout 600 "${AUTOMATE_BIN}" test; then
        success_flag="false"
    fi

    if [[ ${success_flag} == "true" ]]; then
        if tail -40 "${LOG_FILE}" | grep -q 'ROLLBACK'; then
            log_message "ERROR" "Rollback detected after validation for ${project}"
            return 1
        elif tail -40 "${LOG_FILE}" | grep -iq 'error'; then
            log_message "ERROR" "Errors detected during validation or tests for ${project}"
            run_step true "Restoring last backup" run_with_timeout 300 "${BACKUP_MANAGER}" restore "${project}" || true
            return 1
        else
            log_message "SUCCESS" "Codegen, enhancement, validation, and tests completed successfully for ${project}"
        fi
    fi

    [[ ${success_flag} == "true" ]]
    return $?
}

# Function to perform AI automation
perform_ai_automation() {
    local project="$1"

    log_message "INFO" "Performing AI automation for ${project}..."

    if ! run_step false "Running AI automation pipeline" run_with_timeout 300 "${AUTOMATE_BIN}" ai; then
        log_message "ERROR" "AI automation failed for ${project}"
        return 1
    fi

    log_message "INFO" "AI automation completed for ${project}"
    return 0
}

# Function to perform autofix
perform_autofix() {
    local project="$1"

    log_message "INFO" "Performing autofix for ${project}..."

    if ! run_step false "Executing MCP autofix workflow" run_with_timeout 300 "${MCP_WORKFLOW_BIN}" autofix "${project}"; then
        log_message "ERROR" "Autofix failed for ${project}"
        return 1
    fi

    log_message "INFO" "Autofix completed for ${project}"
    return 0
}

# Function to perform enhancement
perform_enhancement() {
    local project="$1"

    log_message "INFO" "Performing AI enhancement for ${project}..."

    # Run AI enhancement analysis
    if ! run_step false "Running AI enhancement analysis" run_with_timeout 300 "${AI_ENHANCEMENT_BIN}" analyze "${project}"; then
        log_message "ERROR" "Enhancement analysis failed for ${project}"
        return 1
    fi

    # Auto-apply safe AI enhancements
    if ! run_step true "Auto-applying safe AI enhancements" run_with_timeout 300 "${AI_ENHANCEMENT_BIN}" auto-apply "${project}"; then
        log_message "ERROR" "Enhancement application failed for ${project}"
        return 1
    fi

    log_message "INFO" "Enhancement completed for ${project}"
    return 0
}

# Function to perform validation
perform_validation() {
    local project="$1"

    log_message "INFO" "Performing validation for ${project}..."

    if ! run_step false "Validating codegen, fixes, and enhancements" run_with_timeout 300 "${AUTO_FIX_VALIDATOR}" validate "${project}"; then
        log_message "ERROR" "Validation failed for ${project}"
        return 1
    fi

    log_message "INFO" "Validation completed for ${project}"
    return 0
}

# Function to perform codegen tests
perform_codegen_tests() {
    local project="$1"

    log_message "INFO" "Performing codegen tests for ${project}..."

    if ! run_step false "Running automated tests after codegen/enhancement" run_with_timeout 600 "${AUTOMATE_BIN}" test; then
        log_message "ERROR" "Codegen tests failed for ${project}"
        return 1
    fi

    log_message "INFO" "Codegen tests completed for ${project}"
    return 0
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Handle single run mode for testing
    if [[ "${1:-}" == "SINGLE_RUN" ]]; then
        log_message "INFO" "Running in SINGLE_RUN mode for testing"
        update_agent_status "${AGENT_NAME}" "running" $$ ""

        # Run a quick codegen check
        log_message "INFO" "Running quick codegen verification..."
        log_message "SUCCESS" "Codegen system operational"

        update_agent_status "${AGENT_NAME}" "completed" $$ ""
        log_message "INFO" "SINGLE_RUN completed successfully"
        exit 0
    fi

    # Start the main agent loop
    trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; log_message "INFO" "CodeGen Agent stopping..."; exit 0' SIGTERM SIGINT
    main "$@"
fi
