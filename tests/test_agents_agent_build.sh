#!/bin/bash
# Test suite for agent_build.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_build.sh"

# Source shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

# Test 1: Script should be executable
test_agent_build_executable() {
    local test_name="test_agent_build_executable"
    announce_test "$test_name"

    assert_file_executable "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 2: Should contain AGENT_NAME variable
test_agent_build_agent_name() {
    local test_name="test_agent_build_agent_name"
    announce_test "$test_name"

    assert_pattern_in_file "AGENT_NAME=\"agent_build.sh\"" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 3: Should source shared_functions.sh
test_agent_build_sources_shared_functions() {
    local test_name="test_agent_build_sources_shared_functions"
    announce_test "$test_name"

    assert_pattern_in_file "source.*shared_functions.sh" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 4: Should have run_with_timeout function
test_agent_build_timeout_function() {
    local test_name="test_agent_build_timeout_function"
    announce_test "$test_name"

    assert_pattern_in_file "run_with_timeout\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 5: Should have check_resource_limits function
test_agent_build_resource_limits() {
    local test_name="test_agent_build_resource_limits"
    announce_test "$test_name"

    assert_pattern_in_file "check_resource_limits\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 6: Should have ensure_within_limits function
test_agent_build_ensure_limits() {
    local test_name="test_agent_build_ensure_limits"
    announce_test "$test_name"

    assert_pattern_in_file "ensure_within_limits\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 7: Should have update_task_status function
test_agent_build_update_task_status() {
    local test_name="test_agent_build_update_task_status"
    announce_test "$test_name"

    assert_pattern_in_file "update_task_status\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 8: Should have process_task function
test_agent_build_process_task() {
    local test_name="test_agent_build_process_task"
    announce_test "$test_name"

    assert_pattern_in_file "process_task\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 9: Should have process_build_task function
test_agent_build_process_build_task() {
    local test_name="test_agent_build_process_build_task"
    announce_test "$test_name"

    assert_pattern_in_file "process_build_task\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 10: Should have perform_project_build function
test_agent_build_perform_build() {
    local test_name="test_agent_build_perform_build"
    announce_test "$test_name"

    assert_pattern_in_file "perform_project_build\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 11: Should have perform_project_tests function
test_agent_build_perform_tests() {
    local test_name="test_agent_build_perform_tests"
    announce_test "$test_name"

    assert_pattern_in_file "perform_project_tests\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 12: Should have perform_project_analysis function
test_agent_build_perform_analysis() {
    local test_name="test_agent_build_perform_analysis"
    announce_test "$test_name"

    assert_pattern_in_file "perform_project_analysis\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 13: Should have perform_project_backup function
test_agent_build_perform_backup() {
    local test_name="test_agent_build_perform_backup"
    announce_test "$test_name"

    assert_pattern_in_file "perform_project_backup\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 14: Should have main function
test_agent_build_main() {
    local test_name="test_agent_build_main"
    announce_test "$test_name"

    assert_pattern_in_file "main\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 15: Should have log_message function
test_agent_build_log_message() {
    local test_name="test_agent_build_log_message"
    announce_test "$test_name"

    assert_pattern_in_file "log_message\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Run all tests
run_tests() {
    echo "Running tests for agent_build.sh..."
    echo "================================================================="

    # Run individual tests
    test_agent_build_executable
    test_agent_build_agent_name
    test_agent_build_sources_shared_functions
    test_agent_build_timeout_function
    test_agent_build_resource_limits
    test_agent_build_ensure_limits
    test_agent_build_update_task_status
    test_agent_build_process_task
    test_agent_build_process_build_task
    test_agent_build_perform_build
    test_agent_build_perform_tests
    test_agent_build_perform_analysis
    test_agent_build_perform_backup
    test_agent_build_main
    test_agent_build_log_message

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
