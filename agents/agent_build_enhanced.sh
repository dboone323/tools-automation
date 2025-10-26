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
