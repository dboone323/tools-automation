#!/bin/bash

# Test suite for validate_command.sh
# Comprehensive tests covering all functionality

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shell_test_framework.sh"

# Override PROJECT_ROOT for this test
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

VALIDATE_COMMAND_SCRIPT="$PROJECT_ROOT/validate_command.sh"

# Test: Basic command validation success
test_validate_command_basic_success() {
    echo "Testing basic command validation success..."

    # Run validation with a safe command
    "$VALIDATE_COMMAND_SCRIPT" "echo hello" "false"

    assert_success "Basic command validation"
}

# Test: Command validation with potential service interference
test_validate_command_service_interference() {
    echo "Testing command validation with service interference..."

    # Mock a background service running
    mock_command "pgrep" "12345"

    # Run validation with a command that may interfere
    "$VALIDATE_COMMAND_SCRIPT" "curl http://example.com" "false"

    local exit_code=$?
    assert_equals 1 "$exit_code" "Should fail when services are running and command may interfere"
}

# Test: Command validation with port conflict
test_validate_command_port_conflict() {
    echo "Testing command validation with port conflict..."

    # Mock lsof to show port 5005 in use
    mock_command "lsof" "COMMAND PID USER FD TYPE DEVICE SIZE/OFF NODE NAME
python 12345 user 3u IPv4 0x123456 0t0 TCP *:5005 (LISTEN)"

    # Run validation with a server command
    "$VALIDATE_COMMAND_SCRIPT" "python mcp_server.py" "true"

    local exit_code=$?
    assert_equals 1 "$exit_code" "Should fail when port 5005 is in use"
}

# Test: Command validation missing working directory
test_validate_command_missing_workdir() {
    echo "Testing command validation missing working directory..."

    # Run validation with a command that needs working directory
    "$VALIDATE_COMMAND_SCRIPT" "python setup.py" "false"

    local exit_code=$?
    assert_equals 1 "$exit_code" "Should warn about missing working directory"
}

# Test: Command validation should use background
test_validate_command_should_background() {
    echo "Testing command validation should use background..."

    # Run validation with a server command not marked as background
    "$VALIDATE_COMMAND_SCRIPT" "python server.py" "false"

    local exit_code=$?
    assert_equals 1 "$exit_code" "Should warn about long-running command not using background"
}

# Test: Safe status check
test_validate_command_safe_status() {
    echo "Testing safe status check..."

    # Mock background services
    mock_command "pgrep" "12345"

    # Run validation with safe status check
    "$VALIDATE_COMMAND_SCRIPT" "curl http://localhost:5005/status" "false"

    assert_success "Safe status check should pass"
}

# Test: No arguments
test_validate_command_no_args() {
    echo "Testing no arguments..."

    # Run with no arguments
    "$VALIDATE_COMMAND_SCRIPT"

    local exit_code=$?
    assert_equals 1 "$exit_code" "Should exit with usage when no arguments"
}

# Test: Log file creation
test_validate_command_log_file() {
    echo "Testing log file creation..."

    # Run validation
    "$VALIDATE_COMMAND_SCRIPT" "echo test" "false"

    assert_success "Log file test"

    # Check if log file exists
    local log_file="$HOME/.copilot_validation.log"
    assert_file_exists "$log_file" "Log file should be created"
}
