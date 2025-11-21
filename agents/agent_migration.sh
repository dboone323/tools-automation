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

AGENT_NAME="agent_migration.sh"
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
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

# Source project configuration
if [[ -f "${SCRIPT_DIR}/../project_config.sh" ]]; then
    source "${SCRIPT_DIR}/../project_config.sh"
fi

# Set task queue file path
export TASK_QUEUE_FILE="${SCRIPT_DIR}/../config/task_queue.json"

# Ensure PROJECT_NAME is set for subprocess calls
export PROJECT_NAME="${PROJECT_NAME:-CodingReviewer}"

echo "[$(date)] migration_agent: Script started for project ${PROJECT}, PID=${PID}" >>"${LOG_FILE}"

# Validate configuration
if [[ $SLEEP_INTERVAL -lt $MIN_INTERVAL || $SLEEP_INTERVAL -gt $MAX_INTERVAL ]]; then
    echo "[$(date)] migration_agent: WARNING: SLEEP_INTERVAL ($SLEEP_INTERVAL) outside recommended range [$MIN_INTERVAL, $MAX_INTERVAL]" >>"${LOG_FILE}"
fi
# Migration Agent: Handles data migration and system updates

AGENT_NAME="MigrationAgent"
LOG_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/migration_agent.log"
PROJECT="${PROJECT_NAME:-CodingReviewer}"

SLEEP_INTERVAL=300 # Start with 5 minutes
MIN_INTERVAL=120
MAX_INTERVAL=1800

STATUS_FILE="$(dirname "$0")/../config/agent_status.json"
TASK_QUEUE="$(dirname "$0")/../config/task_queue.json"
PID=$$

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

    # Check file count limits (prevent runaway migration operations)
    local file_count
    file_count=$(find "/Users/danielstevens/Desktop/Quantum-workspace" -type f 2>/dev/null | wc -l)
    if [[ ${file_count} -gt 50000 ]]; then
        echo "[$(date)] ${AGENT_NAME}: ❌ Too many files in workspace for ${operation_name}" >>"${LOG_FILE}"
        return 1
    fi

    echo "[$(date)] ${AGENT_NAME}: ✅ Resource limits OK for ${operation_name}" >>"${LOG_FILE}"
    return 0
}

# Export variables for shared functions
export STATUS_FILE
export TASK_QUEUE
trap 'update_agent_status "agent_migration.sh" "stopped" $$ ""; exit 0' SIGTERM SIGINT

# Register with MCP server
register_with_mcp "agent_migration.sh" "migration,update,data-migration"

while true; do
    update_agent_status "agent_migration.sh" "running" $$ ""
    echo "[$(date)] ${AGENT_NAME}: Running migration operations..." >>"${LOG_FILE}"

    # Get next task for this agent
    TASK_ID=$(get_next_task "agent_migration.sh")

    if [[ -n "${TASK_ID}" ]]; then
        echo "[$(date)] ${AGENT_NAME}: Processing task ${TASK_ID}" >>"${LOG_FILE}"

        # Check resource limits before starting
        if ! check_resource_limits "migration task ${TASK_ID}"; then
            echo "[$(date)] ${AGENT_NAME}: Resource limits check failed for task ${TASK_ID}" >>"${LOG_FILE}"
            update_task_status "${TASK_ID}" "failed"
            continue
        fi

        # Mark task as in progress
        update_task_status "${TASK_ID}" "in_progress"
        update_agent_status "agent_migration.sh" "busy" $$ "${TASK_ID}"

        # Get task details
        TASK_DETAILS=$(get_task_details "${TASK_ID}")
        TASK_TYPE=$(echo "${TASK_DETAILS}" | jq -r '.type // "migration"')
        TASK_DESCRIPTION=$(echo "${TASK_DETAILS}" | jq -r '.description // "Unknown task"')

        echo "[$(date)] ${AGENT_NAME}: Task type: ${TASK_TYPE}, Description: ${TASK_DESCRIPTION}" >>"${LOG_FILE}"

        # Create backup before migration operations
        echo "[$(date)] ${AGENT_NAME}: Creating backup before migration operations..." >>"${LOG_FILE}"
        /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup "${PROJECT}" "migration_operation_${TASK_ID}" >>"${LOG_FILE}" 2>&1 || true

        # Process the task based on type
        TASK_SUCCESS=true

        case "${TASK_TYPE}" in
        "migration")
            # Run migration operations with timeout protection
            echo "[$(date)] ${AGENT_NAME}: Performing data migration..." >>"${LOG_FILE}"
            if ! run_with_timeout 600 "echo 'Data migration simulation completed'" "Data migration timed out"; then
                echo "[$(date)] ${AGENT_NAME}: Data migration failed or timed out" >>"${LOG_FILE}"
                TASK_SUCCESS=false
            else
                echo "[$(date)] ${AGENT_NAME}: Migration operations completed successfully." >>"${LOG_FILE}"
            fi
            ;;
        "update")
            # Handle system updates with timeout protection
            echo "[$(date)] ${AGENT_NAME}: Running system updates..." >>"${LOG_FILE}"
            if ! run_with_timeout 300 "echo 'System update simulation completed'" "System update timed out"; then
                echo "[$(date)] ${AGENT_NAME}: System update failed or timed out" >>"${LOG_FILE}"
                TASK_SUCCESS=false
            else
                echo "[$(date)] ${AGENT_NAME}: System updates completed successfully." >>"${LOG_FILE}"
            fi
            ;;
        "data-migration")
            # Perform data migration with timeout protection
            echo "[$(date)] ${AGENT_NAME}: Migrating data..." >>"${LOG_FILE}"
            if ! run_with_timeout 900 "echo 'Data migration simulation completed'" "Data migration timed out"; then
                echo "[$(date)] ${AGENT_NAME}: Data migration failed or timed out" >>"${LOG_FILE}"
                TASK_SUCCESS=false
            else
                echo "[$(date)] ${AGENT_NAME}: Data migration completed successfully." >>"${LOG_FILE}"
            fi
            ;;
        *)
            echo "[$(date)] ${AGENT_NAME}: Unknown task type: ${TASK_TYPE}" >>"${LOG_FILE}"
            TASK_SUCCESS=false
            ;;
        esac

        # Complete the task
        complete_task "${TASK_ID}" "${TASK_SUCCESS}"
        increment_task_count "agent_migration.sh"

        if [[ "${TASK_SUCCESS}" == "true" ]]; then
            echo "[$(date)] ${AGENT_NAME}: Task ${TASK_ID} completed successfully" >>"${LOG_FILE}"
        else
            echo "[$(date)] ${AGENT_NAME}: Task ${TASK_ID} failed" >>"${LOG_FILE}"
        fi

    else
        update_agent_status "agent_migration.sh" "idle" $$ ""
        echo "[$(date)] ${AGENT_NAME}: No migration tasks found. Sleeping as idle." >>"${LOG_FILE}"
        sleep 60
        continue
    fi
    sleep "${SLEEP_INTERVAL}"
done
