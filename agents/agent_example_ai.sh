#!/usr/bin/env bash
# Example: Agent with AI Decision Integration
# Demonstrates how to integrate AI decision-making into an existing agent

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source AI helpers
source "${SCRIPT_DIR}/../monitoring/ai_helpers.sh"

# Source configuration discovery
source "${SCRIPT_DIR}/agent_config_discovery.sh"

AGENT_NAME="agent_example_ai"
WORKSPACE_ROOT=$(get_workspace_root)
MCP_URL=$(get_mcp_url)
LOG_FILE="${SCRIPT_DIR}/${AGENT_NAME}.log"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$AGENT_NAME] $*" | tee -a "$LOG_FILE"
}

# Example 1: AI-Assisted Error Recovery
handle_error_with_ai() {
    local error_type="$1"
    local error_message="$2"
    
    log "🤖 Using AI for error recovery decision..."
    
    # Get AI decision
    local decision_json
    decision_json=$(ai_error_recovery "$AGENT_NAME" "$error_type" "$error_message")
    
    if [[ $? -ne 0 ]]; then
        log "⚠️  AI decision failed, using fallback"
        return 1
    fi
    
    # Parse decision
    local action=$(echo "$decision_json" | jq -r '.decision')
    local confidence=$(echo "$decision_json" | jq -r '.confidence')
    local reasoning=$(echo "$decision_json" | jq -r '.reasoning')
    
    log "📊 AI Decision: $action (confidence: $confidence)"
    log "💭 Reasoning: $reasoning"
    
    # Execute decision
    case "$action" in
        "retry_with_backoff")
            log "🔄 Retrying with exponential backoff..."
            for i in 1 2 4 8; do
                sleep $i
                if perform_operation; then
                    log "✅ Retry successful"
                    return 0
                fi
            done
            log "❌ All retries failed"
            return 1
            ;;
        
        "restart_agent")
            log "🔄 Restarting agent as per AI recommendation..."
            exec "$0"
            ;;
        
        "rollback_changes")
            log "⏮️  Rolling back changes..."
            rollback_last_operation
            return 0
            ;;
        
        "log_and_continue")
            log "📝 Logging error and continuing..."
            return 0
            ;;
        
        *)
            log "⚠️  Unknown action: $action"
            return 1
            ;;
    esac
}

# Example 2: AI-Assisted Task Prioritization
prioritize_tasks_with_ai() {
    local tasks_json="$1"
    
    log "🤖 Using AI for task prioritization..."
    
    # Get AI decision
    local decision_json
    decision_json=$(ai_prioritize_tasks "$AGENT_NAME" "$tasks_json")
    
    if [[ $? -ne 0 ]]; then
        log "⚠️  AI prioritization failed, using default order"
        return 1
    fi
    
    # Parse decision
    local priority_order=$(echo "$decision_json" | jq -r '.decision')
    local confidence=$(echo "$decision_json" | jq -r '.confidence')
    
    log "📊 AI Priority Order: $priority_order (confidence: $confidence)"
    
    echo "$priority_order"
}

# Example 3: AI-Assisted Build Failure Diagnosis
diagnose_build_failure_with_ai() {
    local build_log="$1"
    
    log "🤖 Using AI for build failure diagnosis..."
    
    # Get AI decision
    local decision_json
    decision_json=$(ai_diagnose_build_failure "$AGENT_NAME" "$build_log")
    
    if [[ $? -ne 0 ]]; then
        log "⚠️  AI diagnosis failed"
        return 1
    fi
    
    # Parse decision
    local diagnosis=$(echo "$decision_json" | jq -r '.decision')
    local confidence=$(echo "$decision_json" | jq -r '.confidence')
    local reasoning=$(echo "$decision_json" | jq -r '.reasoning')
    
    log "📊 AI Diagnosis: $diagnosis (confidence: $confidence)"
    log "💭 Analysis: $reasoning"
    
    # Take action based on diagnosis
    case "$diagnosis" in
        "missing_dependency")
            log "📦 Installing missing dependencies..."
            install_dependencies
            ;;
        
        "syntax_error")
            log "🔍 Syntax error detected, running linter..."
            run_linter_and_fix
            ;;
        
        "configuration_issue")
            log "⚙️  Configuration issue, checking settings..."
            validate_configuration
            ;;
        
        "environment_problem")
            log "🌍 Environment issue, resetting environment..."
            reset_build_environment
            ;;
        
        *)
            log "⚠️  Unknown diagnosis: $diagnosis"
            ;;
    esac
}

# Dummy functions for illustration
perform_operation() { return 1; }
rollback_last_operation() { log "Rollback complete"; }
install_dependencies() { log "Dependencies installed"; }
run_linter_and_fix() { log "Linter run"; }
validate_configuration() { log "Configuration validated"; }
reset_build_environment() { log "Environment reset"; }

# Main agent loop
main() {
    log "🚀 Starting AI-Enhanced Example Agent"
    
    # Example: Simulate an error and use AI for recovery
    if ! perform_operation; then
        handle_error_with_ai "network_timeout" "Connection to MCP server timed out"
    fi
    
    # Example: AI-assisted task prioritization
    local tasks='[
        {"id": "task1", "name": "Build Project", "priority": 5},
        {"id": "task2", "name": "Run Tests", "priority": 3},
        {"id": "task3", "name": "Deploy", "priority": 8}
    ]'
    
    local prioritized
    prioritized=$(prioritize_tasks_with_ai "$tasks" || echo "[]")
    
    log "📋 Prioritized tasks: $prioritized"
    
    # Show AI metrics
    log "📊 Showing AI decision metrics..."
    ai_metrics 1  # Last 1 hour
    
    log "✅ Agent cycle complete"
}

# Run if executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
