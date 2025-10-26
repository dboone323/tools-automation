#!/bin/bash

# Phase 2 Enhanced Agent Workflow
# Template for agents with full Phase 1 + Phase 2 capabilities

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source Phase 1 helpers
source "$SCRIPT_DIR/agent_helpers.sh"

# Phase 2 Enhanced Workflow
run_agent_with_full_validation() {
    local operation="$1"
    local file_path="${2:-}"
    local context="${3:-{}}"
    
    echo "=== Phase 2 Enhanced Agent Workflow ==="
    
    # 1. Load context
    echo "Loading context..."
    full_context=$(./context_loader.sh load "$operation" "$(echo "$context" | jq -r '.query // ""')")
    
    # 2. Check for related issues
    echo "Checking knowledge base..."
    insights=$(./knowledge_sync.sh query insights 2>/dev/null || echo '[]')
    
    # 3. Create checkpoint
    echo "Creating checkpoint..."
    checkpoint=$(./auto_rollback.sh checkpoint "${operation}_$(date +%s)" "$file_path")
    
    # 4. Execute operation (placeholder - override in specific agent)
    echo "Executing operation..."
    execute_operation "$operation" "$file_path" "$context"
    local exec_result=$?
    
    # 5. Validate (multi-layer)
    if [ $exec_result -eq 0 ] && [ -n "$file_path" ]; then
        echo "Running validation..."
        validation=$(python3 ./validation_framework.py syntax "$file_path" 2>&1 || echo '{"passed": false}')
        
        # 6. Auto-rollback if validation fails
        ./auto_rollback.sh monitor "$validation" "$checkpoint" "true"
        
        if echo "$validation" | jq -e '.passed == true' > /dev/null 2>&1; then
            echo "✅ Validation passed"
            
            # 7. Success verification
            success_report=$(python3 ./success_verifier.py codegen "$file_path" "$context" 2>&1)
            
            if echo "$success_report" | jq -e '.success == true' > /dev/null 2>&1; then
                echo "✅ Success verified"
                
                # 8. Record success in context
                ./context_loader.sh record-success "$operation" "Validated and verified"
                
                # 9. Sync knowledge
                ./knowledge_sync.sh sync
                
                return 0
            else
                echo "❌ Success verification failed"
                return 1
            fi
        else
            echo "❌ Validation failed, rolled back"
            return 1
        fi
    elif [ $exec_result -ne 0 ]; then
        echo "❌ Operation failed"
        ./auto_rollback.sh restore "$checkpoint" "true"
        return 1
    else
        echo "✅ Operation complete (no validation needed)"
        return 0
    fi
}

# Override this in specific agents
execute_operation() {
    local operation="$1"
    local file_path="$2"
    local context="$3"
    
    echo "Executing: $operation on $file_path"
    # Implement actual operation here
    return 0
}

# Example usage
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_agent_with_full_validation "${1:-test}" "${2:-}" "${3:-{}}"
fi
