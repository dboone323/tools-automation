#!/bin/bash
# Test suite for agent_keeper.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_keeper.sh"

# Source shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

# Test 1: Script should be executable
test_agent_keeper_executable() {
    local test_name="test_agent_keeper_executable"
    announce_test "$test_name"

    assert_file_executable "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 2: Should contain AGENT_NAME variable
test_agent_keeper_agent_name() {
    local test_name="test_agent_keeper_agent_name"
    announce_test "$test_name"

    assert_pattern_in_file "AGENT_NAME=\"KeeperAgent\"" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 3: Should source shared_functions.sh
test_agent_keeper_sources_shared_functions() {
    local test_name="test_agent_keeper_sources_shared_functions"
    announce_test "$test_name"

    assert_pattern_in_file "source.*shared_functions.sh" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 4: Should have timeout protection function
test_agent_keeper_timeout_function() {
    local test_name="test_agent_keeper_timeout_function"
    announce_test "$test_name"

    assert_pattern_in_file "run_with_timeout\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 5: Should have resource limits checking
test_agent_keeper_resource_limits() {
    local test_name="test_agent_keeper_resource_limits"
    announce_test "$test_name"

    assert_pattern_in_file "check_resource_limits\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 6: Should define agent capabilities array
test_agent_keeper_agent_capabilities() {
    local test_name="test_agent_keeper_agent_capabilities"
    announce_test "$test_name"

    assert_pattern_in_file "declare -A AGENT_CAPABILITIES" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 7: Should have start_keeper function
test_agent_keeper_start_function() {
    local test_name="test_agent_keeper_start_function"
    announce_test "$test_name"

    assert_pattern_in_file "start_keeper\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 8: Should have deploy_all_agents function
test_agent_keeper_deploy_function() {
    local test_name="test_agent_keeper_deploy_function"
    announce_test "$test_name"

    assert_pattern_in_file "deploy_all_agents\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 9: Should have check_agent_health function
test_agent_keeper_health_check() {
    local test_name="test_agent_keeper_health_check"
    announce_test "$test_name"

    assert_pattern_in_file "check_agent_health\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 10: Should have case statement for command handling
test_agent_keeper_command_handling() {
    local test_name="test_agent_keeper_command_handling"
    announce_test "$test_name"

    assert_pattern_in_file "case.*start" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Run all tests
run_tests() {
    echo "Running tests for agent_keeper.sh..."
    echo "================================================================="

    # Run individual tests
    test_agent_keeper_executable
    test_agent_keeper_agent_name
    test_agent_keeper_sources_shared_functions
    test_agent_keeper_timeout_function
    test_agent_keeper_resource_limits
    test_agent_keeper_agent_capabilities
    test_agent_keeper_start_function
    test_agent_keeper_deploy_function
    test_agent_keeper_health_check
    test_agent_keeper_command_handling

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
