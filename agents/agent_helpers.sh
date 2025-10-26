#!/bin/bash

# Agent Helper Functions - Phase 1 Enhanced Capabilities
# Source this file in your agents to enable enhanced features

AGENT_LIB_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

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
    
    # Get recommendation
    local decision
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
        
        # Execute action based on type
        case "$action" in
            rebuild)
                result=$(agent_action_rebuild)
                success=$?
                ;;
            clean_build)
                result=$(agent_action_clean_build)
                success=$?
                ;;
            fix_lint)
                result=$(agent_action_fix_lint)
                success=$?
                ;;
            fix_format)
                result=$(agent_action_fix_format)
                success=$?
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
    if command -v swiftlint &> /dev/null; then
        swiftlint --fix --quiet
        return $?
    else
        echo "SwiftLint not available"
        return 1
    fi
}

agent_action_fix_format() {
    if command -v swiftformat &> /dev/null; then
        swiftformat . --quiet
        return $?
    else
        echo "SwiftFormat not available"
        return 1
    fi
}

