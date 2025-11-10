#!/bin/bash

# Test file for agent_codegen.sh
# This file contains comprehensive tests for the codegen agent functionality

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shell_test_framework.sh"

# Agent script to test
AGENT_SCRIPT="${SCRIPT_DIR}/agents/agent_codegen.sh"
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
test_ensure_within_limits_exists() {
    grep -q "ensure_within_limits()" "${AGENT_SCRIPT}"
}

test_check_resource_limits_exists() {
    grep -q "check_resource_limits()" "${AGENT_SCRIPT}"
}

test_initialize_project_context_exists() {
    grep -q "initialize_project_context()" "${AGENT_SCRIPT}"
}

test_run_step_exists() {
    grep -q "run_step()" "${AGENT_SCRIPT}"
}

test_record_task_success_exists() {
    grep -q "record_task_success()" "${AGENT_SCRIPT}"
}

test_maybe_update_status_exists() {
    grep -q "maybe_update_status()" "${AGENT_SCRIPT}"
}

test_update_task_status_exists() {
    grep -q "update_task_status()" "${AGENT_SCRIPT}"
}

test_notify_completion_exists() {
    grep -q "notify_completion()" "${AGENT_SCRIPT}"
}

test_has_processed_task_exists() {
    grep -q "has_processed_task()" "${AGENT_SCRIPT}"
}

test_fetch_task_description_exists() {
    grep -q "fetch_task_description()" "${AGENT_SCRIPT}"
}

test_run_codegen_pipeline_exists() {
    grep -q "run_codegen_pipeline()" "${AGENT_SCRIPT}"
}

test_main_exists() {
    grep -q "main()" "${AGENT_SCRIPT}"
}

test_process_codegen_task_exists() {
    grep -q "process_codegen_task()" "${AGENT_SCRIPT}"
}

test_perform_full_codegen_exists() {
    grep -q "perform_full_codegen()" "${AGENT_SCRIPT}"
}

test_perform_ai_automation_exists() {
    grep -q "perform_ai_automation()" "${AGENT_SCRIPT}"
}

test_perform_autofix_exists() {
    grep -q "perform_autofix()" "${AGENT_SCRIPT}"
}

test_perform_enhancement_exists() {
    grep -q "perform_enhancement()" "${AGENT_SCRIPT}"
}

test_perform_validation_exists() {
    grep -q "perform_validation()" "${AGENT_SCRIPT}"
}

test_perform_codegen_tests_exists() {
    grep -q "perform_codegen_tests()" "${AGENT_SCRIPT}"
}

test_run_with_timeout_exists() {
    grep -q "run_with_timeout()" "${AGENT_SCRIPT}"
}

test_log_message_exists() {
    grep -q "log_message()" "${AGENT_SCRIPT}"
}

# Test script structure
test_script_has_shebang() {
    head -1 "${AGENT_SCRIPT}" | grep -q "^#!/bin/bash"
}

test_script_sources_shared_functions() {
    grep -q "source.*shared_functions.sh" "${AGENT_SCRIPT}"
}

test_script_has_agent_variables() {
    grep -q "AGENT_NAME=" "${AGENT_SCRIPT}" && grep -q "AGENT_LABEL=" "${AGENT_SCRIPT}"
}

test_script_has_main_loop() {
    grep -q "while true; do" "${AGENT_SCRIPT}"
}

# Run all tests
echo "Starting tests for agent_codegen.sh"
echo "==================================="

run_test "ensure_within_limits function exists" test_ensure_within_limits_exists 0
run_test "check_resource_limits function exists" test_check_resource_limits_exists 0
run_test "initialize_project_context function exists" test_initialize_project_context_exists 0
run_test "run_step function exists" test_run_step_exists 0
run_test "record_task_success function exists" test_record_task_success_exists 0
run_test "maybe_update_status function exists" test_maybe_update_status_exists 0
run_test "update_task_status function exists" test_update_task_status_exists 0
run_test "notify_completion function exists" test_notify_completion_exists 0
run_test "has_processed_task function exists" test_has_processed_task_exists 0
run_test "fetch_task_description function exists" test_fetch_task_description_exists 0
run_test "run_codegen_pipeline function exists" test_run_codegen_pipeline_exists 0
run_test "main function exists" test_main_exists 0
run_test "process_codegen_task function exists" test_process_codegen_task_exists 0
run_test "perform_full_codegen function exists" test_perform_full_codegen_exists 0
run_test "perform_ai_automation function exists" test_perform_ai_automation_exists 0
run_test "perform_autofix function exists" test_perform_autofix_exists 0
run_test "perform_enhancement function exists" test_perform_enhancement_exists 0
run_test "perform_validation function exists" test_perform_validation_exists 0
run_test "perform_codegen_tests function exists" test_perform_codegen_tests_exists 0
run_test "run_with_timeout function exists" test_run_with_timeout_exists 0
run_test "log_message function exists" test_log_message_exists 0
run_test "script has proper shebang" test_script_has_shebang 0
run_test "script sources shared functions" test_script_sources_shared_functions 0
run_test "script has agent variables" test_script_has_agent_variables 0
run_test "script has main processing loop" test_script_has_main_loop 0

# Summary
echo ""
echo "==================================="
echo "Test Summary for agent_codegen.sh:"
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
