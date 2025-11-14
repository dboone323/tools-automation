#!/bin/bash
# Test suite for agent_analytics.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_analytics.sh"

# Source shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

# Test 1: Script should be executable
test_agent_analytics_executable() {
    local test_name="test_agent_analytics_executable"
    announce_test "$test_name"

    assert_file_executable "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 2: Should contain AGENT_NAME variable
test_agent_analytics_agent_name() {
    local test_name="test_agent_analytics_agent_name"
    announce_test "$test_name"

    assert_pattern_in_file "AGENT_NAME=\"agent_analytics\"" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 3: Should source shared_functions.sh
test_agent_analytics_sources_shared_functions() {
    local test_name="test_agent_analytics_sources_shared_functions"
    announce_test "$test_name"

    assert_pattern_in_file "source.*shared_functions.sh" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 4: Should have run_with_timeout function
test_agent_analytics_timeout_function() {
    local test_name="test_agent_analytics_timeout_function"
    announce_test "$test_name"

    assert_pattern_in_file "run_with_timeout\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 5: Should have check_resource_limits function
test_agent_analytics_resource_limits() {
    local test_name="test_agent_analytics_resource_limits"
    announce_test "$test_name"

    assert_pattern_in_file "check_resource_limits\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 6: Should have ensure_within_limits function
test_agent_analytics_ensure_limits() {
    local test_name="test_agent_analytics_ensure_limits"
    announce_test "$test_name"

    assert_pattern_in_file "ensure_within_limits\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 7: Should have update_agent_status function
test_agent_analytics_update_status() {
    local test_name="test_agent_analytics_update_status"
    announce_test "$test_name"

    assert_pattern_in_file "update_agent_status\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 8: Should have collect_code_metrics function
test_agent_analytics_collect_code() {
    local test_name="test_agent_analytics_collect_code"
    announce_test "$test_name"

    assert_pattern_in_file "collect_code_metrics\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 9: Should have collect_build_metrics function
test_agent_analytics_collect_build() {
    local test_name="test_agent_analytics_collect_build"
    announce_test "$test_name"

    assert_pattern_in_file "collect_build_metrics\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 10: Should have collect_coverage_metrics function
test_agent_analytics_collect_coverage() {
    local test_name="test_agent_analytics_collect_coverage"
    announce_test "$test_name"

    assert_pattern_in_file "collect_coverage_metrics\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 11: Should have collect_agent_metrics function
test_agent_analytics_collect_agent() {
    local test_name="test_agent_analytics_collect_agent"
    announce_test "$test_name"

    assert_pattern_in_file "collect_agent_metrics\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 12: Should have generate_report function
test_agent_analytics_generate_report() {
    local test_name="test_agent_analytics_generate_report"
    announce_test "$test_name"

    assert_pattern_in_file "generate_report\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 13: Should have process_analytics_task function
test_agent_analytics_process_task() {
    local test_name="test_agent_analytics_process_task"
    announce_test "$test_name"

    assert_pattern_in_file "process_analytics_task\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 14: Should have main function
test_agent_analytics_main() {
    local test_name="test_agent_analytics_main"
    announce_test "$test_name"

    assert_pattern_in_file "main\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 15: Should have log_message function
test_agent_analytics_log_message() {
    local test_name="test_agent_analytics_log_message"
    announce_test "$test_name"

    assert_pattern_in_file "log_message\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Run all tests
run_tests() {
    echo "Running tests for agent_analytics.sh..."
    echo "================================================================="

    # Run individual tests
    test_agent_analytics_executable
    test_agent_analytics_agent_name
    test_agent_analytics_sources_shared_functions
    test_agent_analytics_timeout_function
    test_agent_analytics_resource_limits
    test_agent_analytics_ensure_limits
    test_agent_analytics_update_status
    test_agent_analytics_collect_code
    test_agent_analytics_collect_build
    test_agent_analytics_collect_coverage
    test_agent_analytics_collect_agent
    test_agent_analytics_generate_report
    test_agent_analytics_process_task
    test_agent_analytics_main
    test_agent_analytics_log_message

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
