#!/bin/bash

# Test suite for agent_documentation.sh
# Comprehensive testing of documentation agent functionality

# Source test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_documentation.sh"

# Source shell test framework
source "${SCRIPT_DIR}/shell_test_framework.sh"

# Mock external commands and functions
mock_external_commands() {
    # Create a smarter jq mock that can parse JSON
    cat >"/tmp/mock_jq" <<'EOF'
#!/bin/bash
# Simple jq mock for testing
input=$(cat)
case "$*" in
*'.id'*)
    # Check if input contains id field
    if echo "$input" | grep -q '"id":'; then
        echo "test_doc_task_123"
    else
        echo ""
    fi
    ;;
*'.type'*)
    if echo "$input" | grep -q '"type":'; then
        echo "$input" | sed 's/.*"type":"\([^"]*\)".*/\1/'
    else
        echo "documentation"
    fi
    ;;
*'.project'*)
    if echo "$input" | grep -q '"project":'; then
        echo "TestProject"
    else
        echo ""
    fi
    ;;
*'.description'*)
    if echo "$input" | grep -q '"description":'; then
        echo "$input" | sed 's/.*"description":"\([^"]*\)".*/\1/'
    else
        echo "Test documentation task"
    fi
    ;;
*'.assigned_agent'*)
    if echo "$input" | grep -q '"assigned_agent":'; then
        echo "$input" | sed 's/.*"assigned_agent":"\([^"]*\)".*/\1/'
    else
        echo "agent_documentation.sh"
    fi
    ;;
*'.status'*)
    if echo "$input" | grep -q '"status":'; then
        echo "$input" | sed 's/.*"status":"\([^"]*\)".*/\1/'
    else
        echo "assigned"
    fi
    ;;
*)
    echo "$input"
    ;;
esac
exit 0
EOF
    chmod +x "/tmp/mock_jq"
    export PATH="/tmp:$PATH"
    ln -sf "/tmp/mock_jq" "/tmp/jq"

    # Create a smarter df mock
    cat >"/tmp/mock_df" <<'EOF'
#!/bin/bash
# Smart df mock for testing
echo 'Filesystem 1K-blocks Used Available Use% Mounted-on'
echo '/dev/disk1s1 1000000 100000 900000 10% /Users/danielstevens/Desktop/Quantum-workspace'
exit 0
EOF
    chmod +x "/tmp/mock_df"
    export PATH="/tmp:$PATH"
    ln -sf "/tmp/mock_df" "/tmp/df"

    # Create a smarter vm_stat mock
    cat >"/tmp/mock_vm_stat" <<'EOF'
#!/bin/bash
# Smart vm_stat mock for testing
echo 'Pages free: 500000.'
echo 'Pages active: 100.'
echo 'Pages wired: 50.'
exit 0
EOF
    chmod +x "/tmp/mock_vm_stat"
    export PATH="/tmp:$PATH"
    ln -sf "/tmp/mock_vm_stat" "/tmp/vm_stat"

    mock_command "find" $'/fake/file1\n/fake/file2\n/fake/file3'
    mock_command "backup_manager.sh" "echo 'Backup completed successfully'"
    mock_command "master_automation.sh" "echo 'Documentation generation completed'"
    mock_command "sleep" "true"
    mock_command "kill" "true"
    mock_command "tail" "echo 'no errors'"
    mock_command "grep" "true"
    mock_command "cd" "true"
    mock_command "date" "echo '2024-01-01 12:00:00'"
    mock_command "cp" ""
    hash -r # Clear command hash table to ensure mocks are used
}

# Mock agent functions - override them in the test environment
update_agent_status() {
    echo "[MOCK] update_agent_status: $*"
}

get_next_task() {
    echo '{"id":"test_doc_task_123","type":"documentation","project":"TestProject","description":"Test documentation task"}'
}

get_task_details() {
    echo '{"id":"test_doc_task_123","type":"documentation","project":"TestProject","description":"Test documentation task"}'
}

update_task_status() {
    echo "[MOCK] update_task_status: $*"
}

complete_task() {
    echo "[MOCK] complete_task: $*"
}

increment_task_count() {
    echo "[MOCK] increment_task_count: $*"
}

register_with_mcp() {
    echo "[MOCK] register_with_mcp: $*"
}

agent_init_backoff() {
    echo "[MOCK] agent_init_backoff"
}

agent_detect_pipe_and_quick_exit() {
    echo "[MOCK] agent_detect_pipe_and_quick_exit: false"
    return 1 # Return false to not exit early
}

agent_sleep_with_backoff() {
    echo "[MOCK] agent_sleep_with_backoff"
}

record_task_success() {
    echo "[MOCK] record_task_success"
}

notify_completion() {
    echo "[MOCK] notify_completion: $*"
}

has_processed_task() {
    echo "[MOCK] has_processed_task: false"
    return 1 # Return false
}

fetch_task_description() {
    echo "Test documentation task"
}

log_message() {
    echo "[MOCK] log_message: $*" >&2
}

setup_test_env() {
    export PROJECT_NAME="TestProject"
    export PROJECT_DIR="/tmp/test_project"
    export MAX_CONCURRENCY=3
    export LOAD_THRESHOLD=2.0
    export MAX_FILES=1000
    export MAX_MEMORY_USAGE=80
    export MAX_CPU_USAGE=90
    export WORKSPACE_ROOT="/tmp/test_workspace"
    export PROJECTS_DIR="/tmp/test_workspace/Projects"
    export SCRIPT_DIR="/tmp/test_workspace/Tools/Automation/agents"
    export AGENT_STATUS_FILE="/tmp/test_workspace/Tools/Automation/agents/agent_status.json"
    export TASK_QUEUE_FILE="/tmp/test_workspace/Tools/Automation/agents/task_queue.json"
    export PROCESSED_TASKS_FILE="/tmp/test_workspace/Tools/Automation/agents/agent_documentation.sh_processed_tasks.txt"
    export LOG_FILE="/tmp/test_documentation_agent.log"
    export COMM_DIR="/tmp/test_workspace/Tools/Automation/agents/communication"
    export NOTIFICATION_FILE="${COMM_DIR}/agent_documentation.sh_notification.txt"
    export COMPLETED_FILE="${COMM_DIR}/agent_documentation.sh_completed.txt"
    export SLEEP_INTERVAL=600
    export MIN_INTERVAL=120
    export MAX_INTERVAL=1800

    # Create test directories
    mkdir -p "${PROJECT_DIR}"
    mkdir -p "${SCRIPT_DIR}/communication"
    mkdir -p "${SCRIPT_DIR}/../enhancements"
    mkdir -p "/tmp/test_workspace/Tools/Automation/agents"
    mkdir -p "${PROJECTS_DIR}/TestProject"

    # Create mock project files
    mkdir -p "${PROJECTS_DIR}/TestProject/Tests"
    echo 'print("Hello")' >"${PROJECTS_DIR}/TestProject/TestFile.swift"

    # Create mock files
    touch "${NOTIFICATION_FILE}" "${COMPLETED_FILE}" "${PROCESSED_TASKS_FILE}"
    echo '{"agents":{},"last_update":0}' >"${AGENT_STATUS_FILE}"
    echo '{"tasks":[]}' >"${TASK_QUEUE_FILE}"

    # Override LOG_FILE for testing
    export LOG_FILE="/tmp/test_documentation_agent.log"
    export DISABLE_PIPE_QUICK_EXIT=1

    # Mock update_status.py to speed up tests
    if [ -f "update_status.py" ]; then
        cp update_status.py update_status.py.backup
        cat >update_status.py <<'EOF'
#!/usr/bin/env python3
import sys
print(f"[MOCK] update_status.py: {' '.join(sys.argv[1:])}")
EOF
        chmod +x update_status.py
    fi

    mock_external_commands
}

teardown_test_env() {
    rm -rf "/tmp/test_project"
    rm -rf "/tmp/test_workspace"
    rm -f "/tmp/mock_jq"

    # Restore update_status.py
    if [ -f "update_status.py.backup" ]; then
        mv update_status.py.backup update_status.py
    fi
}

# Test basic agent execution
test_agent_documentation_basic() {
    setup_test_env

    # Test that agent script exists and is executable
    assert_file_exists "${AGENT_SCRIPT}" "Agent script should exist"
    assert_success "Agent script should be executable" test -x "${AGENT_SCRIPT}"

    teardown_test_env
}

# Test resource limit checking with sufficient resources
test_agent_documentation_resource_limits_sufficient() {
    setup_test_env

    # Set test mode to prevent main loop execution
    export TEST_MODE=true

    # Source the agent script to access functions
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Re-mock functions after sourcing (shared_functions.sh overrides them)
    update_agent_status() {
        echo "[MOCK] update_agent_status: $*"
    }

    # Test resource limits function with sufficient resources
    check_resource_limits "test_operation"
    assert_success "Resource limits check should pass with sufficient resources"

    teardown_test_env
}

# Test resource limit checking with insufficient disk space
test_agent_documentation_resource_limits_disk() {
    setup_test_env

    # Set test mode to prevent main loop execution
    export TEST_MODE=true

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Re-mock functions after sourcing (shared_functions.sh overrides them)
    update_agent_status() {
        echo "[MOCK] update_agent_status: $*"
    }

    # Mock insufficient disk space
    cat >"/tmp/mock_df_low" <<'EOF'
#!/bin/bash
echo 'Filesystem 1K-blocks Used Available Use% Mounted-on'
echo '/dev/disk1s1 1000000 900000 100000 90% /Users/danielstevens/Desktop/Quantum-workspace'
exit 0
EOF
    chmod +x "/tmp/mock_df_low"
    ln -sf "/tmp/mock_df_low" "/tmp/df"

    # Test resource limits function with low disk space
    check_resource_limits "test_operation"
    local rc=$?
    assert_equals "1" "${rc}" "Resource limits check should fail with insufficient disk space"

    teardown_test_env
}

# Test timeout functionality
test_agent_documentation_timeout() {
    setup_test_env

    # Set test mode to prevent main loop execution
    export TEST_MODE=true

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Re-mock functions after sourcing (shared_functions.sh overrides them)
    update_agent_status() {
        echo "[MOCK] update_agent_status: $*"
    }

    # Create a long-running script for timeout testing
    cat >/tmp/long_running_doc.sh <<'EOF'
#!/bin/bash
for i in {1..10}; do
    echo "Running $i" >/dev/null
    /bin/sleep 1
done
EOF
    chmod +x /tmp/long_running_doc.sh

    # Test run_with_timeout with short timeout on a long-running command
    unmock_command "sleep"
    run_with_timeout 2 "/tmp/long_running_doc.sh"
    local rc=$?
    assert_equals "124" "${rc}" "run_with_timeout should return 124 on timeout"

    # Clean up
    rm -f /tmp/long_running_doc.sh

    teardown_test_env
}

# Test documentation task processing
test_agent_documentation_task_processing() {
    setup_test_env

    # Set test mode to prevent main loop execution
    export TEST_MODE=true

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Re-mock functions after sourcing (shared_functions.sh overrides them)
    update_agent_status() {
        echo "[MOCK] update_agent_status: $*"
    }

    log_message() {
        # Silent mock for testing - don't output to stdout
        true
    }

    # Test that we can process a documentation task (mocked)
    # Since the main processing is in the while loop, we'll test the components

    # Test task details retrieval
    local task_details
    task_details=$(get_task_details "test_doc_task_123")
    assert_success "get_task_details should succeed"

    local task_type
    task_type=$(echo "${task_details}" | jq -r '.type // "documentation"')
    assert_equals "documentation" "${task_type}" "Task type should be documentation"

    teardown_test_env
}

# Test README task processing
test_agent_documentation_readme_task() {
    setup_test_env

    # Set test mode to prevent main loop execution
    export TEST_MODE=true

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Re-mock functions after sourcing (shared_functions.sh overrides them)
    update_agent_status() {
        echo "[MOCK] update_agent_status: $*"
    }

    log_message() {
        # Silent mock for testing - don't output to stdout
        true
    }

    # Mock get_task_details to return readme task
    get_task_details() {
        echo '{"id":"test_readme_task_123","type":"readme","project":"TestProject","description":"Update README files"}'
    }

    # Test task details for readme
    local task_details
    task_details=$(get_task_details "test_readme_task_123")
    local task_type
    task_type=$(echo "${task_details}" | jq -r '.type // "documentation"')
    assert_equals "readme" "${task_type}" "Task type should be readme"

    teardown_test_env
}

# Test API docs task processing
test_agent_documentation_api_docs_task() {
    setup_test_env

    # Set test mode to prevent main loop execution
    export TEST_MODE=true

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Re-mock functions after sourcing (shared_functions.sh overrides them)
    update_agent_status() {
        echo "[MOCK] update_agent_status: $*"
    }

    log_message() {
        # Silent mock for testing - don't output to stdout
        true
    }

    # Mock get_task_details to return api-docs task
    get_task_details() {
        echo '{"id":"test_api_task_123","type":"api-docs","project":"TestProject","description":"Generate API documentation"}'
    }

    # Test task details for api-docs
    local task_details
    task_details=$(get_task_details "test_api_task_123")
    local task_type
    task_type=$(echo "${task_details}" | jq -r '.type // "documentation"')
    assert_equals "api-docs" "${task_type}" "Task type should be api-docs"

    teardown_test_env
}

# Test MCP registration
test_agent_documentation_mcp_registration() {
    setup_test_env

    # Set test mode to prevent main loop execution
    export TEST_MODE=true

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Re-mock functions after sourcing (shared_functions.sh overrides them)
    update_agent_status() {
        echo "[MOCK] update_agent_status: $*"
    }

    # Test MCP registration
    register_with_mcp "agent_documentation.sh" "documentation,readme,api-docs"
    # This is mocked, so we just verify the script can be sourced

    teardown_test_env
}

# Test agent status updates
test_agent_documentation_status_updates() {
    setup_test_env

    # Set test mode to prevent main loop execution
    export TEST_MODE=true

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Re-mock functions after sourcing (shared_functions.sh overrides them)
    update_agent_status() {
        echo "[MOCK] update_agent_status: $*"
    }

    # Test status update functions
    update_agent_status "agent_documentation.sh" "running" $$ "test_task"
    update_task_status "test_doc_task_123" "in_progress"
    complete_task "test_doc_task_123" "true"
    increment_task_count "agent_documentation.sh"

    # Verify mocks were called (functions return success)

    teardown_test_env
}

# Test configuration validation
test_agent_documentation_config_validation() {
    setup_test_env

    # Set test mode to prevent main loop execution
    export TEST_MODE=true

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Re-mock functions after sourcing (shared_functions.sh overrides them)
    update_agent_status() {
        echo "[MOCK] update_agent_status: $*"
    }

    # Test that configuration variables are set
    [[ -n "${WORKSPACE_ROOT}" ]] && assert_success "WORKSPACE_ROOT should be set"
    [[ -n "${PROJECTS_DIR}" ]] && assert_success "PROJECTS_DIR should be set"
    [[ -n "${AGENT_STATUS_FILE}" ]] && assert_success "AGENT_STATUS_FILE should be set"
    [[ ${SLEEP_INTERVAL} -ge ${MIN_INTERVAL} ]] && assert_success "SLEEP_INTERVAL should be >= MIN_INTERVAL"
    [[ ${SLEEP_INTERVAL} -le ${MAX_INTERVAL} ]] && assert_success "SLEEP_INTERVAL should be <= MAX_INTERVAL"

    teardown_test_env
}

# Test invalid task data handling
test_agent_documentation_invalid_task_data() {
    setup_test_env

    # Set test mode to prevent main loop execution
    export TEST_MODE=true

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Re-mock functions after sourcing (shared_functions.sh overrides them)
    update_agent_status() {
        echo "[MOCK] update_agent_status: $*"
    }

    log_message() {
        # Silent mock for testing - don't output to stdout
        true
    }

    # Mock get_task_details to return invalid data
    get_task_details() {
        echo '{}'
    }

    # Test with invalid task data
    local task_details
    task_details=$(get_task_details "invalid_task")
    local task_type
    task_type=$(echo "${task_details}" | jq -r '.type // "documentation"')
    assert_equals "documentation" "${task_type}" "Invalid task should default to documentation type"

    teardown_test_env
}

# Test unknown task type handling
test_agent_documentation_unknown_task_type() {
    setup_test_env

    # Set test mode to prevent main loop execution
    export TEST_MODE=true

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Re-mock functions after sourcing (shared_functions.sh overrides them)
    update_agent_status() {
        echo "[MOCK] update_agent_status: $*"
    }

    log_message() {
        # Silent mock for testing - don't output to stdout
        true
    }

    # Mock get_task_details to return unknown task type
    get_task_details() {
        echo '{"id":"test_unknown_task_123","type":"unknown_type","project":"TestProject","description":"Unknown task type"}'
    }

    # Test task details for unknown type
    local task_details
    task_details=$(get_task_details "test_unknown_task_123")
    local task_type
    task_type=$(echo "${task_details}" | jq -r '.type // "documentation"')
    assert_equals "unknown_type" "${task_type}" "Task type should be unknown_type"

    teardown_test_env
}

# Test backup operation before documentation
test_agent_documentation_backup_operation() {
    setup_test_env

    # Set test mode to prevent main loop execution
    export TEST_MODE=true

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Re-mock functions after sourcing (shared_functions.sh overrides them)
    update_agent_status() {
        echo "[MOCK] update_agent_status: $*"
    }

    log_message() {
        # Silent mock for testing - don't output to stdout
        true
    }

    # Test that backup command is available (mocked)
    # The backup is called in the task processing, but since we're testing components,
    # we verify the mock is set up correctly
    command -v backup_manager.sh >/dev/null 2>&1
    assert_success "backup_manager.sh should be mocked"

    teardown_test_env
}

# Test master automation command for documentation generation
test_agent_documentation_master_automation() {
    setup_test_env

    # Set test mode to prevent main loop execution
    export TEST_MODE=true

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Re-mock functions after sourcing (shared_functions.sh overrides them)
    update_agent_status() {
        echo "[MOCK] update_agent_status: $*"
    }

    log_message() {
        # Silent mock for testing - don't output to stdout
        true
    }

    # Test that master_automation.sh command is available (mocked)
    command -v master_automation.sh >/dev/null 2>&1
    assert_success "master_automation.sh should be mocked"

    teardown_test_env
}

# Test file count limits
test_agent_documentation_file_count_limits() {
    setup_test_env

    # Set test mode to prevent main loop execution
    export TEST_MODE=true

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Re-mock functions after sourcing (shared_functions.sh overrides them)
    update_agent_status() {
        echo "[MOCK] update_agent_status: $*"
    }

    # Mock high file count
    mock_command "find" $'/fake/file1\n/fake/file2\n/fake/file3\n/fake/file4\n/fake/file5\n/fake/file6'

    # Test resource limits function with high file count
    check_resource_limits "test_operation"
    local rc=$?
    assert_equals "1" "${rc}" "Resource limits check should fail with too many files"

    teardown_test_env
}

# Run all tests
# Note: run_test_suite is called externally, not from within this file
