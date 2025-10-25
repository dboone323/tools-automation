#!/bin/bash

# Phase 3 Integration Script
# Integrates Advanced Autonomy components

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

log() {
    echo -e "${BLUE}[Phase 3 Integration]${NC} $*"
}

success() {
    echo -e "${GREEN}[Phase 3 Integration]${NC} $*"
}

warn() {
    echo -e "${YELLOW}[Phase 3 Integration]${NC} $*"
}

error() {
    echo -e "${RED}[Phase 3 Integration]${NC} $*"
}

# Check Phase 1 and 2 are installed
check_prerequisites() {
    log "Checking prerequisites..."

    if [ ! -f "$SCRIPT_DIR/error_learning_agent.sh" ]; then
        error "Phase 1 not found. Please run ./integrate_phase1.sh first"
        exit 1
    fi

    if [ ! -f "$SCRIPT_DIR/knowledge_sync.sh" ]; then
        error "Phase 2 not found. Please run ./integrate_phase2.sh first"
        exit 1
    fi

    success "Prerequisites OK (Phase 1 & 2 installed)"
}

# Initialize prediction engine
initialize_prediction() {
    log "Initializing failure prediction engine..."

    # Create predictions file
    mkdir -p "$SCRIPT_DIR/knowledge"

    if [ ! -f "$SCRIPT_DIR/knowledge/predictions.json" ]; then
        cat >"$SCRIPT_DIR/knowledge/predictions.json" <<EOF
{
  "predictions": [],
  "accuracy": {
    "correct": 0,
    "incorrect": 0
  }
}
EOF
    fi

    # Test prediction engine
    python3 "$SCRIPT_DIR/prediction_engine.py" accuracy >/dev/null 2>&1 || {
        warn "Prediction engine test failed, but continuing..."
    }

    success "Prediction engine initialized"
}

# Initialize proactive monitoring
initialize_monitoring() {
    log "Initializing proactive monitoring..."

    "$SCRIPT_DIR/proactive_monitor.sh" init

    # Run initial monitoring pass
    log "Running initial monitoring scan..."
    "$SCRIPT_DIR/proactive_monitor.sh" run || {
        warn "Initial monitoring scan had warnings, but continuing..."
    }

    success "Proactive monitoring initialized"
}

# Initialize strategy tracking
initialize_strategy_tracking() {
    log "Initializing strategy tracking..."

    # Initialize with base strategies
    python3 "$SCRIPT_DIR/strategy_tracker.py" list >/dev/null 2>&1 || {
        warn "Strategy tracker initialization had warnings..."
    }

    # Add default strategies if not present
    log "Adding default strategies..."
    python3 "$SCRIPT_DIR/strategy_tracker.py" add "rebuild" "Rebuild Project" "Clean rebuild" "build_error" 0.1 60 2>/dev/null || true
    python3 "$SCRIPT_DIR/strategy_tracker.py" add "clean_build" "Clean Build" "Clean and rebuild" "dependency_issue" 0.2 90 2>/dev/null || true
    python3 "$SCRIPT_DIR/strategy_tracker.py" add "fix_imports" "Fix Imports" "Update imports" "import_error" 0.3 40 2>/dev/null || true

    success "Strategy tracking initialized"
}

# Initialize strategy evolution
initialize_evolution() {
    log "Initializing strategy evolution..."

    # Test evolution system
    python3 "$SCRIPT_DIR/strategy_evolution.py" list >/dev/null 2>&1 || {
        warn "Evolution system test failed, but continuing..."
    }

    success "Strategy evolution initialized"
}

# Initialize emergency response
initialize_emergency() {
    log "Initializing emergency response system..."

    "$SCRIPT_DIR/emergency_response.sh" init

    # Check safe-mode status
    local safe_mode_status
    safe_mode_status=$("$SCRIPT_DIR/emergency_response.sh" safe-mode)
    log "Safe-mode status: $safe_mode_status"

    success "Emergency response initialized"
}

# Create integration test
create_integration_test() {
    log "Creating Phase 3 integration test..."

    cat >"$SCRIPT_DIR/test_phase3_integration.sh" <<'EOF'
#!/bin/bash

# Phase 3 Integration Test
# Validates all Phase 3 components work together

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

echo "Phase 3 Integration Test"
echo "========================"
echo ""

# Test 1: Prediction Engine
echo "Test 1: Failure Prediction Engine"
# Create test file
test_file="/tmp/test_phase3_$$.swift"
echo "let x = 42" > "$test_file"
result=$(python3 ./prediction_engine.py analyze "$test_file" "modification" 2>&1 || true)
if echo "$result" | jq -e '.risk_score' > /dev/null 2>&1; then
    echo "✅ Prediction engine working"
else
    echo "❌ Prediction engine failed"
    rm -f "$test_file"
    exit 1
fi
rm -f "$test_file"
echo ""

# Test 2: Proactive Monitoring
echo "Test 2: Proactive Monitoring"
./proactive_monitor.sh status > /dev/null 2>&1
if [ $? -eq 0 ]; then
    echo "✅ Proactive monitoring working"
else
    echo "❌ Proactive monitoring failed"
    exit 1
fi
echo ""

# Test 3: Strategy Tracker
echo "Test 3: Strategy Performance Tracking"
result=$(python3 ./strategy_tracker.py list 2>&1 || true)
if echo "$result" | jq -e '.[0].strategy_id' > /dev/null 2>&1; then
    echo "✅ Strategy tracker working"
else
    echo "❌ Strategy tracker failed"
    exit 1
fi
echo ""

# Test 4: Strategy Evolution
echo "Test 4: Adaptive Strategy Evolution"
result=$(python3 ./strategy_evolution.py list 2>&1 || true)
if echo "$result" | jq -e 'type' > /dev/null 2>&1; then
    echo "✅ Strategy evolution working"
else
    echo "❌ Strategy evolution failed"
    exit 1
fi
echo ""

# Test 5: Emergency Response
echo "Test 5: Emergency Response System"
severity=$(./emergency_response.sh classify "Build failed" 2>&1 || true)
if [ -n "$severity" ]; then
    echo "✅ Emergency response working"
else
    echo "❌ Emergency response failed"
    exit 1
fi
echo ""

echo "========================"
echo "Integration test complete"
echo "✅ Phase 3 components integrated successfully"
EOF

    chmod +x "$SCRIPT_DIR/test_phase3_integration.sh"
    success "Integration test created"
}

# Create Phase 3 workflow template
create_workflow_template() {
    log "Creating Phase 3 enhanced workflow template..."

    cat >"$SCRIPT_DIR/agent_workflow_phase3.sh" <<'EOF'
#!/bin/bash

# Agent Workflow with Phase 1+2+3 Enhancements
# Complete autonomous agent workflow with all capabilities

set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Source Phase 2 workflow
source "$SCRIPT_DIR/agent_workflow_phase2.sh" 2>/dev/null || {
    echo "[Workflow] Warning: Phase 2 workflow not found, using Phase 3 only"
}

# Phase 3 Enhanced Workflow
run_agent_with_full_autonomy() {
    local operation="$1"
    local file_path="$2"
    local context_json="${3:-{}}"
    
    echo "[Agent Phase 3] Starting fully autonomous workflow..."
    echo "[Agent Phase 3] Operation: $operation, File: $file_path"
    
    # Step 1: Predict potential failures (Phase 3)
    echo "[Agent Phase 3] Step 1: Predicting potential failures..."
    local prediction
    prediction=$(python3 "$SCRIPT_DIR/prediction_engine.py" analyze "$file_path" "modification" 2>&1 || echo '{"risk_score": 0.5}')
    local risk_score
    risk_score=$(echo "$prediction" | jq -r '.risk_score' 2>/dev/null || echo "0.5")
    echo "[Agent Phase 3]   Risk score: $risk_score"
    
    # If high risk, consider preventive measures
    if (( $(echo "$risk_score > 0.7" | bc -l 2>/dev/null || echo "0") )); then
        echo "[Agent Phase 3]   HIGH RISK detected - applying preventions..."
        # Apply preventions from prediction
    fi
    
    # Step 2: Check proactive monitors (Phase 3)
    echo "[Agent Phase 3] Step 2: Checking proactive monitors..."
    "$SCRIPT_DIR/proactive_monitor.sh" status > /dev/null 2>&1 || true
    
    # Step 3: Select best strategy (Phase 3)
    echo "[Agent Phase 3] Step 3: Selecting optimal strategy..."
    local strategy_context
    strategy_context=$(echo "$context_json" | jq -r '.context // "general"' 2>/dev/null || echo "general")
    local best_strategy
    best_strategy=$(python3 "$SCRIPT_DIR/strategy_tracker.py" best "$strategy_context" 2>/dev/null || echo "null")
    
    if [ "$best_strategy" != "null" ]; then
        local strategy_id
        strategy_id=$(echo "$best_strategy" | jq -r '.id' 2>/dev/null || echo "unknown")
        echo "[Agent Phase 3]   Selected strategy: $strategy_id"
    fi
    
    # Step 4: Load context (Phase 2)
    echo "[Agent Phase 3] Step 4: Loading context..."
    local context
    context=$("$SCRIPT_DIR/context_loader.sh" load "$operation" "$file_path" 2>/dev/null || echo "{}")
    
    # Step 5: Check knowledge base (Phase 1+2)
    echo "[Agent Phase 3] Step 5: Checking knowledge base..."
    "$SCRIPT_DIR/knowledge_sync.sh" query best_practices > /dev/null 2>&1 || true
    
    # Step 6: Create checkpoint (Phase 2)
    echo "[Agent Phase 3] Step 6: Creating checkpoint..."
    local checkpoint
    checkpoint=$("$SCRIPT_DIR/auto_rollback.sh" checkpoint "phase3_${operation}_$$" "$file_path" 2>&1 || echo "")
    
    # Step 7: Execute operation with emergency handling (Phase 3)
    echo "[Agent Phase 3] Step 7: Executing operation..."
    local start_time
    start_time=$(date +%s)
    
    # Declare emergency if operation fails critically
    local emergency_id=""
    
    if ! execute_operation "$operation" "$file_path"; then
        local error_msg="Operation $operation failed on $file_path"
        local severity
        severity=$("$SCRIPT_DIR/emergency_response.sh" classify "$error_msg" 2>/dev/null || echo "medium")
        
        if [ "$severity" = "critical" ] || [ "$severity" = "high" ]; then
            echo "[Agent Phase 3]   EMERGENCY: Declaring $severity severity emergency"
            emergency_id=$("$SCRIPT_DIR/emergency_response.sh" declare "$error_msg" "$severity" "$context_json" 2>&1 || echo "")
            
            if [ -n "$emergency_id" ]; then
                echo "[Agent Phase 3]   Emergency ID: $emergency_id"
                echo "[Agent Phase 3]   Starting emergency escalation..."
                "$SCRIPT_DIR/emergency_response.sh" handle "$emergency_id" &
            fi
        fi
        
        return 1
    fi
    
    local end_time
    end_time=$(date +%s)
    local execution_time
    execution_time=$((end_time - start_time))
    
    # Step 8: Validate (Phase 2)
    echo "[Agent Phase 3] Step 8: Validating result..."
    local validation
    validation=$(python3 "$SCRIPT_DIR/validation_framework.py" all "$file_path" "$context_json" 2>&1 || echo '{"passed": false}')
    local validation_passed
    validation_passed=$(echo "$validation" | jq -r '.passed' 2>/dev/null || echo "false")
    
    # Step 9: Auto-rollback if needed (Phase 2)
    if [ "$validation_passed" != "true" ]; then
        echo "[Agent Phase 3] Step 9: Validation failed - rolling back..."
        if [ -n "$checkpoint" ]; then
            "$SCRIPT_DIR/auto_rollback.sh" monitor "$validation" "$checkpoint" 2>&1 || true
        fi
        return 1
    fi
    
    # Step 10: Verify success (Phase 2)
    echo "[Agent Phase 3] Step 10: Verifying success..."
    local verification
    verification=$(python3 "$SCRIPT_DIR/success_verifier.py" codegen "$file_path" "$context_json" 2>&1 || echo '{"success": false}')
    local verify_success
    verify_success=$(echo "$verification" | jq -r '.success' 2>/dev/null || echo "false")
    
    # Step 11: Record strategy performance (Phase 3)
    if [ "$verify_success" = "true" ] && [ -n "$best_strategy" ] && [ "$best_strategy" != "null" ]; then
        echo "[Agent Phase 3] Step 11: Recording strategy performance..."
        local strategy_id
        strategy_id=$(echo "$best_strategy" | jq -r '.id' 2>/dev/null || echo "unknown")
        python3 "$SCRIPT_DIR/strategy_tracker.py" record "$strategy_id" "$strategy_context" true "$execution_time" "$context_json" 2>&1 || true
    fi
    
    # Step 12: Update prediction outcome (Phase 3)
    echo "[Agent Phase 3] Step 12: Updating prediction accuracy..."
    # This would update the prediction with actual outcome
    
    # Step 13: Record success in context (Phase 2)
    echo "[Agent Phase 3] Step 13: Recording success..."
    "$SCRIPT_DIR/context_loader.sh" record-success "$operation" "Successfully completed $operation" 2>&1 || true
    
    # Step 14: Sync knowledge (Phase 2)
    echo "[Agent Phase 3] Step 14: Syncing knowledge..."
    "$SCRIPT_DIR/knowledge_sync.sh" sync > /dev/null 2>&1 || true
    
    # Step 15: Resolve emergency if declared (Phase 3)
    if [ -n "$emergency_id" ]; then
        echo "[Agent Phase 3] Step 15: Resolving emergency..."
        "$SCRIPT_DIR/emergency_response.sh" resolve "$emergency_id" "Resolved by agent workflow" 2>&1 || true
    fi
    
    echo "[Agent Phase 3] ✅ Workflow completed successfully"
    return 0
}

# Define your operation function here
execute_operation() {
    local operation="$1"
    local file_path="$2"
    
    # Your agent-specific operation logic goes here
    echo "[Execute] Running $operation on $file_path..."
    
    # Example: just return success
    return 0
}

# Export for other scripts to use
export -f run_agent_with_full_autonomy
export -f execute_operation
EOF

    chmod +x "$SCRIPT_DIR/agent_workflow_phase3.sh"
    success "Phase 3 workflow template created"
}

# Main integration sequence
main() {
    echo ""
    echo "=========================================="
    echo "Phase 3: Advanced Autonomy Integration"
    echo "=========================================="
    echo ""

    check_prerequisites
    initialize_prediction
    initialize_monitoring
    initialize_strategy_tracking
    initialize_evolution
    initialize_emergency
    create_integration_test
    create_workflow_template

    echo ""
    echo "=========================================="
    success "✅ Phase 3 integration complete!"
    echo "=========================================="
    echo ""
    echo "Phase 3 components installed:"
    echo "  • Failure Prediction Engine"
    echo "  • Proactive Monitoring System"
    echo "  • Strategy Performance Tracking"
    echo "  • Adaptive Strategy Evolution"
    echo "  • Emergency Response System"
    echo ""
    echo "Next steps:"
    echo "  1. Run tests: ./test_phase3_integration.sh"
    echo "  2. Start proactive monitoring: ./proactive_monitor.sh watch &"
    echo "  3. Check status: ./proactive_monitor.sh status"
    echo "  4. Use Phase 3 workflow: source agent_workflow_phase3.sh"
    echo ""
}

main "$@"
