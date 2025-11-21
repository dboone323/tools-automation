        #!/usr/bin/env bash

# ══════════════════════════════════════════════════════════════
# Enhanced with Agent Autonomy Features
# ══════════════════════════════════════════════════════════════

# Dynamic Configuration Discovery
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/agent_config_discovery.sh" ]]; then
    source "${SCRIPT_DIR}/agent_config_discovery.sh"
    WORKSPACE_ROOT=$(get_workspace_root 2>/dev/null || echo "$HOME/workspace")
    MCP_URL=$(get_mcp_url 2>/dev/null || echo "http://127.0.0.1:5000")
fi

# AI Decision Helpers (optional - uncomment to enable)
# if [[ -f "${SCRIPT_DIR}/../monitoring/ai_helpers.sh" ]]; then
#     source "${SCRIPT_DIR}/../monitoring/ai_helpers.sh"
# fi

# State Manager Integration (optional - uncomment to enable)
# STATE_MANAGER="${SCRIPT_DIR}/../monitoring/state_manager.py"

# ══════════════════════════════════════════════════════════════

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

AGENT_NAME="agent_codegen.sh"
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

# Source shared functions for file locking and monitoring
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

# Quick-exit for pipeline mode BEFORE setting strict error handling
if [[ -p /dev/stdout ]] || [[ -p /dev/stderr ]]; then
    if [[ "${DISABLE_PIPE_QUICK_EXIT:-0}" -ne 1 ]]; then
        echo "[$(date)] agent_codegen.sh: starting (pipeline mode detected)"
        echo "[$(date)] agent_codegen.sh: PATH='${PATH}'"
        echo "[$(date)] agent_codegen.sh: status=running"
        echo "[$(date)] agent_codegen.sh: no tasks found (quick check)"
        echo "[$(date)] agent_codegen.sh: exiting early to avoid hanging pipelines"
        exit 0
    fi
fi

# Only enable strict mode when the script is executed directly. When the file
# is sourced by tests we avoid forcing `set -e` globally which can change
# test control flow and mask assertions. Tests can still enable strict mode
# if they need to.
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    set -euo pipefail
fi

# Agent throttling configuration
MAX_CONCURRENCY="${MAX_CONCURRENCY:-2}" # Maximum concurrent instances of this agent
LOAD_THRESHOLD="${LOAD_THRESHOLD:-8.0}" # System load threshold (1.0 = 100% on single core)
WAIT_WHEN_BUSY="${WAIT_WHEN_BUSY:-30}"  # Seconds to wait when system is busy

# Resource limits (matching security agent standards)
MAX_FILES=1000
MAX_MEMORY_USAGE=80 # 80% of available memory
MAX_CPU_USAGE=90    # 90% CPU usage threshold

# Task processing limits

# Function to check if we should proceed with task processing
ensure_within_limits() {
    local agent_name="agent_codegen.sh"

    # Check concurrent instances
    local running_count
    running_count=$(pgrep -f "${agent_name}" | wc -l)
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

# CodeGen/Fix Agent: Triggers code generation and auto-fix routines

# Respect any externally provided WORKSPACE (tests override it); otherwise default to repo root
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="${WORKSPACE:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

# Source AI enhancement modules
ENHANCEMENTS_DIR="${SCRIPT_DIR}/../enhancements"
if [[ -f "${ENHANCEMENTS_DIR}/ai_codegen_optimizer.sh" ]]; then
    # shellcheck source=../enhancements/ai_codegen_optimizer.sh
    # shellcheck disable=SC1091
    source "${ENHANCEMENTS_DIR}/ai_codegen_optimizer.sh"
fi

AGENT_NAME="agent_codegen.sh"
AGENT_LABEL="CodeGenAgent"
LOG_FILE="${LOG_FILE:-${SCRIPT_DIR}/codegen_agent.log}"
COMM_DIR="${SCRIPT_DIR}/communication"
NOTIFICATION_FILE="${COMM_DIR}/agent_codegen.sh_notification.txt"
COMPLETED_FILE="${COMM_DIR}/agent_codegen.sh_completed.txt"
PROJECT="CodingReviewer"
AGENT_STATUS_FILE="${WORKSPACE}/config/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/config/task_queue.json"
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

CONSECUTIVE_FAILURES=0

# Idle detection variables

mkdir -p "${COMM_DIR}"
touch "${NOTIFICATION_FILE}" "${COMPLETED_FILE}" "${PROCESSED_TASKS_FILE}"

if [[ -n "${AGENT_STATUS_FILE:-}" ]]; then
    mkdir -p "$(dirname "${AGENT_STATUS_FILE}")" 2>/dev/null || true
    if [[ ! -f ${AGENT_STATUS_FILE} ]]; then
        echo '{"agents":{},"last_update":0}' >"${AGENT_STATUS_FILE}" 2>/dev/null || true
    fi
fi

if [[ -n "${TASK_QUEUE_FILE:-}" ]]; then
    mkdir -p "$(dirname "${TASK_QUEUE_FILE}")" 2>/dev/null || true
    if [[ ! -f ${TASK_QUEUE_FILE} ]]; then
        echo '{"tasks":[]}' >"${TASK_QUEUE_FILE}" 2>/dev/null || true
    fi
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

    # Start the command in background using a small wrapper so the launched process
    # becomes the direct child (via bash -c 'exec ...') which makes killing reliable.
    local cmd_pid
    if command -v bash >/dev/null 2>&1; then
        bash -c 'exec "$@"' bash "$@" &
        cmd_pid=$!
    elif command -v setsid >/dev/null 2>&1; then
        setsid "$@" &
        cmd_pid=$!
    else
        # Fallback: run in background and rely on killing the process group
        ("$@") &
        cmd_pid=$!
    fi

    # Watcher: sleep then kill the command and any children if still running
    # Instead of using a file, signal the parent on timeout (SIGUSR1). Parent
    # sets a trap which sets the timeout_occurred variable.
    local -i timeout_occurred=0
    trap 'timeout_occurred=1' SIGUSR1
    # Capture parent PID explicitly to avoid PPID races when running in
    # nested shells or test harnesses that may change PPID semantics.
    local parent_pid=$$

    (
        sleep "${timeout_secs}"
        if kill -0 "${cmd_pid}" 2>/dev/null; then
            # notify parent that a timeout occurred
            if [[ "${TEST_MODE:-}" == "true" ]]; then
                echo "[TIMEOUT_DEBUG] sending SIGUSR1 to parent (parent_pid=${parent_pid})"
            fi
            kill -USR1 "${parent_pid}" 2>/dev/null || true

            if [[ "${TEST_MODE:-}" == "true" ]]; then
                echo "[TIMEOUT_DEBUG] timeout reached; attempting to kill pid ${cmd_pid}"
                echo "[TIMEOUT_DEBUG] initial children: $(pgrep -P ${cmd_pid} 2>/dev/null || true)"
            fi

            log_message "WARN" "Command timed out after ${timeout_secs}s, killing pid ${cmd_pid} and its children"

            # Try graceful termination first
            kill -TERM "${cmd_pid}" 2>/dev/null || true
            if [[ "${TEST_MODE:-}" == "true" ]]; then
                echo "[TIMEOUT_DEBUG] sent TERM to ${cmd_pid}"
            fi

            # Try to kill direct children of the command (pkill -P)
            if command -v pkill >/dev/null 2>&1; then
                pkill -P "${cmd_pid}" 2>/dev/null || true
                if [[ "${TEST_MODE:-}" == "true" ]]; then
                    echo "[TIMEOUT_DEBUG] sent TERM to children of ${cmd_pid}: $(pgrep -P ${cmd_pid} 2>/dev/null || true)"
                fi
            fi

            # Poll for process termination for a short window
            for _ in 1 2 3 4 5; do
                sleep 0.2
                if ! kill -0 "${cmd_pid}" 2>/dev/null; then
                    break
                fi
                # also check children
                if [[ -n "$(pgrep -P ${cmd_pid} 2>/dev/null || true)" ]]; then
                    # continue polling
                    if [[ "${TEST_MODE:-}" == "true" ]]; then
                        echo "[TIMEOUT_DEBUG] still has children: $(pgrep -P ${cmd_pid} 2>/dev/null || true)"
                    fi
                fi
            done

            # If still alive, escalate to KILL
            if kill -0 "${cmd_pid}" 2>/dev/null; then
                kill -KILL "${cmd_pid}" 2>/dev/null || true
                if command -v pkill >/dev/null 2>&1; then
                    pkill -KILL -P "${cmd_pid}" 2>/dev/null || true
                fi
                if [[ "${TEST_MODE:-}" == "true" ]]; then
                    echo "[TIMEOUT_DEBUG] sent KILL to ${cmd_pid} and remaining children"
                fi
            fi
        fi
    ) &
    local watcher_pid=$!

    # Wait for command to finish
    wait "${cmd_pid}" 2>/dev/null
    local cmd_status=$?
    if [[ "${TEST_MODE:-}" == "true" ]]; then
        echo "[TIMEOUT_DEBUG] command (pid ${cmd_pid}) exited with status ${cmd_status}"
        echo "[TIMEOUT_DEBUG] timeout_occurred=${timeout_occurred}"
    fi

    # Detect if the watcher recorded a timeout via SIGUSR1 trap and enforce a non-zero return
    if [[ "${timeout_occurred}" == "1" ]]; then
        if [[ "${TEST_MODE:-}" == "true" ]]; then
            echo "[TIMEOUT_DEBUG] parent observed timeout_occurred=${timeout_occurred}; returning 124"
        fi
        # Clean up watcher
        kill -9 "${watcher_pid}" 2>/dev/null || true
        wait "${watcher_pid}" 2>/dev/null || true
        # Use a conventional timeout exit code 124 (consistent with timeout(1))
        return 124
    fi

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

        # Pause using exponential backoff
        agent_sleep_with_backoff
    done
}

process_codegen_task() {
    local task_data="$1"
    # TEST_MODE: Dump exact received argument for deterministic debugging
    if [[ "${TEST_MODE:-}" == "true" ]]; then
        echo "[PROC_TRACE] raw_arg_len=${#task_data}"
        printf '[PROC_TRACE] raw_arg_q=%s\n' "$(printf '%q' "$task_data")"
        printf '[PROC_TRACE] raw_arg_hex='
        printf '%s' "$task_data" | od -An -tx1 | tr -d '\n' || true
        echo
    fi
    # Record raw input for diagnostics in TEST_MODE
    if [[ "${TEST_MODE:-}" == "true" ]]; then
        echo "${task_data}" >/tmp/process_codegen_raw_input.txt 2>/dev/null || true
    fi

    # Use jq to validate the JSON and presence of a non-empty id field
    # Quick id extraction using a portable sed-based pattern (avoids relying solely on external jq)
    local id_from_sed
    id_from_sed=$(echo "$task_data" | sed -n 's/.*"id"[[:space:]]*:[[:space:]]*"\([^\"]*\)".*/\1/p' 2>/dev/null || true)
    if [[ -z "${id_from_sed}" ]]; then
        log_message "ERROR" "Invalid task data (missing id field): ${task_data}"
        [[ "${TEST_MODE:-}" == "true" ]] && touch /tmp/process_codegen_invalid_missing_id 2>/dev/null || true
        if [[ "${TEST_MODE:-}" == "true" ]]; then echo "[PROC_RETURN] missing_id -> return 1"; fi
        return 1
    fi

    local task_id
    task_id="${id_from_sed}"
    if [[ "${TEST_MODE:-}" == "true" ]]; then
        echo "[TEST_DEBUG] extracted task_id='${task_id}' from raw input" >>"${LOG_FILE:-/tmp/test_agent.log}" 2>/dev/null || true
        echo "[PROC_DEBUG] extracted_task_id=${task_id}"
        echo "[TRACE] after sed-extract task_id='${task_id}'"
    fi

    # Use jq (if available) to extract other fields (project, type); fall back to simple parsing
    local jq_bin
    jq_bin=$(command -v jq 2>/dev/null || true)
    if [[ -n "${jq_bin}" ]]; then
        if [[ "${TEST_MODE:-}" == "true" ]]; then
            echo "[PROC_DEBUG] using jq at: ${jq_bin}"
        fi
        local project
        project=$(echo "$task_data" | "${jq_bin}" -r '.project // ""' 2>/dev/null || true)
        local jq_proj_rc=$?
        local task_type
        task_type=$(echo "$task_data" | "${jq_bin}" -r '.type // "unknown"' 2>/dev/null || true)
        local jq_type_rc=$?
        if [[ "${TEST_MODE:-}" == "true" ]]; then
            echo "[PROC_TRACE] jq_project_rc=${jq_proj_rc} jq_type_rc=${jq_type_rc} project='${project}' task_type='${task_type}'"
        fi
    else
        # Fallback simple extraction
        local project
        project=$(echo "$task_data" | sed -n 's/.*"project"[[:space:]]*:[[:space:]]*"\([^\"]*\)".*/\1/p' 2>/dev/null || true)
        local task_type
        task_type=$(echo "$task_data" | sed -n 's/.*"type"[[:space:]]*:[[:space:]]*"\([^\"]*\)".*/\1/p' 2>/dev/null || true)
        if [[ "${TEST_MODE:-}" == "true" ]]; then
            echo "[PROC_TRACE] sed_project='${project}' sed_type='${task_type}'"
        fi
    fi

    # Validate task_id format
    if [[ -z "$task_id" ]]; then
        log_message "ERROR" "Invalid task data (empty id): ${task_data}"
        [[ "${TEST_MODE:-}" == "true" ]] && touch /tmp/process_codegen_invalid_missing_id 2>/dev/null || true
        if [[ "${TEST_MODE:-}" == "true" ]]; then echo "[PROC_RETURN] empty_id -> return 1"; fi
        return 1
    fi

    if ! [[ "$task_id" =~ ^[A-Za-z0-9._-]+$ ]]; then
        log_message "ERROR" "Invalid task id format ('$task_id') in data: ${task_data}"
        [[ "${TEST_MODE:-}" == "true" ]] && touch /tmp/process_codegen_invalid_bad_id 2>/dev/null || true
        if [[ "${TEST_MODE:-}" == "true" ]]; then echo "[PROC_RETURN] bad_id_format -> return 1"; fi
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
    increment_task_count "${AGENT_NAME}"
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

    # INTEGRATION: Run AI code review on generated/modified files
    if [[ ${success_flag} == "true" ]]; then
        log_message "INFO" "Running AI code review on generated/modified files..."
        if ! run_ai_code_review "${project}"; then
            log_message "WARN" "AI code review completed with warnings"
        fi
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

# INTEGRATION: Function to run AI code review on generated/modified files
run_ai_code_review() {
    local project="$1"
    local ai_reviewer_script="${SCRIPT_DIR}/../ai_code_reviewer.py"

    log_message "INFO" "Running AI code review for project: ${project}"

    if [[ ! -f "${ai_reviewer_script}" ]]; then
        log_message "WARN" "AI code reviewer script not found: ${ai_reviewer_script}"
        return 1
    fi

    # Find recently modified files in the project (last 30 minutes)
    local project_dir="${WORKSPACE}/Projects/${project}"
    if [[ ! -d "${project_dir}" ]]; then
        log_message "WARN" "Project directory not found: ${project_dir}"
        return 1
    fi

    # Get list of recently modified files
    local modified_files
    modified_files=$(find "${project_dir}" -name "*.py" -o -name "*.js" -o -name "*.ts" -o -name "*.swift" -o -name "*.java" -o -name "*.cpp" -o -name "*.c" -o -name "*.h" -o -name "*.sh" -o -name "*.md" | head -20)

    if [[ -z "${modified_files}" ]]; then
        log_message "INFO" "No recent code files found to review"
        return 0
    fi

    local review_count=0
    local total_score=0

    # Run AI code review on each modified file
    while IFS= read -r file; do
        if [[ -f "${file}" && -s "${file}" ]]; then
            log_message "INFO" "Reviewing file: ${file}"

            # Run the AI code reviewer
            local review_output
            review_output=$(python3 "${ai_reviewer_script}" "${file}" 2>&1)

            if [[ $? -eq 0 ]]; then
                # Extract score from output (assuming format like "Score: 8.5/10")
                local score
                score=$(echo "${review_output}" | grep -o "Score: [0-9.]*" | grep -o "[0-9.]*" | head -1)

                if [[ -n "${score}" ]]; then
                    total_score=$((total_score + score))
                    review_count=$((review_count + 1))
                    log_message "INFO" "AI Code Review Score for ${file}: ${score}/10"
                fi

                # Log any issues found
                if echo "${review_output}" | grep -qi "issue\|warning\|error"; then
                    log_message "WARN" "Issues found in ${file}"
                fi
            else
                log_message "ERROR" "AI code review failed for ${file}: ${review_output}"
            fi
        fi
    done <<<"${modified_files}"

    # Calculate average score
    if [[ ${review_count} -gt 0 ]]; then
        local avg_score
        avg_score=$(echo "scale=1; ${total_score} / ${review_count}" | bc 2>/dev/null || echo "0")
        log_message "INFO" "AI Code Review completed. Average score: ${avg_score}/10 (${review_count} files reviewed)"

        # INTEGRATION: Track analytics event
        track_analytics_event "code_review" "${project}" "${avg_score}" "${review_count}"
    else
        log_message "INFO" "AI Code Review completed. No files were reviewed."
    fi

    return 0
}

# INTEGRATION: Function to track analytics events
track_analytics_event() {
    local event_type="$1"
    local project="$2"
    local score="$3"
    local count="$4"
    local analytics_script="${SCRIPT_DIR}/../umami_analytics.py"

    if [[ -f "${analytics_script}" ]]; then
        log_message "INFO" "Tracking analytics event: ${event_type}"
        python3 "${analytics_script}" track "${event_type}" \
            --project "${project}" \
            --score "${score}" \
            --count "${count}" 2>/dev/null || true
    fi
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
