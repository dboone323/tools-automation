#!/bin/bash
# Test suite for agent_loop_utils.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_loop_utils.sh"

# Source shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

# Test 1: Script should be executable
test_agent_loop_utils_executable() {
    local test_name="test_agent_loop_utils_executable"
    announce_test "$test_name"

    assert_file_executable "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 2: Should have agent_init_backoff function
test_agent_loop_utils_init_backoff() {
    local test_name="test_agent_loop_utils_init_backoff"
    announce_test "$test_name"

    assert_pattern_in_file "agent_init_backoff\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 3: Should have agent_is_pipeline function
test_agent_loop_utils_is_pipeline() {
    local test_name="test_agent_loop_utils_is_pipeline"
    announce_test "$test_name"

    assert_pattern_in_file "agent_is_pipeline\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 4: Should have agent_detect_pipe_and_quick_exit function
test_agent_loop_utils_quick_exit() {
    local test_name="test_agent_loop_utils_quick_exit"
    announce_test "$test_name"

    assert_pattern_in_file "agent_detect_pipe_and_quick_exit\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 5: Should have agent_sleep_with_backoff function
test_agent_loop_utils_sleep_backoff() {
    local test_name="test_agent_loop_utils_sleep_backoff"
    announce_test "$test_name"

    assert_pattern_in_file "agent_sleep_with_backoff\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 6: Should export functions
test_agent_loop_utils_export_functions() {
    local test_name="test_agent_loop_utils_export_functions"
    announce_test "$test_name"

    assert_pattern_in_file "export -f.*agent_init_backoff.*agent_is_pipeline.*agent_detect_pipe_and_quick_exit.*agent_sleep_with_backoff" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 7: Should have SLEEP_INTERVAL variable handling
test_agent_loop_utils_sleep_interval() {
    local test_name="test_agent_loop_utils_sleep_interval"
    announce_test "$test_name"

    assert_pattern_in_file "SLEEP_INTERVAL.*TEST_SLEEP_INTERVAL" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 8: Should have MAX_INTERVAL variable handling
test_agent_loop_utils_max_interval() {
    local test_name="test_agent_loop_utils_max_interval"
    announce_test "$test_name"

    assert_pattern_in_file "MAX_INTERVAL.*TEST_MAX_INTERVAL" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 9: Should check for pipeline mode
test_agent_loop_utils_pipeline_check() {
    local test_name="test_agent_loop_utils_pipeline_check"
    announce_test "$test_name"

    assert_pattern_in_file "/dev/stdout.*dev/stderr" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 10: Should have exponential backoff logic
test_agent_loop_utils_exponential_backoff() {
    local test_name="test_agent_loop_utils_exponential_backoff"
    announce_test "$test_name"

    assert_pattern_in_file "SLEEP_INTERVAL=.*SLEEP_INTERVAL \* 2" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Run all tests
run_tests() {
    echo "Running tests for agent_loop_utils.sh..."
    echo "================================================================="

    # Run individual tests
    test_agent_loop_utils_executable
    test_agent_loop_utils_init_backoff
    test_agent_loop_utils_is_pipeline
    test_agent_loop_utils_quick_exit
    test_agent_loop_utils_sleep_backoff
    test_agent_loop_utils_export_functions
    test_agent_loop_utils_sleep_interval
    test_agent_loop_utils_max_interval
    test_agent_loop_utils_pipeline_check
    test_agent_loop_utils_exponential_backoff

    echo "================================================================="
    echo "Test Summary:"
    echo "Total tests: $(get_total_tests)"
    echo "Passed: $(get_passed_tests)"
    echo "Failed: $(get_failed_tests)"

    # Return success/failure
    if [[ $(get_failed_tests) -eq 0 ]]; then
        echo "✅ All tests passed!"
        return 0
    else
        echo "❌ Some tests failed!"
        return 1
    fi
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
