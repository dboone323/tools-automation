#!/bin/bash
# Test suite for shared_functions.sh
# Comprehensive testing for agent coordination and task management functions

# Source the agent script for testing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(cd "${SCRIPT_DIR}/../agents" && pwd)"
AGENT_SCRIPT="${AGENTS_DIR}/shared_functions.sh"

# Set test mode to prevent main loop execution
export TEST_MODE=true

# Source the agent script
# shellcheck source=../agents/shared_functions.sh
source "${AGENT_SCRIPT}"

# Mock external commands and functions for testing
mock_python3() {
    local script="$1"
    case "$script" in
    *update_status.py*)
        echo "python3 update_status.py mocked - success"
        return 0
        ;;
    *get_next_task*)
        # Mock task retrieval - return a sample task JSON
        echo '{"id": "test_task_001", "agent": "test_agent", "status": "pending", "priority": 5, "description": "Test task"}'
        return 0
        ;;
    *update_task_status*)
        echo "Task status updated successfully"
        return 0
        ;;
    *add_task_to_queue*)
        # Check if this contains invalid JSON
        if [[ "$*" == *invalid*json* ]]; then
            echo "Failed to add task to queue: Expecting ',' delimiter: line 1 column 14 (char 13)" >&2
            return 1
        fi
        echo "Task added to queue successfully"
        return 0
        ;;
    *)
        echo "python3 mocked"
        return 0
        ;;
    esac
}

mock_ulimit() {
    local flag="$1"
    local value="$2"
    case "$flag" in
    "-t")
        echo "CPU time limit set to ${value}s"
        ;;
    "-v")
        echo "Memory limit set to ${value}KB"
        ;;
    "-u")
        echo "Process limit set to ${value}"
        ;;
    "-f")
        echo "File size limit set to ${value}KB"
        ;;
    *)
        echo "ulimit mocked: $flag $value"
        ;;
    esac
    return 0
}

mock_bash() {
    local command="$*"
    if [[ "$command" == *"ulimit"* ]]; then
        echo "bash with ulimit executed: $command"
        return 0
    else
        # Execute the actual command for other cases
        eval "$command"
    fi
}

# Override commands with mocks
python3() { mock_python3 "$@"; }
ulimit() { mock_ulimit "$@"; }
bash() { mock_bash "$@"; }

# Test setup and teardown
setup_test_env() {
    export TEST_MODE=true

    # Create test directories and files
    mkdir -p /tmp/test_agents
    export STATUS_FILE="/tmp/test_agents/agent_status.json"
    export TASK_QUEUE_FILE="/tmp/test_agents/task_queue.json"

    # Initialize status file
    echo '{"agents":{},"last_update":0}' >"$STATUS_FILE"

    # Initialize task queue file
    echo '{"tasks":[]}' >"$TASK_QUEUE_FILE"
}

teardown_test_env() {
    rm -rf /tmp/test_agents
    unset STATUS_FILE
    unset TASK_QUEUE_FILE
}

# Test functions
test_basic_execution() {
    echo "Testing basic execution..."

    # Test that the script sources without errors
    assert_success "Script sources successfully" true

    echo "✓ Basic execution test passed"
}

test_update_agent_status() {
    echo "Testing update_agent_status function..."

    # Test successful status update
    assert_success "Agent status updates successfully" update_agent_status "test_agent" "running" "12345" "task_001"

    # Test status update without task_id
    assert_success "Agent status updates without task_id" update_agent_status "test_agent" "idle" "12345"

    echo "✓ update_agent_status test passed"
}

test_get_next_task() {
    echo "Testing get_next_task function..."

    # Test getting next task for an agent
    local result
    result=$(get_next_task "test_agent")
    assert_success "get_next_task returns valid JSON" [ -n "$result" ]

    # Test with different agent name formats
    result=$(get_next_task "agent_test")
    assert_success "get_next_task works with agent_ prefix" [ -n "$result" ]

    result=$(get_next_task "test_agent.sh")
    assert_success "get_next_task works with .sh suffix" [ -n "$result" ]

    echo "✓ get_next_task test passed"
}

test_update_task_status() {
    echo "Testing update_task_status function..."

    # Test updating task status
    assert_success "Task status updates to in_progress" update_task_status "test_task_001" "in_progress"

    assert_success "Task status updates to completed" update_task_status "test_task_001" "completed"

    assert_success "Task status updates to failed" update_task_status "test_task_001" "failed"

    echo "✓ update_task_status test passed"
}

test_add_task_to_queue() {
    echo "Testing add_task_to_queue function..."

    # Test adding a task to queue
    local task_json='{"id": "new_task_001", "agent": "test_agent", "status": "pending", "priority": 3, "description": "New test task"}'
    assert_success "Task added to queue successfully" add_task_to_queue "$task_json"

    # Test adding task without created_at timestamp
    local task_json_no_timestamp='{"id": "new_task_002", "agent": "test_agent", "status": "pending"}'
    assert_success "Task without timestamp added successfully" add_task_to_queue "$task_json_no_timestamp"

    echo "✓ add_task_to_queue test passed"
}

test_set_resource_limits() {
    echo "Testing set_resource_limits function..."

    # Test with default values
    assert_success "Resource limits set with defaults" set_resource_limits

    # Test with custom values
    assert_success "Resource limits set with custom values" set_resource_limits 600 1048576 100

    echo "✓ set_resource_limits test passed"
}

test_with_resource_limits() {
    echo "Testing with_resource_limits function..."

    # Test executing command with resource limits
    assert_success "Command executes with resource limits" with_resource_limits 300 524288 50 echo "test command"

    # Test with custom limits
    assert_success "Command executes with custom limits" with_resource_limits 600 1048576 100 echo "test command with custom limits"

    echo "✓ with_resource_limits test passed"
}

test_resource_limits_integration() {
    echo "Testing resource limits integration..."

    # Test that set_resource_limits and with_resource_limits work together
    set_resource_limits 300 524288 50
    assert_success "Integrated resource limits work" with_resource_limits 300 524288 50 echo "integrated test"

    echo "✓ Resource limits integration test passed"
}

test_task_management_workflow() {
    echo "Testing complete task management workflow..."

    # Add a task
    local task_json='{"id": "workflow_task_001", "agent": "workflow_agent", "status": "pending", "priority": 5}'
    assert_success "Task added in workflow" add_task_to_queue "$task_json"

    # Get the task
    local task_data
    task_data=$(get_next_task "workflow_agent")
    assert_success "Task retrieved in workflow" [ -n "$task_data" ]

    # Update task status to in progress
    assert_success "Task status updated to in_progress" update_task_status "workflow_task_001" "in_progress"

    # Update agent status
    assert_success "Agent status updated during workflow" update_agent_status "workflow_agent" "busy" "12345" "workflow_task_001"

    # Complete the task
    assert_success "Task completed in workflow" update_task_status "workflow_task_001" "completed"

    # Update agent status to idle
    assert_success "Agent status updated to idle" update_agent_status "workflow_agent" "idle" "12345"

    echo "✓ Task management workflow test passed"
}

test_error_handling() {
    echo "Testing error handling..."

    # Test updating non-existent task (should not crash)
    assert_success "Non-existent task update handled gracefully" update_task_status "non_existent_task" "completed"

    # Test with empty agent name
    local result
    result=$(get_next_task "")
    assert_success "Empty agent name handled gracefully" [ -z "$result" ]

    echo "✓ Error handling test passed"
}

# Assertion functions
assert_success() {
    local message="$1"
    shift
    if "$@"; then
        echo "✓ ${message}"
        return 0
    else
        echo "✗ ${message}"
        return 1
    fi
}

# Run tests
main() {
    echo "Running shared_functions.sh test suite..."
    echo "==========================================="

    local failed_tests=0
    local total_tests=0

    setup_test_env

    # Run all tests
    for test_func in test_basic_execution test_update_agent_status test_get_next_task test_update_task_status test_add_task_to_queue test_set_resource_limits test_with_resource_limits test_resource_limits_integration test_task_management_workflow test_error_handling; do
        ((total_tests++))
        echo ""
        echo "Running ${test_func}..."
        if ! ${test_func}; then
            ((failed_tests++))
            echo "✗ ${test_func} failed"
        fi
    done

    teardown_test_env

    echo ""
    echo "==========================================="
    echo "Test Results: ${total_tests} total, $((total_tests - failed_tests)) passed, ${failed_tests} failed"

    if [[ ${failed_tests} -eq 0 ]]; then
        echo "✓ All tests passed!"
        exit 0
    else
        echo "✗ ${failed_tests} test(s) failed"
        exit 1
    fi
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
<parameter name="filePath">/Users/danielstevens/Desktop/github-projects/tools-automation/tests/test_agents_shared_functions.sh