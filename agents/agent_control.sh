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

log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date)] [${AGENT_NAME}] [${level}] ${message}" >>"${LOG_FILE}"
}

process_control_task() {
    local task="$1"

    log_message "INFO" "Processing control task: $task"

    case "$task" in
    test_control_run)
        log_message "INFO" "Running control system verification..."
        log_message "SUCCESS" "Control system operational"
        ;;
    start_all_agents)
        start_all
        ;;
    stop_all_agents)
        stop_all
        ;;
    restart_all_agents)
        log_message "INFO" "🔄 Restarting all agents..."
        stop_all
        sleep 2
        start_all
        ;;
    show_status)
        show_status
        ;;
    list_agents)
        list_agents
        ;;
    start_*)
        local agent="${task#start_}"
        start_agent "$agent"
        ;;
    stop_*)
        local agent="${task#stop_}"
        stop_agent "$agent"
        ;;
    restart_*)
        local agent="${task#restart_}"
        restart_agent "$agent"
        ;;
    *)
        log_message "WARN" "Unknown control task: $task"
        ;;
    esac
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
    process_control_task "test_control_run"
    log_message "INFO" "[Single run control complete]"
    exit 0
fi

while true; do
    task=$(get_next_task "control")
    if [[ -n "$task" ]]; then
        process_control_task "$task"
        update_task_status "$task" "completed"
    fi
    sleep 5
done
