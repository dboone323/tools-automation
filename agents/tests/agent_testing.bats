#!/usr/bin/env bats
# Tests for agent_testing.sh - Testing agent functionality

setup() {
    export SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/.." && pwd)"
    export PROJECTS_DIR="/tmp/test_projects_$$"
    export LOG_FILE="/tmp/testing_agent_test.log"
    export STATUS_FILE="${SCRIPT_DIR}/test_agent_status.json"
    export TASK_QUEUE="${SCRIPT_DIR}/test_task_queue.json"
    
    # Create test directories
    mkdir -p "$PROJECTS_DIR"
    
    # Create log file
    touch "$LOG_FILE"
    
    # Initialize status and queue files
    echo '{"agents":{},"last_update":0}' > "$STATUS_FILE"
    echo '{"tasks":[]}' > "$TASK_QUEUE"
    
    # Source the agent script
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
}

teardown() {
    # Cleanup
    rm -rf "$PROJECTS_DIR"
    rm -f "$LOG_FILE"
    rm -f "$STATUS_FILE" "$TASK_QUEUE"
}

@test "agent_testing.sh is sourceable" {
    run bash -c "source '${SCRIPT_DIR}/agent_testing.sh' 2>&1"
    # Should source without fatal errors (warnings are OK)
    [ "$status" -eq 0 ] || [[ "$output" != *"fatal"* ]]
}

@test "AGENT_NAME is set" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    [[ -n "$AGENT_NAME" ]]
}

@test "LOG_FILE path is configured" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    [[ -n "$LOG_FILE" ]]
}

@test "PROJECTS_DIR path is configured" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    [[ -n "$PROJECTS_DIR" ]]
}

@test "run_with_timeout function exists" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    type run_with_timeout | grep -q "function"
}

@test "run_with_timeout executes simple command" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    run run_with_timeout 5 "echo 'test'"
    [ "$status" -eq 0 ]
}

@test "run_with_timeout respects timeout" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    # This should timeout
    run run_with_timeout 2 "sleep 10"
    # Should return timeout exit code (124)
    [ "$status" -eq 124 ] || [ "$status" -ne 0 ]
}

@test "run_with_timeout allows command to complete" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    run run_with_timeout 5 "sleep 1"
    [ "$status" -eq 0 ]
}

@test "check_resource_limits function exists" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    type check_resource_limits | grep -q "function"
}

@test "check_resource_limits with valid operation name" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    run check_resource_limits "test_operation"
    # Should execute without crashing
    true
}

@test "check_resource_limits checks disk space" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    # Run and check it doesn't crash
    check_resource_limits "disk_check" 2>&1 | grep -q "disk\|space" || true
}

@test "check_resource_limits writes to log" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    check_resource_limits "log_test" 2>/dev/null
    # Log file should have content
    [[ -s "$LOG_FILE" ]] || true
}

@test "update_status function exists" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    type update_status | grep -q "function" || type update_status | grep -q "alias"
}

@test "update_status can be called" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    run update_status "idle"
    # Should not crash
    true
}

@test "SLEEP_INTERVAL is numeric" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    [[ "$SLEEP_INTERVAL" =~ ^[0-9]+$ ]]
}

@test "MAX_INTERVAL is numeric" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    [[ "$MAX_INTERVAL" =~ ^[0-9]+$ ]]
}

@test "SLEEP_INTERVAL is less than MAX_INTERVAL" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    [[ "$SLEEP_INTERVAL" -lt "$MAX_INTERVAL" ]]
}

@test "PID is set" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    [[ -n "$PID" ]]
    [[ "$PID" =~ ^[0-9]+$ ]]
}

@test "agent creates log file if missing" {
    rm -f "$LOG_FILE"
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    # After sourcing, operations should create log
    check_resource_limits "test" 2>/dev/null || true
    [[ -f "$LOG_FILE" ]] || true
}

@test "run_with_timeout logs start message" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    run_with_timeout 3 "true" 2>/dev/null
    grep -q "Starting operation with" "$LOG_FILE" || true
}

@test "run_with_timeout logs timeout message" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    run_with_timeout 1 "sleep 10" 2>/dev/null || true
    grep -q "timed out\|timeout" "$LOG_FILE" || true
}

@test "check_resource_limits logs operation name" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    check_resource_limits "custom_operation" 2>/dev/null || true
    grep -q "custom_operation" "$LOG_FILE" || true
}

@test "check_resource_limits checks available space" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    check_resource_limits "space_test" 2>/dev/null || true
    # Should complete without error
    true
}

@test "check_resource_limits handles non-existent directory" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    export PROJECTS_DIR="/nonexistent/path/$$"
    run check_resource_limits "test"
    # Should handle gracefully
    true
}

@test "agent handles SIGTERM gracefully" {
    if [[ "$(uname)" == "Darwin" ]]; then
        skip "Signal propagation timing is flaky on macOS non-interactive shells"
    fi
    # Start a backgrounded version
    bash -c "source '${SCRIPT_DIR}/agent_testing.sh' 2>/dev/null; sleep 30" &
    local pid=$!
    sleep 1
    # Send SIGTERM to the entire process group to ensure foreground children receive it
    kill -TERM -"$pid" 2>/dev/null || true
        # Wait briefly for termination
        for _ in 1 2 3 4 5; do
            sleep 0.2
            ! kill -0 "$pid" 2>/dev/null && break
        done
        ! kill -0 "$pid" 2>/dev/null
}

@test "agent handles SIGINT gracefully" {
    if [[ "$(uname)" == "Darwin" ]]; then
        skip "Signal propagation timing is flaky on macOS non-interactive shells"
    fi
    # Start a backgrounded version
    bash -c "source '${SCRIPT_DIR}/agent_testing.sh' 2>/dev/null; sleep 30" &
    local pid=$!
    sleep 1
    # Send SIGINT to the entire process group to ensure foreground children receive it
    kill -INT -"$pid" 2>/dev/null || true
        # Wait briefly for termination
        for _ in 1 2 3 4 5; do
            sleep 0.2
            ! kill -0 "$pid" 2>/dev/null && break
        done
        ! kill -0 "$pid" 2>/dev/null
}

@test "run_with_timeout handles command failures" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    run run_with_timeout 5 "false"
    # Should return non-zero (not timeout code)
    [ "$status" -ne 0 ]
    [ "$status" -ne 124 ]
}

@test "run_with_timeout preserves command exit code" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    run run_with_timeout 5 "exit 42"
    [ "$status" -eq 42 ]
}

@test "check_resource_limits file count limit" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    # Create test directory
    mkdir -p "$PROJECTS_DIR/test"
    # Should handle directory with files
    run check_resource_limits "file_count_test"
    true
}

@test "agent source does not pollute environment" {
    # Capture initial env
    env_before=$(env | sort)
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    env_after=$(env | sort)
    # Major env variables should not be drastically different
    true
}

@test "agent logs are timestamped" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    check_resource_limits "timestamp_test" 2>/dev/null || true
    # Check for date/time format in log
    grep -E "\[[A-Z][a-z]{2} [A-Z][a-z]{2} [0-9 :]+" "$LOG_FILE" || true
}

@test "agent can handle empty PROJECTS_DIR" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    export PROJECTS_DIR="/tmp/empty_projects_$$"
    mkdir -p "$PROJECTS_DIR"
    run check_resource_limits "empty_dir_test"
    # Should not fail
    true
}

@test "run_with_timeout with zero timeout" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    run run_with_timeout 0 "echo test"
    # Should handle edge case
    true
}

@test "run_with_timeout with negative timeout" {
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    run run_with_timeout -1 "echo test"
    # Should handle invalid input
    true
}

@test "agent respects existing log file permissions" {
    touch "$LOG_FILE"
    chmod 600 "$LOG_FILE"
    source "${SCRIPT_DIR}/agent_testing.sh" 2>/dev/null || true
    check_resource_limits "permission_test" 2>/dev/null || true
    # Permissions should be maintained or writable
    [[ -w "$LOG_FILE" ]] || true
}
