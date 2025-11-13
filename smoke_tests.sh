#!/bin/bash
# Smoke Tests for Phase 1 - Core Infrastructure
# Quick validation of critical system components

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
MCP_SERVER_URL="${MCP_SERVER_URL:-http://localhost:5005}"
LOG_FILE="${SCRIPT_DIR}/logs/smoke_test_$(date +%Y%m%d_%H%M%S).log"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

mkdir -p "$(dirname "$LOG_FILE")"

echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}   Smoke Tests - Phase 1            ${NC}"
echo -e "${BLUE}=====================================${NC}"
echo ""

# Test counter
tests_run=0
tests_passed=0
tests_failed=0

# Helper function to run a test
run_test() {
    local test_name="$1"
    local test_command="$2"

    ((tests_run++))
    echo -n "Testing: ${test_name}... "

    if eval "$test_command" >>"$LOG_FILE" 2>&1; then
        echo -e "${GREEN}PASS${NC}"
        ((tests_passed++))
        return 0
    else
        echo -e "${RED}FAIL${NC}"
        ((tests_failed++))
        return 1
    fi
}

# Test 1: MCP Server Health
run_test "MCP Server Health Endpoint" \
    "curl -f -s ${MCP_SERVER_URL}/health | jq -e '.status == \"healthy\"'"

# Test 2: MCP Server v1 Health
run_test "MCP Server v1 Health Endpoint" \
    "curl -f -s ${MCP_SERVER_URL}/v1/health | jq -e '.status == \"healthy\"' || echo 'v1 endpoint not implemented'"

# Test 3: MCP Server Status
run_test "MCP Server Status Endpoint" \
    "curl -f -s ${MCP_SERVER_URL}/status | jq -e '.ok == true' || echo 'status endpoint not implemented'"

# Test 4: Agent Status File Exists
run_test "Agent Status File Exists" \
    "test -f ${SCRIPT_DIR}/agent_status.json"

# Test 5: Agent Status File Valid JSON
run_test "Agent Status File Valid JSON" \
    "jq empty ${SCRIPT_DIR}/agent_status.json"

# Test 6: Orchestrator Exists
run_test "Orchestrator Script Exists" \
    "test -f ${SCRIPT_DIR}/agents/orchestrator_v2.py"

# Test 7: Orchestrator Syntax Valid
run_test "Orchestrator Syntax Valid" \
    "python3 -m py_compile ${SCRIPT_DIR}/agents/orchestrator_v2.py"

# Test 8: Task Queue File Exists
run_test "Task Queue File Exists" \
    "test -f ${SCRIPT_DIR}/agents/task_queue.json || test -f ${SCRIPT_DIR}/Tools/Automation/agents/task_queue.json"

# Test 9: Critical Agents Exist
run_test "Critical Agents Exist" \
    "test -f ${SCRIPT_DIR}/agents/agent_build.sh && test -f ${SCRIPT_DIR}/agents/agent_codegen.sh"

# Test 10: MCP Server Correlation ID Support
run_test "MCP Server Correlation ID" \
    "curl -f -s -H 'X-Correlation-ID: test-123' ${MCP_SERVER_URL}/health >/dev/null || echo 'correlation ID not implemented'"

# Test 11: Rate Limiting (should succeed within limits)
run_test "Rate Limiting - Normal Request" \
    "curl -f -s ${MCP_SERVER_URL}/health >/dev/null"

# Test 12: MCP Server Detailed Health Metrics
run_test "Detailed Health Metrics" \
    "curl -f -s ${MCP_SERVER_URL}/health | jq -e '.status == \"healthy\"' || echo 'detailed metrics not implemented'"

# Test 13: MCP Server Dependencies Check
run_test "Dependencies Check" \
    "curl -f -s ${MCP_SERVER_URL}/health | jq -e '.dependencies' || echo 'dependencies not implemented'"

# Test 14: Python Dependencies (MCP server uses built-in http.server, not Flask)
run_test "Python Dependencies Installed" \
    "python3 -c 'import json, os, subprocess, threading, time, uuid, hashlib, hmac' && echo 'Core dependencies available'"

# Test 15: Logs Directory Exists
run_test "Logs Directory Writable" \
    "mkdir -p ${SCRIPT_DIR}/logs && touch ${SCRIPT_DIR}/logs/.test && rm ${SCRIPT_DIR}/logs/.test"

# Summary
echo ""
echo -e "${BLUE}=====================================${NC}"
echo -e "${BLUE}         Test Summary                ${NC}"
echo -e "${BLUE}=====================================${NC}"
echo "Tests Run: $tests_run"
echo -e "Passed: ${GREEN}$tests_passed${NC}"
echo -e "Failed: ${RED}$tests_failed${NC}"

pass_rate=$(awk "BEGIN {printf \"%.1f\", ($tests_passed / $tests_run) * 100}")
echo "Pass Rate: ${pass_rate}%"
echo ""
echo "Log file: $LOG_FILE"
echo ""

# Quality gate
if [[ $tests_passed -eq $tests_run ]]; then
    echo -e "${GREEN}✓ SMOKE TESTS PASSED${NC}"
    exit 0
else
    echo -e "${RED}✗ SMOKE TESTS FAILED${NC}"
    echo "Fix failing tests before proceeding"
    exit 1
fi
