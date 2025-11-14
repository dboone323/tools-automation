#!/bin/bash

# Test file for agent_documentation.sh
# This file contains comprehensive tests for the documentation agent functionality

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shell_test_framework.sh"

# Agent script to test
AGENT_SCRIPT="${SCRIPT_DIR}/agents/agent_documentation.sh"
if [[ ! -f "${AGENT_SCRIPT}" ]]; then
    echo "ERROR: Agent script not found at ${AGENT_SCRIPT}"
    exit 1
fi

# Test counter
TEST_COUNT=0
PASSED_COUNT=0
FAILED_COUNT=0

# Test helper function
run_test() {
    local test_name="$1"
    local test_function="$2"
    local expected_result="$3"

    ((TEST_COUNT++))
    echo "Running test ${TEST_COUNT}: ${test_name}"

    if ${test_function}; then
        local actual_result=0
    else
        local actual_result=$?
    fi

    if [[ ${actual_result} -eq ${expected_result} ]]; then
        echo "✓ PASSED: ${test_name}"
        ((PASSED_COUNT++))
    else
        echo "✗ FAILED: ${test_name} (expected ${expected_result}, got ${actual_result})"
        ((FAILED_COUNT++))
    fi
}

# Test functions - check if functions exist in the script
test_run_with_timeout_exists() {
    grep -q "run_with_timeout()" "${AGENT_SCRIPT}"
}

test_check_resource_limits_exists() {
    grep -q "check_resource_limits()" "${AGENT_SCRIPT}"
}

test_register_with_mcp_exists() {
    grep -q "register_with_mcp" "${AGENT_SCRIPT}"
}

test_get_next_task_exists() {
    grep -q "get_next_task" "${AGENT_SCRIPT}"
}

test_update_task_status_exists() {
    grep -q "update_task_status" "${AGENT_SCRIPT}"
}

test_get_task_details_exists() {
    grep -q "get_task_details" "${AGENT_SCRIPT}"
}

test_complete_task_exists() {
    grep -q "complete_task" "${AGENT_SCRIPT}"
}

test_increment_task_count_exists() {
    grep -q "increment_task_count" "${AGENT_SCRIPT}"
}

# Test script structure
test_script_has_shebang() {
    head -1 "${AGENT_SCRIPT}" | grep -q "^#!/bin/bash"
}

test_script_sources_shared_functions() {
    grep -q "source.*shared_functions.sh" "${AGENT_SCRIPT}"
}

test_script_has_agent_variables() {
    grep -q "AGENT_NAME=" "${AGENT_SCRIPT}" && grep -q "LOG_FILE=" "${AGENT_SCRIPT}"
}

test_script_has_main_loop() {
    grep -q "while true; do" "${AGENT_SCRIPT}"
}

test_script_has_task_types() {
    grep -q "documentation\|readme\|api-docs" "${AGENT_SCRIPT}"
}

test_script_has_timeout_protection() {
    grep -q "run_with_timeout" "${AGENT_SCRIPT}"
}

test_script_has_resource_limits() {
    grep -q "check_resource_limits" "${AGENT_SCRIPT}"
}

# Run all tests
echo "Starting tests for agent_documentation.sh"
echo "========================================="

run_test "run_with_timeout function exists" test_run_with_timeout_exists 0
run_test "check_resource_limits function exists" test_check_resource_limits_exists 0
run_test "register_with_mcp function exists" test_register_with_mcp_exists 0
run_test "get_next_task function exists" test_get_next_task_exists 0
run_test "update_task_status function exists" test_update_task_status_exists 0
run_test "get_task_details function exists" test_get_task_details_exists 0
run_test "complete_task function exists" test_complete_task_exists 0
run_test "increment_task_count function exists" test_increment_task_count_exists 0
run_test "script has proper shebang" test_script_has_shebang 0
run_test "script sources shared functions" test_script_sources_shared_functions 0
run_test "script has agent variables" test_script_has_agent_variables 0
run_test "script has main processing loop" test_script_has_main_loop 0
run_test "script handles task types" test_script_has_task_types 0
run_test "script has timeout protection" test_script_has_timeout_protection 0
run_test "script has resource limits" test_script_has_resource_limits 0

# Summary
echo ""
echo "==================================="
echo "Test Summary for agent_documentation.sh:"
echo "Total tests: ${TEST_COUNT}"
echo "Passed: ${PASSED_COUNT}"
echo "Failed: ${FAILED_COUNT}"

if [[ ${FAILED_COUNT} -eq 0 ]]; then
    echo "✓ All tests passed!"
    exit 0
else
    echo "✗ Some tests failed."
    exit 1
fi
