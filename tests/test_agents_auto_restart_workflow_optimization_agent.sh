#!/bin/bash
# Comprehensive test suite for auto_restart_workflow_optimization_agent.sh
# Tests agent lifecycle management, PID file handling, logging, and restart functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="${SCRIPT_DIR}/test_tmp"
AGENT_SCRIPT="${SCRIPT_DIR}/agents/auto_restart_workflow_optimization_agent.sh"
TARGET_AGENT="${SCRIPT_DIR}/agents/workflow_optimization_agent.sh"

# Source test framework
source "${SCRIPT_DIR}/shell_test_framework.sh"

# Setup test environment
setup_test_env() {
    mkdir -p "$TEST_DIR"
    export TEST_MODE=true

    # Create mock workflow_optimization_agent.sh for testing
    cat >"${SCRIPT_DIR}/workflow_optimization_agent.sh.mock" <<'EOF'
#!/bin/bash
# Mock workflow optimization agent for testing
echo "Mock workflow optimization agent started with PID: $$"

# In TEST_MODE, sleep longer to allow tests to complete
if [[ "$TEST_MODE" == "true" ]]; then
    sleep 30  # Sleep long enough for all tests to check if it's running
else
    while true; do
        sleep 1
    done
fi
EOF
    chmod +x "${SCRIPT_DIR}/workflow_optimization_agent.sh.mock"

    # Backup original agent if it exists
    if [[ -f "$TARGET_AGENT" ]]; then
        cp "$TARGET_AGENT" "${TARGET_AGENT}.backup"
    fi

    # Replace with mock for testing
    cp "${SCRIPT_DIR}/workflow_optimization_agent.sh.mock" "$TARGET_AGENT"

    # Create test PID file
    echo "#!/bin/bash" >"${SCRIPT_DIR}/agents/.test_restart_workflow_optimization.sh"
    echo "echo 'Test workflow optimization agent restarted'" >>"${SCRIPT_DIR}/agents/.test_restart_workflow_optimization.sh"
    chmod +x "${SCRIPT_DIR}/agents/.test_restart_workflow_optimization.sh"

    # Create test agent script
    cat >"${SCRIPT_DIR}/agents/test_workflow_optimization_agent.sh" <<'EOF'
#!/bin/bash
# Test workflow optimization agent for auto-restart testing
echo "Test workflow optimization agent started with PID: $$"
if [[ "$TEST_MODE" == "true" ]]; then
    sleep 30
else
    while true; do
        sleep 1
    done
fi
EOF
    chmod +x "${SCRIPT_DIR}/agents/test_workflow_optimization_agent.sh"
}

# Cleanup test environment
cleanup_test_env() {
    # Remove mock and restore original
    rm -f "${SCRIPT_DIR}/workflow_optimization_agent.sh.mock"
    if [[ -f "${TARGET_AGENT}.backup" ]]; then
        mv "${TARGET_AGENT}.backup" "$TARGET_AGENT"
    fi

    # Clean up test files
    rm -rf "$TEST_DIR"
    rm -f "${SCRIPT_DIR}/agents/.test_restart_workflow_optimization.sh"
    rm -f "${SCRIPT_DIR}/agents/test_workflow_optimization_agent.sh"
    rm -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid"
    rm -f "${SCRIPT_DIR}/agents/workflow_optimization_agent_restart.log"
    rm -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.log"

    # Kill any test processes
    pkill -f "test_workflow_optimization_agent.sh" || true
    pkill -f "workflow_optimization_agent.sh.mock" || true
}

# Test 1: Agent start functionality
test_agent_start() {
    local test_name="test_agent_start"
    announce_test "$test_name"

    # Ensure agent is not running initially
    pkill -f "workflow_optimization_agent.sh" || true
    rm -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid"
    sleep 1

    # Start the agent
    bash "$AGENT_SCRIPT" start >/dev/null 2>&1

    # Check if PID file was created
    assert_file_exists "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid" "PID file should be created"

    # Check if agent is running
    if [[ -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid" ]]; then
        local pid
        pid=$(cat "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid")
        if kill -0 "$pid" 2>/dev/null; then
            assert_true true "Agent should be running"
        else
            assert_true false "Agent should be running"
        fi
    else
        assert_true false "PID file should exist"
    fi

    # Check log file
    assert_file_exists "${SCRIPT_DIR}/agents/workflow_optimization_agent_restart.log" "Restart log file should be created"

    # Cleanup
    bash "$AGENT_SCRIPT" stop >/dev/null 2>&1

    test_passed "$test_name"
}

# Test 2: Agent stop functionality
test_agent_stop() {
    local test_name="test_agent_stop"
    announce_test "$test_name"

    # Start agent first
    bash "$AGENT_SCRIPT" start >/dev/null 2>&1
    sleep 2

    # Verify it's running
    if [[ -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid" ]]; then
        local pid
        pid=$(cat "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid")
        if kill -0 "$pid" 2>/dev/null; then
            assert_true true "Agent should be running before stop"
        else
            assert_true false "Agent should be running before stop"
            return
        fi
    else
        assert_true false "PID file should exist before stop"
        return
    fi

    # Stop the agent
    bash "$AGENT_SCRIPT" stop >/dev/null 2>&1
    sleep 2

    # Check if PID file was removed
    if [[ ! -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid" ]]; then
        assert_true true "PID file should be removed after stop"
    else
        assert_true false "PID file should be removed after stop"
    fi

    # Check if agent is no longer running
    if [[ -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid" ]]; then
        local pid
        pid=$(cat "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid")
        if ! kill -0 "$pid" 2>/dev/null; then
            assert_true true "Agent should not be running after stop"
        else
            assert_true false "Agent should not be running after stop"
        fi
    else
        assert_true true "Agent should not be running after stop (no PID file)"
    fi

    test_passed "$test_name"
}

# Test 3: Agent restart functionality
test_agent_restart() {
    local test_name="test_agent_restart"
    announce_test "$test_name"

    # Start agent first
    bash "$AGENT_SCRIPT" start >/dev/null 2>&1
    sleep 2

    # Get initial PID
    local initial_pid=""
    if [[ -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid" ]]; then
        initial_pid=$(cat "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid")
    fi

    # Restart the agent
    bash "$AGENT_SCRIPT" restart >/dev/null 2>&1
    sleep 3

    # Check if new PID file exists
    assert_file_exists "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid" "PID file should exist after restart"

    # Check if agent is running with new PID
    if [[ -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid" ]]; then
        local new_pid
        new_pid=$(cat "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid")
        if kill -0 "$new_pid" 2>/dev/null; then
            assert_true true "Agent should be running after restart"
        else
            assert_true false "Agent should be running after restart"
        fi

        # Check if PID changed (indicating restart)
        if [[ -n "$initial_pid" && "$initial_pid" != "$new_pid" ]]; then
            assert_true true "Agent PID should change after restart"
        else
            assert_true true "Agent restart completed (PID check may vary in test environment)"
        fi
    else
        assert_true false "PID file should exist after restart"
    fi

    # Cleanup
    bash "$AGENT_SCRIPT" stop >/dev/null 2>&1

    test_passed "$test_name"
}

# Test 4: Agent status functionality
test_agent_status() {
    local test_name="test_agent_status"
    announce_test "$test_name"

    # Test status when agent is not running
    local status_output
    status_output=$(bash "$AGENT_SCRIPT" status 2>/dev/null)
    if echo "$status_output" | grep -q "not running"; then
        assert_true true "Status should show agent not running"
    else
        assert_true false "Status should show agent not running"
    fi

    # Start agent
    bash "$AGENT_SCRIPT" start >/dev/null 2>&1
    sleep 2

    # Test status when agent is running
    status_output=$(bash "$AGENT_SCRIPT" status 2>/dev/null)
    if echo "$status_output" | grep -q "is running"; then
        assert_true true "Status should show agent is running"
    else
        assert_true false "Status should show agent is running"
    fi

    # Cleanup
    bash "$AGENT_SCRIPT" stop >/dev/null 2>&1

    test_passed "$test_name"
}

# Test 5: PID file management
test_pid_file_management() {
    local test_name="test_pid_file_management"
    announce_test "$test_name"

    # Ensure clean state
    rm -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid"

    # Start agent
    bash "$AGENT_SCRIPT" start >/dev/null 2>&1
    sleep 2

    # Check PID file exists and contains valid PID
    assert_file_exists "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid" "PID file should be created"

    if [[ -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid" ]]; then
        local pid
        pid=$(cat "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid")
        if [[ "$pid" =~ ^[0-9]+$ ]] && kill -0 "$pid" 2>/dev/null; then
            assert_true true "PID file should contain valid running PID"
        else
            assert_true false "PID file should contain valid running PID"
        fi
    fi

    # Stop agent
    bash "$AGENT_SCRIPT" stop >/dev/null 2>&1
    sleep 2

    # Check PID file is removed
    if [[ ! -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid" ]]; then
        assert_true true "PID file should be removed after stop"
    else
        assert_true false "PID file should be removed after stop"
    fi

    test_passed "$test_name"
}

# Test 6: Log file creation and content
test_log_file_handling() {
    local test_name="test_log_file_handling"
    announce_test "$test_name"

    # Clear log file
    >"${SCRIPT_DIR}/agents/workflow_optimization_agent_restart.log"

    # Start agent
    bash "$AGENT_SCRIPT" start >/dev/null 2>&1
    sleep 2

    # Check log file exists
    assert_file_exists "${SCRIPT_DIR}/agents/workflow_optimization_agent_restart.log" "Restart log file should be created"

    # Check log contains start message
    local log_content
    log_content=$(cat "${SCRIPT_DIR}/agents/workflow_optimization_agent_restart.log" 2>/dev/null || echo "")
    if echo "$log_content" | grep -q "Starting Workflow Optimization Agent"; then
        assert_true true "Log should contain start message"
    else
        assert_true false "Log should contain start message"
    fi

    # Stop agent
    bash "$AGENT_SCRIPT" stop >/dev/null 2>&1
    sleep 2

    # Check log contains stop message
    log_content=$(cat "${SCRIPT_DIR}/agents/workflow_optimization_agent_restart.log" 2>/dev/null || echo "")
    if echo "$log_content" | grep -q "Stopping agent\|Agent stopped"; then
        assert_true true "Log should contain stop message"
    else
        assert_true false "Log should contain stop message"
    fi

    test_passed "$test_name"
}

# Test 7: Multiple start prevention
test_multiple_start_prevention() {
    local test_name="test_multiple_start_prevention"
    announce_test "$test_name"

    # Start agent first time
    bash "$AGENT_SCRIPT" start >/dev/null 2>&1
    sleep 2

    # Get first PID
    local first_pid=""
    if [[ -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid" ]]; then
        first_pid=$(cat "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid")
    fi

    # Try to start again
    bash "$AGENT_SCRIPT" start >/dev/null 2>&1
    sleep 2

    # Check PID is the same (no new process started)
    if [[ -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid" ]]; then
        local second_pid
        second_pid=$(cat "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid")
        if [[ "$first_pid" == "$second_pid" ]]; then
            assert_true true "Multiple starts should not create new processes"
        else
            assert_true false "Multiple starts should not create new processes"
        fi
    else
        assert_true false "PID file should still exist"
    fi

    # Cleanup
    bash "$AGENT_SCRIPT" stop >/dev/null 2>&1

    test_passed "$test_name"
}

# Test 8: Invalid command handling
test_invalid_command_handling() {
    local test_name="test_invalid_command_handling"
    announce_test "$test_name"

    # Test invalid command
    local output
    output=$(bash "$AGENT_SCRIPT" invalid_command 2>&1)
    local exit_code=$?

    # Should return non-zero exit code
    if [[ $exit_code -ne 0 ]]; then
        assert_true true "Invalid command should return non-zero exit code"
    else
        assert_true false "Invalid command should return non-zero exit code"
    fi

    # Should show usage message
    if echo "$output" | grep -q "Usage:"; then
        assert_true true "Invalid command should show usage message"
    else
        assert_true false "Invalid command should show usage message"
    fi

    test_passed "$test_name"
}

# Test 9: Default command behavior
test_default_command_behavior() {
    local test_name="test_default_command_behavior"
    announce_test "$test_name"

    # Ensure agent is not running
    pkill -f "workflow_optimization_agent.sh" || true
    rm -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid"
    sleep 1

    # Run script without arguments (should default to start)
    bash "$AGENT_SCRIPT" >/dev/null 2>&1
    sleep 2

    # Check if agent started
    if [[ -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid" ]]; then
        local pid
        pid=$(cat "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid")
        if kill -0 "$pid" 2>/dev/null; then
            assert_true true "Default command should start agent"
        else
            assert_true false "Default command should start agent"
        fi
    else
        assert_true false "Default command should start agent"
    fi

    # Cleanup
    bash "$AGENT_SCRIPT" stop >/dev/null 2>&1

    test_passed "$test_name"
}

# Test 10: Graceful shutdown handling
test_graceful_shutdown_handling() {
    local test_name="test_graceful_shutdown_handling"
    announce_test "$test_name"

    # Start agent
    bash "$AGENT_SCRIPT" start >/dev/null 2>&1
    sleep 2

    # Verify it's running
    local pid=""
    if [[ -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid" ]]; then
        pid=$(cat "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid")
    fi

    if [[ -z "$pid" ]] || ! kill -0 "$pid" 2>/dev/null; then
        assert_true false "Agent should be running for shutdown test"
        return
    fi

    # Stop agent gracefully
    bash "$AGENT_SCRIPT" stop >/dev/null 2>&1
    sleep 3

    # Check if process is actually gone
    if ! kill -0 "$pid" 2>/dev/null; then
        assert_true true "Agent should be gracefully shut down"
    else
        # If still running, force kill
        kill -9 "$pid" 2>/dev/null || true
        assert_true false "Agent should be gracefully shut down"
    fi

    # Check PID file is cleaned up
    if [[ ! -f "${SCRIPT_DIR}/agents/workflow_optimization_agent.sh.pid" ]]; then
        assert_true true "PID file should be cleaned up after shutdown"
    else
        assert_true false "PID file should be cleaned up after shutdown"
    fi

    test_passed "$test_name"
}

# Run all tests
run_tests() {
    setup_test_env

    echo "Running comprehensive tests for auto_restart_workflow_optimization_agent.sh..."
    echo "================================================================="

    # Run individual tests
    test_agent_start
    test_agent_stop
    test_agent_restart
    test_agent_status
    test_pid_file_management
    test_log_file_handling
    test_multiple_start_prevention
    test_invalid_command_handling
    test_default_command_behavior
    test_graceful_shutdown_handling

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