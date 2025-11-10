#!/bin/bash
# Test suite for uiux_agent.sh
# This test suite validates the UI/UX agent functionality

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shell_test_framework.sh
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/uiux_agent.sh"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Script should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"
}

# Test 3: Script should have AGENT_NAME variable
test_has_agent_name() {
    assert_pattern_in_file "AGENT_NAME=\"UIUXAgent\"" "${AGENT_SCRIPT}"
}

# Test 4: Script should have LOG_FILE variable
test_has_log_file() {
    assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"
}

# Test 5: Script should have PROJECT variable
test_has_project() {
    assert_pattern_in_file "PROJECT=" "${AGENT_SCRIPT}"
}

# Test 6: Script should have get_project_from_task function
test_has_get_project_from_task() {
    assert_pattern_in_file "get_project_from_task\(\)" "${AGENT_SCRIPT}"
}

# Test 7: Script should have perform_ui_enhancements function
test_has_perform_ui_enhancements() {
    assert_pattern_in_file "perform_ui_enhancements\(\)" "${AGENT_SCRIPT}"
}

# Test 8: Script should have run_step function
test_has_run_step() {
    assert_pattern_in_file "run_step\(\)" "${AGENT_SCRIPT}"
}

# Test 9: Script should have process_assigned_tasks function
test_has_process_assigned_tasks() {
    assert_pattern_in_file "process_assigned_tasks\(\)" "${AGENT_SCRIPT}"
}

# Test 10: Script should have ensure_within_limits function
test_has_ensure_within_limits() {
    assert_pattern_in_file "ensure_within_limits\(\)" "${AGENT_SCRIPT}"
}

# Test 11: Script should have main while loop
test_has_main_loop() {
    assert_pattern_in_file "while true; do" "${AGENT_SCRIPT}"
}

# Test 12: Script should check for SINGLE_RUN mode
test_has_single_run_mode() {
    assert_pattern_in_file "SINGLE_RUN" "${AGENT_SCRIPT}"
}

# Test 13: Script should have sleep in main loop
test_has_sleep_in_loop() {
    assert_pattern_in_file "sleep.*SLEEP_INTERVAL" "${AGENT_SCRIPT}"
}

# Test 14: Script should have MAX_CONCURRENCY variable
test_has_max_concurrency() {
    assert_pattern_in_file "MAX_CONCURRENCY=" "${AGENT_SCRIPT}"
}

# Test 15: Script should have LOAD_THRESHOLD variable
test_has_load_threshold() {
    assert_pattern_in_file "LOAD_THRESHOLD=" "${AGENT_SCRIPT}"
}

# Test 16: Script should have WAIT_WHEN_BUSY variable
test_has_wait_when_busy() {
    assert_pattern_in_file "WAIT_WHEN_BUSY=" "${AGENT_SCRIPT}"
}

# Test 17: Script should have SLEEP_INTERVAL variable
test_has_sleep_interval() {
    assert_pattern_in_file "SLEEP_INTERVAL=" "${AGENT_SCRIPT}"
}

# Test 18: Script should have MIN_INTERVAL variable
test_has_min_interval() {
    assert_pattern_in_file "MIN_INTERVAL=" "${AGENT_SCRIPT}"
}

# Test 19: Script should have MAX_INTERVAL variable
test_has_max_interval() {
    assert_pattern_in_file "MAX_INTERVAL=" "${AGENT_SCRIPT}"
}

# Test 20: Script should use jq for JSON processing
test_uses_jq() {
    assert_pattern_in_file "jq" "${AGENT_SCRIPT}"
}

# Run all tests
run_tests() {
    echo "Running tests for uiux_agent.sh..."
    echo "Test Results for uiux_agent.sh" >"${SCRIPT_DIR}/test_results_uiux_agent.txt"
    echo "Generated: $(date)" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: uiux_agent.sh is executable"
        echo "✅ Test 1 PASSED: uiux_agent.sh is executable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: uiux_agent.sh is not executable"
        echo "❌ Test 1 FAILED: uiux_agent.sh is not executable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 2: Should source shared_functions.sh
    ((total_tests++))
    if assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Sources shared_functions.sh"
        echo "✅ Test 2 PASSED: Sources shared_functions.sh" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not source shared_functions.sh"
        echo "❌ Test 2 FAILED: Does not source shared_functions.sh" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 3: Should define AGENT_NAME variable
    ((total_tests++))
    if assert_pattern_in_file "AGENT_NAME=\"UIUXAgent\"" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Defines AGENT_NAME variable"
        echo "✅ Test 3 PASSED: Defines AGENT_NAME variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not define AGENT_NAME variable"
        echo "❌ Test 3 FAILED: Does not define AGENT_NAME variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 4: Should define LOG_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines LOG_FILE variable"
        echo "✅ Test 4 PASSED: Defines LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define LOG_FILE variable"
        echo "❌ Test 4 FAILED: Does not define LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 5: Should define PROJECT variable
    ((total_tests++))
    if assert_pattern_in_file "PROJECT=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Defines PROJECT variable"
        echo "✅ Test 5 PASSED: Defines PROJECT variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not define PROJECT variable"
        echo "❌ Test 5 FAILED: Does not define PROJECT variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 6: Should have get_project_from_task function
    ((total_tests++))
    if assert_pattern_in_file "get_project_from_task\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Has get_project_from_task function"
        echo "✅ Test 6 PASSED: Has get_project_from_task function" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Missing get_project_from_task function"
        echo "❌ Test 6 FAILED: Missing get_project_from_task function" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 7: Should have perform_ui_enhancements function
    ((total_tests++))
    if assert_pattern_in_file "perform_ui_enhancements\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Has perform_ui_enhancements function"
        echo "✅ Test 7 PASSED: Has perform_ui_enhancements function" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Missing perform_ui_enhancements function"
        echo "❌ Test 7 FAILED: Missing perform_ui_enhancements function" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 8: Should have run_step function
    ((total_tests++))
    if assert_pattern_in_file "run_step\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Has run_step function"
        echo "✅ Test 8 PASSED: Has run_step function" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Missing run_step function"
        echo "❌ Test 8 FAILED: Missing run_step function" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 9: Should have process_assigned_tasks function
    ((total_tests++))
    if assert_pattern_in_file "process_assigned_tasks\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Has process_assigned_tasks function"
        echo "✅ Test 9 PASSED: Has process_assigned_tasks function" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Missing process_assigned_tasks function"
        echo "❌ Test 9 FAILED: Missing process_assigned_tasks function" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 10: Should have ensure_within_limits function
    ((total_tests++))
    if assert_pattern_in_file "ensure_within_limits\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Has ensure_within_limits function"
        echo "✅ Test 10 PASSED: Has ensure_within_limits function" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Missing ensure_within_limits function"
        echo "❌ Test 10 FAILED: Missing ensure_within_limits function" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 11: Should have main loop with while true
    ((total_tests++))
    if assert_pattern_in_file "while true; do" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Has main loop with while true"
        echo "✅ Test 11 PASSED: Has main loop with while true" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Missing main loop"
        echo "❌ Test 11 FAILED: Missing main loop" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 12: Should check for SINGLE_RUN mode
    ((total_tests++))
    if assert_pattern_in_file "SINGLE_RUN" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Checks for SINGLE_RUN mode"
        echo "✅ Test 12 PASSED: Checks for SINGLE_RUN mode" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not check for SINGLE_RUN mode"
        echo "❌ Test 12 FAILED: Does not check for SINGLE_RUN mode" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 13: Should have sleep in main loop
    ((total_tests++))
    if assert_pattern_in_file "sleep.*SLEEP_INTERVAL" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Has sleep with SLEEP_INTERVAL in main loop"
        echo "✅ Test 13 PASSED: Has sleep with SLEEP_INTERVAL in main loop" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Missing sleep in main loop"
        echo "❌ Test 13 FAILED: Missing sleep in main loop" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 14: Should have MAX_CONCURRENCY variable
    ((total_tests++))
    if assert_pattern_in_file "MAX_CONCURRENCY=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Has MAX_CONCURRENCY variable"
        echo "✅ Test 14 PASSED: Has MAX_CONCURRENCY variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Missing MAX_CONCURRENCY variable"
        echo "❌ Test 14 FAILED: Missing MAX_CONCURRENCY variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 15: Should have LOAD_THRESHOLD variable
    ((total_tests++))
    if assert_pattern_in_file "LOAD_THRESHOLD=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Has LOAD_THRESHOLD variable"
        echo "✅ Test 15 PASSED: Has LOAD_THRESHOLD variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Missing LOAD_THRESHOLD variable"
        echo "❌ Test 15 FAILED: Missing LOAD_THRESHOLD variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 16: Should have WAIT_WHEN_BUSY variable
    ((total_tests++))
    if assert_pattern_in_file "WAIT_WHEN_BUSY=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Has WAIT_WHEN_BUSY variable"
        echo "✅ Test 16 PASSED: Has WAIT_WHEN_BUSY variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Missing WAIT_WHEN_BUSY variable"
        echo "❌ Test 16 FAILED: Missing WAIT_WHEN_BUSY variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 17: Should have SLEEP_INTERVAL variable
    ((total_tests++))
    if assert_pattern_in_file "SLEEP_INTERVAL=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Has SLEEP_INTERVAL variable"
        echo "✅ Test 17 PASSED: Has SLEEP_INTERVAL variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Missing SLEEP_INTERVAL variable"
        echo "❌ Test 17 FAILED: Missing SLEEP_INTERVAL variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 18: Should have MIN_INTERVAL variable
    ((total_tests++))
    if assert_pattern_in_file "MIN_INTERVAL=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Has MIN_INTERVAL variable"
        echo "✅ Test 18 PASSED: Has MIN_INTERVAL variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Missing MIN_INTERVAL variable"
        echo "❌ Test 18 FAILED: Missing MIN_INTERVAL variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 19: Should have MAX_INTERVAL variable
    ((total_tests++))
    if assert_pattern_in_file "MAX_INTERVAL=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Has MAX_INTERVAL variable"
        echo "✅ Test 19 PASSED: Has MAX_INTERVAL variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Missing MAX_INTERVAL variable"
        echo "❌ Test 19 FAILED: Missing MAX_INTERVAL variable" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Test 20: Should use jq for JSON processing
    ((total_tests++))
    if assert_pattern_in_file "jq" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Uses jq for JSON processing"
        echo "✅ Test 20 PASSED: Uses jq for JSON processing" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Does not use jq for JSON processing"
        echo "❌ Test 20 FAILED: Does not use jq for JSON processing" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for uiux_agent.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_uiux_agent.txt"
    fi
}

# Run the tests
run_tests
