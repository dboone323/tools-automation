#!/bin/bash

set -euo pipefail

# Agent Helper Functions - Phase 1 Enhanced Capabilities
# Source this file in your agents to enable enhanced features

AGENT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Agent configuration
AGENT_NAME="HelpersAgent"
# Use AGENT_LOG_DIR env or default to ./agents/logs
AGENT_LOG_DIR="${AGENT_LOG_DIR:-$(pwd)/agents/logs}"
mkdir -p "$AGENT_LOG_DIR"
HELPER_LOG_FILE="${AGENT_LOG_DIR}/helpers_agent.log"
LOG_FILE="${HELPER_LOG_FILE}"
export STATUS_FILE="${AGENT_LIB_DIR}/agent_status.json"
export TASK_QUEUE="${AGENT_LIB_DIR}/task_queue.json"
export PID=$$

# Source shared functions for task management
if [[ -f "${AGENT_LIB_DIR}/shared_functions.sh" ]]; then
    source "${AGENT_LIB_DIR}/shared_functions.sh"
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
    available_space=$(df -k "${WORKSPACE_ROOT:-$(pwd)}" | tail -1 | awk '{print $4}')
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

    # Check file count limits (prevent runaway helper operations)
    local file_count
    file_count=$(find "${WORKSPACE_ROOT:-$(pwd)}" -type f 2>/dev/null | wc -l)
    if [[ ${file_count} -gt 50000 ]]; then
        echo "[$(date)] ${AGENT_NAME}: ❌ Too many files in workspace for ${operation_name}" >>"${LOG_FILE}"
        return 1
    fi

    echo "[$(date)] ${AGENT_NAME}: ✅ Resource limits OK for ${operation_name}" >>"${LOG_FILE}"
    return 0
}

# Canonical health check used by the patcher/boilerplate
agent_health_check() {
    local status_ok=true
    local -a issues

    # Basic writable checks
    if [[ ! -w "${AGENT_LIB_DIR:-/tmp}" ]]; then
        issues+=("libdir_not_writable")
        status_ok=false
    fi

    # Ensure log file directory is writable
    local logdir
    logdir=$(dirname "${LOG_FILE:-/tmp/agent.log}")
    if [[ ! -d "$logdir" || ! -w "$logdir" ]]; then
        issues+=("logdir_unwritable")
        status_ok=false
    fi

    # Reuse resource limits check if available
    if ! check_resource_limits "health_check" >/dev/null 2>&1; then
        issues+=("resource_limits_fail")
        status_ok=false
    fi

    # Optional: check presence of required binaries
    if ! command -v jq >/dev/null 2>&1; then
        issues+=("missing_jq")
        status_ok=false
    fi

    if [[ "$status_ok" == true ]]; then
        printf '{"ok":true}\n'
        return 0
    else
        # join issues by comma
        local joined
        joined=$(
            IFS=","
            echo "${issues[*]}"
        )
        printf '{"ok":false,"issues":["%s"]}\n' "$joined"
        return 2
    fi
}

# Suggest fix for an error
agent_suggest_fix() {
    local error_pattern="$1"
    local context="${2:-{}}"

    python3 "$AGENT_LIB_DIR/fix_suggester.py" suggest "$error_pattern" "$context" 2>/dev/null
}

# Get recommended action using decision engine
agent_decide() {
    local error_pattern="$1"
    local context="${2:-{}}"

    python3 "$AGENT_LIB_DIR/decision_engine.py" evaluate "$error_pattern" "$context" 2>/dev/null
}

# Record fix attempt
agent_record_fix() {
    local error_pattern="$1"
    local action="$2"
    local success="$3"
    local duration="${4:-0}"

    python3 "$AGENT_LIB_DIR/decision_engine.py" record "$error_pattern" "$action" "$success" "$duration" 2>/dev/null
}

# Verify if action succeeded
agent_verify() {
    local action="$1"
    local before="$2"
    local after="$3"

    python3 "$AGENT_LIB_DIR/decision_engine.py" verify "$action" "$before" "$after" 2>/dev/null
}

# Get AI analysis of error (if MCP available)
agent_ai_analyze() {
    local error_pattern="$1"
    local context="${2:-}"

    if [ -x "$AGENT_LIB_DIR/mcp_client.sh" ]; then
        "$AGENT_LIB_DIR/mcp_client.sh" analyze-error "$error_pattern" "$context" 2>/dev/null
    else
        echo '{"error": "MCP client not available"}'
    fi
}

# Execute action with automatic decision making
agent_auto_fix() {
    local error_pattern="$1"
    local context="${2:-{}}"
    local force="${3:-false}"

    # Get recommendation with timeout protection
    local decision
    if ! run_with_timeout 30 "agent_decide '$error_pattern' '$context'" "Decision making timed out"; then
        echo "[$(date)] ${AGENT_NAME}: Decision making failed or timed out" >>"${LOG_FILE}"
        return 1
    fi
    decision=$(agent_decide "$error_pattern" "$context")

    local action
    local confidence
    local auto_execute
    action=$(echo "$decision" | jq -r '.recommended_action // "skip"')
    confidence=$(echo "$decision" | jq -r '.confidence // 0')
    auto_execute=$(echo "$decision" | jq -r '.auto_execute // false')

    echo "Recommended action: $action (confidence: $confidence)"

    # Check if we should auto-execute
    if [ "$force" = "true" ] || [ "$auto_execute" = "true" ]; then
        echo "Executing: $action"

        local start_time
        start_time=$(date +%s)

        local result
        local success

        # Execute action based on type with timeout protection
        case "$action" in
        rebuild)
            if run_with_timeout 300 "agent_action_rebuild" "Rebuild action timed out"; then
                success=0
                result="Rebuild completed"
            else
                success=1
                result="Rebuild timed out or failed"
            fi
            ;;
        clean_build)
            if run_with_timeout 300 "agent_action_clean_build" "Clean build action timed out"; then
                success=0
                result="Clean build completed"
            else
                success=1
                result="Clean build timed out or failed"
            fi
            ;;
        fix_lint)
            if run_with_timeout 180 "agent_action_fix_lint" "Lint fix action timed out"; then
                success=0
                result="Lint fix completed"
            else
                success=1
                result="Lint fix timed out or failed"
            fi
            ;;
        fix_format)
            if run_with_timeout 180 "agent_action_fix_format" "Format fix action timed out"; then
                success=0
                result="Format fix completed"
            else
                success=1
                result="Format fix timed out or failed"
            fi
            ;;
        *)
            echo "Unknown action: $action"
            success=1
            result="Action not implemented"
            ;;
        esac

        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))

        # Record the attempt
        if [ $success -eq 0 ]; then
            agent_record_fix "$error_pattern" "$action" "true" "$duration"
            echo "✅ Fix succeeded in ${duration}s"
        else
            agent_record_fix "$error_pattern" "$action" "false" "$duration"
            echo "❌ Fix failed after ${duration}s: $result"
        fi

        return $success
    else
        echo "⚠️  Confidence too low for auto-execution, manual intervention required"
        echo "Reasoning: $(echo "$decision" | jq -r '.reasoning // "unknown"')"
        return 2
    fi
}

# Action implementations (override these in specific agents)
agent_action_rebuild() {
    echo "Default rebuild action - override in specific agent"
    return 0
}

agent_action_clean_build() {
    echo "Default clean build action - override in specific agent"
    return 0
}

agent_action_fix_lint() {
    if command -v swiftlint &>/dev/null; then
        swiftlint --fix --quiet
        return $?
    else
        echo "SwiftLint not available"
        return 1
    fi
}

agent_action_fix_format() {
    if command -v swiftformat &>/dev/null; then
        swiftformat . --quiet
        return $?
    else
        echo "SwiftFormat not available"
        return 1
    fi
}

# Process helper task
process_helper_task() {
    local task_data="$1"

    # Extract task information
    local task_id
    task_id=$(echo "$task_data" | jq -r '.id // empty')
    local task_type
    task_type=$(echo "$task_data" | jq -r '.type // "suggest_fix"')
    local error_pattern
    error_pattern=$(echo "$task_data" | jq -r '.error_pattern // empty')
    local context
    context=$(echo "$task_data" | jq -r '.context // "{}"')

    if [[ -z "$task_id" ]]; then
        echo "[$(date)] ${AGENT_NAME}: Invalid task data: $task_data" >>"${LOG_FILE}"
        return 1
    fi

    echo "[$(date)] ${AGENT_NAME}: Processing helper task ${task_id} (type: ${task_type})" >>"${LOG_FILE}"

    # Check resource limits before starting
    if ! check_resource_limits "helper task ${task_id}"; then
        echo "[$(date)] ${AGENT_NAME}: Resource limits check failed for task ${task_id}" >>"${LOG_FILE}"
        return 1
    fi

    # Create backup before helper operations
    echo "[$(date)] ${AGENT_NAME}: Creating backup before helper operations..." >>"${LOG_FILE}"
    "${AGENT_LIB_DIR}/backup_manager.sh" backup "global" "helper_operation_${task_id}" >>"${LOG_FILE}" 2>&1 || true

    case "$task_type" in
    "suggest_fix")
        if [[ -n "$error_pattern" ]]; then
            if run_with_timeout 60 "agent_suggest_fix '$error_pattern' '$context'" "Fix suggestion timed out"; then
                echo "[$(date)] ${AGENT_NAME}: Fix suggestion completed for task ${task_id}" >>"${LOG_FILE}"
                return 0
            else
                echo "[$(date)] ${AGENT_NAME}: Fix suggestion failed for task ${task_id}" >>"${LOG_FILE}"
                return 1
            fi
        else
            echo "[$(date)] ${AGENT_NAME}: No error pattern provided for task ${task_id}" >>"${LOG_FILE}"
            return 1
        fi
        ;;
    "auto_fix")
        if [[ -n "$error_pattern" ]]; then
            if agent_auto_fix "$error_pattern" "$context" "false"; then
                echo "[$(date)] ${AGENT_NAME}: Auto fix completed for task ${task_id}" >>"${LOG_FILE}"
                return 0
            else
                echo "[$(date)] ${AGENT_NAME}: Auto fix failed for task ${task_id}" >>"${LOG_FILE}"
                return 1
            fi
        else
            echo "[$(date)] ${AGENT_NAME}: No error pattern provided for task ${task_id}" >>"${LOG_FILE}"
            return 1
        fi
        ;;
    "ai_analyze")
        if [[ -n "$error_pattern" ]]; then
            if run_with_timeout 120 "agent_ai_analyze '$error_pattern' '$context'" "AI analysis timed out"; then
                echo "[$(date)] ${AGENT_NAME}: AI analysis completed for task ${task_id}" >>"${LOG_FILE}"
                return 0
            else
                echo "[$(date)] ${AGENT_NAME}: AI analysis failed for task ${task_id}" >>"${LOG_FILE}"
                return 1
            fi
        else
            echo "[$(date)] ${AGENT_NAME}: No error pattern provided for task ${task_id}" >>"${LOG_FILE}"
            return 1
        fi
        ;;
    *)
        echo "[$(date)] ${AGENT_NAME}: Unknown helper task type: ${task_type}" >>"${LOG_FILE}"
        return 1
        ;;
    esac
}

# Main agent loop
main_agent_loop() {
    echo "[$(date)] ${AGENT_NAME}: Starting helpers agent..." >>"${LOG_FILE}"

    while true; do
        update_agent_status "${AGENT_NAME}" "running" $$ ""

        # Get next task for this agent
        local task_data
        task_data=$(get_next_task "agent_helpers.sh" 2>/dev/null || echo "")

        if [[ -n "$task_data" ]]; then
            update_agent_status "${AGENT_NAME}" "busy" $$ "$(echo "$task_data" | jq -r '.id')"
            if process_helper_task "$task_data"; then
                update_task_status "$(echo "$task_data" | jq -r '.id')" "completed"
                increment_task_count "${AGENT_NAME}"
                echo "[$(date)] ${AGENT_NAME}: Task completed successfully" >>"${LOG_FILE}"
            else
                update_task_status "$(echo "$task_data" | jq -r '.id')" "failed"
                echo "[$(date)] ${AGENT_NAME}: Task failed" >>"${LOG_FILE}"
            fi
            update_agent_status "${AGENT_NAME}" "idle" $$ ""
        else
            update_agent_status "${AGENT_NAME}" "idle" $$ ""
            echo "[$(date)] ${AGENT_NAME}: No helper tasks found. Sleeping as idle." >>"${LOG_FILE}"
            sleep 300 # Sleep for 5 minutes when idle
        fi

        sleep 60 # Brief pause between checks
    done
}

# Check if running as agent or library
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "${1:-}" == "agent" ]]; then
        # Run as continuous agent
        main_agent_loop
    else
        # Run as library - do nothing special
        echo "[$(date)] ${AGENT_NAME}: Loaded as helper library" >>"${LOG_FILE}"
    fi
fi
