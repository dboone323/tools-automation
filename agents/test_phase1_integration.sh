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
