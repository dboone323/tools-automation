#!/bin/bash
# Test suite for plugin_api.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/plugin_api.sh"

# Source shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

# Test 1: Script should be executable
test_plugin_api_executable() {
    local test_name="test_plugin_api_executable"
    announce_test "$test_name"

    assert_file_executable "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 2: Should source shared_functions.sh
test_plugin_api_sources_shared_functions() {
    local test_name="test_plugin_api_sources_shared_functions"
    announce_test "$test_name"

    assert_pattern_in_file "source.*shared_functions.sh" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 3: Should define PLUGINS_DIR variable
test_plugin_api_plugins_dir() {
    local test_name="test_plugin_api_plugins_dir"
    announce_test "$test_name"

    assert_pattern_in_file "PLUGINS_DIR=.*plugins" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 4: Should define AUDIT_LOG variable
test_plugin_api_audit_log() {
    local test_name="test_plugin_api_audit_log"
    announce_test "$test_name"

    assert_pattern_in_file "AUDIT_LOG=.*audit.log" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 5: Should define POLICY_CONF variable
test_plugin_api_policy_conf() {
    local test_name="test_plugin_api_policy_conf"
    announce_test "$test_name"

    assert_pattern_in_file "POLICY_CONF=.*policy.conf" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 6: Should have list command handling
test_plugin_api_list_command() {
    local test_name="test_plugin_api_list_command"
    announce_test "$test_name"
    
    assert_pattern_in_file "list)" "$AGENT_SCRIPT"
    
    test_passed "$test_name"
}

# Test 7: Should have run command handling
test_plugin_api_run_command() {
    local test_name="test_plugin_api_run_command"
    announce_test "$test_name"
    
    assert_pattern_in_file "run)" "$AGENT_SCRIPT"
    
    test_passed "$test_name"
}

# Test 8: Should check API_TOKEN for run command
test_plugin_api_api_token_check() {
    local test_name="test_plugin_api_api_token_check"
    announce_test "$test_name"
    
    assert_pattern_in_file "API_TOKEN" "$AGENT_SCRIPT"
    
    test_passed "$test_name"
}

# Test 9: Should have policy enforcement
test_plugin_api_policy_enforcement() {
    local test_name="test_plugin_api_policy_enforcement"
    announce_test "$test_name"
    
    assert_pattern_in_file "allow_list.*block_list" "$AGENT_SCRIPT"
    
    test_passed "$test_name"
}# Test 10: Should log audit information
test_plugin_api_audit_logging() {
    local test_name="test_plugin_api_audit_logging"
    announce_test "$test_name"

    assert_pattern_in_file "echo.*date.*user=.*action=.*result=" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Run all tests
run_tests() {
    echo "Running tests for plugin_api.sh..."
    echo "================================================================="

    # Run individual tests
    test_plugin_api_executable
    test_plugin_api_sources_shared_functions
    test_plugin_api_plugins_dir
    test_plugin_api_audit_log
    test_plugin_api_policy_conf
    test_plugin_api_list_command
    test_plugin_api_run_command
    test_plugin_api_api_token_check
    test_plugin_api_policy_enforcement
    test_plugin_api_audit_logging

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
