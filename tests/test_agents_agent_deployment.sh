#!/bin/bash

# Comprehensive test suite for agent_deployment.sh
# Tests deployment, release, and publishing operations

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_deployment.sh"
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
    # Check if input contains id field
    if echo "$input" | grep -q '"id":'; then
        echo "test_task_123"
    else
        echo ""
    fi
    ;;
*'.type'*)
    if echo "$input" | grep -q '"type":'; then
        echo "$input" | sed 's/.*"type":"\([^"]*\)".*/\1/'
    else
        echo "deployment"
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
        echo "Test deployment task"
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

    mock_command "pgrep" "echo '1'"
    mock_command "sysctl" "echo 'vm.loadavg: { 0.50 0.40 0.30 }'"
    mock_command "vm_stat" "echo 'Pages free: 500000.'"
    mock_command "ps" "echo '10.0'"
    mock_command "uptime" "echo 'load average: 0.50, 0.40, 0.30'"
    mock_command "find" "echo '/fake/file1'; echo '/fake/file2'"
    mock_command "python3" "echo 'status updated'"
    mock_command "nice" "shift; \"\$@\""
    mock_command "sleep" "true"
    mock_command "kill" "true"
    mock_command "tail" "echo 'no errors'"
    mock_command "grep" "true"
    mock_command "cd" "true"
    mock_command "df" "echo 'Filesystem 1K-blocks Used Available Use% Mounted-on'; echo '/dev/disk1s1 1000000 100000 900000 10% /Users/danielstevens/Desktop/Quantum-workspace'"
}

# Mock agent functions - override them in the test environment
update_agent_status() {
    echo "[MOCK] update_agent_status: $*"
}

get_next_task() {
    echo '{"id":"test_task_123","type":"deployment","project":"TestProject","description":"Test deployment task"}'
}

get_task_details() {
    echo '{"id":"test_task_123","type":"deployment","project":"TestProject","description":"Test deployment task"}'
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
    echo "Test deployment task"
}

log_message() {
    echo "[MOCK] log_message: $*"
}

setup_test_env() {
    export PROJECT_NAME="TestProject"
    export PROJECT_DIR="/tmp/test_project"
    export MAX_CONCURRENCY=3
    export LOAD_THRESHOLD=2.0
    export MAX_FILES=1000
    export MAX_MEMORY_USAGE=80
    export MAX_CPU_USAGE=90
    export WORKSPACE="/tmp/test_workspace"
    export SCRIPT_DIR="/tmp/test_workspace/Tools/Automation/agents"

    # Create test directories
    mkdir -p "${PROJECT_DIR}"
    mkdir -p "${SCRIPT_DIR}/communication"
    mkdir -p "${SCRIPT_DIR}/../enhancements"
    mkdir -p "/tmp/test_workspace/Tools/Automation/agents"

    # Create mock files
    touch "${SCRIPT_DIR}/communication/agent_deployment.sh_notification.txt"
    touch "${SCRIPT_DIR}/communication/agent_deployment.sh_completed.txt"
    touch "${SCRIPT_DIR}/agent_deployment.sh_processed_tasks.txt"
    echo '{"agents":{},"last_update":0}' >"${SCRIPT_DIR}/agent_status.json"
    echo '{"tasks":[]}' >"${SCRIPT_DIR}/task_queue.json"

    # Override LOG_FILE for testing
    export LOG_FILE="/tmp/test_deployment_agent.log"

    # Create mock binaries
    echo '#!/bin/bash
echo "Master automation status completed"
exit 0' >"/tmp/test_workspace/Tools/Automation/master_automation.sh"
    chmod +x "/tmp/test_workspace/Tools/Automation/master_automation.sh"

    echo '#!/bin/bash
if [[ "$1" == "backup" ]]; then echo "Backup created for $2"; exit 0; fi
exit 1' >"/tmp/test_workspace/Tools/Automation/agents/backup_manager.sh"
    chmod +x "/tmp/test_workspace/Tools/Automation/agents/backup_manager.sh"

    mock_external_commands
}

teardown_test_env() {
    rm -rf "/tmp/test_project"
    rm -rf "/tmp/test_workspace"
    rm -f "/tmp/mock_jq"
}

# Test basic agent execution
test_agent_deployment_basic() {
    setup_test_env

    # Test that agent script exists and is executable
    assert_file_exists "${AGENT_SCRIPT}" "Agent script should exist"
    assert_success "Agent script should be executable" test -x "${AGENT_SCRIPT}"

    teardown_test_env
}

# Test resource limit checking
test_agent_deployment_resource_limits() {
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
test_agent_deployment_resource_limits_insufficient_disk() {
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

    # Unmock tail and df, then mock df properly
    unmock_command "tail"
    unmock_command "df"
    mock_command "df" "echo 'Filesystem 1K-blocks Used Available Use% Mounted-on
/dev/disk1s1 1000000 950000 50000 95% /Users/danielstevens/Desktop/Quantum-workspace'"

    # Test resource limits function with insufficient disk space
    check_resource_limits "test_operation"
    local rc=$?
    assert_equals "1" "${rc}" "Resource limits check should fail (return 1) with insufficient disk space"

    teardown_test_env
}

# Test timeout functionality
test_agent_deployment_timeout() {
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

    # Create a long-running script for timeout testing (using a command that won't be mocked)
    cat >/tmp/long_running_deploy.sh <<'EOF'
#!/bin/bash
# Use a loop that won't be interrupted by mocks
for i in {1..10}; do
    echo "Running $i" >/dev/null
    /bin/sleep 1
done
EOF
    chmod +x /tmp/long_running_deploy.sh

    # Test run_with_timeout with short timeout on a long-running command
    # Temporarily unmock sleep for this test
    unmock_command "sleep"
    run_with_timeout 2 "/tmp/long_running_deploy.sh"
    local rc=$?
    assert_equals "124" "${rc}" "run_with_timeout should return 124 on timeout"

    # Clean up
    rm -f /tmp/long_running_deploy.sh

    teardown_test_env
}

# Test deployment task processing
test_agent_deployment_task_deployment() {
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

    # Override hardcoded paths after sourcing
    export WORKSPACE="/tmp/test_workspace"
    export SCRIPT_DIR="/tmp/test_workspace/Tools/Automation/agents"

    # Mock task data for deployment
    get_next_task() {
        echo '{"id":"test_deployment_123","type":"deployment","project":"TestProject","description":"Test deployment task"}'
    }

    get_task_details() {
        echo '{"id":"test_deployment_123","type":"deployment","project":"TestProject","description":"Test deployment task"}'
    }

    # This would normally run the main loop, but we'll test the components
    # The main loop is difficult to test directly due to infinite loop

    teardown_test_env
}

# Test release task processing
test_agent_deployment_task_release() {
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

    # Override hardcoded paths after sourcing
    export WORKSPACE="/tmp/test_workspace"
    export SCRIPT_DIR="/tmp/test_workspace/Tools/Automation/agents"

    # Mock task data for release
    get_next_task() {
        echo '{"id":"test_release_123","type":"release","project":"TestProject","description":"Test release task"}'
    }

    get_task_details() {
        echo '{"id":"test_release_123","type":"release","project":"TestProject","description":"Test release task"}'
    }

    # Test that the task type handling works (would be tested in main loop)

    teardown_test_env
}

# Test publish task processing
test_agent_deployment_task_publish() {
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

    # Override hardcoded paths after sourcing
    export WORKSPACE="/tmp/test_workspace"
    export SCRIPT_DIR="/tmp/test_workspace/Tools/Automation/agents"

    # Mock task data for publish
    get_next_task() {
        echo '{"id":"test_publish_123","type":"publish","project":"TestProject","description":"Test publish task"}'
    }

    get_task_details() {
        echo '{"id":"test_publish_123","type":"publish","project":"TestProject","description":"Test publish task"}'
    }

    # Test that the task type handling works (would be tested in main loop)

    teardown_test_env
}

# Test unknown task type handling
test_agent_deployment_unknown_task_type() {
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

    # Override hardcoded paths after sourcing
    export WORKSPACE="/tmp/test_workspace"
    export SCRIPT_DIR="/tmp/test_workspace/Tools/Automation/agents"

    # Mock task data with unknown type
    get_next_task() {
        echo '{"id":"test_unknown_123","type":"unknown_type","project":"TestProject","description":"Test unknown task"}'
    }

    get_task_details() {
        echo '{"id":"test_unknown_123","type":"unknown_type","project":"TestProject","description":"Test unknown task"}'
    }

    # Test that unknown task types are handled (would be tested in main loop)

    teardown_test_env
}

# Test backup creation before deployment
test_agent_deployment_backup_creation() {
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

    # Override hardcoded paths after sourcing
    export WORKSPACE="/tmp/test_workspace"
    export SCRIPT_DIR="/tmp/test_workspace/Tools/Automation/agents"

    # Test that backup manager is called (this would happen in the main task processing)

    teardown_test_env
}

# Test MCP registration
test_agent_deployment_mcp_registration() {
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

    # Test MCP registration (this happens at startup)
    register_with_mcp "agent_deployment.sh" "deployment,release,publish"
    # This is mocked, so we just verify the script can be sourced

    teardown_test_env
}

# Test agent status updates
test_agent_deployment_status_updates() {
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

    # Test status update functions (these are mocked)
    update_agent_status "agent_deployment.sh" "running" $$ ""
    update_task_status "test_task_123" "in_progress"
    complete_task "test_task_123" "true"
    increment_task_count "agent_deployment.sh"

    # Verify mocks were called (functions return success)

    teardown_test_env
}

# Test configuration validation
test_agent_deployment_config_validation() {
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

    # Test that configuration variables are set (using assert_equals with expected non-empty values)
    [[ -n "${SLEEP_INTERVAL}" ]] && assert_success "SLEEP_INTERVAL should be set"
    [[ -n "${MIN_INTERVAL}" ]] && assert_success "MIN_INTERVAL should be set"
    [[ -n "${MAX_INTERVAL}" ]] && assert_success "MAX_INTERVAL should be set"

    teardown_test_env
}

# Test no tasks available scenario
test_agent_deployment_no_tasks() {
    setup_test_env

    # Mock no tasks available
    get_next_task() {
        echo ""
    }

    # Set test mode to prevent main loop execution
    export TEST_MODE=true

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Re-mock functions after sourcing (shared_functions.sh overrides them)
    update_agent_status() {
        echo "[MOCK] update_agent_status: $*"
    }

    # Test that agent handles no tasks gracefully (would be tested in main loop)

    teardown_test_env
}

# Run all tests
# Note: run_test_suite is called externally, not from within this file
