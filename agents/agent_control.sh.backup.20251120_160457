        #!/usr/bin/env bash
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

AGENT_NAME="agent_control.sh"
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
# Agent Control: Unified agent management interface
# Commands: start, stop, restart, status, list
# Author: Quantum Workspace AI Agent System
# Created: 2025-10-06 (Phase 5)

# Source shared functions for task management
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Core agents (Tier 1 & 2)
CORE_AGENTS=(
    "agent_supervisor.sh"
    "agent_analytics.sh"
    "agent_validation.sh"
    "agent_integration.sh"
    "agent_notification.sh"
    "agent_optimization.sh"
    "agent_backup.sh"
    "agent_cleanup.sh"
    "agent_security.sh"
    "agent_test_quality.sh"
)

# Logging configuration
AGENT_NAME="ControlAgent"
LOG_FILE="${SCRIPT_DIR}/control_agent.log"
export STATUS_FILE="${SCRIPT_DIR}/../config/agent_status.json"
export TASK_QUEUE="${SCRIPT_DIR}/../config/task_queue.json"
export PID=$$

# Timeout protection function
run_with_timeout() {
    local timeout_seconds="$1"
    local command="$2"
    local timeout_msg="${3:-Operation timed out after ${timeout_seconds} seconds}"

    log_message "INFO" "Starting operation with ${timeout_seconds}s timeout..."

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
            log_message "WARN" "${timeout_msg}"
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

# Resource limits checking function
check_resource_limits() {
    local operation_name="$1"

    log_message "INFO" "Checking resource limits for ${operation_name}..."

    # Check available disk space (require at least 1GB)
    local available_space
    available_space=$(df -k "/Users/danielstevens/Desktop/Quantum-workspace" | tail -1 | awk '{print $4}')
    if [[ ${available_space} -lt 1048576 ]]; then # 1GB in KB
        log_message "ERROR" "Insufficient disk space for ${operation_name}"
        return 1
    fi

    # Check memory usage (require less than 90% usage)
    local mem_usage
    mem_usage=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
    if [[ ${mem_usage} -lt 100000 ]]; then # Rough check for memory pressure
        log_message "ERROR" "High memory usage detected for ${operation_name}"
        return 1
    fi

    # Check file count limits (prevent runaway control operations)
    local file_count
    file_count=$(find "/Users/danielstevens/Desktop/Quantum-workspace" -type f 2>/dev/null | wc -l)
    if [[ ${file_count} -gt 50000 ]]; then
        log_message "ERROR" "Too many files in workspace for ${operation_name}"
        return 1
    fi

    log_message "INFO" "Resource limits OK for ${operation_name}"
    return 0
}

process_control_task() {
    local task="$1"

    log_message "INFO" "Processing control task: $task"

    # Check resource limits before processing
    if ! check_resource_limits "control task ${task}"; then
        log_message "ERROR" "Resource limits check failed for control task ${task}"
        return 1
    fi

    # Create backup before control operations
    log_message "INFO" "Creating backup before control operations..."
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup "global" "control_operation_${task}" >>"${LOG_FILE}" 2>&1 || true

    case "$task" in
    test_control_run)
        log_message "INFO" "Running control system verification..."
        log_message "SUCCESS" "Control system operational"
        ;;
    start_all_agents)
        if ! run_with_timeout 300 "start_all" "Starting all agents timed out"; then
            log_message "ERROR" "Failed to start all agents within timeout"
            return 1
        fi
        ;;
    stop_all_agents)
        if ! run_with_timeout 120 "stop_all" "Stopping all agents timed out"; then
            log_message "ERROR" "Failed to stop all agents within timeout"
            return 1
        fi
        ;;
    restart_all_agents)
        log_message "INFO" "🔄 Restarting all agents..."
        if ! run_with_timeout 120 "stop_all" "Stopping agents for restart timed out"; then
            log_message "ERROR" "Failed to stop agents for restart"
            return 1
        fi
        sleep 2
        if ! run_with_timeout 300 "start_all" "Starting agents after restart timed out"; then
            log_message "ERROR" "Failed to start agents after restart"
            return 1
        fi
        ;;
    show_status)
        if ! run_with_timeout 60 "show_status" "Status check timed out"; then
            log_message "ERROR" "Failed to show status within timeout"
            return 1
        fi
        ;;
    list_agents)
        if ! run_with_timeout 30 "list_agents" "Agent listing timed out"; then
            log_message "ERROR" "Failed to list agents within timeout"
            return 1
        fi
        ;;
    start_*)
        local agent="${task#start_}"
        if ! run_with_timeout 60 "start_agent '${agent}'" "Starting agent ${agent} timed out"; then
            log_message "ERROR" "Failed to start agent ${agent} within timeout"
            return 1
        fi
        ;;
    stop_*)
        local agent="${task#stop_}"
        if ! run_with_timeout 60 "stop_agent '${agent}'" "Stopping agent ${agent} timed out"; then
            log_message "ERROR" "Failed to stop agent ${agent} within timeout"
            return 1
        fi
        ;;
    restart_*)
        local agent="${task#restart_}"
        if ! run_with_timeout 120 "restart_agent '${agent}'" "Restarting agent ${agent} timed out"; then
            log_message "ERROR" "Failed to restart agent ${agent} within timeout"
            return 1
        fi
        ;;
    *)
        log_message "WARN" "Unknown control task: $task"
        return 1
        ;;
    esac

    return 0
}

start_agent() {
    local agent="$1"
    local agent_path="${SCRIPT_DIR}/${agent}"

    if [[ ! -f ${agent_path} ]]; then
        log_message "ERROR" "Agent not found: ${agent}"
        return 1
    fi

    # Check if already running
    if pgrep -f "${agent}" &>/dev/null; then
        log_message "WARN" "${agent} is already running"
        return 0
    fi

    log_message "INFO" "Starting ${agent}..."
    "${agent_path}" daemon &>/dev/null &
    local pid=$!

    sleep 3

    if ps -p "${pid}" &>/dev/null; then
        log_message "SUCCESS" "${agent} started (PID: ${pid})"
        return 0
    else
        log_message "ERROR" "Failed to start ${agent}"
        return 1
    fi
}

stop_agent() {
    local agent="$1"

    log_message "INFO" "Stopping ${agent}..."

    pkill -f "${agent}" 2>/dev/null || {
        log_message "WARN" "${agent} not running"
        return 0
    }

    sleep 1

    if ! pgrep -f "${agent}" &>/dev/null; then
        log_message "SUCCESS" "${agent} stopped"
        return 0
    else
        log_message "ERROR" "Failed to stop ${agent}"
        return 1
    fi
}

restart_agent() {
    local agent="$1"

    log_message "INFO" "Restarting ${agent}..."
    stop_agent "${agent}"
    sleep 2
    start_agent "${agent}"
}

show_status() {
    log_message "INFO" "Agent Status Report"
    echo ""
    printf "%-35s %-10s %-10s\n" "AGENT" "STATUS" "PID"
    printf "%-35s %-10s %-10s\n" "-----" "------" "---"

    for agent in "${CORE_AGENTS[@]}"; do
        local pid
        pid=$(pgrep -f "${agent}" 2>/dev/null | head -1 || echo "N/A")

        if [[ ${pid} != "N/A" ]]; then
            printf "%-35s %-10s %-10s\n" "${agent}" "Running" "${pid}"
        else
            printf "%-35s %-10s %-10s\n" "${agent}" "Stopped" "-"
        fi
    done

    echo ""
    log_message "INFO" "Total processes: $(pgrep -f 'agent.*\.sh' | wc -l | tr -d ' ')"
}

list_agents() {
    log_message "INFO" "Available Agents"
    echo ""
    echo "Tier 1: Core Operations (Always Running)"
    echo "  - agent_supervisor.sh"
    echo "  - agent_analytics.sh"
    echo "  - agent_validation.sh"
    echo "  - agent_integration.sh"
    echo "  - agent_notification.sh"
    echo ""
    echo "Tier 2: Automation & Maintenance (Scheduled)"
    echo "  - agent_optimization.sh"
    echo "  - agent_backup.sh"
    echo "  - agent_cleanup.sh"
    echo "  - agent_security.sh"
    echo "  - agent_test_quality.sh"
    echo ""
    echo "Use: ./agent_control.sh start <agent>"
}

start_all() {
    log_message "INFO" "Starting all core agents..."

    local success=0
    local failed=0

    for agent in "${CORE_AGENTS[@]}"; do
        if start_agent "${agent}"; then
            ((success++))
        else
            ((failed++))
        fi
    done

    log_message "INFO" "Summary: ${success} started, ${failed} failed"
}

stop_all() {
    log_message "INFO" "Stopping all agents..."

    for agent in "${CORE_AGENTS[@]}"; do
        stop_agent "${agent}" || true
    done

    log_message "INFO" "All agents stopped"
}

# Main task processing loop
log_message "INFO" "[Control Agent starting...]"

if [[ "${SINGLE_RUN:-false}" == "true" ]]; then
    log_message "INFO" "[Running in SINGLE_RUN mode for testing]"
    update_agent_status "${AGENT_NAME}" "running" $$ ""
    if process_control_task "test_control_run"; then
        update_agent_status "${AGENT_NAME}" "completed" $$ ""
        log_message "INFO" "[Single run control complete]"
    else
        update_agent_status "${AGENT_NAME}" "failed" $$ ""
        log_message "ERROR" "[Single run control failed]"
    fi
    exit 0
fi

while true; do
    update_agent_status "${AGENT_NAME}" "running" $$ ""

    task=$(get_next_task "agent_control.sh" 2>/dev/null || echo "")
    if [[ -n "$task" ]]; then
        update_agent_status "${AGENT_NAME}" "busy" $$ "${task}"
        if process_control_task "$task"; then
            update_task_status "$task" "completed"
    increment_task_count "${AGENT_NAME}"
            log_message "INFO" "Control task ${task} completed successfully"
        else
            update_task_status "$task" "failed"
            log_message "ERROR" "Control task ${task} failed"
        fi
        update_agent_status "${AGENT_NAME}" "idle" $$ ""
    else
        update_agent_status "${AGENT_NAME}" "idle" $$ ""
    fi
    sleep 5
done
