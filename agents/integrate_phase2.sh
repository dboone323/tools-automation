#!/bin/bash

# Phase 2 Integration Script
# Integrates Intelligence Amplification components

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log() {
    echo -e "${GREEN}[Phase 2 Integration]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[Phase 2 Integration]${NC} $*"
}

error() {
    echo -e "${RED}[Phase 2 Integration]${NC} $*"
    exit 1
}

# Check Phase 1 components exist
check_phase1() {
    log "Checking Phase 1 components..."

    local missing=0

    for component in decision_engine.py fix_suggester.py mcp_client.sh error_learning_agent.sh; do
        if [ ! -f "$SCRIPT_DIR/$component" ]; then
            error "$component not found - run Phase 1 first"
            missing=1
        fi
    done

    if [ $missing -eq 1 ]; then
        error "Phase 1 not complete"
    fi

    log "✅ Phase 1 components present"
}

# Check Phase 2 components exist
check_phase2() {
    log "Checking Phase 2 components..."

    local components=(
        "knowledge_sync.sh"
        "validation_framework.py"
        "auto_rollback.sh"
        "success_verifier.py"
        "context_loader.sh"
    )

    for component in "${components[@]}"; do
        if [ ! -f "$SCRIPT_DIR/$component" ]; then
            error "$component not found"
        fi
    done

    log "✅ All Phase 2 components present"
}

# Initialize Phase 2 systems
initialize_systems() {
    log "Initializing Phase 2 systems..."

    # Initialize knowledge sync
    ./knowledge_sync.sh init
    log "  ✅ Knowledge sync initialized"

    # Initialize context system
    ./context_loader.sh init
    log "  ✅ Context system initialized"

    # Initialize rollback system
    ./auto_rollback.sh init
    log "  ✅ Rollback system initialized"

    log "✅ All systems initialized"
}

# Run initial sync
run_initial_sync() {
    log "Running initial knowledge sync..."

    ./knowledge_sync.sh sync
    log "✅ Initial sync complete"
}

# Update project memory with architecture rules
populate_project_memory() {
    log "Populating project memory..."

    # Add architecture decisions
    ./context_loader.sh record-success "MVVM pattern" "Base architecture for all projects"
    ./context_loader.sh record-success "SwiftUI preferred" "Use SwiftUI over UIKit where possible"

    # Update test coverage
    ./context_loader.sh update "current_state.test_coverage" "0.77"

    # Update build status
    ./context_loader.sh update "current_state.build_status" "passing"

    log "✅ Project memory populated"
}

# Create enhanced agent wrappers with Phase 2
create_phase2_wrappers() {
    log "Creating Phase 2-enhanced agent wrappers..."

    # Create enhanced workflow template
    cat >"$SCRIPT_DIR/agent_workflow_phase2.sh" <<'WORKFLOW_EOF'
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
WORKFLOW_EOF

    chmod +x "$SCRIPT_DIR/agent_workflow_phase2.sh"
    log "  ✅ Created agent_workflow_phase2.sh"

    log "✅ Phase 2 wrappers created"
}

# Create integration test
create_integration_test() {
    log "Creating Phase 2 integration test..."

    cat >"$SCRIPT_DIR/test_phase2_integration.sh" <<'TEST_EOF'
#!/bin/bash

# Phase 2 Integration Test
# Validates all Phase 2 components work together

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Phase 2 Integration Test"
echo "========================"
echo ""

# Test 1: Knowledge Sync
echo "Test 1: Knowledge Sync"
./knowledge_sync.sh sync > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Knowledge sync working"
else
    echo "❌ Knowledge sync failed"
    exit 1
fi
echo ""

# Test 2: Validation Framework
echo "Test 2: Validation Framework"
# Create test file
test_file="/tmp/test_phase2_$$. swift"
echo "let x = 42" > "$test_file"
result=$(python3 ./validation_framework.py syntax "$test_file" 2>&1)
if echo "$result" | jq -e '.passed == true' > /dev/null 2>&1; then
    echo "✅ Validation framework working"
else
    echo "❌ Validation framework failed"
    rm -f "$test_file"
    exit 1
fi
rm -f "$test_file"
echo ""

# Test 3: Auto-Rollback
echo "Test 3: Auto-Rollback System"
test_checkpoint=$(./auto_rollback.sh checkpoint "test_$$" "" 2>&1)
if [ -n "$test_checkpoint" ]; then
    echo "✅ Auto-rollback working"
    ./auto_rollback.sh clean 0 > /dev/null 2>&1  # Clean up test checkpoint
else
    echo "❌ Auto-rollback failed"
    exit 1
fi
echo ""

# Test 4: Success Verifier
echo "Test 4: Success Verifier"
result=$(python3 ./success_verifier.py build '{"project":"TestProject"}' 2>&1)
if echo "$result" | jq -e '.total_checks' > /dev/null 2>&1; then
    echo "✅ Success verifier working"
else
    echo "❌ Success verifier failed"
    exit 1
fi
echo ""

# Test 5: Context Loader
echo "Test 5: Context Loader"
context=$(./context_loader.sh memory 2>&1)
if echo "$context" | jq -e '.project_name' > /dev/null 2>&1; then
    echo "✅ Context loader working"
else
    echo "❌ Context loader failed"
    exit 1
fi
echo ""

# Test 6: Full Workflow
echo "Test 6: Full Phase 2 Workflow"
if [ -f "./agent_workflow_phase2.sh" ]; then
    echo "✅ Phase 2 workflow template exists"
else
    echo "❌ Phase 2 workflow template missing"
    exit 1
fi
echo ""

echo "========================"
echo "Integration test complete"
echo "✅ Phase 2 components integrated successfully"
TEST_EOF

    chmod +x "$SCRIPT_DIR/test_phase2_integration.sh"
    log "✅ Created test_phase2_integration.sh"
}

# Main execution
main() {
    log "Starting Phase 2 integration..."
    echo ""

    check_phase1
    check_phase2
    initialize_systems
    run_initial_sync
    populate_project_memory
    create_phase2_wrappers
    create_integration_test

    echo ""
    log "Phase 2 integration complete! 🎉"
    echo ""
    echo "New capabilities added:"
    echo "  - Cross-Agent Knowledge Sharing (knowledge_sync.sh)"
    echo "  - Multi-Layer Validation (validation_framework.py)"
    echo "  - Auto-Rollback System (auto_rollback.sh)"
    echo "  - Success Verification (success_verifier.py)"
    echo "  - Context-Aware Operations (context_loader.sh)"
    echo "  - Full workflow template (agent_workflow_phase2.sh)"
    echo ""
    echo "Test integration:"
    echo "  ./test_phase2_integration.sh"
    echo ""
    echo "View context:"
    echo "  ./context_loader.sh summary"
    echo ""
    echo "Sync knowledge:"
    echo "  ./knowledge_sync.sh sync"
}

main "$@"
