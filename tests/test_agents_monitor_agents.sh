#!/bin/bash
# Comprehensive test suite for monitor_agents.sh
# Tests agent supervision, failure detection, stuck task handling, and process monitoring

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/monitor_agents.sh"
TEST_FRAMEWORK="${SCRIPT_DIR}/../shell_test_framework.sh"

# Source the test framework
source "$TEST_FRAMEWORK"

# Source shared functions that the agent uses
source "${SCRIPT_DIR}/../agents/shared_functions.sh"

# Test setup
setup_test_environment() {
    export TEST_MODE=true
    export SCRIPT_DIR="${SCRIPT_DIR}/../agents"
    export LOG_FILE="${SCRIPT_DIR}/test_agent_supervision.log"
    export STATUS_FILE="${SCRIPT_DIR}/test_agent_status.json"
    export TASK_QUEUE_FILE="${SCRIPT_DIR}/test_task_queue.json"

    # Clean up any existing test files
    rm -f "$LOG_FILE" "$STATUS_FILE" "$TASK_QUEUE_FILE"
}

# Test cleanup
cleanup_test_environment() {
    rm -f "$LOG_FILE" "$STATUS_FILE" "$TASK_QUEUE_FILE"
}

# Test 1: Verify script structure and function definitions
test_monitor_agents_script_structure() {
    announce_test "Script structure and function definitions"

    # Check if script exists and is executable
    assert_file_exists "$AGENT_SCRIPT"
    assert_file_executable "$AGENT_SCRIPT"

    # Check for required function definitions
    assert_pattern_in_file "start_agent()" "$AGENT_SCRIPT"
    assert_pattern_in_file "ensure_agents_running()" "$AGENT_SCRIPT"
    assert_pattern_in_file "check_repeated_failures()" "$AGENT_SCRIPT"
    assert_pattern_in_file "handle_stuck_tasks()" "$AGENT_SCRIPT"
    assert_pattern_in_file "monitor_long_running_processes()" "$AGENT_SCRIPT"

    # Check for required variable definitions
    assert_pattern_in_file "AGENTS=(" "$AGENT_SCRIPT"
    assert_pattern_in_file "LOG_FILE=" "$AGENT_SCRIPT"
    assert_pattern_in_file "STATUS_FILE=" "$AGENT_SCRIPT"
    assert_pattern_in_file "TASK_QUEUE_FILE=" "$AGENT_SCRIPT"

    test_passed "Script structure validation"
}

# Test 2: Verify agent array configuration
test_agent_array_configuration() {
    announce_test "Agent array configuration"

    # Check that AGENTS array contains expected agents
    assert_pattern_in_file '"agent_build.sh"' "$AGENT_SCRIPT"
    assert_pattern_in_file '"agent_debug.sh"' "$AGENT_SCRIPT"
    assert_pattern_in_file '"agent_codegen.sh"' "$AGENT_SCRIPT"

    test_passed "Agent array configuration"
}

# Test 3: Verify logging configuration
test_logging_configuration() {
    announce_test "Logging configuration"

    # Check for log file setup
    assert_pattern_in_file "LOG_FILE=" "$AGENT_SCRIPT"
    assert_pattern_in_file "tee -a" "$AGENT_SCRIPT"

    # Check for date stamps in logging
    assert_pattern_in_file '$(date)' "$AGENT_SCRIPT"

    test_passed "Logging configuration"
}

# Test 4: Verify failure detection logic
test_failure_detection_logic() {
    announce_test "Failure detection logic"

    # Check for consecutive failures pattern detection
    assert_pattern_in_file "Consecutive failures:" "$AGENT_SCRIPT"
    assert_pattern_in_file "grep -c" "$AGENT_SCRIPT"
    assert_pattern_in_file "add_task_to_queue" "$AGENT_SCRIPT"

    # Check for threshold-based detection
    assert_pattern_in_file 'threshold=${1:-3}' "$AGENT_SCRIPT"

    test_passed "Failure detection logic"
}

# Test 5: Verify stuck task handling
test_stuck_task_handling() {
    announce_test "Stuck task handling"

    # Check for stuck task detection
    assert_pattern_in_file "handle_stuck_tasks" "$AGENT_SCRIPT"
    assert_pattern_in_file "in_progress" "$AGENT_SCRIPT"
    assert_pattern_in_file "stuck_requeued_at" "$AGENT_SCRIPT"
    assert_pattern_in_file "retry_count" "$AGENT_SCRIPT"

    # Check for time-based cutoff logic
    assert_pattern_in_file "cutoff=" "$AGENT_SCRIPT"
    assert_pattern_in_file "started_at" "$AGENT_SCRIPT"

    test_passed "Stuck task handling"
}

# Test 6: Verify process monitoring functionality
test_process_monitoring() {
    announce_test "Process monitoring functionality"

    # Check for long-running process detection
    assert_pattern_in_file "monitor_long_running_processes" "$AGENT_SCRIPT"
    assert_pattern_in_file "ps -eo" "$AGENT_SCRIPT"
    assert_pattern_in_file "etime" "$AGENT_SCRIPT"
    assert_pattern_in_file "max_minutes" "$AGENT_SCRIPT"

    # Check for process filtering logic
    assert_pattern_in_file "pid < 100" "$AGENT_SCRIPT"
    assert_pattern_in_file "/System/" "$AGENT_SCRIPT"
    assert_pattern_in_file "launchd" "$AGENT_SCRIPT"

    test_passed "Process monitoring functionality"
}

# Test 7: Verify task queue integration
test_task_queue_integration() {
    announce_test "Task queue integration"

    # Check for task creation and queuing
    assert_pattern_in_file "add_task_to_queue" "$AGENT_SCRIPT"
    assert_pattern_in_file "task_json=" "$AGENT_SCRIPT"
    assert_pattern_in_file 'type.*debug' "$AGENT_SCRIPT"
    assert_pattern_in_file 'type.*alert' "$AGENT_SCRIPT"

    # Check for task ID generation
    assert_pattern_in_file "auto_debug_" "$AGENT_SCRIPT"
    assert_pattern_in_file "long_running_" "$AGENT_SCRIPT"

    test_passed "Task queue integration"
}

# Test 8: Verify status reporting
test_status_reporting() {
    announce_test "Status reporting"

    # Check for status file reading
    assert_pattern_in_file "STATUS_FILE" "$AGENT_SCRIPT"
    assert_pattern_in_file "python3.*STATUS_FILE" "$AGENT_SCRIPT"
    assert_pattern_in_file "agents.*keys" "$AGENT_SCRIPT"

    test_passed "Status reporting"
}

# Test 9: Verify shared functions integration
test_shared_functions_integration() {
    announce_test "Shared functions integration"

    # Check for shared functions sourcing
    assert_pattern_in_file "source.*shared_functions.sh" "$AGENT_SCRIPT"
    assert_pattern_in_file "update_agent_status" "$AGENT_SCRIPT"

    test_passed "Shared functions integration"
}

# Test 10: Verify main execution flow
test_main_execution_flow() {
    announce_test "Main execution flow"

    # Check for main function calls
    assert_pattern_in_file "ensure_agents_running" "$AGENT_SCRIPT"
    assert_pattern_in_file "check_repeated_failures 3" "$AGENT_SCRIPT"
    assert_pattern_in_file "handle_stuck_tasks 10" "$AGENT_SCRIPT"
    assert_pattern_in_file "monitor_long_running_processes" "$AGENT_SCRIPT"

    test_passed "Main execution flow"
}

# Run all tests
run_monitor_agents_tests() {
    echo "🧪 Running comprehensive tests for monitor_agents.sh"
    echo "=================================================="

    setup_test_environment

    test_monitor_agents_script_structure
    test_agent_array_configuration
    test_logging_configuration
    test_failure_detection_logic
    test_stuck_task_handling
    test_process_monitoring
    test_task_queue_integration
    test_status_reporting
    test_shared_functions_integration
    test_main_execution_flow

    cleanup_test_environment

    echo ""
    echo "✅ All tests passed!"
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_monitor_agents_tests
fi
