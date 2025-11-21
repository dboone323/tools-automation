#!/usr/bin/env bash
# AI Decision Helper for Shell Scripts
# Provides easy AI decision-making interface for bash agents

# Source configuration discovery if available
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
if [[ -f "${SCRIPT_DIR}/../agents/agent_config_discovery.sh" ]]; then
    source "${SCRIPT_DIR}/../agents/agent_config_discovery.sh"
fi

AI_ENGINE="${SCRIPT_DIR}/ai_decision_engine.py"
AI_PROVIDER="${AI_PROVIDER:-ollama}"  # Default to Ollama

# Make an AI decision from shell script
# Usage: ai_decide <agent_name> <decision_type> <context_json> [options...]
ai_decide() {
    local agent_name="$1"
    local decision_type="$2"
    local context_json="$3"
    shift 3
    local options=("$@")
    
    if [[ ! -f "$AI_ENGINE" ]]; then
        echo '{"decision":"fallback","confidence":0.3,"reasoning":"AI engine not available"}' >&2
        return 1
    fi
    
    # Build command
    local cmd=(python3 "$AI_ENGINE" 
               --provider "$AI_PROVIDER"
               --agent "$agent_name"
               --type "$decision_type"
               --context "$context_json")
    
    if [[ ${#options[@]} -gt 0 ]]; then
        cmd+=(--options "${options[@]}")
    fi
    
    # Execute and return JSON result
    "${cmd[@]}" 2>/dev/null
}

# Quick error recovery decision
# Usage: ai_error_recovery <agent_name> <error_type> <error_message>
ai_error_recovery() {
    local agent_name="$1"
    local error_type="$2"
    local error_message="$3"
    
    local context=$(cat <<EOF
{
    "error_type": "$error_type",
    "error_message": "$error_message",
    "timestamp": $(date +%s)
}
EOF
)
    
    ai_decide "$agent_name" "error_recovery" "$context" \
        "retry_with_backoff" "restart_agent" "rollback_changes" "log_and_continue"
}

# Quick task prioritization decision
# Usage: ai_prioritize_tasks <agent_name> <tasks_json>
ai_prioritize_tasks() {
    local agent_name="$1"
    local tasks_json="$2"
    
    local context=$(cat <<EOF
{
    "tasks": $tasks_json,
    "timestamp": $(date +%s)
}
EOF
)
    
    ai_decide "$agent_name" "task_prioritization" "$context"
}

# Quick build failure diagnosis
# Usage: ai_diagnose_build_failure <agent_name> <build_log_excerpt>
ai_diagnose_build_failure() {
    local agent_name="$1"
    local build_log="$2"
    
    local context=$(cat <<EOF
{
    "build_log": "$build_log",
    "timestamp": $(date +%s)
}
EOF
)
    
    ai_decide "$agent_name" "build_failure_diagnosis" "$context" \
        "missing_dependency" "syntax_error" "configuration_issue" "environment_problem"
}

# Get AI decision metrics
# Usage: ai_metrics [hours]
ai_metrics() {
    local hours="${1:-24}"
    
    if [[ ! -f "$AI_ENGINE" ]]; then
        echo "AI engine not available" >&2
        return 1
    fi
    
    python3 "$AI_ENGINE" --agent "all" --type "any" --metrics --hours "$hours"
}

# Get AI decision history
# Usage: ai_history <agent_name> [hours]
ai_history() {
    local agent_name="$1"
    local hours="${2:-24}"
    
    if [[ ! -f "$AI_ENGINE" ]]; then
        echo "AI engine not available" >&2
        return 1
    fi
    
    python3 "$AI_ENGINE" --agent "$agent_name" --type "any" --history --hours "$hours"
}

# Export functions for use in other scripts
export -f ai_decide
export -f ai_error_recovery
export -f ai_prioritize_tasks
export -f ai_diagnose_build_failure
export -f ai_metrics
export -f ai_history

# Example usage in agent scripts:
#
# source "${SCRIPT_DIR}/../monitoring/ai_helpers.sh"
#
# # Make error recovery decision
# decision=$(ai_error_recovery "agent_build" "compile_error" "$error_output")
# action=$(echo "$decision" | jq -r '.decision')
# confidence=$(echo "$decision" | jq -r '.confidence')
#
# if [[ "$action" == "retry_with_backoff" ]]; then
#     sleep 5
#     retry_build
# elif [[ "$action" == "restart_agent" ]]; then
#     restart_self
# fi
