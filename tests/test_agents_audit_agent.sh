#!/bin/bash
# Test suite for audit_agent.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_PATH="${SCRIPT_DIR}/../agents/audit_agent.sh"
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
    assert_pattern_in_file "AGENT_NAME=\"audit_agent.sh\"" "${AGENT_PATH}"
}

# Test 4: Script should define WORKSPACE variable
test_defines_workspace() {
    assert_pattern_in_file "WORKSPACE=" "${AGENT_PATH}"
}

# Test 5: Script should define LOG_FILE variable
test_defines_log_file() {
    assert_pattern_in_file "LOG_FILE=" "${AGENT_PATH}"
}

# Test 6: Script should define ollama_query function
test_defines_ollama_query_function() {
    assert_pattern_in_file "ollama_query\(\)" "${AGENT_PATH}"
}

# Test 7: Script should define update_status function
test_defines_update_status_function() {
    assert_pattern_in_file "update_status\(\)" "${AGENT_PATH}"
}

# Test 8: Script should define process_task function
test_defines_process_task_function() {
    assert_pattern_in_file "process_task\(\)" "${AGENT_PATH}"
}

# Test 9: Script should have main loop with while true
test_has_main_loop() {
    assert_pattern_in_file "while true; do" "${AGENT_PATH}"
}

# Test 10: Script should check for task notifications
test_checks_notifications() {
    assert_pattern_in_file "NOTIFICATION_FILE" "${AGENT_PATH}"
}

# Run all tests
run_audit_agent_tests() {
    echo "🧪 Running tests for audit_agent.sh"
    echo "==================================="

    test_script_executable
    test_sources_shared_functions
    test_defines_agent_name
    test_defines_workspace
    test_defines_log_file
    test_defines_ollama_query_function
    test_defines_update_status_function
    test_defines_process_task_function
    test_has_main_loop
    test_checks_notifications

    echo ""
    echo "✅ All tests passed!"
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_audit_agent_tests
fi
