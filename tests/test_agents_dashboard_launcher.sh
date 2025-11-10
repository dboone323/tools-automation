#!/bin/bash
# Test suite for dashboard_launcher.sh

# Source test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_FILE="/Users/danielstevens/Desktop/github-projects/tools-automation/agents/dashboard_launcher.sh"

# Test 1: Script should be executable
test_dashboard_launcher_executable() {
    assert_file_executable "${AGENT_FILE}" "dashboard_launcher.sh should be executable"
}

# Test 2: Script should have proper shebang
test_dashboard_launcher_shebang() {
    assert_pattern_in_file "^#!/bin/bash" "${AGENT_FILE}" "dashboard_launcher.sh should have bash shebang"
}

# Test 3: Script should source shared_functions.sh
test_dashboard_launcher_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_FILE}" "dashboard_launcher.sh should source shared_functions.sh"
}

# Test 4: Script should define DASHBOARD_AGENT variable
test_dashboard_launcher_defines_dashboard_agent() {
    assert_pattern_in_file "DASHBOARD_AGENT=" "${AGENT_FILE}" "dashboard_launcher.sh should define DASHBOARD_AGENT"
}

# Test 5: Script should have log_message function
test_dashboard_launcher_has_log_message_function() {
    assert_pattern_in_file "log_message\(\)" "${AGENT_FILE}" "dashboard_launcher.sh should have log_message function"
}

# Test 6: Script should have is_dashboard_running function
test_dashboard_launcher_has_is_dashboard_running_function() {
    assert_pattern_in_file "is_dashboard_running\(\)" "${AGENT_FILE}" "dashboard_launcher.sh should have is_dashboard_running function"
}

# Test 7: Script should have start_dashboard function
test_dashboard_launcher_has_start_dashboard_function() {
    assert_pattern_in_file "start_dashboard\(\)" "${AGENT_FILE}" "dashboard_launcher.sh should have start_dashboard function"
}

# Test 8: Script should have stop_dashboard function
test_dashboard_launcher_has_stop_dashboard_function() {
    assert_pattern_in_file "stop_dashboard\(\)" "${AGENT_FILE}" "dashboard_launcher.sh should have stop_dashboard function"
}

# Test 9: Script should have case statement for commands
test_dashboard_launcher_has_case_statement() {
    assert_pattern_in_file "case.*1.*start" "${AGENT_FILE}" "dashboard_launcher.sh should have case statement for commands"
}

# Test 10: Script should have show_help function
test_dashboard_launcher_has_show_help_function() {
    assert_pattern_in_file "show_help\(\)" "${AGENT_FILE}" "dashboard_launcher.sh should have show_help function"
}

# Run all tests
run_dashboard_launcher_tests() {
    echo "🧪 Running tests for dashboard_launcher.sh"
    echo "=========================================="

    test_dashboard_launcher_executable
    test_dashboard_launcher_shebang
    test_dashboard_launcher_sources_shared_functions
    test_dashboard_launcher_defines_dashboard_agent
    test_dashboard_launcher_has_log_message_function
    test_dashboard_launcher_has_is_dashboard_running_function
    test_dashboard_launcher_has_start_dashboard_function
    test_dashboard_launcher_has_stop_dashboard_function
    test_dashboard_launcher_has_case_statement
    test_dashboard_launcher_has_show_help_function

    echo ""
    echo "✅ All tests passed!"
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_dashboard_launcher_tests
fi
