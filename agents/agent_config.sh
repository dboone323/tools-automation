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
WORKSPACE_ROOT="${WORKSPACE_ROOT:-$(git rev-parse --show-toplevel 2>/dev/null)}"
  # shellcheck disable=SC1091
  source "$DIR/agent_helpers.sh"
fi

set -euo pipefail

AGENT_NAME="agent_config.sh"
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
# Global Agent Configuration
# This file contains centralized configuration for all agents
# Source this file in agents to get consistent throttling settings

# Agent Throttling Configuration
# These can be overridden by environment variables
export MAX_CONCURRENCY="${MAX_CONCURRENCY:-2}" # Maximum concurrent instances per agent
export LOAD_THRESHOLD="${LOAD_THRESHOLD:-8.0}" # System load threshold (1.0 = 100% on single core)
export WAIT_WHEN_BUSY="${WAIT_WHEN_BUSY:-30}"  # Initial seconds to wait when system is busy

# Centralized TODO Processing Configuration
export GLOBAL_AGENT_CAP="${GLOBAL_AGENT_CAP:-10}"           # Maximum total agents that can be assigned tasks
export TODO_MONITOR_INTERVAL="${TODO_MONITOR_INTERVAL:-60}" # TODO monitor check interval (seconds)
export TODO_MIN_IDLE_TIME="${TODO_MIN_IDLE_TIME:-300}"      # Agents must be idle for this many seconds before triggering TODOs

# Agent-Specific Overrides (uncomment and modify as needed)
# export MAX_CONCURRENCY_agent_debug=1        # Debug agent: more conservative
# export MAX_CONCURRENCY_agent_build=3        # Build agent: can handle more concurrency
# export MAX_CONCURRENCY_agent_codegen=2      # Codegen agent: default
# export LOAD_THRESHOLD_high_priority=3.0     # Lower threshold for critical agents
# export LOAD_THRESHOLD_low_priority=5.0      # Higher threshold for background agents

# Configuration Agent Setup
AGENT_NAME="ConfigAgent"
LOG_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/config_agent.log"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
export STATUS_FILE="${SCRIPT_DIR}/../config/agent_status.json"
export TASK_QUEUE="${SCRIPT_DIR}/../config/task_queue.json"
export PID=$$

# Source shared functions for file locking and monitoring
if [[ -f "${SCRIPT_DIR}/shared_functions.sh" ]]; then
    source "${SCRIPT_DIR}/shared_functions.sh"
fi

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

# Resource limits checking function
check_resource_limits() {
    local operation_name="$1"

    echo "[$(date)] ${AGENT_NAME}: Checking resource limits for ${operation_name}..." >>"${LOG_FILE}"

    # Check available disk space (require at least 1GB)
    local available_space
    available_space=$(df -k "/Users/danielstevens/Desktop/Quantum-workspace" | tail -1 | awk '{print $4}')
    if [[ ${available_space} -lt 1048576 ]]; then # 1GB in KB
        echo "[$(date)] ${AGENT_NAME}: ❌ Insufficient disk space for ${operation_name}" >>"${LOG_FILE}"
        return 1
    fi

    # Check memory usage (require less than 90% usage)
    local mem_usage
    mem_usage=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
    if [[ ${mem_usage} -lt 100000 ]]; then # Rough check for memory pressure
        echo "[$(date)] ${AGENT_NAME}: ❌ High memory usage detected for ${operation_name}" >>"${LOG_FILE}"
        return 1
    fi

    # Check file count limits (prevent runaway config operations)
    local file_count
    file_count=$(find "${WORKSPACE_ROOT}" -type f 2>/dev/null | wc -l)
    if [[ ${file_count} -gt 50000 ]]; then
        echo "[$(date)] ${AGENT_NAME}: ❌ Too many files in workspace for ${operation_name}" >>"${LOG_FILE}"
        return 1
    fi

    echo "[$(date)] ${AGENT_NAME}: ✅ Resource limits OK for ${operation_name}" >>"${LOG_FILE}"
    return 0
}

# Function to get agent-specific configuration
get_agent_config() {
    local agent_name="$1"
    local config_key="$2"
    local default_value="$3"

    # Check for agent-specific override
    local agent_specific_var="${config_key}_${agent_name}"
    local value="${!agent_specific_var:-$default_value}"

    echo "$value"
}

# Logging configuration
export AGENT_LOG_LEVEL="${AGENT_LOG_LEVEL:-INFO}"           # DEBUG, INFO, WARN, ERROR
export AGENT_LOG_MAX_SIZE="${AGENT_LOG_MAX_SIZE:-10485760}" # 10MB max log size
export AGENT_LOG_RETENTION="${AGENT_LOG_RETENTION:-7}"      # Days to keep logs

# Performance monitoring
export AGENT_PERF_MONITOR="${AGENT_PERF_MONITOR:-true}"                  # Enable performance monitoring
export AGENT_HEALTH_CHECK_INTERVAL="${AGENT_HEALTH_CHECK_INTERVAL:-300}" # Health check every 5 minutes

# Backup and recovery
export AGENT_AUTO_BACKUP="${AGENT_AUTO_BACKUP:-true}"          # Enable automatic backups
export AGENT_BACKUP_INTERVAL="${AGENT_BACKUP_INTERVAL:-86400}" # Daily backups
export AGENT_BACKUP_RETENTION="${AGENT_BACKUP_RETENTION:-30}"  # Keep backups for 30 days

# Resource limits
export AGENT_MAX_MEMORY="${AGENT_MAX_MEMORY:-512}" # MB per agent process
export AGENT_MAX_CPU="${AGENT_MAX_CPU:-50}"        # CPU percentage per agent
export AGENT_TIMEOUT="${AGENT_TIMEOUT:-3600}"      # Max runtime per task (seconds)

# Network and API configuration
export AGENT_API_TIMEOUT="${AGENT_API_TIMEOUT:-30}"      # API call timeout (seconds)
export AGENT_RETRY_ATTEMPTS="${AGENT_RETRY_ATTEMPTS:-3}" # Number of retry attempts
export AGENT_RETRY_DELAY="${AGENT_RETRY_DELAY:-5}"       # Delay between retries (seconds)

# Development and testing
export AGENT_SINGLE_RUN="${SINGLE_RUN:-false}" # Exit after one cycle (for testing)
export AGENT_DRY_RUN="${DRY_RUN:-false}"       # Don't make actual changes (for testing)
export AGENT_VERBOSE="${VERBOSE:-false}"       # Enable verbose logging

# Emergency controls
export AGENT_EMERGENCY_STOP="${EMERGENCY_STOP:-false}"     # Stop all agents immediately
export AGENT_MAINTENANCE_MODE="${MAINTENANCE_MODE:-false}" # Put system in maintenance mode

# Configuration validation
validate_config() {
    local errors=0

    # Validate MAX_CONCURRENCY
    if ! [[ "$MAX_CONCURRENCY" =~ ^[0-9]+$ ]] || [[ "$MAX_CONCURRENCY" -lt 1 ]]; then
        echo "ERROR: MAX_CONCURRENCY must be a positive integer, got: $MAX_CONCURRENCY"
        ((errors++))
    fi

    # Validate LOAD_THRESHOLD
    if ! [[ "$LOAD_THRESHOLD" =~ ^[0-9]*\.?[0-9]+$ ]]; then
        echo "ERROR: LOAD_THRESHOLD must be a number, got: $LOAD_THRESHOLD"
        ((errors++))
    fi

    # Validate WAIT_WHEN_BUSY
    if ! [[ "$WAIT_WHEN_BUSY" =~ ^[0-9]+$ ]] || [[ "$WAIT_WHEN_BUSY" -lt 1 ]]; then
        echo "ERROR: WAIT_WHEN_BUSY must be a positive integer, got: $WAIT_WHEN_BUSY"
        ((errors++))
    fi

    # Validate GLOBAL_AGENT_CAP
    if ! [[ "$GLOBAL_AGENT_CAP" =~ ^[0-9]+$ ]] || [[ "$GLOBAL_AGENT_CAP" -lt 1 ]]; then
        echo "ERROR: GLOBAL_AGENT_CAP must be a positive integer, got: $GLOBAL_AGENT_CAP"
        ((errors++))
    fi

    if [[ $errors -gt 0 ]]; then
        echo "Configuration validation failed with $errors errors"
        return 1
    fi

    echo "Configuration validation passed"
    return 0
}

# Auto-validate on source
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Script is being run directly - start agent loop
    echo "[$(date)] ${AGENT_NAME}: Starting configuration agent..." >>"${LOG_FILE}"

    # Validate configuration first
    if ! validate_config; then
        echo "[$(date)] ${AGENT_NAME}: Configuration validation failed, exiting" >>"${LOG_FILE}"
        exit 1
    fi

    # Main agent loop
    while true; do
        update_agent_status "${AGENT_NAME}" "running" $$ ""

        # Check for configuration tasks
        TASK_ID=$(get_next_task "agent_config.sh" 2>/dev/null || echo "")

        if [[ -n "${TASK_ID}" ]]; then
            echo "[$(date)] ${AGENT_NAME}: Processing configuration task ${TASK_ID}" >>"${LOG_FILE}"

            # Check resource limits before starting
            if ! check_resource_limits "config task ${TASK_ID}"; then
                echo "[$(date)] ${AGENT_NAME}: Resource limits check failed for task ${TASK_ID}" >>"${LOG_FILE}"
                update_task_status "${TASK_ID}" "failed"
                continue
            fi

            # Mark task as in progress
            update_task_status "${TASK_ID}" "in_progress"
            update_agent_status "${AGENT_NAME}" "busy" $$ "${TASK_ID}"

            # Create backup before configuration changes
            echo "[$(date)] ${AGENT_NAME}: Creating backup before configuration operations..." >>"${LOG_FILE}"
            /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup "global" "config_operation_${TASK_ID}" >>"${LOG_FILE}" 2>&1 || true

            # Process configuration task with timeout protection
            if run_with_timeout 300 "
                echo '[$(date)] ${AGENT_NAME}: Validating and updating agent configurations...' >>'${LOG_FILE}'
                # Validate all agent configurations
                if validate_config >>'${LOG_FILE}' 2>&1; then
                    echo '[$(date)] ${AGENT_NAME}: Configuration validation successful' >>'${LOG_FILE}'
                    exit 0
                else
                    echo '[$(date)] ${AGENT_NAME}: Configuration validation failed' >>'${LOG_FILE}'
                    exit 1
                fi
            " "Configuration task timed out"; then
                echo "[$(date)] ${AGENT_NAME}: Configuration task ${TASK_ID} completed successfully" >>"${LOG_FILE}"
                update_task_status "${TASK_ID}" "completed"
    increment_task_count "${AGENT_NAME}"
            else
                echo "[$(date)] ${AGENT_NAME}: Configuration task ${TASK_ID} failed or timed out" >>"${LOG_FILE}"
                update_task_status "${TASK_ID}" "failed"
            fi

            update_agent_status "${AGENT_NAME}" "idle" $$ ""
        else
            update_agent_status "${AGENT_NAME}" "idle" $$ ""
            echo "[$(date)] ${AGENT_NAME}: No configuration tasks found. Sleeping as idle." >>"${LOG_FILE}"
            sleep 300 # Sleep for 5 minutes when idle
        fi

        sleep 60 # Brief pause between checks
    done
else
    # Script is being sourced
    if ! validate_config >/dev/null 2>&1; then
        echo "WARNING: Agent configuration validation failed. Using defaults."
    fi
fi
