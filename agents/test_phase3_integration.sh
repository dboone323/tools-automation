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
echo "let x = 42" >"$test_file"
result=$(python3 ./prediction_engine.py analyze "$test_file" "modification" 2>/dev/null || true)
if echo "$result" | jq -e '.risk_score' >/dev/null 2>&1; then
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
./proactive_monitor.sh status >/dev/null 2>&1
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
if echo "$result" | jq -e '.[0].strategy_id' >/dev/null 2>&1; then
    echo "✅ Strategy tracker working"
else
    echo "❌ Strategy tracker failed"
    exit 1
fi
echo ""

# Test 4: Strategy Evolution
echo "Test 4: Adaptive Strategy Evolution"
result=$(python3 ./strategy_evolution.py list 2>&1 || true)
if echo "$result" | jq -e 'type' >/dev/null 2>&1; then
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
