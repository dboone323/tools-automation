#!/bin/bash

# Test file for agent_control.sh
# This file contains comprehensive tests for the control agent functionality

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shell_test_framework.sh"

# Agent script to test
AGENT_SCRIPT="${SCRIPT_DIR}/agents/agent_control.sh"
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

test_process_control_task_exists() {
    grep -q "process_control_task()" "${AGENT_SCRIPT}"
}

test_start_agent_exists() {
    grep -q "start_agent()" "${AGENT_SCRIPT}"
}

test_stop_agent_exists() {
    grep -q "stop_agent()" "${AGENT_SCRIPT}"
}

test_restart_agent_exists() {
    grep -q "restart_agent()" "${AGENT_SCRIPT}"
}

test_show_status_exists() {
    grep -q "show_status()" "${AGENT_SCRIPT}"
}

test_list_agents_exists() {
    grep -q "list_agents()" "${AGENT_SCRIPT}"
}

test_start_all_exists() {
    grep -q "start_all()" "${AGENT_SCRIPT}"
}

test_stop_all_exists() {
    grep -q "stop_all()" "${AGENT_SCRIPT}"
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

test_script_has_core_agents_array() {
    grep -q "CORE_AGENTS=(" "${AGENT_SCRIPT}"
}

test_script_has_single_run_mode() {
    grep -q "SINGLE_RUN" "${AGENT_SCRIPT}"
}

# Run all tests
echo "Starting tests for agent_control.sh"
echo "==================================="

run_test "run_with_timeout function exists" test_run_with_timeout_exists 0
run_test "check_resource_limits function exists" test_check_resource_limits_exists 0
run_test "process_control_task function exists" test_process_control_task_exists 0
run_test "start_agent function exists" test_start_agent_exists 0
run_test "stop_agent function exists" test_stop_agent_exists 0
run_test "restart_agent function exists" test_restart_agent_exists 0
run_test "show_status function exists" test_show_status_exists 0
run_test "list_agents function exists" test_list_agents_exists 0
run_test "start_all function exists" test_start_all_exists 0
run_test "stop_all function exists" test_stop_all_exists 0
run_test "script has proper shebang" test_script_has_shebang 0
run_test "script sources shared functions" test_script_sources_shared_functions 0
run_test "script has agent variables" test_script_has_agent_variables 0
run_test "script has main processing loop" test_script_has_main_loop 0
run_test "script has core agents array" test_script_has_core_agents_array 0
run_test "script has single run mode" test_script_has_single_run_mode 0

# Summary
echo ""
echo "==================================="
echo "Test Summary for agent_control.sh:"
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
