#!/bin/bash

# Agent Enhancement Integration Script
# Enhances existing agents with Phase 1 capabilities:
# - Error learning system
# - MCP integration
# - Autonomous decision making

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log() {
    echo -e "${GREEN}[Integration]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[Integration]${NC} $*"
}

error() {
    echo -e "${RED}[Integration]${NC} $*"
    exit 1
}

# Check if components exist
check_components() {
    log "Checking Phase 1 components..."

    local missing=0

    if [ ! -f "$SCRIPT_DIR/decision_engine.py" ]; then
        error "decision_engine.py not found"
        missing=1
    fi

    if [ ! -f "$SCRIPT_DIR/fix_suggester.py" ]; then
        error "fix_suggester.py not found"
        missing=1
    fi

    if [ ! -f "$SCRIPT_DIR/mcp_client.sh" ]; then
        error "mcp_client.sh not found"
        missing=1
    fi

    if [ ! -f "$SCRIPT_DIR/error_learning_agent.sh" ]; then
        error "error_learning_agent.sh not found"
        missing=1
    fi

    if [ ! -d "$SCRIPT_DIR/knowledge" ]; then
        error "Knowledge base directory not found"
        missing=1
    fi

    if [ $missing -eq 1 ]; then
        error "Missing required components, run implement_phase1.sh first"
    fi

    log "✅ All components present"
}

# Create enhanced agent wrapper function
create_agent_helpers() {
    log "Creating agent helper functions..."

    cat >"$SCRIPT_DIR/agent_helpers.sh" <<'HELPERS_EOF'
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

HELPERS_EOF

    chmod +x "$SCRIPT_DIR/agent_helpers.sh"
    log "✅ Created agent_helpers.sh"
}

# Create enhanced agent_build.sh wrapper
enhance_agent_build() {
    log "Creating enhanced agent_build.sh..."

    # Check if original exists
    if [ ! -f "$SCRIPT_DIR/agent_build.sh" ]; then
        warn "agent_build.sh not found, skipping enhancement"
        return
    fi

    # Backup original if not already backed up
    if [ ! -f "$SCRIPT_DIR/agent_build.sh.original" ]; then
        cp "$SCRIPT_DIR/agent_build.sh" "$SCRIPT_DIR/agent_build.sh.original"
        log "Backed up original agent_build.sh"
    fi

    # Create enhanced version
    cat >"$SCRIPT_DIR/agent_build_enhanced.sh" <<'BUILD_EOF'
#!/bin/bash

# Enhanced Agent Build - With Phase 1 Capabilities
# Autonomous build fixing with error learning

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/agent_helpers.sh"

# Override action implementations for build agent
agent_action_rebuild() {
    cd "$ROOT_DIR" || return 1
    xcodebuild clean build -scheme "${SCHEME:-CodingReviewer}" -configuration "${CONFIG:-Debug}"
}

agent_action_clean_build() {
    cd "$ROOT_DIR" || return 1
    xcodebuild clean build -scheme "${SCHEME:-CodingReviewer}" -configuration "${CONFIG:-Debug}" -derivedDataPath /tmp/xcode_derived_data
}

# Main build with auto-fix
main() {
    local project="${1:-CodingReviewer}"
    local auto_fix="${2:-false}"
    
    echo "Building project: $project"
    
    # Initial build attempt
    local build_log
    build_log=$(mktemp)
    
    if xcodebuild build -scheme "$project" -configuration Debug > "$build_log" 2>&1; then
        echo "✅ Build succeeded"
        rm -f "$build_log"
        exit 0
    else
        echo "❌ Build failed, analyzing..."
        
        # Extract errors from build log
        local errors
        errors=$(grep -E "(error:|failed)" "$build_log" | head -5)
        
        if [ -z "$errors" ]; then
            echo "No specific errors found in build log"
            rm -f "$build_log"
            exit 1
        fi
        
        # Try to fix each error
        while IFS= read -r error_line; do
            echo "Error: $error_line"
            
            if [ "$auto_fix" = "true" ]; then
                echo "Attempting auto-fix..."
                if agent_auto_fix "$error_line" '{"project": "'"$project"'"}' "true"; then
                    echo "Auto-fix successful, retrying build..."
                    
                    # Retry build
                    if xcodebuild build -scheme "$project" -configuration Debug; then
                        echo "✅ Build succeeded after auto-fix"
                        rm -f "$build_log"
                        exit 0
                    fi
                fi
            else
                # Just suggest fixes
                local suggestion
                suggestion=$(agent_suggest_fix "$error_line")
                echo "Suggestion: $(echo "$suggestion" | jq -r '.primary_suggestion.action // "unknown"')"
                echo "Confidence: $(echo "$suggestion" | jq -r '.confidence // 0')"
            fi
        done <<< "$errors"
        
        rm -f "$build_log"
        exit 1
    fi
}

main "$@"
BUILD_EOF

    chmod +x "$SCRIPT_DIR/agent_build_enhanced.sh"
    log "✅ Created agent_build_enhanced.sh"
}

# Create enhanced agent_debug.sh wrapper
enhance_agent_debug() {
    log "Creating enhanced agent_debug.sh..."

    # Create new enhanced version
    cat >"$SCRIPT_DIR/agent_debug_enhanced.sh" <<'DEBUG_EOF'
#!/bin/bash

# Enhanced Agent Debug - With Phase 1 Capabilities
# Intelligent debugging with AI assistance

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/agent_helpers.sh"

# Debug a specific error with AI help
debug_error() {
    local error_pattern="$1"
    local use_ai="${2:-true}"
    
    echo "Debugging: $error_pattern"
    echo ""
    
    # Get fix suggestion
    echo "📋 Fix Suggestion:"
    local suggestion
    suggestion=$(agent_suggest_fix "$error_pattern")
    
    local action
    local confidence
    local reasoning
    action=$(echo "$suggestion" | jq -r '.primary_suggestion.action // "unknown"')
    confidence=$(echo "$suggestion" | jq -r '.confidence // 0')
    reasoning=$(echo "$suggestion" | jq -r '.reasoning // "No reasoning available"')
    
    echo "  Action: $action"
    echo "  Confidence: $confidence"
    echo "  Reasoning: $reasoning"
    echo ""
    
    # Get AI analysis if requested and available
    if [ "$use_ai" = "true" ]; then
        echo "🤖 AI Analysis:"
        local ai_result
        ai_result=$(agent_ai_analyze "$error_pattern")
        
        if echo "$ai_result" | jq -e '.error' > /dev/null 2>&1; then
            echo "  (AI not available or failed)"
        else
            echo "$ai_result" | head -10
        fi
        echo ""
    fi
    
    # Show alternatives
    echo "🔄 Alternative Actions:"
    echo "$suggestion" | jq -r '.alternatives[] | "  - \(.action) (confidence: \(.confidence))"'
}

# Analyze log file for errors
analyze_log() {
    local log_file="$1"
    
    if [ ! -f "$log_file" ]; then
        echo "Log file not found: $log_file"
        exit 1
    fi
    
    echo "Analyzing log: $log_file"
    echo ""
    
    # Extract unique errors
    local errors
    errors=$(grep -E "(error:|ERROR:|failed|Failed)" "$log_file" | sort -u | head -10)
    
    if [ -z "$errors" ]; then
        echo "No errors found in log"
        exit 0
    fi
    
    echo "Found $(echo "$errors" | wc -l | tr -d ' ') unique errors"
    echo ""
    
    # Analyze each error
    local count=1
    while IFS= read -r error_line; do
        echo "[$count] $error_line"
        debug_error "$error_line" "false"
        echo "---"
        count=$((count + 1))
    done <<< "$errors"
}

# Main entry point
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
        help|--help|-h)
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

main "$@"
DEBUG_EOF

    chmod +x "$SCRIPT_DIR/agent_debug_enhanced.sh"
    log "✅ Created agent_debug_enhanced.sh"
}

# Create integration test
create_integration_test() {
    log "Creating integration test..."

    cat >"$SCRIPT_DIR/test_phase1_integration.sh" <<'TEST_EOF'
#!/bin/bash

# Phase 1 Integration Test
# Validates all components work together

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Phase 1 Integration Test"
echo "========================"
echo ""

# Test 1: Decision Engine
echo "Test 1: Decision Engine"
result=$(python3 "$SCRIPT_DIR/decision_engine.py" evaluate "Build failed: Test error")
if echo "$result" | jq -e '.recommended_action' > /dev/null 2>&1; then
    echo "✅ Decision engine working"
else
    echo "❌ Decision engine failed"
    exit 1
fi
echo ""

# Test 2: Fix Suggester
echo "Test 2: Fix Suggester"
result=$(python3 "$SCRIPT_DIR/fix_suggester.py" suggest "Build failed: Test error")
if echo "$result" | jq -e '.primary_suggestion' > /dev/null 2>&1; then
    echo "✅ Fix suggester working"
else
    echo "❌ Fix suggester failed"
    exit 1
fi
echo ""

# Test 3: MCP Client (optional - may not be available)
echo "Test 3: MCP Client"
if "$SCRIPT_DIR/mcp_client.sh" test > /dev/null 2>&1; then
    echo "✅ MCP client available and working"
else
    echo "⚠️  MCP client not available (Ollama not running)"
fi
echo ""

# Test 4: Agent Helpers
echo "Test 4: Agent Helpers"
if [ -f "$SCRIPT_DIR/agent_helpers.sh" ]; then
    source "$SCRIPT_DIR/agent_helpers.sh"
    
    # Test suggest function
    result=$(agent_suggest_fix "Test error")
    if echo "$result" | jq -e '.primary_suggestion' > /dev/null 2>&1; then
        echo "✅ Agent helpers working"
    else
        echo "❌ Agent helpers failed"
        exit 1
    fi
else
    echo "❌ Agent helpers not found"
    exit 1
fi
echo ""

# Test 5: Enhanced Agents
echo "Test 5: Enhanced Agents"
has_enhanced=0
[ -f "$SCRIPT_DIR/agent_build_enhanced.sh" ] && has_enhanced=$((has_enhanced + 1))
[ -f "$SCRIPT_DIR/agent_debug_enhanced.sh" ] && has_enhanced=$((has_enhanced + 1))

if [ $has_enhanced -eq 2 ]; then
    echo "✅ All enhanced agents present"
elif [ $has_enhanced -gt 0 ]; then
    echo "⚠️  Some enhanced agents missing ($has_enhanced/2)"
else
    echo "❌ No enhanced agents found"
    exit 1
fi
echo ""

echo "========================"
echo "Integration test complete"
echo "✅ Phase 1 components integrated successfully"
TEST_EOF

    chmod +x "$SCRIPT_DIR/test_phase1_integration.sh"
    log "✅ Created test_phase1_integration.sh"
}

# Main execution
main() {
    log "Starting Phase 1 integration..."
    echo ""

    check_components
    create_agent_helpers
    enhance_agent_build
    enhance_agent_debug
    create_integration_test

    echo ""
    log "Integration complete! 🎉"
    echo ""
    echo "New capabilities added:"
    echo "  - agent_helpers.sh: Common functions for all agents"
    echo "  - agent_build_enhanced.sh: Auto-fixing build agent"
    echo "  - agent_debug_enhanced.sh: AI-powered debugging agent"
    echo "  - test_phase1_integration.sh: Integration test suite"
    echo ""
    echo "Test integration:"
    echo "  ./agents/test_phase1_integration.sh"
    echo ""
    echo "Use enhanced agents:"
    echo "  ./agents/agent_build_enhanced.sh <project> [auto_fix]"
    echo "  ./agents/agent_debug_enhanced.sh error '<error_pattern>'"
    echo "  ./agents/agent_debug_enhanced.sh log <log_file>"
}

main "$@"
