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

AGENT_NAME="agent_debug_enhanced.sh"
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

# Enhanced Agent Debug - With Phase 1 Capabilities
# Intelligent debugging with AI assistance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/agent_helpers.sh"

# Agent configuration
AGENT_NAME="DebugEnhancedAgent"
LOG_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/debug_enhanced_agent.log"
export STATUS_FILE="${SCRIPT_DIR}/agent_status.json"
export TASK_QUEUE="${SCRIPT_DIR}/task_queue.json"
export PID=$$

# Source shared functions for task management
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

    # Check file count limits (prevent runaway debug operations)
    local file_count
    file_count=$(find "/Users/danielstevens/Desktop/Quantum-workspace" -type f 2>/dev/null | wc -l)
    if [[ ${file_count} -gt 50000 ]]; then
        echo "[$(date)] ${AGENT_NAME}: ❌ Too many files in workspace for ${operation_name}" >>"${LOG_FILE}"
        return 1
    fi

    echo "[$(date)] ${AGENT_NAME}: ✅ Resource limits OK for ${operation_name}" >>"${LOG_FILE}"
    return 0
}

# Debug a specific error with AI help
debug_error() {
    local error_pattern="$1"
    local use_ai="${2:-true}"

    echo "[$(date)] ${AGENT_NAME}: Debugging: $error_pattern" >>"${LOG_FILE}"
    echo "Debugging: $error_pattern"
    echo ""

    # Get fix suggestion with timeout protection
    echo "📋 Fix Suggestion:"
    if ! run_with_timeout 60 "
        local suggestion
        suggestion=\$(agent_suggest_fix '$error_pattern')

        local action
        local confidence
        local reasoning
        action=\$(echo \"\$suggestion\" | jq -r '.primary_suggestion.action // \"unknown\"')
        confidence=\$(echo \"\$suggestion\" | jq -r '.confidence // 0')
        reasoning=\$(echo \"\$suggestion\" | jq -r '.reasoning // \"No reasoning available\"')

        echo \"  Action: \$action\"
        echo \"  Confidence: \$confidence\"
        echo \"  Reasoning: \$reasoning\"
        echo \"\"

        # Get AI analysis if requested and available
        if [ '$use_ai' = 'true' ]; then
            echo \"🤖 AI Analysis:\"
            local ai_result
            ai_result=\$(agent_ai_analyze '$error_pattern')

            if echo \"\$ai_result\" | jq -e '.error' > /dev/null 2>&1; then
                echo \"  (AI not available or failed)\"
            else
                echo \"\$ai_result\" | head -10
            fi
            echo \"\"
        fi

        # Show alternatives
        echo \"🔄 Alternative Actions:\"
        echo \"\$suggestion\" | jq -r '.alternatives[] | \"  - \(.action) (confidence: \(.confidence))\"'
    " "Error debugging timed out"; then
        echo "[$(date)] ${AGENT_NAME}: Error debugging failed or timed out" >>"${LOG_FILE}"
        return 1
    fi

    return 0
}

# Analyze log file for errors
analyze_log() {
    local log_file="$1"

    if [ ! -f "$log_file" ]; then
        echo "[$(date)] ${AGENT_NAME}: Log file not found: $log_file" >>"${LOG_FILE}"
        echo "Log file not found: $log_file"
        return 1
    fi

    echo "[$(date)] ${AGENT_NAME}: Analyzing log: $log_file" >>"${LOG_FILE}"
    echo "Analyzing log: $log_file"
    echo ""

    # Extract unique errors with timeout protection
    if ! run_with_timeout 120 "
        local errors
        errors=\$(grep -E '(error:|ERROR:|failed|Failed)' '$log_file' | sort -u | head -10)

        if [ -z \"\$errors\" ]; then
            echo 'No errors found in log'
            exit 0
        fi

        echo \"Found \$(echo \"\$errors\" | wc -l | tr -d ' ') unique errors\"
        echo \"\"

        # Analyze each error
        local count=1
        while IFS= read -r error_line; do
            echo \"[\$count] \$error_line\"
            # Note: Nested timeout calls can be complex, so we'll do basic analysis
            echo \"📋 Quick Analysis for: \$error_line\" | head -5
            echo \"---\"
            count=\$((count + 1))
        done <<< \"\$errors\"
    " "Log analysis timed out"; then
        echo "[$(date)] ${AGENT_NAME}: Log analysis failed or timed out" >>"${LOG_FILE}"
        return 1
    fi

    return 0
}

# Process debug task
process_debug_task() {
    local task_data="$1"

    # Extract task information
    local task_id
    task_id=$(echo "$task_data" | jq -r '.id // empty')
    local task_type
    task_type=$(echo "$task_data" | jq -r '.type // "debug_error"')
    local error_pattern
    error_pattern=$(echo "$task_data" | jq -r '.error_pattern // empty')
    local log_file
    log_file=$(echo "$task_data" | jq -r '.log_file // empty')

    if [[ -z "$task_id" ]]; then
        echo "[$(date)] ${AGENT_NAME}: Invalid task data: $task_data" >>"${LOG_FILE}"
        return 1
    fi

    echo "[$(date)] ${AGENT_NAME}: Processing debug task ${task_id} (type: ${task_type})" >>"${LOG_FILE}"

    # Check resource limits before starting
    if ! check_resource_limits "debug task ${task_id}"; then
        echo "[$(date)] ${AGENT_NAME}: Resource limits check failed for task ${task_id}" >>"${LOG_FILE}"
        return 1
    fi

    # Create backup before debug operations
    echo "[$(date)] ${AGENT_NAME}: Creating backup before debug operations..." >>"${LOG_FILE}"
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup "global" "debug_operation_${task_id}" >>"${LOG_FILE}" 2>&1 || true

    case "$task_type" in
    "debug_error")
        if [[ -n "$error_pattern" ]]; then
            if debug_error "$error_pattern" "true"; then
                echo "[$(date)] ${AGENT_NAME}: Error debugging completed for task ${task_id}" >>"${LOG_FILE}"
                return 0
            else
                echo "[$(date)] ${AGENT_NAME}: Error debugging failed for task ${task_id}" >>"${LOG_FILE}"
                return 1
            fi
        else
            echo "[$(date)] ${AGENT_NAME}: No error pattern provided for task ${task_id}" >>"${LOG_FILE}"
            return 1
        fi
        ;;
    "analyze_log")
        if [[ -n "$log_file" ]]; then
            if analyze_log "$log_file"; then
                echo "[$(date)] ${AGENT_NAME}: Log analysis completed for task ${task_id}" >>"${LOG_FILE}"
                return 0
            else
                echo "[$(date)] ${AGENT_NAME}: Log analysis failed for task ${task_id}" >>"${LOG_FILE}"
                return 1
            fi
        else
            echo "[$(date)] ${AGENT_NAME}: No log file provided for task ${task_id}" >>"${LOG_FILE}"
            return 1
        fi
        ;;
    *)
        echo "[$(date)] ${AGENT_NAME}: Unknown debug task type: ${task_type}" >>"${LOG_FILE}"
        return 1
        ;;
    esac
}

# Main agent loop
main_agent_loop() {
    echo "[$(date)] ${AGENT_NAME}: Starting debug enhanced agent..." >>"${LOG_FILE}"

    while true; do
        update_agent_status "${AGENT_NAME}" "running" $$ ""

        # Get next task for this agent
        local task_data
        task_data=$(get_next_task "agent_debug_enhanced.sh" 2>/dev/null || echo "")

        if [[ -n "$task_data" ]]; then
            update_agent_status "${AGENT_NAME}" "busy" $$ "$(echo "$task_data" | jq -r '.id')"
            if process_debug_task "$task_data"; then
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
            echo "[$(date)] ${AGENT_NAME}: No debug tasks found. Sleeping as idle." >>"${LOG_FILE}"
            sleep 300 # Sleep for 5 minutes when idle
        fi

        sleep 60 # Brief pause between checks
    done
}

# Legacy main entry point for backward compatibility
main() {
    local command="${1:-help}"
    shift || true

    case "$command" in
    error)
        if [ $# -lt 1 ]; then
            echo "Usage: agent_debug_enhanced.sh error <error_pattern>"
            exit 1
        fi
        debug_error "$1" "true"
        ;;
    log)
        if [ $# -lt 1 ]; then
            echo "Usage: agent_debug_enhanced.sh log <log_file>"
            exit 1
        fi
        analyze_log "$1"
        ;;
    help | --help | -h)
        cat <<HELP
Enhanced Agent Debug - Intelligent Debugging

Usage: agent_debug_enhanced.sh <command> [arguments]

Commands:
  error <pattern>    Debug specific error with AI assistance
  log <file>         Analyze log file for errors and suggest fixes
  help               Show this help message

Examples:
  agent_debug_enhanced.sh error "Build failed: No such module"
  agent_debug_enhanced.sh log test_results.log
HELP
        ;;
    *)
        echo "Unknown command: $command"
        echo "Try 'agent_debug_enhanced.sh help' for usage"
        exit 1
        ;;
    esac
}

# Check if running as agent or command-line tool
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ "${1:-}" == "agent" ]]; then
        # Run as continuous agent
        main_agent_loop
    else
        # Run as command-line tool
        main "$@"
    fi
fi
