#!/bin/bash
# Auto-generated test for .auto_restart_agent_integration.sh
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MARKER_FILE="$SCRIPT_DIR/agents/.auto_restart_agent_integration.sh"
AGENT_FILE="$SCRIPT_DIR/agents/agent_integration.sh"

# Source test framework
source "$SCRIPT_DIR/shell_test_framework.sh"

run_tests() {
    announce_test "check_marker__auto_restart_agent_integration"

    assert_file_exists "$MARKER_FILE" "Marker file should exist"
    assert_file_executable "$MARKER_FILE" "Marker file should be executable"

    local content
    content=$(cat "$MARKER_FILE" 2>/dev/null || echo "")
    assert_contains "$content" "exit 0" "Marker file should exit 0"

    assert_file_exists "$AGENT_FILE" "Corresponding agent should exist"
    assert_file_executable "$AGENT_FILE" "Corresponding agent should be executable"

    test_passed "check_marker__auto_restart_agent_integration"
}

if [[ "tests/generate_auto_restart_marker_tests.sh" == "tests/generate_auto_restart_marker_tests.sh" ]]; then
    run_tests
    exit 0
fi
