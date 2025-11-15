#!/usr/bin/env bash
        # Auto-injected health & reliability shim

        DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer shared helpers when available
if [[ -f "$DIR/shared_functions.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/shared_functions.sh"
fi

if [[ -f "$DIR/agent_helpers.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/agent_helpers.sh"
fi

set -euo pipefail

AGENT_NAME="test_agents_auto_restart_code_analysis_agent.sh"
LOG_FILE="${LOG_FILE:-$DIR/${AGENT_NAME}.log}"
PID=$$

if type update_agent_status >/dev/null 2>&1; then
  trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; exit 0' SIGTERM SIGINT
else
  trap 'exit 0' SIGTERM SIGINT
fi

if [[ "${1-}" == "--health" || "${1-}" == "health" || "${1-}" == "-h" ]]; then
  if type agent_health_check >/dev/null 2>&1; then
    agent_health_check
    exit $?
  fi
  issues=()
  if [[ ! -w "/tmp" ]]; then
    issues+=("tmp_not_writable")
  fi
  if [[ ! -d "$DIR" ]]; then
    issues+=("cwd_missing")
  fi
  if [[ ${#issues[@]} -gt 0 ]]; then
    printf '{"ok":false,"issues":["%s"]}\n' "${issues[*]}"
    exit 2
  fi
  printf '{"ok":true}\n'
  exit 0
fi

# Original agent script continues below
#!/bin/bash
# Comprehensive test suite for auto_restart_code_analysis_agent.sh
# Tests agent lifecycle management, PID file handling, logging, and error conditions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="${SCRIPT_DIR}/test_tmp"
AGENT_SCRIPT="${SCRIPT_DIR}/agents/auto_restart_code_analysis_agent.sh"
TARGET_AGENT="${SCRIPT_DIR}/agents/code_analysis_agent.sh"

# Source test framework
source "${SCRIPT_DIR}/shell_test_framework.sh"

# Setup test environment
setup_test_env() {
    mkdir -p "$TEST_DIR"
    export TEST_MODE=true

    # Create mock code_analysis_agent.sh for testing
    cat >"${SCRIPT_DIR}/code_analysis_agent.sh.mock" <<'EOF'
#!/bin/bash
# Mock code analysis agent for testing
echo "Mock code analysis agent started with PID: $$"

# In TEST_MODE, just sleep briefly and exit
if [[ "$TEST_MODE" == "true" ]]; then
    sleep 10  # Sleep long enough for tests to check if it's running
else
    while true; do
        sleep 1
    done
fi
EOF
    chmod +x "${SCRIPT_DIR}/code_analysis_agent.sh.mock"

    # Backup original agent if it exists
    if [[ -f "$TARGET_AGENT" ]]; then
        cp "$TARGET_AGENT" "${TARGET_AGENT}.backup"
    fi

    # Replace with mock for testing
    cp "${SCRIPT_DIR}/code_analysis_agent.sh.mock" "$TARGET_AGENT"
}

# Cleanup test environment
cleanup_test_env() {
    # Remove mock and restore original
    rm -f "${SCRIPT_DIR}/code_analysis_agent.sh.mock"
    if [[ -f "${TARGET_AGENT}.backup" ]]; then
        mv "${TARGET_AGENT}.backup" "$TARGET_AGENT"
    fi

    # Clean up test files
    rm -rf "$TEST_DIR"
    rm -f "${SCRIPT_DIR}/agents/code_analysis_agent.sh.pid"
    rm -f "${SCRIPT_DIR}/agents/code_analysis_agent_restart.log"
}

# Test 1: Agent start functionality
test_agent_start() {
    local test_name="test_agent_start"
    announce_test "$test_name"

    # Ensure agent is not running initially
    "$AGENT_SCRIPT" stop >/dev/null 2>&1

    # Start the agent
    local output
    output=$("$AGENT_SCRIPT" start 2>&1)

    # Verify PID file was created
    assert_file_exists "${SCRIPT_DIR}/agents/code_analysis_agent.sh.pid" "PID file should be created"

    # Verify log file was created and contains start message
    assert_file_exists "${SCRIPT_DIR}/agents/code_analysis_agent_restart.log" "Log file should be created"

    # Check log contains start message
    local log_content
    log_content=$(cat "${SCRIPT_DIR}/agents/code_analysis_agent_restart.log")
    assert_contains "$log_content" "Starting Code Analysis Agent" "Log should contain start message"

    # Verify agent is running
    local pid
    pid=$(cat "${SCRIPT_DIR}/agents/code_analysis_agent.sh.pid" 2>/dev/null)
    if [[ -n "$pid" ]] && kill -0 "$pid" 2>/dev/null; then
        assert_true true "Agent should be running after start"
    else
        assert_true false "Agent should be running after start"
    fi

    # Cleanup
    "$AGENT_SCRIPT" stop >/dev/null 2>&1

    test_passed "$test_name"
}

# Test 2: Agent stop functionality
test_agent_stop() {
    local test_name="test_agent_stop"
    announce_test "$test_name"

    # Start agent first
    "$AGENT_SCRIPT" start >/dev/null 2>&1
    sleep 1

    # Verify it's running
    local initial_pid
    initial_pid=$(cat "${SCRIPT_DIR}/agents/code_analysis_agent.sh.pid" 2>/dev/null)
    assert_not_empty "$initial_pid" "Agent should be running initially"

    # Stop the agent
    local output
    output=$("$AGENT_SCRIPT" stop 2>&1)

    # Verify PID file was removed
    assert_file_not_exists "${SCRIPT_DIR}/agents/code_analysis_agent.sh.pid" "PID file should be removed after stop"

    # Check log contains stop message
    local log_content
    log_content=$(cat "${SCRIPT_DIR}/agents/code_analysis_agent_restart.log")
    assert_contains "$log_content" "Agent stopped" "Log should contain stop message"

    # Verify agent is no longer running
    if [[ -n "$initial_pid" ]] && ! kill -0 "$initial_pid" 2>/dev/null; then
        assert_true true "Agent should not be running after stop"
    else
        assert_true false "Agent should not be running after stop"
    fi

    test_passed "$test_name"
}

# Test 3: Agent restart functionality
test_agent_restart() {
    local test_name="test_agent_restart"
    announce_test "$test_name"

    # Start agent first
    "$AGENT_SCRIPT" start >/dev/null 2>&1
    sleep 1

    local initial_pid
    initial_pid=$(cat "${SCRIPT_DIR}/agents/code_analysis_agent.sh.pid" 2>/dev/null)
    assert_not_empty "$initial_pid" "Agent should be running initially"

    # Restart the agent
    local output
    output=$("$AGENT_SCRIPT" restart 2>&1)

    # Verify new PID file exists
    assert_file_exists "${SCRIPT_DIR}/agents/code_analysis_agent.sh.pid" "PID file should exist after restart"

    # Check log contains restart messages
    local log_content
    log_content=$(cat "${SCRIPT_DIR}/agents/code_analysis_agent_restart.log")
    assert_contains "$log_content" "Restarting Code Analysis Agent" "Log should contain restart message"
    assert_contains "$log_content" "Agent stopped" "Log should contain stop message"
    assert_contains "$log_content" "Agent started with PID" "Log should contain start message"

    # Verify old process is gone and new one exists
    local new_pid
    new_pid=$(cat "${SCRIPT_DIR}/agents/code_analysis_agent.sh.pid" 2>/dev/null)
    assert_not_empty "$new_pid" "New agent should be running after restart"

    if [[ "$initial_pid" != "$new_pid" ]]; then
        assert_true true "Agent should have new PID after restart"
    else
        assert_true false "Agent should have new PID after restart"
    fi

    # Cleanup
    "$AGENT_SCRIPT" stop >/dev/null 2>&1

    test_passed "$test_name"
}

# Test 4: Agent status functionality
test_agent_status() {
    local test_name="test_agent_status"
    announce_test "$test_name"

    # Test status when agent is not running
    "$AGENT_SCRIPT" stop >/dev/null 2>&1
    sleep 1

    local status_output
    status_output=$("$AGENT_SCRIPT" status 2>&1)
    assert_contains "$status_output" "not running" "Status should show agent not running"

    # Test status when agent is running
    "$AGENT_SCRIPT" start >/dev/null 2>&1
    sleep 1

    status_output=$("$AGENT_SCRIPT" status 2>&1)
    assert_contains "$status_output" "is running" "Status should show agent is running"
    assert_contains "$status_output" "PID:" "Status should show PID"

    # Cleanup
    "$AGENT_SCRIPT" stop >/dev/null 2>&1

    test_passed "$test_name"
}

# Test 5: Default command (start)
test_default_command() {
    local test_name="test_default_command"
    announce_test "$test_name"

    # Ensure agent is not running
    "$AGENT_SCRIPT" stop >/dev/null 2>&1

    # Run script without arguments (should default to start)
    local output
    output=$("$AGENT_SCRIPT" 2>&1)

    # Verify agent started
    assert_file_exists "${SCRIPT_DIR}/agents/code_analysis_agent.sh.pid" "PID file should be created with default command"

    local log_content
    log_content=$(cat "${SCRIPT_DIR}/agents/code_analysis_agent_restart.log")
    assert_contains "$log_content" "Starting Code Analysis Agent" "Log should contain start message for default command"

    # Cleanup
    "$AGENT_SCRIPT" stop >/dev/null 2>&1

    test_passed "$test_name"
}

# Test 6: Invalid command handling
test_invalid_command() {
    local test_name="test_invalid_command"
    announce_test "$test_name"

    # Run script with invalid command
    local output
    output=$("$AGENT_SCRIPT" invalid_command 2>&1)
    local exit_code=$?

    # Should show usage message and exit with error
    assert_contains "$output" "Usage:" "Should show usage message for invalid command"
    assert_equals "$exit_code" "1" "Should exit with code 1 for invalid command"

    test_passed "$test_name"
}

# Test 7: PID file cleanup on abnormal termination
test_pid_file_cleanup() {
    local test_name="test_pid_file_cleanup"
    announce_test "$test_name"

    # Start agent
    "$AGENT_SCRIPT" start >/dev/null 2>&1
    sleep 1

    local pid
    pid=$(cat "${SCRIPT_DIR}/agents/code_analysis_agent.sh.pid" 2>/dev/null)
    assert_not_empty "$pid" "Agent should be running"

    # Simulate abnormal termination by killing process directly
    if [[ -n "$pid" ]]; then
        kill -9 "$pid" 2>/dev/null || true
        sleep 2
    fi

    # Try to start again - should clean up stale PID file
    local output
    output=$("$AGENT_SCRIPT" start 2>&1)

    # Should start successfully despite stale PID file
    local new_pid
    new_pid=$(cat "${SCRIPT_DIR}/agents/code_analysis_agent.sh.pid" 2>/dev/null)
    assert_not_empty "$new_pid" "Agent should start successfully after cleanup"

    # Cleanup
    "$AGENT_SCRIPT" stop >/dev/null 2>&1

    test_passed "$test_name"
}

# Test 8: Multiple start attempts
test_multiple_starts() {
    local test_name="test_multiple_starts"
    announce_test "$test_name"

    # Ensure clean state
    "$AGENT_SCRIPT" stop >/dev/null 2>&1

    # Start agent first time
    "$AGENT_SCRIPT" start >/dev/null 2>&1
    sleep 1

    local first_pid
    first_pid=$(cat "${SCRIPT_DIR}/agents/code_analysis_agent.sh.pid" 2>/dev/null)
    assert_not_empty "$first_pid" "Agent should be running after first start"

    # Try to start again
    local output
    output=$("$AGENT_SCRIPT" start 2>&1)

    # Should indicate already running
    local log_content
    log_content=$(cat "${SCRIPT_DIR}/agents/code_analysis_agent_restart.log")
    assert_contains "$log_content" "Agent is already running" "Should log that agent is already running"

    # PID should remain the same
    local second_pid
    second_pid=$(cat "${SCRIPT_DIR}/agents/code_analysis_agent.sh.pid" 2>/dev/null)
    assert_equals "$first_pid" "$second_pid" "PID should remain the same on multiple starts"

    # Cleanup
    "$AGENT_SCRIPT" stop >/dev/null 2>&1

    test_passed "$test_name"
}

# Test 9: Stop when not running
test_stop_when_not_running() {
    local test_name="test_stop_when_not_running"
    announce_test "$test_name"

    # Ensure agent is not running
    "$AGENT_SCRIPT" stop >/dev/null 2>&1
    sleep 1

    # Try to stop again
    local output
    output=$("$AGENT_SCRIPT" stop 2>&1)

    # Should handle gracefully
    local log_content
    log_content=$(cat "${SCRIPT_DIR}/agents/code_analysis_agent_restart.log")
    assert_contains "$log_content" "No PID file found" "Should log that no PID file was found"

    test_passed "$test_name"
}

# Test 10: Logging functionality
test_logging_functionality() {
    local test_name="test_logging_functionality"
    announce_test "$test_name"

    # Clear log file
    >"${SCRIPT_DIR}/agents/code_analysis_agent_restart.log"

    # Start agent
    "$AGENT_SCRIPT" start >/dev/null 2>&1
    sleep 1

    # Stop agent
    "$AGENT_SCRIPT" stop >/dev/null 2>&1

    # Check log format
    local log_content
    log_content=$(cat "${SCRIPT_DIR}/agents/code_analysis_agent_restart.log")

    # Should contain timestamps
    assert_regex "$log_content" "\\[.*\\]" "Log should contain timestamp brackets"

    # Should contain start and stop messages
    assert_contains "$log_content" "Starting Code Analysis Agent" "Should log start message"
    assert_contains "$log_content" "Agent stopped" "Should log stop message"

    test_passed "$test_name"
}

# Run all tests
run_tests() {
    setup_test_env

    echo "Running comprehensive tests for auto_restart_code_analysis_agent.sh..."
    echo "================================================================="

    # Run individual tests
    test_agent_start
    test_agent_stop
    test_agent_restart
    test_agent_status
    test_default_command
    test_invalid_command
    test_pid_file_cleanup
    test_multiple_starts
    test_stop_when_not_running
    test_logging_functionality

    echo "================================================================="
    echo "Test Summary:"
    echo "Total tests: $(get_total_tests)"
    echo "Passed: $(get_passed_tests)"
    echo "Failed: $(get_failed_tests)"

    cleanup_test_env

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
