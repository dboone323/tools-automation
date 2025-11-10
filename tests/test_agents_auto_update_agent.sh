#!/bin/bash
# Test suite for auto_update_agent.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_PATH="${SCRIPT_DIR}/../agents/auto_update_agent.sh"
SHELL_TEST_FRAMEWORK="${SCRIPT_DIR}/../shell_test_framework.sh"

# Source the test framework
source "${SHELL_TEST_FRAMEWORK}"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_PATH}"
}

# Test 2: Script should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_PATH}"
}

# Test 3: Script should define AGENT_NAME variable
test_defines_agent_name() {
    assert_pattern_in_file "AGENT_NAME=\"AutoUpdateAgent\"" "${AGENT_PATH}"
}

# Test 4: Script should define LOG_FILE variable
test_defines_log_file() {
    assert_pattern_in_file "LOG_FILE=" "${AGENT_PATH}"
}

# Test 5: Script should define NOTIFICATION_FILE variable
test_defines_notification_file() {
    assert_pattern_in_file "NOTIFICATION_FILE=" "${AGENT_PATH}"
}

# Test 6: Script should define log_message function
test_defines_log_message_function() {
    assert_pattern_in_file "log_message\(\)" "${AGENT_PATH}"
}

# Test 7: Script should define check_for_updates function
test_defines_check_for_updates_function() {
    assert_pattern_in_file "check_for_updates\(\)" "${AGENT_PATH}"
}

# Test 8: Script should define apply_updates function
test_defines_apply_updates_function() {
    assert_pattern_in_file "apply_updates\(\)" "${AGENT_PATH}"
}

# Test 9: Script should have main loop with while true
test_has_main_loop() {
    assert_pattern_in_file "while true; do" "${AGENT_PATH}"
}

# Test 10: Script should define UPDATE_QUEUE_FILE variable
test_defines_update_queue_file() {
    assert_pattern_in_file "UPDATE_QUEUE_FILE=" "${AGENT_PATH}"
}

# Run all tests
run_auto_update_agent_tests() {
    echo "🧪 Running tests for auto_update_agent.sh"
    echo "========================================"

    test_script_executable
    test_sources_shared_functions
    test_defines_agent_name
    test_defines_log_file
    test_defines_notification_file
    test_defines_log_message_function
    test_defines_check_for_updates_function
    test_defines_apply_updates_function
    test_has_main_loop
    test_defines_update_queue_file

    echo ""
    echo "✅ All tests passed!"
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_auto_update_agent_tests
fi
