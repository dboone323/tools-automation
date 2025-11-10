#!/bin/bash
# Test suite for agent_cleanup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_cleanup.sh"

# Source shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

# Test 1: Script should be executable
test_agent_cleanup_executable() {
    local test_name="test_agent_cleanup_executable"
    announce_test "$test_name"

    assert_file_executable "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 2: Should source shared_functions.sh
test_agent_cleanup_sources_shared_functions() {
    local test_name="test_agent_cleanup_sources_shared_functions"
    announce_test "$test_name"

    assert_pattern_in_file "source.*shared_functions.sh" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 3: Should have ensure_within_limits function
test_agent_cleanup_ensure_limits() {
    local test_name="test_agent_cleanup_ensure_limits"
    announce_test "$test_name"

    assert_pattern_in_file "ensure_within_limits\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 4: Should have run_with_timeout function
test_agent_cleanup_timeout_function() {
    local test_name="test_agent_cleanup_timeout_function"
    announce_test "$test_name"

    assert_pattern_in_file "run_with_timeout\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 5: Should have check_resource_limits function
test_agent_cleanup_resource_limits() {
    local test_name="test_agent_cleanup_resource_limits"
    announce_test "$test_name"

    assert_pattern_in_file "check_resource_limits\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 6: Should have log_message function
test_agent_cleanup_log_message() {
    local test_name="test_agent_cleanup_log_message"
    announce_test "$test_name"

    assert_pattern_in_file "log_message\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 7: Should have update_agent_status function call
test_agent_cleanup_update_status() {
    local test_name="test_agent_cleanup_update_status"
    announce_test "$test_name"

    assert_pattern_in_file "update_agent_status" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 8: Should have get_next_task function call
test_agent_cleanup_get_next_task() {
    local test_name="test_agent_cleanup_get_next_task"
    announce_test "$test_name"

    assert_pattern_in_file "get_next_task" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 9: Should have main function
test_agent_cleanup_main() {
    local test_name="test_agent_cleanup_main"
    announce_test "$test_name"

    assert_pattern_in_file "main\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 10: Should have cleanup functions
test_agent_cleanup_cleanup_functions() {
    local test_name="test_agent_cleanup_cleanup_functions"
    announce_test "$test_name"

    assert_pattern_in_file "clean_" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 11: Should have rotate functions
test_agent_cleanup_rotate_functions() {
    local test_name="test_agent_cleanup_rotate_functions"
    announce_test "$test_name"

    assert_pattern_in_file "rotate_logs" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 12: Should have generate_cleanup_report function
test_agent_cleanup_generate_report() {
    local test_name="test_agent_cleanup_generate_report"
    announce_test "$test_name"

    assert_pattern_in_file "generate_cleanup_report" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 13: Should have process_cleanup_task function
test_agent_cleanup_process_task() {
    local test_name="test_agent_cleanup_process_task"
    announce_test "$test_name"

    assert_pattern_in_file "process_cleanup_task" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 14: Should have run_full_cleanup function
test_agent_cleanup_run_full_cleanup() {
    local test_name="test_agent_cleanup_run_full_cleanup"
    announce_test "$test_name"

    assert_pattern_in_file "run_full_cleanup" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 15: Should have update_task_status function call
test_agent_cleanup_update_task_status() {
    local test_name="test_agent_cleanup_update_task_status"
    announce_test "$test_name"

    assert_pattern_in_file "update_task_status" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Run all tests
run_tests() {
    echo "Running tests for agent_cleanup.sh..."
    echo "================================================================="

    # Run individual tests
    test_agent_cleanup_executable
    test_agent_cleanup_sources_shared_functions
    test_agent_cleanup_ensure_limits
    test_agent_cleanup_timeout_function
    test_agent_cleanup_resource_limits
    test_agent_cleanup_log_message
    test_agent_cleanup_update_status
    test_agent_cleanup_get_next_task
    test_agent_cleanup_main
    test_agent_cleanup_cleanup_functions
    test_agent_cleanup_rotate_functions
    test_agent_cleanup_prune_functions
    test_agent_cleanup_process_task
    test_agent_cleanup_perform_cleanup
    test_agent_cleanup_maintenance

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
