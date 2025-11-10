#!/bin/bash
# Test suite for dashboard_launcher.sh
# This test suite validates the dashboard launcher functionality

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shell_test_framework.sh
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/dashboard_launcher.sh"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Script should define SCRIPT_DIR variable
test_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

# Test 3: Script should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"
}

# Test 4: Script should define DASHBOARD_AGENT variable
test_defines_dashboard_agent() {
    assert_pattern_in_file "DASHBOARD_AGENT=" "${AGENT_SCRIPT}"
}

# Test 5: Script should define DASHBOARD_PID_FILE variable
test_defines_dashboard_pid_file() {
    assert_pattern_in_file "DASHBOARD_PID_FILE=" "${AGENT_SCRIPT}"
}

# Test 6: Script should define LOG_FILE variable
test_defines_log_file() {
    assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"
}

# Test 7: Script should define color constants
test_defines_color_constants() {
    assert_pattern_in_file "RED=" "${AGENT_SCRIPT}"
}

# Test 8: Script should define log_message function
test_defines_log_message_function() {
    assert_pattern_in_file "log_message\(\)" "${AGENT_SCRIPT}"
}

# Test 9: Script should define is_dashboard_running function
test_defines_is_dashboard_running_function() {
    assert_pattern_in_file "is_dashboard_running\(\)" "${AGENT_SCRIPT}"
}

# Test 10: Script should define start_dashboard function
test_defines_start_dashboard_function() {
    assert_pattern_in_file "start_dashboard\(\)" "${AGENT_SCRIPT}"
}

# Test 11: Script should define stop_dashboard function
test_defines_stop_dashboard_function() {
    assert_pattern_in_file "stop_dashboard\(\)" "${AGENT_SCRIPT}"
}

# Test 12: Script should define restart_dashboard function
test_defines_restart_dashboard_function() {
    assert_pattern_in_file "restart_dashboard\(\)" "${AGENT_SCRIPT}"
}

# Test 13: Script should define show_status function
test_defines_show_status_function() {
    assert_pattern_in_file "show_status\(\)" "${AGENT_SCRIPT}"
}

# Test 14: Script should define show_help function
test_defines_show_help_function() {
    assert_pattern_in_file "show_help\(\)" "${AGENT_SCRIPT}"
}

# Test 15: Script should use case statement for command handling
test_uses_case_statement() {
    assert_pattern_in_file "case.*start" "${AGENT_SCRIPT}"
}

# Test 16: Should handle start command
test_handles_start_command() {
    assert_pattern_in_file "start" "${AGENT_SCRIPT}"
}

# Test 17: Should handle stop command
test_handles_stop_command() {
    assert_pattern_in_file "stop" "${AGENT_SCRIPT}"
}

# Test 18: Should handle restart command
test_handles_restart_command() {
    assert_pattern_in_file "restart" "${AGENT_SCRIPT}"
}

# Test 19: Should handle status command
test_handles_status_command() {
    assert_pattern_in_file "status" "${AGENT_SCRIPT}"
}

# Test 20: Script should handle help command
test_handles_help_command() {
    assert_pattern_in_file "\"help\"" "${AGENT_SCRIPT}"
}

# Run all tests
run_tests() {
    echo "Running tests for dashboard_launcher.sh..."
    echo "Test Results for dashboard_launcher.sh" >"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
    echo "Generated: $(date)" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: dashboard_launcher.sh is executable"
        echo "✅ Test 1 PASSED: dashboard_launcher.sh is executable" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: dashboard_launcher.sh is not executable"
        echo "❌ Test 1 FAILED: dashboard_launcher.sh is not executable" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 2: Should define SCRIPT_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable"
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable"
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 3: Should source shared_functions.sh
    ((total_tests++))
    if assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Sources shared_functions.sh"
        echo "✅ Test 3 PASSED: Sources shared_functions.sh" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not source shared_functions.sh"
        echo "❌ Test 3 FAILED: Does not source shared_functions.sh" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 4: Should define DASHBOARD_AGENT variable
    ((total_tests++))
    if assert_pattern_in_file "DASHBOARD_AGENT=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines DASHBOARD_AGENT variable"
        echo "✅ Test 4 PASSED: Defines DASHBOARD_AGENT variable" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define DASHBOARD_AGENT variable"
        echo "❌ Test 4 FAILED: Does not define DASHBOARD_AGENT variable" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 5: Should define DASHBOARD_PID_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "DASHBOARD_PID_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Defines DASHBOARD_PID_FILE variable"
        echo "✅ Test 5 PASSED: Defines DASHBOARD_PID_FILE variable" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not define DASHBOARD_PID_FILE variable"
        echo "❌ Test 5 FAILED: Does not define DASHBOARD_PID_FILE variable" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 6: Should define LOG_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Defines LOG_FILE variable"
        echo "✅ Test 6 PASSED: Defines LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not define LOG_FILE variable"
        echo "❌ Test 6 FAILED: Does not define LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 7: Should define color constants
    ((total_tests++))
    if assert_pattern_in_file "RED=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Defines color constants"
        echo "✅ Test 7 PASSED: Defines color constants" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not define color constants"
        echo "❌ Test 7 FAILED: Does not define color constants" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 8: Should define log_message function
    ((total_tests++))
    if assert_pattern_in_file "log_message\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Defines log_message function"
        echo "✅ Test 8 PASSED: Defines log_message function" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Does not define log_message function"
        echo "❌ Test 8 FAILED: Does not define log_message function" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 9: Should define is_dashboard_running function
    ((total_tests++))
    if assert_pattern_in_file "is_dashboard_running\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Defines is_dashboard_running function"
        echo "✅ Test 9 PASSED: Defines is_dashboard_running function" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Does not define is_dashboard_running function"
        echo "❌ Test 9 FAILED: Does not define is_dashboard_running function" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 10: Should define start_dashboard function
    ((total_tests++))
    if assert_pattern_in_file "start_dashboard\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Defines start_dashboard function"
        echo "✅ Test 10 PASSED: Defines start_dashboard function" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not define start_dashboard function"
        echo "❌ Test 10 FAILED: Does not define start_dashboard function" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 11: Should define stop_dashboard function
    ((total_tests++))
    if assert_pattern_in_file "stop_dashboard\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Defines stop_dashboard function"
        echo "✅ Test 11 PASSED: Defines stop_dashboard function" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not define stop_dashboard function"
        echo "❌ Test 11 FAILED: Does not define stop_dashboard function" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 12: Should define restart_dashboard function
    ((total_tests++))
    if assert_pattern_in_file "restart_dashboard\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Defines restart_dashboard function"
        echo "✅ Test 12 PASSED: Defines restart_dashboard function" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not define restart_dashboard function"
        echo "❌ Test 12 FAILED: Does not define restart_dashboard function" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 13: Should define show_status function
    ((total_tests++))
    if assert_pattern_in_file "show_status\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Defines show_status function"
        echo "✅ Test 13 PASSED: Defines show_status function" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not define show_status function"
        echo "❌ Test 13 FAILED: Does not define show_status function" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 14: Should define show_help function
    ((total_tests++))
    if assert_pattern_in_file "show_help\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Defines show_help function"
        echo "✅ Test 14 PASSED: Defines show_help function" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not define show_help function"
        echo "❌ Test 14 FAILED: Does not define show_help function" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 15: Should use case statement for command handling
    ((total_tests++))
    if assert_pattern_in_file "case.*start" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Uses case statement for command handling"
        echo "✅ Test 15 PASSED: Uses case statement for command handling" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not use case statement for command handling"
        echo "❌ Test 15 FAILED: Does not use case statement for command handling" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 16: Should handle start command
    ((total_tests++))
    if assert_pattern_in_file "start" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Handles start command"
        echo "✅ Test 16 PASSED: Handles start command" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Does not handle start command"
        echo "❌ Test 16 FAILED: Does not handle start command" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 17: Should handle stop command
    ((total_tests++))
    if assert_pattern_in_file "stop" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Handles stop command"
        echo "✅ Test 17 PASSED: Handles stop command" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Does not handle stop command"
        echo "❌ Test 17 FAILED: Does not handle stop command" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 18: Should handle restart command
    ((total_tests++))
    if assert_pattern_in_file "restart" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Handles restart command"
        echo "✅ Test 18 PASSED: Handles restart command" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Does not handle restart command"
        echo "❌ Test 18 FAILED: Does not handle restart command" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 19: Should handle status command
    ((total_tests++))
    if assert_pattern_in_file "status" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Handles status command"
        echo "✅ Test 19 PASSED: Handles status command" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Does not handle status command"
        echo "❌ Test 19 FAILED: Does not handle status command" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Test 20: Should handle help command
    ((total_tests++))
    if assert_pattern_in_file "\"help\"" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Handles help command"
        echo "✅ Test 20 PASSED: Handles help command" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Does not handle help command"
        echo "❌ Test 20 FAILED: Does not handle help command" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for dashboard_launcher.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_dashboard_launcher.txt"
    fi
}

# Run the tests
run_tests
