#!/bin/bash
# Test suite for watch_supervisor.sh
# This test suite validates the supervisor watch functionality

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shell_test_framework.sh
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/watch_supervisor.sh"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Script should define SCRIPT_DIR variable
test_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

# Test 3: Script should define LOG_DIR variable
test_defines_log_dir() {
    assert_pattern_in_file "LOG_DIR=" "${AGENT_SCRIPT}"
}

# Test 4: Script should define LOG_FILE variable
test_defines_log_file() {
    assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"
}

# Test 5: Script should have main while loop
test_has_main_loop() {
    assert_pattern_in_file "while true; do" "${AGENT_SCRIPT}"
}

# Test 6: Script should call monitor_agents.sh
test_calls_monitor_agents() {
    assert_pattern_in_file "monitor_agents\.sh" "${AGENT_SCRIPT}"
}

# Test 7: Script should redirect output to log file
test_redirects_output() {
    assert_pattern_in_file ">>.*LOG_FILE" "${AGENT_SCRIPT}"
}

# Test 8: Script should redirect stderr to log file
test_redirects_stderr() {
    assert_pattern_in_file "2>&1" "${AGENT_SCRIPT}"
}

# Test 9: Script should sleep for 60 seconds
test_sleeps_60_seconds() {
    assert_pattern_in_file "sleep 60" "${AGENT_SCRIPT}"
}

# Test 10: Should use SCRIPT_DIR in monitor_agents call
test_uses_script_dir() {
    assert_pattern_in_file '${SCRIPT_DIR}/monitor_agents\.sh' "${AGENT_SCRIPT}"
}

# Test 11: Should use LOG_DIR in LOG_FILE definition
test_uses_log_dir_in_log_file() {
    assert_pattern_in_file 'LOG_DIR="${SCRIPT_DIR}"' "${AGENT_SCRIPT}"
}

# Test 12: Should use LOG_DIR in LOG_FILE path
test_uses_log_dir_in_path() {
    assert_pattern_in_file 'LOG_FILE="${LOG_DIR}/agent_supervision_watch.log"' "${AGENT_SCRIPT}"
}

# Test 13: Script should have proper shebang
test_has_shebang() {
    assert_pattern_in_file "#!/bin/bash" "${AGENT_SCRIPT}"
}

# Test 14: Script should use cd command for SCRIPT_DIR
test_uses_cd_for_script_dir() {
    assert_pattern_in_file "cd.*dirname.*BASH_SOURCE" "${AGENT_SCRIPT}"
}

# Test 15: Script should use pwd command
test_uses_pwd() {
    assert_pattern_in_file "pwd" "${AGENT_SCRIPT}"
}

# Test 16: Script should have done at end of loop
test_has_done() {
    assert_pattern_in_file "done" "${AGENT_SCRIPT}"
}

# Test 17: Script should have comment about supervisor watch loop
test_has_comment() {
    assert_pattern_in_file "# Simple 1-minute supervisor watch loop" "${AGENT_SCRIPT}"
}

# Test 18: Should have comment about LOG_DIR
test_has_log_dir_comment() {
    assert_pattern_in_file "LOG_DIR=" "${AGENT_SCRIPT}"
}

# Test 19: Should have comment about LOG_FILE
test_has_log_file_comment() {
    assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"
}

# Test 20: Should have comment about while loop
test_has_while_comment() {
    assert_pattern_in_file "while true" "${AGENT_SCRIPT}"
}

# Run all tests
run_tests() {
    echo "Running tests for watch_supervisor.sh..."
    echo "Test Results for watch_supervisor.sh" >"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
    echo "Generated: $(date)" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: watch_supervisor.sh is executable"
        echo "✅ Test 1 PASSED: watch_supervisor.sh is executable" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: watch_supervisor.sh is not executable"
        echo "❌ Test 1 FAILED: watch_supervisor.sh is not executable" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 2: Should define SCRIPT_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable"
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable"
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 3: Should define LOG_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "LOG_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Defines LOG_DIR variable"
        echo "✅ Test 3 PASSED: Defines LOG_DIR variable" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not define LOG_DIR variable"
        echo "❌ Test 3 FAILED: Does not define LOG_DIR variable" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 4: Should define LOG_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines LOG_FILE variable"
        echo "✅ Test 4 PASSED: Defines LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define LOG_FILE variable"
        echo "❌ Test 4 FAILED: Does not define LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 5: Should have main loop with while true
    ((total_tests++))
    if assert_pattern_in_file "while true; do" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Has main loop with while true"
        echo "✅ Test 5 PASSED: Has main loop with while true" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Missing main loop"
        echo "❌ Test 5 FAILED: Missing main loop" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 6: Should call monitor_agents.sh
    ((total_tests++))
    if assert_pattern_in_file "monitor_agents\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Calls monitor_agents.sh"
        echo "✅ Test 6 PASSED: Calls monitor_agents.sh" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not call monitor_agents.sh"
        echo "❌ Test 6 FAILED: Does not call monitor_agents.sh" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 7: Should redirect output to log file
    ((total_tests++))
    if assert_pattern_in_file ">>.*LOG_FILE" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Redirects output to LOG_FILE"
        echo "✅ Test 7 PASSED: Redirects output to LOG_FILE" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not redirect output to log file"
        echo "❌ Test 7 FAILED: Does not redirect output to log file" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 8: Should redirect stderr to log file
    ((total_tests++))
    if assert_pattern_in_file "2>&1" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Redirects stderr to log file"
        echo "✅ Test 8 PASSED: Redirects stderr to log file" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Does not redirect stderr to log file"
        echo "❌ Test 8 FAILED: Does not redirect stderr to log file" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 9: Should sleep for 60 seconds
    ((total_tests++))
    if assert_pattern_in_file "sleep 60" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Sleeps for 60 seconds"
        echo "✅ Test 9 PASSED: Sleeps for 60 seconds" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Does not sleep for 60 seconds"
        echo "❌ Test 9 FAILED: Does not sleep for 60 seconds" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 10: Should use SCRIPT_DIR in monitor_agents call
    ((total_tests++))
    if assert_pattern_in_file '${SCRIPT_DIR}/monitor_agents\.sh' "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Uses SCRIPT_DIR in monitor_agents call"
        echo "✅ Test 10 PASSED: Uses SCRIPT_DIR in monitor_agents call" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not use SCRIPT_DIR in monitor_agents call"
        echo "❌ Test 10 FAILED: Does not use SCRIPT_DIR in monitor_agents call" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 11: Should use LOG_DIR in LOG_FILE definition
    ((total_tests++))
    if assert_pattern_in_file 'LOG_DIR="${SCRIPT_DIR}"' "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Sets LOG_DIR to SCRIPT_DIR"
        echo "✅ Test 11 PASSED: Sets LOG_DIR to SCRIPT_DIR" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not set LOG_DIR to SCRIPT_DIR"
        echo "❌ Test 11 FAILED: Does not set LOG_DIR to SCRIPT_DIR" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 12: Should use LOG_DIR in LOG_FILE path
    ((total_tests++))
    if assert_pattern_in_file 'LOG_FILE="${LOG_DIR}/agent_supervision_watch.log"' "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Uses LOG_DIR in LOG_FILE path"
        echo "✅ Test 12 PASSED: Uses LOG_DIR in LOG_FILE path" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not use LOG_DIR in LOG_FILE path"
        echo "❌ Test 12 FAILED: Does not use LOG_DIR in LOG_FILE path" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 13: Should have proper shebang
    ((total_tests++))
    if assert_pattern_in_file "#!/bin/bash" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Has proper shebang"
        echo "✅ Test 13 PASSED: Has proper shebang" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Missing proper shebang"
        echo "❌ Test 13 FAILED: Missing proper shebang" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 14: Should use cd command for SCRIPT_DIR
    ((total_tests++))
    if assert_pattern_in_file "cd.*dirname.*BASH_SOURCE" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Uses cd command for SCRIPT_DIR"
        echo "✅ Test 14 PASSED: Uses cd command for SCRIPT_DIR" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not use cd command for SCRIPT_DIR"
        echo "❌ Test 14 FAILED: Does not use cd command for SCRIPT_DIR" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 15: Should use pwd command
    ((total_tests++))
    if assert_pattern_in_file "pwd" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Uses pwd command"
        echo "✅ Test 15 PASSED: Uses pwd command" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not use pwd command"
        echo "❌ Test 15 FAILED: Does not use pwd command" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 16: Should have done at end of loop
    ((total_tests++))
    if assert_pattern_in_file "done" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Has done at end of loop"
        echo "✅ Test 16 PASSED: Has done at end of loop" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Missing done at end of loop"
        echo "❌ Test 16 FAILED: Missing done at end of loop" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 17: Should have comment about supervisor watch loop
    ((total_tests++))
    if assert_pattern_in_file "# Simple 1-minute supervisor watch loop" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Has comment about supervisor watch loop"
        echo "✅ Test 17 PASSED: Has comment about supervisor watch loop" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Missing comment about supervisor watch loop"
        echo "❌ Test 17 FAILED: Missing comment about supervisor watch loop" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 18: Should have comment about LOG_DIR
    ((total_tests++))
    if assert_pattern_in_file "LOG_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Has LOG_DIR variable definition"
        echo "✅ Test 18 PASSED: Has LOG_DIR variable definition" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Missing LOG_DIR variable definition"
        echo "❌ Test 18 FAILED: Missing LOG_DIR variable definition" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 19: Should have comment about LOG_FILE
    ((total_tests++))
    if assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Has LOG_FILE variable definition"
        echo "✅ Test 19 PASSED: Has LOG_FILE variable definition" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Missing LOG_FILE variable definition"
        echo "❌ Test 19 FAILED: Missing LOG_FILE variable definition" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Test 20: Should have comment about while loop
    ((total_tests++))
    if assert_pattern_in_file "while true" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Has while true loop"
        echo "✅ Test 20 PASSED: Has while true loop" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Missing while true loop"
        echo "❌ Test 20 FAILED: Missing while true loop" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for watch_supervisor.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_watch_supervisor.txt"
    fi
}

# Run the tests
run_tests
