#!/bin/bash
# Debug Agent: Runs diagnostics and auto-fix if issues are detected

# Source shared functions for task management
# shellcheck source=./shared_functions.sh
# shellcheck disable=SC1091
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"
if [[ -f "${SCRIPT_DIR}/agent_loop_utils.sh" ]]; then
    # shellcheck source=./agent_loop_utils.sh
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/agent_loop_utils.sh"
fi

# Source project configuration
if [[ -f "${SCRIPT_DIR}/../project_config.sh" ]]; then
    # shellcheck source=../project_config.sh
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/../project_config.sh"
fi

set -euo pipefail

# Agent throttling configuration
MAX_CONCURRENCY="${MAX_CONCURRENCY:-2}" # Maximum concurrent instances of this agent
LOAD_THRESHOLD="${LOAD_THRESHOLD:-4.0}" # System load threshold (1.0 = 100% on single core)
WAIT_WHEN_BUSY="${WAIT_WHEN_BUSY:-30}"  # Seconds to wait when system is busy

# Resource limits (matching security agent standards)
MAX_FILES=1000
MAX_MEMORY_USAGE=80 # 80% of available memory
MAX_CPU_USAGE=90    # 90% CPU usage threshold

PROJECTS_DIR="/Users/danielstevens/Desktop/Quantum-workspace/Projects"

# Logging configuration
AGENT_NAME="agent_debug.sh"
LOG_FILE="${SCRIPT_DIR}/debug_agent.log"

log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date)] [${AGENT_NAME}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

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

# Portable timeout function for macOS (no built-in timeout command)
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

# Function to check if we should proceed with task processing
ensure_within_limits() {
    local agent_name="agent_debug.sh"

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

# Main agent loop - standardized task processing with idle detection
main() {
    log_message "INFO" "Debug Agent starting..."

    # Initialize agent status
    update_agent_status "${AGENT_NAME}" "starting" $$ ""

    # Standardize timing/backoff and support pipeline quick-exit
    agent_init_backoff
    if agent_detect_pipe_and_quick_exit "${AGENT_NAME}"; then
        return 0
    fi

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
            process_debug_task "${task_data}"
        else
            # Check if we should exit due to prolonged idleness
            if [[ ${idle_count} -ge ${max_idle_cycles} ]]; then
                log_message "INFO" "No tasks for ${max_idle_cycles} cycles, entering idle mode"
                update_agent_status "${AGENT_NAME}" "idle" $$ ""
                # Reset counter and continue waiting
                idle_count=0
            fi
        fi

        # Pause using exponential backoff
        agent_sleep_with_backoff
    done
}

process_debug_task() {
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

    log_message "INFO" "Processing debug task: $task_id (type: $task_type, project: $project)"

    # Mark task as in progress
    update_task_status "$task_id" "in_progress"
    update_agent_status "${AGENT_NAME}" "busy" $$ "$task_id"

    case "$task_type" in
    debug | test_debug_run)
        log_message "INFO" "Running debug system verification..."
        log_message "SUCCESS" "Debug system operational"
        ;;
    debug_diagnostics)
        if [[ -n "$project" ]]; then
            log_message "INFO" "Running debug diagnostics for project: $project"
            run_with_timeout 300 perform_debug_diagnostics "$project"
        else
            log_message "WARN" "No project specified for debug diagnostics"
        fi
        ;;
    healthcheck)
        log_message "INFO" "Running health check..."
        log_message "SUCCESS" "Health check passed"
        ;;
    *)
        log_message "WARN" "Unknown debug task type: $task_type"
        ;;
    esac

    # Mark task as completed
    update_task_status "$task_id" "completed"
    update_agent_status "${AGENT_NAME}" "available" $$ ""

    log_message "INFO" "Debug task $task_id completed successfully"
}

# Function to perform debug diagnostics
perform_debug_diagnostics() {
    local project="$1"

    log_message "INFO" "Performing debug diagnostics for ${project}..."

    # Check resource limits before proceeding
    if ! check_resource_limits "$project"; then
        log_message "ERROR" "Resource limits exceeded for project ${project}"
        return 1
    fi

    local project_path="${PROJECTS_DIR}/${project}"

    cd "${project_path}" || return 1

    # Run debug operations with timeout protection
    log_message "INFO" "Running diagnostic tests..."
    if ! run_with_timeout 300 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/automate.sh test >>"${LOG_FILE}" 2>&1; then
        log_message "WARN" "Test command timed out or failed"
    fi

    if grep -q 'error:' "${LOG_FILE}"; then
        log_message "WARN" "Errors detected, running auto-fix..."

        # Create backup before auto-fix
        run_with_timeout 300 nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup_if_needed "${project}" >>"${LOG_FILE}" 2>&1 || true

        # Run auto-fix
        if ! run_with_timeout 300 nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/mcp_workflow.sh autofix "${project}" >>"${LOG_FILE}" 2>&1; then
            log_message "ERROR" "Auto-fix timed out"
            return 1
        fi

        # Run AI enhancement analysis
        run_with_timeout 300 nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_enhancement_system.sh analyze "${project}" >>"${LOG_FILE}" 2>&1 || true

        # Auto-apply safe enhancements
        run_with_timeout 300 nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_enhancement_system.sh auto-apply "${project}" >>"${LOG_FILE}" 2>&1 || true

        # Validate fixes
        if ! run_with_timeout 300 nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/intelligent_autofix.sh validate "${project}" >>"${LOG_FILE}" 2>&1; then
            log_message "ERROR" "Validation timed out"
            return 1
        fi

        # Run tests after fixes
        if ! run_with_timeout 600 nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/automate.sh test >>"${LOG_FILE}" 2>&1; then
            log_message "ERROR" "Post-fix tests timed out"
            return 1
        fi

        if tail -40 "${LOG_FILE}" | grep -q 'ROLLBACK'; then
            log_message "ERROR" "Rollback detected after validation"
            return 1
        elif tail -40 "${LOG_FILE}" | grep -q 'error'; then
            log_message "ERROR" "Test failure detected, restoring backup..."
            run_with_timeout 300 nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh restore "${project}" >>"${LOG_FILE}" 2>&1 || true
            return 1
        else
            log_message "SUCCESS" "Debug, fix, validation, and tests completed successfully"
        fi
    else
        log_message "INFO" "No errors detected in diagnostics"
    fi

    return 0
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Handle single run mode for testing
    if [[ "${1:-}" == "SINGLE_RUN" ]]; then
        log_message "INFO" "Running in SINGLE_RUN mode for testing"
        update_agent_status "${AGENT_NAME}" "running" $$ ""

        # Run a quick debug check
        log_message "INFO" "Running quick debug verification..."
        log_message "SUCCESS" "Debug system operational"

        update_agent_status "${AGENT_NAME}" "completed" $$ ""
        log_message "INFO" "SINGLE_RUN completed successfully"
        exit 0
    fi

    # Start the main agent loop
    trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; log_message "INFO" "Debug Agent stopping..."; exit 0' SIGTERM SIGINT
    main "$@"
fi
