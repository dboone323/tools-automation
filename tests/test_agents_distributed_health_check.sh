#!/bin/bash
# Test suite for distributed_health_check.sh
# This test suite validates the distributed health check functionality

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shell_test_framework.sh
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/distributed_health_check.sh"

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

# Test 4: Script should define REMOTE_HOSTS array
test_defines_remote_hosts() {
    assert_pattern_in_file "REMOTE_HOSTS=" "${AGENT_SCRIPT}"
}

# Test 5: Script should define AGENTS_DIR variable
test_defines_agents_dir() {
    assert_pattern_in_file "AGENTS_DIR=" "${AGENT_SCRIPT}"
}

# Test 6: Script should use for loop for remote hosts
test_uses_for_loop() {
    assert_pattern_in_file "for.*host.*REMOTE_HOSTS" "${AGENT_SCRIPT}"
}

# Test 7: Script should iterate over remote hosts array
test_iterates_remote_hosts() {
    assert_pattern_in_file "REMOTE_HOSTS\[@\]" "${AGENT_SCRIPT}"
}

# Test 8: Script should check each host
test_checks_each_host() {
    assert_pattern_in_file "Checking.*host" "${AGENT_SCRIPT}"
}

# Test 9: Script should define log_path variable
test_defines_log_path() {
    assert_pattern_in_file "log_path=" "${AGENT_SCRIPT}"
}

# Test 10: Script should use ssh command
test_uses_ssh_command() {
    assert_pattern_in_file "ssh.*host" "${AGENT_SCRIPT}"
}

# Test 11: Script should use tail command
test_uses_tail_command() {
    assert_pattern_in_file "tail.*-n.*10" "${AGENT_SCRIPT}"
}

# Test 12: Script should check supervisor_remote.log
test_checks_supervisor_remote_log() {
    assert_pattern_in_file "supervisor_remote\.log" "${AGENT_SCRIPT}"
}

# Test 13: Script should use logs directory
test_uses_logs_directory() {
    assert_pattern_in_file "logs/" "${AGENT_SCRIPT}"
}

# Test 14: Script should use AGENTS_DIR in log path
test_uses_agents_dir_in_log_path() {
    assert_pattern_in_file "AGENTS_DIR.*logs" "${AGENT_SCRIPT}"
}

# Test 15: Script should use dirname command
test_uses_dirname_command() {
    assert_pattern_in_file "dirname.*\$0" "${AGENT_SCRIPT}"
}

# Test 16: Script should use echo for host checking message
test_uses_echo_for_host_checking() {
    assert_pattern_in_file "echo.*Checking" "${AGENT_SCRIPT}"
}

# Test 17: Script should use variable expansion for host
test_uses_variable_expansion_for_host() {
    assert_pattern_in_file "host" "${AGENT_SCRIPT}"
}

# Test 18: Script should use double quotes for array elements
test_uses_double_quotes_for_array() {
    assert_pattern_in_file "\"host1\.example\.com\"" "${AGENT_SCRIPT}"
}

# Test 19: Should use parentheses for array declaration
test_uses_parentheses_for_array_declaration() {
    assert_pattern_in_file "REMOTE_HOSTS=.*(" "${AGENT_SCRIPT}"
}

# Test 20: Script should use done to close for loop
test_uses_done_to_close_loop() {
    assert_pattern_in_file "done" "${AGENT_SCRIPT}"
}

# Run all tests
run_tests() {
    echo "Running tests for distributed_health_check.sh..."
    echo "Test Results for distributed_health_check.sh" >"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
    echo "Generated: $(date)" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: distributed_health_check.sh is executable"
        echo "✅ Test 1 PASSED: distributed_health_check.sh is executable" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: distributed_health_check.sh is not executable"
        echo "❌ Test 1 FAILED: distributed_health_check.sh is not executable" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 2: Should define SCRIPT_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable"
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable"
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 3: Should source shared_functions.sh
    ((total_tests++))
    if assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Sources shared_functions.sh"
        echo "✅ Test 3 PASSED: Sources shared_functions.sh" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not source shared_functions.sh"
        echo "❌ Test 3 FAILED: Does not source shared_functions.sh" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 4: Should define REMOTE_HOSTS array
    ((total_tests++))
    if assert_pattern_in_file "REMOTE_HOSTS=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines REMOTE_HOSTS array"
        echo "✅ Test 4 PASSED: Defines REMOTE_HOSTS array" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define REMOTE_HOSTS array"
        echo "❌ Test 4 FAILED: Does not define REMOTE_HOSTS array" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 5: Should define AGENTS_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "AGENTS_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Defines AGENTS_DIR variable"
        echo "✅ Test 5 PASSED: Defines AGENTS_DIR variable" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not define AGENTS_DIR variable"
        echo "❌ Test 5 FAILED: Does not define AGENTS_DIR variable" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 6: Should use for loop for remote hosts
    ((total_tests++))
    if assert_pattern_in_file "for.*host.*REMOTE_HOSTS" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Uses for loop for remote hosts"
        echo "✅ Test 6 PASSED: Uses for loop for remote hosts" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not use for loop for remote hosts"
        echo "❌ Test 6 FAILED: Does not use for loop for remote hosts" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 7: Should iterate over remote hosts array
    ((total_tests++))
    if assert_pattern_in_file "REMOTE_HOSTS\[@\]" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Iterates over remote hosts array"
        echo "✅ Test 7 PASSED: Iterates over remote hosts array" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not iterate over remote hosts array"
        echo "❌ Test 7 FAILED: Does not iterate over remote hosts array" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 8: Should check each host
    ((total_tests++))
    if assert_pattern_in_file "Checking.*host" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Checks each host"
        echo "✅ Test 8 PASSED: Checks each host" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Does not check each host"
        echo "❌ Test 8 FAILED: Does not check each host" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 9: Should define log_path variable
    ((total_tests++))
    if assert_pattern_in_file "log_path=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Defines log_path variable"
        echo "✅ Test 9 PASSED: Defines log_path variable" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Does not define log_path variable"
        echo "❌ Test 9 FAILED: Does not define log_path variable" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 10: Should use ssh command
    ((total_tests++))
    if assert_pattern_in_file "ssh.*host" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Uses ssh command"
        echo "✅ Test 10 PASSED: Uses ssh command" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not use ssh command"
        echo "❌ Test 10 FAILED: Does not use ssh command" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 11: Should use tail command
    ((total_tests++))
    if assert_pattern_in_file "tail.*-n.*10" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Uses tail command"
        echo "✅ Test 11 PASSED: Uses tail command" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not use tail command"
        echo "❌ Test 11 FAILED: Does not use tail command" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 12: Should check supervisor_remote.log
    ((total_tests++))
    if assert_pattern_in_file "supervisor_remote\.log" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Checks supervisor_remote.log"
        echo "✅ Test 12 PASSED: Checks supervisor_remote.log" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not check supervisor_remote.log"
        echo "❌ Test 12 FAILED: Does not check supervisor_remote.log" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 13: Should use logs directory
    ((total_tests++))
    if assert_pattern_in_file "logs/" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Uses logs directory"
        echo "✅ Test 13 PASSED: Uses logs directory" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not use logs directory"
        echo "❌ Test 13 FAILED: Does not use logs directory" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 14: Should use AGENTS_DIR in log path
    ((total_tests++))
    if assert_pattern_in_file "AGENTS_DIR.*logs" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Uses AGENTS_DIR in log path"
        echo "✅ Test 14 PASSED: Uses AGENTS_DIR in log path" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not use AGENTS_DIR in log path"
        echo "❌ Test 14 FAILED: Does not use AGENTS_DIR in log path" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 15: Should use dirname command
    ((total_tests++))
    if assert_pattern_in_file "dirname.*\$0" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Uses dirname command"
        echo "✅ Test 15 PASSED: Uses dirname command" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not use dirname command"
        echo "❌ Test 15 FAILED: Does not use dirname command" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 16: Should use echo for host checking message
    ((total_tests++))
    if assert_pattern_in_file "echo.*Checking" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Uses echo for host checking message"
        echo "✅ Test 16 PASSED: Uses echo for host checking message" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Does not use echo for host checking message"
        echo "❌ Test 16 FAILED: Does not use echo for host checking message" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 17: Should use variable expansion for host
    ((total_tests++))
    if assert_pattern_in_file "host" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Uses variable expansion for host"
        echo "✅ Test 17 PASSED: Uses variable expansion for host" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Does not use variable expansion for host"
        echo "❌ Test 17 FAILED: Does not use variable expansion for host" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 18: Should use double quotes for array elements
    ((total_tests++))
    if assert_pattern_in_file "\"host1\.example\.com\"" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Uses double quotes for array elements"
        echo "✅ Test 18 PASSED: Uses double quotes for array elements" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Does not use double quotes for array elements"
        echo "❌ Test 18 FAILED: Does not use double quotes for array elements" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 19: Should use parentheses for array declaration
    ((total_tests++))
    if assert_pattern_in_file "REMOTE_HOSTS=(" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Uses parentheses for array declaration"
        echo "✅ Test 19 PASSED: Uses parentheses for array declaration" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Does not use parentheses for array declaration"
        echo "❌ Test 19 FAILED: Does not use parentheses for array declaration" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Test 20: Should use done to close for loop
    ((total_tests++))
    if assert_pattern_in_file "done" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Uses done to close for loop"
        echo "✅ Test 20 PASSED: Uses done to close for loop" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Does not use done to close for loop"
        echo "❌ Test 20 FAILED: Does not use done to close for loop" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for distributed_health_check.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_distributed_health_check.txt"
    fi
}

# Run the tests
run_tests
