#!/bin/bash
# Comprehensive test suite for agent_config.sh
# Tests global configuration management, validation, and agent coordination

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shell_test_framework.sh"

# Source the agent to test
AGENT_PATH="${SCRIPT_DIR}/../agents/agent_config.sh"
if [[ ! -f "${AGENT_PATH}" ]]; then
    echo "ERROR: Cannot find agent_config.sh at ${AGENT_PATH}"
    exit 1
fi

# Set TEST_MODE to prevent real operations
export TEST_MODE=true

# Mock external commands and functions for testing
mock_commands() {
    # Mock df command for disk space checks
    df() {
        if [[ "$*" == *"/Users/danielstevens/Desktop/Quantum-workspace"* ]]; then
            echo "Filesystem     1K-blocks    Used Available Use% Mounted on"
            echo "/dev/disk1s1   488245288 100000000 388245288  21% /"
        else
            command df "$@"
        fi
    }

    # Mock vm_stat for memory checks
    vm_stat() {
        echo "Pages free:                               1000000."
        echo "Pages active:                             500000."
        echo "Pages inactive:                           200000."
    }

    # Mock find command for file counting
    find() {
        if [[ "$*" == *"/Users/danielstevens/Desktop/Quantum-workspace"* ]] && [[ "$*" == *"-type f"* ]]; then
            # Return 10000 files (well under limit)
            for i in {1..10000}; do echo "/fake/file${i}"; done
        else
            command find "$@"
        fi
    }

    # Mock date command for consistent timestamps
    date() {
        echo "2025-01-15 10:30:45"
    }

    # Mock sleep to speed up tests
    sleep() {
        # Do nothing - speed up tests
        true
    }
}

# Setup test environment
setup_test_env() {
    # Create temporary directories for testing
    export TEST_TMP_DIR="${SCRIPT_DIR}/test_tmp"
    mkdir -p "${TEST_TMP_DIR}"

    # Set up test paths
    export LOG_FILE="${TEST_TMP_DIR}/test_config_agent.log"
    export STATUS_FILE="${TEST_TMP_DIR}/test_agent_status.json"
    export TASK_QUEUE="${TEST_TMP_DIR}/test_task_queue.json"

    # Initialize empty status and task files
    echo "{}" >"${STATUS_FILE}"
    echo "[]" >"${TASK_QUEUE}"

    # Mock external commands
    mock_commands
}

# Cleanup test environment
cleanup_test_env() {
    rm -rf "${TEST_TMP_DIR}"
}

# Test 1: Configuration validation with valid values
test_config_validation_valid() {
    setup_test_env

    # Set valid configuration values
    export MAX_CONCURRENCY=3
    export LOAD_THRESHOLD=4.0
    export WAIT_WHEN_BUSY=30
    export GLOBAL_AGENT_CAP=10

    # Source the agent (this will run validate_config)
    source "${AGENT_PATH}" >/dev/null 2>&1

    # Test the validate_config function directly
    if validate_config >/dev/null 2>&1; then
        assert_success "Configuration validation should pass with valid values"
    else
        assert_failure "Configuration validation should pass with valid values"
    fi

    cleanup_test_env
}

# Test 2: Configuration validation with invalid MAX_CONCURRENCY
test_config_validation_invalid_concurrency() {
    setup_test_env

    # Set invalid MAX_CONCURRENCY
    export MAX_CONCURRENCY="invalid"
    export LOAD_THRESHOLD=4.0
    export WAIT_WHEN_BUSY=30
    export GLOBAL_AGENT_CAP=10

    # Test the validate_config function directly
    if ! validate_config >/dev/null 2>&1; then
        assert_success "Configuration validation should fail with invalid MAX_CONCURRENCY"
    else
        assert_failure "Configuration validation should fail with invalid MAX_CONCURRENCY"
    fi

    cleanup_test_env
}

# Test 3: Configuration validation with invalid LOAD_THRESHOLD
test_config_validation_invalid_load_threshold() {
    setup_test_env

    # Set invalid LOAD_THRESHOLD
    export MAX_CONCURRENCY=3
    export LOAD_THRESHOLD="not_a_number"
    export WAIT_WHEN_BUSY=30
    export GLOBAL_AGENT_CAP=10

    # Test the validate_config function directly
    if ! validate_config >/dev/null 2>&1; then
        assert_success "Configuration validation should fail with invalid LOAD_THRESHOLD"
    else
        assert_failure "Configuration validation should fail with invalid LOAD_THRESHOLD"
    fi

    cleanup_test_env
}

# Test 4: Configuration validation with invalid WAIT_WHEN_BUSY
test_config_validation_invalid_wait_time() {
    setup_test_env

    # Set invalid WAIT_WHEN_BUSY
    export MAX_CONCURRENCY=3
    export LOAD_THRESHOLD=4.0
    export WAIT_WHEN_BUSY="negative"
    export GLOBAL_AGENT_CAP=10

    # Test the validate_config function directly
    if ! validate_config >/dev/null 2>&1; then
        assert_success "Configuration validation should fail with invalid WAIT_WHEN_BUSY"
    else
        assert_failure "Configuration validation should fail with invalid WAIT_WHEN_BUSY"
    fi

    cleanup_test_env
}

# Test 5: Configuration validation with invalid GLOBAL_AGENT_CAP
test_config_validation_invalid_agent_cap() {
    setup_test_env

    # Set invalid GLOBAL_AGENT_CAP
    export MAX_CONCURRENCY=3
    export LOAD_THRESHOLD=4.0
    export WAIT_WHEN_BUSY=30
    export GLOBAL_AGENT_CAP="zero"

    # Test the validate_config function directly
    if ! validate_config >/dev/null 2>&1; then
        assert_success "Configuration validation should fail with invalid GLOBAL_AGENT_CAP"
    else
        assert_failure "Configuration validation should fail with invalid GLOBAL_AGENT_CAP"
    fi

    cleanup_test_env
}

# Test 6: Agent-specific configuration retrieval
test_get_agent_config() {
    setup_test_env

    # Set up test configurations
    export MAX_CONCURRENCY=2
    export MAX_CONCURRENCY_agent_debug=1
    export MAX_CONCURRENCY_agent_build=3

    # Source the agent to load functions
    source "${AGENT_PATH}" >/dev/null 2>&1

    # Test default value retrieval (should return the default passed, not global var)
    local result
    result=$(get_agent_config "agent_test" "MAX_CONCURRENCY" "5")
    if [[ "$result" == "5" ]]; then
        assert_success "get_agent_config should return provided default for unknown agent"
    else
        assert_failure "get_agent_config should return provided default for unknown agent, got: $result"
    fi

    # Test agent-specific override
    result=$(get_agent_config "agent_debug" "MAX_CONCURRENCY" "5")
    if [[ "$result" == "1" ]]; then
        assert_success "get_agent_config should return agent-specific MAX_CONCURRENCY for agent_debug"
    else
        assert_failure "get_agent_config should return agent-specific MAX_CONCURRENCY for agent_debug, got: $result"
    fi

    # Test another agent-specific override
    result=$(get_agent_config "agent_build" "MAX_CONCURRENCY" "5")
    if [[ "$result" == "3" ]]; then
        assert_success "get_agent_config should return agent-specific MAX_CONCURRENCY for agent_build"
    else
        assert_failure "get_agent_config should return agent-specific MAX_CONCURRENCY for agent_build, got: $result"
    fi

    cleanup_test_env
}

# Test 7: Resource limits checking with sufficient resources
test_resource_limits_sufficient() {
    setup_test_env

    # Source the agent to load functions
    source "${AGENT_PATH}" >/dev/null 2>&1

    # Test resource limits check (should pass with mocked sufficient resources)
    if check_resource_limits "test_operation" >/dev/null 2>&1; then
        assert_success "Resource limits check should pass with sufficient resources"
    else
        assert_failure "Resource limits check should pass with sufficient resources"
    fi

    cleanup_test_env
}

# Test 8: Resource limits checking with insufficient disk space
test_resource_limits_insufficient_disk() {
    setup_test_env

    # Override df command to simulate low disk space
    df() {
        echo "Filesystem     1K-blocks    Used Available Use% Mounted on"
        echo "/dev/disk1s1   488245288 400000000 88245288  82% /" # Less than 1GB available
    }

    # Source the agent to load functions
    source "${AGENT_PATH}" >/dev/null 2>&1

    # Test resource limits check (should fail with insufficient disk)
    if ! check_resource_limits "test_operation" >/dev/null 2>&1; then
        assert_success "Resource limits check should fail with insufficient disk space"
    else
        assert_failure "Resource limits check should fail with insufficient disk space"
    fi

    cleanup_test_env
}

# Test 9: Resource limits checking with high memory usage
test_resource_limits_high_memory() {
    setup_test_env

    # Override vm_stat to simulate high memory usage
    vm_stat() {
        echo "Pages free:                               50000." # Very low free memory
        echo "Pages active:                             500000."
        echo "Pages inactive:                           200000."
    }

    # Source the agent to load functions
    source "${AGENT_PATH}" >/dev/null 2>&1

    # Test resource limits check (should fail with high memory usage)
    if ! check_resource_limits "test_operation" >/dev/null 2>&1; then
        assert_success "Resource limits check should fail with high memory usage"
    else
        assert_failure "Resource limits check should fail with high memory usage"
    fi

    cleanup_test_env
}

# Test 10: Resource limits checking with too many files
test_resource_limits_too_many_files() {
    setup_test_env

    # Override find command to simulate too many files
    find() {
        if [[ "$*" == *"/Users/danielstevens/Desktop/Quantum-workspace"* ]] && [[ "$*" == *"-type f"* ]]; then
            # Return 60000 files (over limit)
            for i in {1..60000}; do echo "/fake/file${i}"; done
        else
            command find "$@"
        fi
    }

    # Source the agent to load functions
    source "${AGENT_PATH}" >/dev/null 2>&1

    # Test resource limits check (should fail with too many files)
    if ! check_resource_limits "test_operation" >/dev/null 2>&1; then
        assert_success "Resource limits check should fail with too many files"
    else
        assert_failure "Resource limits check should fail with too many files"
    fi

    cleanup_test_env
}

# Test 11: Timeout protection with successful command
test_timeout_protection_success() {
    setup_test_env

    # Source the agent to load functions
    source "${AGENT_PATH}" >/dev/null 2>&1

    # Test timeout protection with a quick command
    if run_with_timeout 10 "echo 'test' && sleep 1 && echo 'done'" >/dev/null 2>&1; then
        assert_success "Timeout protection should succeed with quick command"
    else
        assert_failure "Timeout protection should succeed with quick command"
    fi

    cleanup_test_env
}

# Test 12: Timeout protection with timeout
test_timeout_protection_timeout() {
    setup_test_env

    # Source the agent to load functions
    source "${AGENT_PATH}" >/dev/null 2>&1

    # Test timeout protection with a slow command that should timeout
    if ! run_with_timeout 2 "sleep 5" >/dev/null 2>&1; then
        assert_success "Timeout protection should fail with slow command"
    else
        assert_failure "Timeout protection should fail with slow command"
    fi

    cleanup_test_env
}

# Test 13: Environment variable defaults
test_environment_defaults() {
    setup_test_env

    # Clear any existing environment variables
    unset MAX_CONCURRENCY LOAD_THRESHOLD WAIT_WHEN_BUSY GLOBAL_AGENT_CAP

    # Source the agent to load defaults
    source "${AGENT_PATH}" >/dev/null 2>&1

    # Check that defaults are set
    if [[ "${MAX_CONCURRENCY}" == "2" ]] && [[ "${LOAD_THRESHOLD}" == "4.0" ]] && [[ "${WAIT_WHEN_BUSY}" == "30" ]] && [[ "${GLOBAL_AGENT_CAP}" == "10" ]]; then
        assert_success "Environment variable defaults should be set correctly"
    else
        assert_failure "Environment variable defaults should be set correctly: MAX_CONCURRENCY=${MAX_CONCURRENCY}, LOAD_THRESHOLD=${LOAD_THRESHOLD}, WAIT_WHEN_BUSY=${WAIT_WHEN_BUSY}, GLOBAL_AGENT_CAP=${GLOBAL_AGENT_CAP}"
    fi

    cleanup_test_env
}

# Test 14: Agent status updates in TEST_MODE
test_agent_status_updates() {
    setup_test_env

    # Source the agent to load functions
    source "${AGENT_PATH}" >/dev/null 2>&1

    # Test agent status update (should work in TEST_MODE)
    if update_agent_status "ConfigAgent" "running" $$ "" >/dev/null 2>&1; then
        assert_success "Agent status updates should work in TEST_MODE"
    else
        assert_failure "Agent status updates should work in TEST_MODE"
    fi

    # Verify status file was created/updated
    if [[ -f "${STATUS_FILE}" ]]; then
        assert_success "Status file should be created during status updates"
    else
        assert_failure "Status file should be created during status updates"
    fi

    cleanup_test_env
}

# Test 15: Task status updates in TEST_MODE
test_task_status_updates() {
    setup_test_env

    # Source the agent to load functions
    source "${AGENT_PATH}" >/dev/null 2>&1

    # Test task status update (should work in TEST_MODE)
    if update_task_status "test_task_123" "completed" >/dev/null 2>&1; then
        assert_success "Task status updates should work in TEST_MODE"
    else
        assert_failure "Task status updates should work in TEST_MODE"
    fi

    cleanup_test_env
}

# Run all tests
run_tests() {
    echo "Running comprehensive tests for agent_config.sh..."

    test_config_validation_valid
    test_config_validation_invalid_concurrency
    test_config_validation_invalid_load_threshold
    test_config_validation_invalid_wait_time
    test_config_validation_invalid_agent_cap
    test_get_agent_config
    test_resource_limits_sufficient
    test_resource_limits_insufficient_disk
    test_resource_limits_high_memory
    test_resource_limits_too_many_files
    test_timeout_protection_success
    test_timeout_protection_timeout
    test_environment_defaults
    test_agent_status_updates
    test_task_status_updates

    echo "All agent_config.sh tests completed."
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
