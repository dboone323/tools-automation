#!/bin/bash
# Test suite for minimal_dashboard.sh

# Source test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/../shell_test_framework.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Resolve repository root deterministically (avoid git output duplication)
REPO_ROOT="$(cd "$SCRIPT_DIR/.." && pwd -P)"
AGENT_FILE="$REPO_ROOT/agents/minimal_dashboard.sh"

# Test 1: Script should be executable
test_minimal_dashboard_executable() {
    assert_file_executable "${AGENT_FILE}" "minimal_dashboard.sh should be executable"
}

# Test 2: Script should have proper shebang
test_minimal_dashboard_shebang() {
    assert_pattern_in_file "^#!/bin/bash" "${AGENT_FILE}" "minimal_dashboard.sh should have bash shebang"
}

# Test 3: Script should source shared_functions.sh
test_minimal_dashboard_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_FILE}" "minimal_dashboard.sh should source shared_functions.sh"
}

# Test 4: Script should define SCRIPT_DIR variable
test_minimal_dashboard_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_FILE}" "minimal_dashboard.sh should define SCRIPT_DIR"
}

# Test 5: Script should define LOG_FILE variable
test_minimal_dashboard_defines_log_file() {
    assert_pattern_in_file "LOG_FILE=" "${AGENT_FILE}" "minimal_dashboard.sh should define LOG_FILE"
}

# Test 6: Script should create HTML file
test_minimal_dashboard_creates_html() {
    assert_pattern_in_file "DASHBOARD_HTML_FILE=" "${AGENT_FILE}" "minimal_dashboard.sh should define DASHBOARD_HTML_FILE"
}

# Test 7: Script should have HTML content creation
test_minimal_dashboard_has_html_content() {
    assert_pattern_in_file "<!DOCTYPE html>" "${AGENT_FILE}" "minimal_dashboard.sh should create HTML content"
}

# Test 8: Script should start HTTP server
test_minimal_dashboard_starts_server() {
    assert_pattern_in_file "python3 -m http.server" "${AGENT_FILE}" "minimal_dashboard.sh should start HTTP server"
}

# Test 9: Script should create PID file
test_minimal_dashboard_creates_pid_file() {
    assert_pattern_in_file "minimal_server.pid" "${AGENT_FILE}" "minimal_dashboard.sh should create PID file"
}

# Test 10: Script should have cleanup logic
test_minimal_dashboard_has_cleanup() {
    assert_pattern_in_file "kill.*server_pid" "${AGENT_FILE}" "minimal_dashboard.sh should have cleanup logic"
}

# Run all tests
run_minimal_dashboard_tests() {
    echo "🧪 Running tests for minimal_dashboard.sh"
    echo "========================================"

    test_minimal_dashboard_executable
    test_minimal_dashboard_shebang
    test_minimal_dashboard_sources_shared_functions
    test_minimal_dashboard_defines_script_dir
    test_minimal_dashboard_defines_log_file
    test_minimal_dashboard_creates_html
    test_minimal_dashboard_has_html_content
    test_minimal_dashboard_starts_server
    test_minimal_dashboard_creates_pid_file
    test_minimal_dashboard_has_cleanup

    echo ""
    echo "✅ All tests passed!"
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_minimal_dashboard_tests
fi
