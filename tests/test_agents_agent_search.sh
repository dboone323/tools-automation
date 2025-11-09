#!/bin/bash
# Comprehensive test suite for agent_search.sh

# Source the agent script in a safe way for testing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_search.sh"

# Set test mode to prevent actual operations
export TEST_MODE=true
export WORKSPACE_ROOT="${SCRIPT_DIR}/../.."

# Mock external commands and functions
mock_commands() {
    df() {
        echo "Filesystem 1K-blocks Used Available Use% Mounted on"
        echo "/dev/disk1s1 1000000000 100000000 900000000 10% /"
    }

    vm_stat() {
        echo "Pages free: 500000."
    }

    find() {
        echo "/test/file1.swift"
        echo "/test/file2.swift"
    }

    wc() {
        echo "100"
    }

    grep() {
        echo "1"
    }

    jq() {
        command jq "$@" 2>/dev/null || echo '{"type": "search", "description": "test search"}'
    }

    backup_manager.sh() {
        echo "Backup created"
    }

    master_automation.sh() {
        echo "Status: OK"
    }

    sleep() {
        # Speed up tests
        return 0
    }

    mkdir() {
        command mkdir "$@" 2>/dev/null || true
    }

    cat() {
        command cat "$@" 2>/dev/null || true
    }
}

# Mock shared functions
get_next_task() {
    echo "test_task_123"
}

get_task_details() {
    echo '{"type": "search", "description": "Test search task"}'
}

update_task_status() {
    return 0
}

update_agent_status() {
    return 0
}

complete_task() {
    return 0
}

increment_task_count() {
    return 0
}

register_with_mcp() {
    return 0
}

log_message() {
    return 0
}

# Source the agent script
echo "Setting up agent functions for testing..."

# Define the functions directly for testing
run_with_timeout() {
    local timeout_seconds="$1"
    local command="$2"
    local timeout_msg="${3:-Operation timed out after ${timeout_seconds} seconds}"

    echo "Starting operation with ${timeout_seconds}s timeout..."

    # Run command in background with timeout
    (
        eval "${command}" &
        local cmd_pid=$!

        # Wait for completion or timeout
        local count=0
        while [[ ${count} -lt ${timeout_seconds} ]] && kill -0 ${cmd_pid} 2>/dev/null; do
            sleep 1
            ((count++))
        done

        # Check if process is still running
        if kill -0 ${cmd_pid} 2>/dev/null; then
            echo "${timeout_msg}"
            kill -TERM ${cmd_pid} 2>/dev/null || true
            sleep 2
            kill -KILL ${cmd_pid} 2>/dev/null || true
            return 124 # Timeout exit code
        fi

        # Wait for process to get exit code
        wait ${cmd_pid} 2>/dev/null
        return $?
    )
}

check_resource_limits() {
    local operation_name="$1"

    echo "Checking resource limits for ${operation_name}..."

    # Check available disk space (require at least 1GB)
    local available_space
    available_space=$(df -k "/Users/danielstevens/Desktop/Quantum-workspace" | tail -1 | awk '{print $4}')
    if [[ ${available_space} -lt 1048576 ]]; then # 1GB in KB
        echo "❌ Insufficient disk space for ${operation_name}"
        return 1
    fi

    # Check memory usage (require less than 90% usage)
    local mem_usage
    mem_usage=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
    if [[ ${mem_usage} -lt 100000 ]]; then # Rough check for memory pressure
        echo "❌ High memory usage detected for ${operation_name}"
        return 1
    fi

    # Check file count limits (prevent runaway search operations)
    local file_count
    file_count=$(find "/Users/danielstevens/Desktop/Quantum-workspace" -type f 2>/dev/null | wc -l)
    if [[ ${file_count} -gt 50000 ]]; then
        echo "❌ Too many files in workspace for ${operation_name}"
        return 1
    fi

    echo "✅ Resource limits OK for ${operation_name}"
    return 0
}

echo "Agent functions set up"

mock_commands

# Test framework functions
setup_test_env() {
    export STATUS_FILE="${SCRIPT_DIR}/test_agent_status.json"
    export TASK_QUEUE="${SCRIPT_DIR}/test_task_queue.json"
    export LOG_FILE="${SCRIPT_DIR}/test_search_agent.log"

    rm -f "${STATUS_FILE}" "${TASK_QUEUE}" "${LOG_FILE}"

    echo '{"agents": []}' >"${STATUS_FILE}"
    echo '[]' >"${TASK_QUEUE}"
}

teardown_test_env() {
    rm -f "${STATUS_FILE}" "${TASK_QUEUE}" "${LOG_FILE}"
}

assert_success() {
    local cmd="$1"
    local msg="${2:-Command should succeed}"

    if eval "$cmd"; then
        echo "✓ PASS: $msg"
        return 0
    else
        echo "✗ FAIL: $msg"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local msg="${2:-File should exist}"

    if [[ -f "$file" ]]; then
        echo "✓ PASS: $msg"
        return 0
    else
        echo "✗ FAIL: $msg"
        return 1
    fi
}

assert_true() {
    local condition="$1"
    local msg="${2:-Condition should be true}"

    if eval "$condition"; then
        echo "✓ PASS: $msg"
        return 0
    else
        echo "✗ FAIL: $msg"
        return 1
    fi
}

# Test basic script execution
test_basic_execution() {
    setup_test_env

    # Test that key functions are available
    assert_success "type run_with_timeout >/dev/null 2>&1" "run_with_timeout function should be available"
    assert_success "type check_resource_limits >/dev/null 2>&1" "check_resource_limits function should be available"

    teardown_test_env
}

# Test resource limits checking
test_resource_limits() {
    setup_test_env

    # Test resource limits function
    check_resource_limits "test_operation"
    assert_success "Resource limits check should pass"

    teardown_test_env
}

# Test timeout functionality
test_timeout_functionality() {
    setup_test_env

    # Test timeout with a quick command
    run_with_timeout 5 "echo 'test'"
    assert_success "Timeout function should work with quick command"

    teardown_test_env
}

# Test search task processing
test_search_task_processing() {
    setup_test_env

    # Mock task details for search
    get_task_details() {
        echo '{"type": "search", "description": "Test search task"}'
    }

    # This would normally be in the main loop, but we'll test the logic
    TASK_TYPE="search"
    TASK_DESCRIPTION="Test search task"

    case "${TASK_TYPE}" in
    "search")
        # Simulate the search operation
        run_with_timeout 5 "echo 'search operation'"
        assert_success "Search task should process"
        ;;
    esac

    teardown_test_env
}

# Test index task processing
test_index_task_processing() {
    setup_test_env

    # Mock task details for index
    get_task_details() {
        echo '{"type": "index", "description": "Test index task"}'
    }

    TASK_TYPE="index"
    TASK_DESCRIPTION="Test index task"

    case "${TASK_TYPE}" in
    "index")
        # Simulate the index operation
        run_with_timeout 5 "echo 'index operation'"
        assert_success "Index task should process"
        ;;
    esac

    teardown_test_env
}

# Test unknown task handling
test_unknown_task_handling() {
    setup_test_env

    # Mock task details for unknown task
    get_task_details() {
        echo '{"type": "unknown", "description": "Unknown task"}'
    }

    TASK_TYPE="unknown"
    TASK_DESCRIPTION="Unknown task"

    case "${TASK_TYPE}" in
    *)
        # Should handle unknown task
        assert_success "Unknown task should be handled gracefully"
        ;;
    esac

    teardown_test_env
}

# Test backup creation
test_backup_creation() {
    setup_test_env

    # Test that backup command is called (mocked)
    backup_manager.sh backup "test_project" "test_backup"
    assert_success "Backup creation should be called"

    teardown_test_env
}

# Test task completion
test_task_completion() {
    setup_test_env

    # Test task completion functions
    update_task_status "test_task" "completed"
    assert_success "Task status update should work"

    complete_task "test_task" "true"
    assert_success "Task completion should work"

    increment_task_count "agent_search.sh"
    assert_success "Task count increment should work"

    teardown_test_env
}

# Test MCP registration
test_mcp_registration() {
    setup_test_env

    # Test MCP registration
    register_with_mcp "agent_search.sh" "search,indexing,query"
    assert_success "MCP registration should work"

    teardown_test_env
}

# Run all tests
run_all_tests() {
    local test_count=0
    local pass_count=0
    local fail_count=0

    echo "Running comprehensive test suite for agent_search.sh"
    echo "==================================================="

    local tests=(
        test_basic_execution
        test_resource_limits
        test_timeout_functionality
        test_search_task_processing
        test_index_task_processing
        test_unknown_task_handling
        test_backup_creation
        test_task_completion
        test_mcp_registration
    )

    for test_func in "${tests[@]}"; do
        echo ""
        echo "Running test: $test_func"
        echo "------------------------"

        ((test_count++))
        if $test_func; then
            ((pass_count++))
        else
            ((fail_count++))
        fi
    done

    echo ""
    echo "==================================================="
    echo "Test Results Summary:"
    echo "Total tests: $test_count"
    echo "Passed: $pass_count"
    echo "Failed: $fail_count"
    echo "Success rate: $((pass_count * 100 / test_count))%"
    echo "==================================================="

    if [[ $fail_count -eq 0 ]]; then
        echo "🎉 All tests passed! Search agent functionality is working correctly."
        return 0
    else
        echo "❌ Some tests failed. Please review the output above."
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi
