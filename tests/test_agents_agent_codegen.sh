#!/bin/bash
# Test suite for agent_codegen.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_codegen.sh"

# Source shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

# Test 1: Script should be executable
test_agent_codegen_executable() {
    local test_name="test_agent_codegen_executable"
    announce_test "$test_name"

    assert_file_executable "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 2: Should source shared_functions.sh
test_agent_codegen_sources_shared_functions() {
    local test_name="test_agent_codegen_sources_shared_functions"
    announce_test "$test_name"

    assert_pattern_in_file "source.*shared_functions.sh" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 3: Should have run_with_timeout function
test_agent_codegen_timeout_function() {
    local test_name="test_agent_codegen_timeout_function"
    announce_test "$test_name"

    assert_pattern_in_file "run_with_timeout" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 4: Should have check_resource_limits function
test_agent_codegen_resource_limits() {
    local test_name="test_agent_codegen_resource_limits"
    announce_test "$test_name"

    assert_pattern_in_file "check_resource_limits" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 5: Should have ensure_within_limits function
test_agent_codegen_ensure_limits() {
    local test_name="test_agent_codegen_ensure_limits"
    announce_test "$test_name"

    assert_pattern_in_file "ensure_within_limits" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 6: Should have log_message function
test_agent_codegen_log_message() {
    local test_name="test_agent_codegen_log_message"
    announce_test "$test_name"

    assert_pattern_in_file "log_message" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 7: Should have update_agent_status function call
test_agent_codegen_update_status() {
    local test_name="test_agent_codegen_update_status"
    announce_test "$test_name"

    assert_pattern_in_file "update_agent_status" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 8: Should have get_next_task function call
test_agent_codegen_get_next_task() {
    local test_name="test_agent_codegen_get_next_task"
    announce_test "$test_name"

    assert_pattern_in_file "get_next_task" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 9: Should have main function
test_agent_codegen_main() {
    local test_name="test_agent_codegen_main"
    announce_test "$test_name"

    assert_pattern_in_file "main\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 10: Should have codegen functions
test_agent_codegen_codegen_functions() {
    local test_name="test_agent_codegen_codegen_functions"
    announce_test "$test_name"

    assert_pattern_in_file "codegen" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 11: Should have generate functions
test_agent_codegen_generate_functions() {
    local test_name="test_agent_codegen_generate_functions"
    announce_test "$test_name"

    assert_pattern_in_file "generate_" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 12: Should have process_codegen_task function
test_agent_codegen_process_task() {
    local test_name="test_agent_codegen_process_task"
    announce_test "$test_name"

    assert_pattern_in_file "process_codegen_task" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 13: Should have perform_codegen function
test_agent_codegen_perform_codegen() {
    local test_name="test_agent_codegen_perform_codegen"
    announce_test "$test_name"

    assert_pattern_in_file "perform_codegen" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 14: Should have template functions
test_agent_codegen_template_functions() {
    local test_name="test_agent_codegen_template_functions"
    announce_test "$test_name"

    assert_pattern_in_file "template" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 15: Should have update_task_status function call
test_agent_codegen_update_task_status() {
    local test_name="test_agent_codegen_update_task_status"
    announce_test "$test_name"

    assert_pattern_in_file "update_task_status" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Run all tests
run_tests() {
    echo "Running tests for agent_codegen.sh..."
    echo "================================================================="

    # Run individual tests
    test_agent_codegen_executable
    test_agent_codegen_sources_shared_functions
    test_agent_codegen_timeout_function
    test_agent_codegen_resource_limits
    test_agent_codegen_ensure_limits
    test_agent_codegen_log_message
    test_agent_codegen_update_status
    test_agent_codegen_get_next_task
    test_agent_codegen_main
    test_agent_codegen_codegen_functions
    test_agent_codegen_generate_functions
    test_agent_codegen_process_task
    test_agent_codegen_perform_codegen
    test_agent_codegen_template_functions
    test_agent_codegen_update_task_status

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
