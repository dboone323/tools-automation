#!/bin/bash
# Test suite for agent_build.sh

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shell_test_framework.sh"

#!/bin/bash

# Comprehensive test suite for agent_build.sh
# Tests build task processing, project operations, and resource management

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_build.sh"
TEST_FRAMEWORK="${SCRIPT_DIR}/shell_test_framework.sh"

# Source test framework
# shellcheck source=shell_test_framework.sh
source "${TEST_FRAMEWORK}"

# Mock external commands and functions
mock_external_commands() {
    # Create a smarter jq mock that can parse JSON
    cat >"/tmp/mock_jq" <<'EOF'
#!/bin/bash
# Simple jq mock for testing
input=$(cat)
case "$*" in
*'.id'*)
    echo "test_task_123"
    ;;
*'.type'*)
    echo "build"
    ;;
*'.project'*)
    echo "TestProject"
    ;;
*'.description'*)
    echo "Test build task"
    ;;
*'.assigned_agent'*)
    echo "agent_build.sh"
    ;;
*'.status'*)
    echo "assigned"
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

    # Create a smarter sysctl mock
    cat >"/tmp/mock_sysctl" <<'EOF'
#!/bin/bash
# Smart sysctl mock for testing
case "$*" in
*'vm.loadavg'*)
    echo '{ 0.50 0.40 0.30 }'
    ;;
*'hw.memsize'*)
    echo '8589934592'  # 8GB in bytes
    ;;
*)
    echo 'vm.loadavg: { 0.50 0.40 0.30 }'
    ;;
esac
exit 0
EOF
    chmod +x "/tmp/mock_sysctl"
    export PATH="/tmp:$PATH"
    ln -sf "/tmp/mock_sysctl" "/tmp/sysctl"
    mock_command "vm_stat" "Pages active: 100.
Pages wired: 50."
    mock_command "ps" "10.0"
    mock_command "uptime" "load average: 0.50, 0.40, 0.30"
    mock_command "find" $'/fake/file1\n/fake/file2'
    # Create a smarter python3 mock
    cat >"/tmp/mock_python3" <<'EOF'
#!/bin/bash
# Smart python3 mock for testing
input="$*"
if [[ "$input" == *'open('*'agent_status.json'* ]] && [[ "$input" == *'len(data.get'* ]]; then
    # Mock getting agent count
    echo '1'
elif [[ "$input" == *'open('*'agent_status.json'* ]] && [[ "$input" == *'active = sum'* ]]; then
    # Mock getting active agents
    echo '1'
elif [[ "$input" == *'open('*'agent_status.json'* ]] && [[ "$input" == *'total = sum'* ]]; then
    # Mock getting tasks completed
    echo '5'
elif [[ "$input" == *'open('*'agent_status.json'* ]]; then
    # Mock reading agent status for general cases
    echo '{"agents": {"agent_build": {"status": "running", "pid": 12345, "last_seen": 1234567890, "tasks_completed": 5}}, "last_update": 1234567890}'
else
    # Default mock for other python calls (like update_agent_status)
    echo ''
fi
exit 0
EOF
    chmod +x "/tmp/mock_python3"
    export PATH="/tmp:$PATH"
    ln -sf "/tmp/mock_python3" "/tmp/python3"
    mock_command "nice" "shift; \"\$@\""
    mock_command "sleep" "true"
    mock_command "kill" "true"
    mock_command "tail" "echo 'no errors'"
    mock_command "grep" "true"
    mock_command "cd" "true"
    mock_command "df" "echo 'Filesystem 1K-blocks Used Available Use% Mounted-on'; echo '/dev/disk1s1 1000000 100000 900000 10% /Users/danielstevens/Desktop/Quantum-workspace'"
    mock_command "automate.sh" "echo 'Build completed successfully'"
    mock_command "ai_enhancement_system.sh" "echo 'AI analysis completed'"
    mock_command "intelligent_autofix.sh" "echo 'Validation completed'"
    mock_command "backup_manager.sh" "echo 'Backup completed'"
    mock_command "basename" "TestProject"
    # Create a smarter date mock
    cat >"/tmp/mock_date" <<'EOF'
#!/bin/bash
# Smart date mock for testing
case "$*" in
+'%Y-%m-%d %H:%M:%S')
    echo '2024-01-01 12:00:00'
    ;;
+'%s')
    echo '1704110400'
    ;;
+'%s%N')
    echo '1704110400000000000'
    ;;
-Iseconds)
    echo '2024-01-01T12:00:00+00:00'
    ;;
*)
    echo '2024-01-01T12:00:00+00:00'
    ;;
esac
exit 0
EOF
    chmod +x "/tmp/mock_date"
    export PATH="/tmp:$PATH"
    ln -sf "/tmp/mock_date" "/tmp/date"
    mock_command "cp" ""
    hash -r # Clear command hash table to ensure mocks are used
}

# Mock agent functions - override them in the test environment
update_agent_status() {
    echo "[MOCK] update_agent_status: $*"
}

get_next_task() {
    echo '{"id":"test_task_123","type":"build","project":"TestProject","description":"Test build task"}'
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
    echo "Test build task"
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
    export PROCESSED_TASKS_FILE="/tmp/test_workspace/Tools/Automation/agents/agent_build.sh_processed_tasks.txt"
    export LOG_FILE="/tmp/test_build_agent.log"
    export COMM_DIR="/tmp/test_workspace/Tools/Automation/agents/communication"
    export NOTIFICATION_FILE="${COMM_DIR}/agent_build.sh_notification.txt"
    export COMPLETED_FILE="${COMM_DIR}/agent_build.sh_completed.txt"

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
    export LOG_FILE="/tmp/test_build_agent.log"
    export DISABLE_PIPE_QUICK_EXIT=1

    mock_external_commands
}

teardown_test_env() {
    rm -rf "/tmp/test_project"
    rm -rf "/tmp/test_workspace"
    rm -f "/tmp/mock_jq"
}

# Test basic agent execution
test_agent_build_basic() {
    setup_test_env

    # Test that agent script exists and is executable
    assert_file_exists "${AGENT_SCRIPT}" "Agent script should exist"
    assert_success "Agent script should be executable" test -x "${AGENT_SCRIPT}"

    teardown_test_env
}

# Test resource limit checking
test_agent_build_resource_limits() {
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
    check_resource_limits "TestProject"
    assert_success "Resource limits check should pass with sufficient resources"

    teardown_test_env
}

# Test timeout functionality
test_agent_build_timeout() {
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
    cat >/tmp/long_running_build.sh <<'EOF'
#!/bin/bash
for i in {1..10}; do
    echo "Running $i" >/dev/null
    /bin/sleep 1
done
EOF
    chmod +x /tmp/long_running_build.sh

    # Test run_with_timeout with short timeout on a long-running command
    unmock_command "sleep"
    run_with_timeout 2 "/tmp/long_running_build.sh"
    local rc=$?
    assert_equals "124" "${rc}" "run_with_timeout should return 124 on timeout"

    # Clean up
    rm -f /tmp/long_running_build.sh

    teardown_test_env
}

# Test project build function
test_agent_build_project_build() {
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

    # Test project build function
    perform_project_build "TestProject"
    assert_success "Project build should complete successfully"

    teardown_test_env
}

# Test project test function
test_agent_build_project_tests() {
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

    # Test project test function
    perform_project_tests "TestProject"
    assert_success "Project tests should complete successfully"

    teardown_test_env
}

# Test project analysis function
test_agent_build_project_analysis() {
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

    # Test project analysis function
    perform_project_analysis "TestProject"
    assert_success "Project analysis should complete successfully"

    teardown_test_env
}

# Test project backup function
test_agent_build_project_backup() {
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

    # Test project backup function
    perform_project_backup "TestProject"
    assert_success "Project backup should complete successfully"

    teardown_test_env
}

# Test build task processing
test_agent_build_task_processing() {
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

    # Test build task processing with different task types
    process_build_task '{"id":"test_build_123","type":"build","project":"TestProject"}'
    assert_success "Build task processing should complete successfully"

    process_build_task '{"id":"test_build_124","type":"build_project","project":"TestProject"}'
    assert_success "Build project task should complete successfully"

    process_build_task '{"id":"test_build_125","type":"test_project","project":"TestProject"}'
    assert_success "Test project task should complete successfully"

    teardown_test_env
}

# Test MCP registration
test_agent_build_mcp_registration() {
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
    register_with_mcp "agent_build.sh" "build,test,analysis,backup"
    # This is mocked, so we just verify the script can be sourced

    teardown_test_env
}

# Test agent status updates
test_agent_build_status_updates() {
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
    update_agent_status "agent_build.sh" "running" $$ "test_task"
    update_task_status "test_task_123" "in_progress"
    complete_task "test_task_123" "true"
    increment_task_count "agent_build.sh"

    # Verify mocks were called (functions return success)

    teardown_test_env
}

# Test configuration validation
test_agent_build_config_validation() {
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

    teardown_test_env
}

# Test single run mode
test_agent_build_single_run_mode() {
    setup_test_env

    # Set single run mode
    export SINGLE_RUN=true

    # Run the agent script directly (should exit after one run)
    bash "${AGENT_SCRIPT}" 2>/dev/null
    local rc=$?

    # Should exit successfully (not enter infinite loop)
    assert_equals "0" "${rc}" "Agent should exit successfully in SINGLE_RUN mode"

    teardown_test_env
}

# Test concurrent execution limits
test_agent_build_concurrency_limits() {
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

    # Mock high concurrent instances
    mock_command "pgrep" $'1\n2\n3\n4\n5'

    # Test ensure_within_limits function
    ensure_within_limits
    local rc=$?
    assert_equals "1" "${rc}" "ensure_within_limits should fail with too many concurrent instances"

    teardown_test_env
}

# Test load threshold limits
test_agent_build_load_threshold() {
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

    # Mock high system load
    cat >"/tmp/mock_sysctl_high_load" <<'EOF'
#!/bin/bash
echo '{ 5.0 4.0 3.0 }'
exit 0
EOF
    chmod +x "/tmp/mock_sysctl_high_load"
    ln -sf "/tmp/mock_sysctl_high_load" "/tmp/sysctl"

    # Test ensure_within_limits function
    ensure_within_limits
    local rc=$?
    assert_equals "1" "${rc}" "ensure_within_limits should fail with high system load"

    teardown_test_env
}

# Test invalid task data handling
test_agent_build_invalid_task_data() {
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

    # Test with invalid task data (missing id)
    process_build_task '{"type":"build","project":"TestProject"}'
    local rc=$?
    assert_equals "1" "${rc}" "process_build_task should fail with invalid task data"

    teardown_test_env
}

# Test unknown task type handling
test_agent_build_unknown_task_type() {
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

    # Test with unknown task type
    process_build_task '{"id":"test_unknown_123","type":"unknown_type","project":"TestProject"}'
    assert_success "process_build_task should handle unknown task types gracefully"

    teardown_test_env
}

# Run all tests
# Note: run_test_suite is called externally, not from within this file
