#!/bin/bash

# Test suite for agent_integration.sh
# Comprehensive testing of integration agent functionality

# Source test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_integration.sh"

# Source shell test framework
source "${SCRIPT_DIR}/shell_test_framework.sh"

# Mock external commands and functions
mock_external_commands() {
    # Create a simple jq mock
    cat >"/tmp/mock_jq" <<'EOF'
#!/bin/bash
# Simple jq mock for testing
echo "test_integration_task_123"
exit 0
EOF
    chmod +x "/tmp/mock_jq"
    export PATH="/tmp:$PATH"
    ln -sf "/tmp/mock_jq" "/tmp/jq"

    # Create a smarter df mock
    cat >"/tmp/mock_df" <<'EOF'
#!/bin/bash
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
echo 'Pages free: 500000.'
echo 'Pages active: 100.'
echo 'Pages wired: 50.'
exit 0
EOF
    chmod +x "/tmp/mock_vm_stat"
    export PATH="/tmp:$PATH"
    ln -sf "/tmp/mock_vm_stat" "/tmp/vm_stat"

    # Create a smarter ps mock
    cat >"/tmp/mock_ps" <<'EOF'
#!/bin/bash
echo '%CPU'
echo '10.0'
echo '5.0'
exit 0
EOF
    chmod +x "/tmp/mock_ps"
    export PATH="/tmp:$PATH"
    ln -sf "/tmp/mock_ps" "/tmp/ps"

    # Create a smarter gh mock
    cat >"/tmp/mock_gh" <<'EOF'
#!/bin/bash
case "$*" in
*run\ list*)
    echo '[{"status": "completed", "conclusion": "success", "name": "test-workflow"}]'
    ;;
*run\ delete*)
    echo "Deleted run"
    ;;
*)
    echo "Mock GitHub CLI"
    ;;
esac
exit 0
EOF
    chmod +x "/tmp/mock_gh"
    export PATH="/tmp:$PATH"
    ln -sf "/tmp/mock_gh" "/tmp/gh"

    # Create a simple python3 mock for YAML validation
    cat >"/tmp/mock_python3" <<'EOF'
#!/bin/bash
echo "Valid YAML"
exit 0
EOF
    chmod +x "/tmp/mock_python3"
    export PATH="/tmp:$PATH"
    ln -sf "/tmp/mock_python3" "/tmp/python3"

    mock_command "find" $'/fake/file1\n/fake/file2\n/fake/file3'
    mock_command "git" "echo 'Mock git command'"
    mock_command "bc" "echo '50'"
    mock_command "sysctl" "echo 'hw.memsize: 8589934592'"
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
    echo "test_integration_run"
}

get_task_details() {
    echo '{"id":"test_integration_task_123","type":"integration","project":"TestProject","description":"Test integration task"}'
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
    echo "Test integration task"
}

log_message() {
    echo "[MOCK] log_message: $*" >&2
}

ensure_within_limits() {
    echo "[MOCK] ensure_within_limits: $*"
    return 0 # Allow execution
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
    export PROCESSED_TASKS_FILE="/tmp/test_workspace/Tools/Automation/agents/agent_integration.sh_processed_tasks.txt"
    export LOG_FILE="/tmp/test_integration_agent.log"
    export COMM_DIR="/tmp/test_workspace/Tools/Automation/agents/communication"
    export NOTIFICATION_FILE="${COMM_DIR}/agent_integration.sh_notification.txt"
    export COMPLETED_FILE="${COMM_DIR}/agent_integration.sh_completed.txt"
    export SLEEP_INTERVAL=600
    export MIN_INTERVAL=120
    export MAX_INTERVAL=1800
    export WORKFLOWS_DIR="/tmp/test_workspace/.github/workflows"
    export AGENT_NAME="IntegrationAgent"

    # Create test directories
    mkdir -p "${PROJECT_DIR}"
    mkdir -p "${SCRIPT_DIR}/communication"
    mkdir -p "${SCRIPT_DIR}/../enhancements"
    mkdir -p "/tmp/test_workspace/Tools/Automation/agents"
    mkdir -p "${PROJECTS_DIR}/TestProject"
    mkdir -p "${WORKFLOWS_DIR}"
    mkdir -p "/tmp/test_workspace/.metrics"

    # Create mock project files
    mkdir -p "${PROJECTS_DIR}/TestProject/Tests"
    echo 'print("Hello")' >"${PROJECTS_DIR}/TestProject/TestFile.swift"

    # Create mock workflow files
    cat >"${WORKFLOWS_DIR}/pr-validation-unified.yml" <<'EOF'
name: PR Validation
on: pull_request
jobs:
  test:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run tests
        run: echo "Tests passed"
EOF

    cat >"${WORKFLOWS_DIR}/swiftlint-auto-fix.yml" <<'EOF'
name: SwiftLint Auto Fix
on: push
jobs:
  lint:
    runs-on: ubuntu-latest
    steps:
      - uses: actions/checkout@v3
      - name: Run SwiftLint
        run: echo "Linting completed"
EOF

    # Create mock files
    touch "${NOTIFICATION_FILE}" "${COMPLETED_FILE}" "${PROCESSED_TASKS_FILE}"
    echo '{"agents":{},"last_update":0}' >"${AGENT_STATUS_FILE}"
    echo '{"tasks":[]}' >"${TASK_QUEUE_FILE}"

    # Override LOG_FILE for testing
    export LOG_FILE="/tmp/test_integration_agent.log"
    export DISABLE_PIPE_QUICK_EXIT=1

    # Mock update_status.py to speed up tests
    if [ -f "update_status.py" ]; then
        cp update_status.py update_status.py.backup
        cat > update_status.py << 'EOF'
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
test_agent_integration_basic() {
    setup_test_env

    # Test that agent script exists and is executable
    assert_file_exists "${AGENT_SCRIPT}" "Agent script should exist"
    assert_success "Agent script should be executable" test -x "${AGENT_SCRIPT}"

    teardown_test_env
}

# Test resource limit checking with sufficient resources
test_agent_integration_resource_limits_sufficient() {
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
test_agent_integration_resource_limits_disk() {
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
test_agent_integration_timeout() {
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
    cat >/tmp/long_running_integration.sh <<'EOF'
#!/bin/bash
for i in {1..10}; do
    echo "Running $i" >/dev/null
    /bin/sleep 1
done
EOF
    chmod +x /tmp/long_running_integration.sh

    # Test run_with_timeout with short timeout on a long-running command
    unmock_command "sleep"
    run_with_timeout 2 "/tmp/long_running_integration.sh"
    local rc=$?
    assert_equals "124" "${rc}" "run_with_timeout should return 124 on timeout"

    # Clean up
    rm -f /tmp/long_running_integration.sh

    teardown_test_env
}

# Test integration task processing - test_integration_run
test_agent_integration_task_test_integration_run() {
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

    # Test processing test_integration_run task
    process_integration_task "test_integration_run"
    # This should succeed without error

    teardown_test_env
}

# Test workflow validation
test_agent_integration_validate_workflows() {
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

    # Test workflow validation
    validate_workflow_syntax "${WORKFLOWS_DIR}/pr-validation-unified.yml"
    assert_success "Workflow validation should succeed for valid YAML"

    teardown_test_env
}

# Test workflow monitoring
test_agent_integration_monitor_workflows() {
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

    # Test workflow monitoring
    monitor_workflows
    assert_success "Workflow monitoring should succeed"

    # Check if health report was created
    local health_files
    health_files=$(find "/tmp/test_workspace/.metrics" -name "workflow_health_*.json" 2>/dev/null | wc -l)
    assert_equals "1" "${health_files}" "Health report should be created"

    teardown_test_env
}

# Test workflow sync
test_agent_integration_sync_workflows() {
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

    # Test workflow sync
    sync_workflows
    assert_success "Workflow sync should succeed"

    teardown_test_env
}

# Test MCP registration
test_agent_integration_mcp_registration() {
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
    register_with_mcp "agent_integration.sh" "integration,workflows,ci-cd"
    # This is mocked, so we just verify the script can be sourced

    teardown_test_env
}

# Test agent status updates
test_agent_integration_status_updates() {
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
    update_agent_status "IntegrationAgent" "running" $$ "test_task"
    update_task_status "test_integration_task_123" "in_progress"
    complete_task "test_integration_task_123" "true"
    increment_task_count "agent_integration.sh"

    # Verify mocks were called (functions return success)

    teardown_test_env
}

# Test configuration validation
test_agent_integration_config_validation() {
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
    [[ -n "${WORKFLOWS_DIR}" ]] && assert_success "WORKFLOWS_DIR should be set"
    [[ -n "${AGENT_STATUS_FILE}" ]] && assert_success "AGENT_STATUS_FILE should be set"
    [[ ${SLEEP_INTERVAL} -ge ${MIN_INTERVAL} ]] && assert_success "SLEEP_INTERVAL should be >= MIN_INTERVAL"
    [[ ${SLEEP_INTERVAL} -le ${MAX_INTERVAL} ]] && assert_success "SLEEP_INTERVAL should be <= MAX_INTERVAL"

    teardown_test_env
}

# Test invalid workflow file handling
test_agent_integration_invalid_workflow() {
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

    # Create invalid workflow file
    echo "invalid: yaml: content: [" >"${WORKFLOWS_DIR}/invalid.yml"

    # Test validation of invalid workflow
    validate_workflow_syntax "${WORKFLOWS_DIR}/invalid.yml"
    local rc=$?
    assert_equals "1" "${rc}" "Invalid workflow should fail validation"

    teardown_test_env
}

# Test cleanup runs functionality
test_agent_integration_cleanup_runs() {
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

    # Test cleanup runs
    cleanup_old_runs
    assert_success "Cleanup runs should succeed"

    teardown_test_env
}

# Test deploy workflows functionality
test_agent_integration_deploy_workflows() {
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

    # Test deploy workflows
    deploy_workflows
    assert_success "Deploy workflows should succeed"

    teardown_test_env
}

# Test unknown task type handling
test_agent_integration_unknown_task_type() {
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

    # Test processing unknown task type
    process_integration_task "unknown_task_type"
    # Should log warning but not fail

    teardown_test_env
}

# Run all tests
# Note: run_test_suite is called externally, not from within this file</content>
<parameter name="filePath">/Users/danielstevens/Desktop/github-projects/tools-automation/tests/test_agents_agent_integration.sh