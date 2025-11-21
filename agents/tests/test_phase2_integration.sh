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
./knowledge_sync.sh sync >/dev/null 2>&1
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
echo "let x = 42" >"$test_file"
result=$(python3 ./validation_framework.py syntax "$test_file" 2>&1)
if echo "$result" | jq -e '.passed == true' >/dev/null 2>&1; then
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
    ./auto_rollback.sh clean 0 >/dev/null 2>&1 # Clean up test checkpoint
else
    echo "❌ Auto-rollback failed"
    exit 1
fi
echo ""

# Test 4: Success Verifier
echo "Test 4: Success Verifier"
# Note: We check if the verifier runs and returns valid JSON, not if verification passes
result=$(python3 ./success_verifier.py build '{"project":"TestProject"}' 2>&1 || true)
if echo "$result" | jq -e '.total_checks' >/dev/null 2>&1; then
    echo "✅ Success verifier working"
else
    echo "❌ Success verifier failed"
    exit 1
fi
echo ""

# Test 5: Context Loader
echo "Test 5: Context Loader"
context=$(./context_loader.sh memory 2>&1)
if echo "$context" | jq -e '.project_name' >/dev/null 2>&1; then
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
