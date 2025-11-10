#!/bin/bash
# Test suite for configure_auto_restart.sh
# This test suite validates the auto-restart configuration functionality

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shell_test_framework.sh
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/configure_auto_restart.sh"

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

# Test 4: Script should have usage function
test_has_usage_function() {
    assert_pattern_in_file "usage\(\)" "${AGENT_SCRIPT}"
}

# Test 5: Script should check argument count
test_checks_argument_count() {
    assert_pattern_in_file '\[\[ \$\# -lt 1 \]\]' "${AGENT_SCRIPT}"
}

# Test 6: Script should handle enable command
test_handles_enable_command() {
    assert_pattern_in_file "enable\)" "${AGENT_SCRIPT}"
}

# Test 7: Script should handle disable command
test_handles_disable_command() {
    assert_pattern_in_file "disable\)" "${AGENT_SCRIPT}"
}

# Test 8: Script should handle status command
test_handles_status_command() {
    assert_pattern_in_file "status\)" "${AGENT_SCRIPT}"
}

# Test 9: Script should validate agent name for enable
test_validates_agent_name_enable() {
    assert_pattern_in_file "Agent name required" "${AGENT_SCRIPT}"
}

# Test 10: Script should validate agent name for disable
test_validates_agent_name_disable() {
    assert_pattern_in_file "Agent name required" "${AGENT_SCRIPT}"
}

# Test 11: Script should call enable_auto_restart function
test_calls_enable_auto_restart() {
    assert_pattern_in_file "enable_auto_restart" "${AGENT_SCRIPT}"
}

# Test 12: Script should call disable_auto_restart function
test_calls_disable_auto_restart() {
    assert_pattern_in_file "disable_auto_restart" "${AGENT_SCRIPT}"
}

# Test 13: Script should call should_auto_restart function
test_calls_should_auto_restart() {
    assert_pattern_in_file "should_auto_restart" "${AGENT_SCRIPT}"
}

# Test 14: Script should iterate through agent files
test_iterates_agent_files() {
    assert_pattern_in_file "for agent_file in" "${AGENT_SCRIPT}"
}

# Test 15: Script should skip shared_functions.sh
test_skips_shared_functions() {
    assert_pattern_in_file "shared_functions\.sh.*continue" "${AGENT_SCRIPT}"
}

# Test 16: Script should skip configure_auto_restart.sh
test_skips_configure_script() {
    assert_pattern_in_file "configure_auto_restart\.sh.*continue" "${AGENT_SCRIPT}"
}

# Test 17: Script should use basename to get agent name
test_uses_basename() {
    assert_pattern_in_file "basename" "${AGENT_SCRIPT}"
}

# Test 18: Script should display enabled status
test_displays_enabled_status() {
    assert_pattern_in_file "ENABLED" "${AGENT_SCRIPT}"
}

# Test 19: Script should display disabled status
test_displays_disabled_status() {
    assert_pattern_in_file "DISABLED" "${AGENT_SCRIPT}"
}

# Test 20: Script should handle unknown commands
test_handles_unknown_commands() {
    assert_pattern_in_file "Unknown command" "${AGENT_SCRIPT}"
}

# Run all tests
run_tests() {
    echo "Running tests for configure_auto_restart.sh..."
    echo "Test Results for configure_auto_restart.sh" >"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
    echo "Generated: $(date)" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: configure_auto_restart.sh is executable"
        echo "✅ Test 1 PASSED: configure_auto_restart.sh is executable" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: configure_auto_restart.sh is not executable"
        echo "❌ Test 1 FAILED: configure_auto_restart.sh is not executable" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 2: Should define SCRIPT_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable"
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable"
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 3: Should source shared_functions.sh
    ((total_tests++))
    if assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Sources shared_functions.sh"
        echo "✅ Test 3 PASSED: Sources shared_functions.sh" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not source shared_functions.sh"
        echo "❌ Test 3 FAILED: Does not source shared_functions.sh" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 4: Should have usage function
    ((total_tests++))
    if assert_pattern_in_file "usage\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Has usage function"
        echo "✅ Test 4 PASSED: Has usage function" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Missing usage function"
        echo "❌ Test 4 FAILED: Missing usage function" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 5: Should check argument count
    ((total_tests++))
    if assert_pattern_in_file '\[\[ \$\# -lt 1 \]\]' "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Checks argument count"
        echo "✅ Test 5 PASSED: Checks argument count" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not check argument count"
        echo "❌ Test 5 FAILED: Does not check argument count" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 6: Should handle enable command
    ((total_tests++))
    if assert_pattern_in_file "enable)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Handles enable command"
        echo "✅ Test 6 PASSED: Handles enable command" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not handle enable command"
        echo "❌ Test 6 FAILED: Does not handle enable command" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 7: Should handle disable command
    ((total_tests++))
    if assert_pattern_in_file "disable)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Handles disable command"
        echo "✅ Test 7 PASSED: Handles disable command" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not handle disable command"
        echo "❌ Test 7 FAILED: Does not handle disable command" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 8: Should handle status command
    ((total_tests++))
    if assert_pattern_in_file "status)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Handles status command"
        echo "✅ Test 8 PASSED: Handles status command" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Does not handle status command"
        echo "❌ Test 8 FAILED: Does not handle status command" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 9: Should validate agent name for enable
    ((total_tests++))
    if assert_pattern_in_file "Agent name required" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Validates agent name for enable"
        echo "✅ Test 9 PASSED: Validates agent name for enable" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Does not validate agent name for enable"
        echo "❌ Test 9 FAILED: Does not validate agent name for enable" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 10: Should validate agent name for disable
    ((total_tests++))
    if assert_pattern_in_file "Agent name required" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Validates agent name for disable"
        echo "✅ Test 10 PASSED: Validates agent name for disable" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not validate agent name for disable"
        echo "❌ Test 10 FAILED: Does not validate agent name for disable" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 11: Should call enable_auto_restart function
    ((total_tests++))
    if assert_pattern_in_file "enable_auto_restart" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Calls enable_auto_restart function"
        echo "✅ Test 11 PASSED: Calls enable_auto_restart function" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not call enable_auto_restart function"
        echo "❌ Test 11 FAILED: Does not call enable_auto_restart function" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 12: Should call disable_auto_restart function
    ((total_tests++))
    if assert_pattern_in_file "disable_auto_restart" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Calls disable_auto_restart function"
        echo "✅ Test 12 PASSED: Calls disable_auto_restart function" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not call disable_auto_restart function"
        echo "❌ Test 12 FAILED: Does not call disable_auto_restart function" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 13: Should call should_auto_restart function
    ((total_tests++))
    if assert_pattern_in_file "should_auto_restart" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Calls should_auto_restart function"
        echo "✅ Test 13 PASSED: Calls should_auto_restart function" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not call should_auto_restart function"
        echo "❌ Test 13 FAILED: Does not call should_auto_restart function" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 14: Should iterate through agent files
    ((total_tests++))
    if assert_pattern_in_file "for agent_file in" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Iterates through agent files"
        echo "✅ Test 14 PASSED: Iterates through agent files" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not iterate through agent files"
        echo "❌ Test 14 FAILED: Does not iterate through agent files" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 15: Should skip shared_functions.sh
    ((total_tests++))
    if assert_pattern_in_file "shared_functions\.sh.*continue" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Skips shared_functions.sh"
        echo "✅ Test 15 PASSED: Skips shared_functions.sh" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not skip shared_functions.sh"
        echo "❌ Test 15 FAILED: Does not skip shared_functions.sh" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 16: Should skip configure_auto_restart.sh
    ((total_tests++))
    if assert_pattern_in_file "configure_auto_restart\.sh.*continue" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Skips configure_auto_restart.sh"
        echo "✅ Test 16 PASSED: Skips configure_auto_restart.sh" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Does not skip configure_auto_restart.sh"
        echo "❌ Test 16 FAILED: Does not skip configure_auto_restart.sh" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 17: Should use basename to get agent name
    ((total_tests++))
    if assert_pattern_in_file "basename" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Uses basename to get agent name"
        echo "✅ Test 17 PASSED: Uses basename to get agent name" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Does not use basename to get agent name"
        echo "❌ Test 17 FAILED: Does not use basename to get agent name" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 18: Should display enabled status
    ((total_tests++))
    if assert_pattern_in_file "ENABLED" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Displays enabled status"
        echo "✅ Test 18 PASSED: Displays enabled status" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Does not display enabled status"
        echo "❌ Test 18 FAILED: Does not display enabled status" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 19: Should display disabled status
    ((total_tests++))
    if assert_pattern_in_file "DISABLED" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Displays disabled status"
        echo "✅ Test 19 PASSED: Displays disabled status" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Does not display disabled status"
        echo "❌ Test 19 FAILED: Does not display disabled status" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Test 20: Should handle unknown commands
    ((total_tests++))
    if assert_pattern_in_file "Unknown command" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Handles unknown commands"
        echo "✅ Test 20 PASSED: Handles unknown commands" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Does not handle unknown commands"
        echo "❌ Test 20 FAILED: Does not handle unknown commands" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for configure_auto_restart.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_configure_auto_restart.txt"
    fi
}

# Run the tests
run_tests
