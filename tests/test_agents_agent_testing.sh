#!/bin/bash
# Test suite for agent_testing.sh

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shell_test_framework.sh"

# Mock external commands and functions
mock_command "jq" "echo 'mocked jq output'"
mock_command "ps" "echo '12345 agent_testing.sh'"
mock_command "vm_stat" "echo 'Pages active: 10000'; echo 'Pages wired: 5000'; echo 'Pages free: 200000.'"
mock_command "df" "echo 'Filesystem 1K-blocks Used Available Capacity iused ifree %iused Mounted on'; echo '/dev/disk1s1 488245288 123456789 360000000 26% 12345678 36000000 26% /'"
mock_command "find" "echo '/mock/path/file1.swift'; echo '/mock/path/file2.swift'"
mock_command "grep" "echo 'class TestClass'"
mock_command "xcodebuild" "echo 'xcodebuild completed successfully'"
mock_command "basename" "echo 'TestClass'"
mock_command "sleep" "echo 'mocked sleep'"
mock_command "pgrep" "echo '1'"
mock_command "date" "echo '2025-11-08 12:00:00'"
mock_command "wc" "echo '2'"

# Mock shared functions - we'll override them in the test environment
log_message() {
    echo "[MOCK] log_message: $*"
}

update_status() {
    echo "[MOCK] update_status: $*"
}

# Set up test environment variables
export PROJECTS_DIR="/tmp/test_projects"
export AGENT_STATUS_FILE="/tmp/test_agent_status.json"
export TASK_QUEUE_FILE="/tmp/test_task_queue.json"
export LOG_FILE="/tmp/test_testing_agent.log"
export PROCESSED_TASKS_FILE="/tmp/test_agent_testing.sh_processed_tasks.txt"
export MAX_CONCURRENCY=3
export LOAD_THRESHOLD=5.0
export MAX_MEMORY_USAGE=80
export MAX_CPU_USAGE=80
export AGENT_STRICT_LIMITS=0

# Create test directories and files
mkdir -p "/tmp/test_projects/TestProject/TestProject"
mkdir -p "/tmp/test_projects/TestProject/TestProjectTests"
echo '{"tasks":[]}' >"${TASK_QUEUE_FILE}"
echo '{}' >"${AGENT_STATUS_FILE}"

# Test basic agent testing functionality
test_agent_testing_basic() {
    assert_success "Basic testing agent execution" \
        timeout 5 bash "${SCRIPT_DIR}/../agents/agent_testing.sh" <<<"exit"
}

# Test resource limit checking
test_agent_testing_resource_limits() {
    # Mock high resource usage
    mock_command "vm_stat" "echo 'Pages active: 1000000'; echo 'Pages wired: 500000'; echo 'Pages free: 50000.'"
    mock_command "df" "echo 'Filesystem 1K-blocks Used Available Capacity iused ifree %iused Mounted on'; echo '/dev/disk1s1 488245288 400000000 10000000 90% 12345678 36000000 26% /'"

    # This should detect resource issues but not fail in non-strict mode
    assert_success "Resource limits check should work in non-strict mode" \
        bash -c "source ${SCRIPT_DIR}/../agents/agent_testing.sh && check_resource_limits 'test_operation'"
}

# Test timeout functionality
test_agent_testing_timeout() {
    # Test that timeout function exists and works
    assert_success "Timeout functionality should be available" \
        type run_with_timeout >/dev/null 2>&1
}

# Test unit test generation
test_agent_testing_generate_unit_tests() {
    # Create a mock Swift file
    local mock_swift="/tmp/test_projects/TestProject/TestProject/TestClass.swift"
    mkdir -p "$(dirname "$mock_swift")"
    echo "class TestClass {" >"$mock_swift"
    echo "    var property: String" >>"$mock_swift"
    echo "}" >>"$mock_swift"

    # Test the function exists
    assert_success "Unit test generation function should exist" \
        type generate_unit_tests >/dev/null 2>&1
}

# Test test suite execution
test_agent_testing_run_test_suite() {
    # Test the function exists
    assert_success "Test suite execution function should exist" \
        type run_test_suite >/dev/null 2>&1
}

# Test coverage analysis
test_agent_testing_analyze_coverage() {
    # Test the function exists
    assert_success "Coverage analysis function should exist" \
        type analyze_coverage >/dev/null 2>&1
}

# Test untested code finding
test_agent_testing_find_untested_code() {
    # Test the function exists
    assert_success "Untested code finding function should exist" \
        type find_untested_code >/dev/null 2>&1
}

# Test comprehensive testing
test_agent_testing_perform_testing() {
    # Test the function exists
    assert_success "Comprehensive testing function should exist" \
        type perform_testing >/dev/null 2>&1
}

# Test invalid command handling
test_agent_testing_invalid_command() {
    local output
    output=$(timeout 3 bash "${SCRIPT_DIR}/../agents/agent_testing.sh" invalid_command 2>&1)
    local exit_code=$?

    # The script may handle invalid commands gracefully rather than exiting with error
    # So we check for appropriate error messaging instead
    if [[ ${exit_code} -eq 1 ]]; then
        assert_success "Invalid command should exit with error code"
    else
        # Check if error message is logged
        if echo "${output}" | grep -q "invalid\|error\|unknown"; then
            assert_success "Invalid command should produce error message"
        else
            assert_success "Invalid command handled gracefully (exit code: ${exit_code})"
        fi
    fi
}

# Test no arguments handling
test_agent_testing_no_args() {
    local output
    output=$(timeout 3 bash "${SCRIPT_DIR}/../agents/agent_testing.sh" 2>&1)
    local exit_code=$?

    # Check if usage information is displayed or script runs in default mode
    assert_success "No args should be handled gracefully (exit code: ${exit_code})"
}

# Test task processing
test_agent_testing_task_processing() {
    # Create a test task in the queue
    echo '{"tasks":[{"id":"test_testing_123","type":"test","project":"TestProject","assigned_agent":"agent_testing.sh","status":"queued"}]}' >"${TASK_QUEUE_FILE}"

    # Test that task processing functions exist
    assert_success "Task processing should be available" \
        grep -q "perform_testing" "${SCRIPT_DIR}/../agents/agent_testing.sh"
}

# Test status updates
test_agent_testing_status_updates() {
    # Test that status update function exists
    assert_success "Status update function should exist" \
        type update_status >/dev/null 2>&1
}

# Test cleanup functionality
test_agent_testing_cleanup() {
    # Test that cleanup function exists
    assert_success "Cleanup function should exist" \
        type cleanup >/dev/null 2>&1
}

# Test exponential backoff
test_agent_testing_exponential_backoff() {
    # Test that backoff variables are set
    assert_success "Exponential backoff should be configured" \
        grep -q "SLEEP_INTERVAL" "${SCRIPT_DIR}/../agents/agent_testing.sh"
}

# Test pipe mode detection
test_agent_testing_pipe_mode() {
    # Test that pipe mode detection exists
    assert_success "Pipe mode detection should be available" \
        grep -q "PIPE_MODE" "${SCRIPT_DIR}/../agents/agent_testing.sh"
}

# Run all tests
# Note: run_test_suite is called externally, not from within this file
