#!/bin/bash
# Test suite for launch_agent_dashboard.sh

# Source test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_FILE="/Users/danielstevens/Desktop/github-projects/tools-automation/agents/launch_agent_dashboard.sh"

# Test 1: Script should be executable
test_launch_agent_dashboard_executable() {
    assert_file_executable "${AGENT_FILE}" "launch_agent_dashboard.sh should be executable"
}

# Test 2: Script should have proper shebang
test_launch_agent_dashboard_shebang() {
    assert_pattern_in_file "^#!/bin/bash" "${AGENT_FILE}" "launch_agent_dashboard.sh should have bash shebang"
}

# Test 3: Script should source shared_functions.sh
test_launch_agent_dashboard_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_FILE}" "launch_agent_dashboard.sh should source shared_functions.sh"
}

# Test 4: Script should define WORKSPACE variable
test_launch_agent_dashboard_defines_workspace() {
    assert_pattern_in_file "WORKSPACE=" "${AGENT_FILE}" "launch_agent_dashboard.sh should define WORKSPACE"
}

# Test 5: Script should have log function
test_launch_agent_dashboard_has_log_function() {
    assert_pattern_in_file "log\(\)" "${AGENT_FILE}" "launch_agent_dashboard.sh should have log function"
}

# Test 6: Script should have is_server_running function
test_launch_agent_dashboard_has_is_server_running_function() {
    assert_pattern_in_file "is_server_running\(\)" "${AGENT_FILE}" "launch_agent_dashboard.sh should have is_server_running function"
}

# Test 7: Script should have start_server function
test_launch_agent_dashboard_has_start_server_function() {
    assert_pattern_in_file "start_server\(\)" "${AGENT_FILE}" "launch_agent_dashboard.sh should have start_server function"
}

# Test 8: Script should have stop_server function
test_launch_agent_dashboard_has_stop_server_function() {
    assert_pattern_in_file "stop_server\(\)" "${AGENT_FILE}" "launch_agent_dashboard.sh should have stop_server function"
}

# Test 9: Script should have case statement for commands
test_launch_agent_dashboard_has_case_statement() {
    assert_pattern_in_file "case.*command" "${AGENT_FILE}" "launch_agent_dashboard.sh should have case statement for commands"
}

# Test 10: Script should have open_dashboard function
test_launch_agent_dashboard_has_open_dashboard_function() {
    assert_pattern_in_file "open_dashboard\(\)" "${AGENT_FILE}" "launch_agent_dashboard.sh should have open_dashboard function"
}

# Run all tests
run_launch_agent_dashboard_tests() {
    echo "🧪 Running tests for launch_agent_dashboard.sh"
    echo "=============================================="

    test_launch_agent_dashboard_executable
    test_launch_agent_dashboard_shebang
    test_launch_agent_dashboard_sources_shared_functions
    test_launch_agent_dashboard_defines_workspace
    test_launch_agent_dashboard_has_log_function
    test_launch_agent_dashboard_has_is_server_running_function
    test_launch_agent_dashboard_has_start_server_function
    test_launch_agent_dashboard_has_stop_server_function
    test_launch_agent_dashboard_has_case_statement
    test_launch_agent_dashboard_has_open_dashboard_function

    echo ""
    echo "✅ All tests passed!"
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_launch_agent_dashboard_tests
fi
