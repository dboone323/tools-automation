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
