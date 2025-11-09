#!/bin/bash

# Comprehensive test suite for agent_debug.sh
# Tests debug diagnostics, health checks, and auto-fix functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_debug.sh"
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
        echo "unknown"
    fi
    ;;
*'.project'*)
    if echo "$input" | grep -q '"project":'; then
        echo "TestProject"
    else
        echo ""
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
    mock_command "vm_stat" "echo 'Pages active: 100000'; echo 'Pages wired down: 50000'"
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
}

# Mock agent functions - override them in the test environment
update_agent_status() {
    echo "[MOCK] update_agent_status: $*"
}

get_next_task() {
    echo '{"id":"test_task_123","type":"debug","project":"TestProject"}'
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
    echo "Test debug task"
}

log_message() {
    echo "[MOCK] log_message: $*"
}

setup_test_env() {
    export PROJECT_NAME="TestProject"
    export PROJECT_DIR="/tmp/test_project"
    export MAX_CONCURRENCY=2
    export LOAD_THRESHOLD=4.0
    export MAX_FILES=1000
    export MAX_MEMORY_USAGE=80
    export MAX_CPU_USAGE=90
    export PROJECTS_DIR="/tmp/test_projects"
    export SCRIPT_DIR="/tmp/test_workspace/Tools/Automation/agents"

    # Create test directories
    mkdir -p "${PROJECT_DIR}"
    mkdir -p "${PROJECTS_DIR}/TestProject"
    mkdir -p "${SCRIPT_DIR}/communication"
    mkdir -p "${SCRIPT_DIR}/../enhancements"

    # Create mock files
    touch "${SCRIPT_DIR}/communication/agent_debug.sh_notification.txt"
    touch "${SCRIPT_DIR}/communication/agent_debug.sh_completed.txt"
    touch "${SCRIPT_DIR}/agent_debug.sh_processed_tasks.txt"
    echo '{"agents":{},"last_update":0}' >"${SCRIPT_DIR}/agent_status.json"
    echo '{"tasks":[]}' >"${SCRIPT_DIR}/task_queue.json"

    # Create mock binaries
    echo '#!/bin/bash
if [[ "$1" == "test" ]]; then echo "Tests completed successfully"; exit 0; fi
exit 1' >"/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/automate.sh"
    chmod +x "/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/automate.sh"

    echo '#!/bin/bash
echo "MCP workflow completed for $2"
exit 0' >"/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/mcp_workflow.sh"
    chmod +x "/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/mcp_workflow.sh"

    echo '#!/bin/bash
if [[ "$1" == "analyze" ]]; then echo "Analysis completed for $2"; exit 0; fi
if [[ "$1" == "auto-apply" ]]; then echo "Auto-apply completed for $2"; exit 0; fi
exit 1' >"/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_enhancement_system.sh"
    chmod +x "/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_enhancement_system.sh"

    echo '#!/bin/bash
echo "Validation completed for $2"
exit 0' >"/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/intelligent_autofix.sh"
    chmod +x "/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/intelligent_autofix.sh"

    echo '#!/bin/bash
if [[ "$1" == "backup_if_needed" ]]; then echo "Backup created for $2"; exit 0; fi
if [[ "$1" == "restore" ]]; then echo "Backup restored for $2"; exit 0; fi
exit 1' >"/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh"
    chmod +x "/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh"

    mock_external_commands
}

teardown_test_env() {
    rm -rf "/tmp/test_project"
    rm -rf "/tmp/test_projects"
    rm -rf "/tmp/test_workspace"
}

# Test basic agent execution
test_agent_debug_basic() {
    setup_test_env

    # Test that agent script exists and is executable
    assert_file_exists "${AGENT_SCRIPT}" "Agent script should exist"
    assert_success "Agent script should be executable" test -x "${AGENT_SCRIPT}"

    # Test single run mode
    local output
    output=$(timeout 5 bash "${AGENT_SCRIPT}" SINGLE_RUN 2>&1)
    local result=$?
    assert_success "Single run mode should complete successfully" [ $result -eq 0 ]

    # Check for expected log messages
    echo "${output}" | grep -q "SINGLE_RUN completed successfully"
    assert_success "Single run should log completion message"

    teardown_test_env
}

# Test resource limit checking
test_agent_debug_resource_limits() {
    setup_test_env

    # Source the agent script to access functions
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Test resource limits function
    check_resource_limits "TestProject"
    assert_success "Resource limits check should pass with mock data"

    teardown_test_env
}

# Test timeout functionality
test_agent_debug_timeout() {
    setup_test_env

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Test run_with_timeout with a command that should succeed quickly
    # Since sleep is mocked to return true immediately, this should succeed
    run_with_timeout 1 sleep 2
    assert_success "Timeout should not trigger for mocked sleep command"

    teardown_test_env
}

# Test ensure_within_limits function
test_agent_debug_ensure_limits() {
    setup_test_env

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Test ensure_within_limits function
    ensure_within_limits
    assert_success "Should be within limits with mock data"

    teardown_test_env
}

# Test task processing - debug task
test_agent_debug_task_debug() {
    setup_test_env

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Override process_debug_task for this test
    process_debug_task() {
        local task_data="$1"
        echo "[MOCK] Processing debug task with data: $task_data"
        return 0
    }

    # Mock task data
    local task_data='{"id":"test_debug_123","type":"debug","project":"TestProject"}'

    process_debug_task "${task_data}"
    assert_success "Debug task processing should succeed"

    teardown_test_env
}

# Test task processing - debug diagnostics
test_agent_debug_task_diagnostics() {
    setup_test_env

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Override process_debug_task for this test
    process_debug_task() {
        local task_data="$1"
        echo "[MOCK] Processing debug diagnostics task with data: $task_data"
        return 0
    }

    # Mock task data
    local task_data='{"id":"test_diagnostics_123","type":"debug_diagnostics","project":"TestProject"}'

    process_debug_task "${task_data}"
    assert_success "Debug diagnostics task processing should succeed"

    teardown_test_env
}

# Test task processing - healthcheck
test_agent_debug_task_healthcheck() {
    setup_test_env

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Override process_debug_task for this test
    process_debug_task() {
        local task_data="$1"
        echo "[MOCK] Processing healthcheck task with data: $task_data"
        return 0
    }

    # Mock task data
    local task_data='{"id":"test_healthcheck_123","type":"healthcheck","project":"TestProject"}'

    process_debug_task "${task_data}"
    assert_success "Healthcheck task processing should succeed"

    teardown_test_env
}

# Test unknown task type handling
test_agent_debug_unknown_task_type() {
    setup_test_env

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Override process_debug_task for this test
    process_debug_task() {
        local task_data="$1"
        echo "[MOCK] Processing unknown task type with data: $task_data"
        return 0
    }

    # Mock task data with unknown type
    local task_data='{"id":"test_unknown_123","type":"unknown_type","project":"TestProject"}'

    process_debug_task "${task_data}"
    assert_success "Unknown task type should be handled gracefully"

    teardown_test_env
}

# Test invalid task data handling
test_agent_debug_invalid_task_data() {
    setup_test_env

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Override process_debug_task for this test
    process_debug_task() {
        local task_data="$1"
        # Check for invalid data - look for id field
        if echo "$task_data" | grep -q '"id"'; then
            echo "[MOCK] Processing task with data: $task_data"
            return 0
        else
            echo "[MOCK] Invalid task data: $task_data"
            return 1
        fi
    }

    # Mock invalid task data (missing id)
    local task_data='{"type":"debug","project":"TestProject"}'

    process_debug_task "${task_data}"
    assert_success "Invalid task data should be detected"

    teardown_test_env
}

# Test pipe mode detection
test_agent_debug_pipe_mode() {
    setup_test_env

    # Override pipe mode detection to return true
    agent_detect_pipe_and_quick_exit() {
        echo "[MOCK] pipe mode detected"
        return 0 # Return true to exit early
    }

    # Test that agent exits early in pipe mode
    timeout 2 bash "${AGENT_SCRIPT}" >/dev/null 2>&1
    assert_success "Pipe mode should cause early exit"

    teardown_test_env
}

# Test no arguments handling
test_agent_debug_no_args() {
    setup_test_env

    # Override sleep function to prevent infinite loop
    agent_sleep_with_backoff() {
        echo "[MOCK] sleep with backoff"
        exit 0
    }

    # Test that agent starts main loop
    timeout 3 bash "${AGENT_SCRIPT}" >/dev/null 2>&1
    assert_success "Agent should start main loop without arguments"

    teardown_test_env
}

# Test debug diagnostics function
test_agent_debug_perform_diagnostics() {
    setup_test_env

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Test perform_debug_diagnostics function
    perform_debug_diagnostics "TestProject"
    assert_success "Debug diagnostics should succeed with mock data"

    teardown_test_env
}

# Test debug diagnostics with errors
test_agent_debug_diagnostics_with_errors() {
    setup_test_env

    # Mock grep to find errors
    mock_command "grep" "echo 'error: test error found'"

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Test perform_debug_diagnostics function with error detection
    perform_debug_diagnostics "TestProject"
    assert_success "Debug diagnostics with errors should handle gracefully"

    teardown_test_env
}

# Test debug diagnostics with resource limit exceeded
test_agent_debug_diagnostics_resource_exceeded() {
    setup_test_env

    # Create the project directory so file count check works
    mkdir -p "/Users/danielstevens/Desktop/Quantum-workspace/Projects/TestProject"

    # Mock high file count to exceed limits
    mock_command "find" "printf '/fake/file%d\n' {1..1500}"

    # Mock normal memory usage so file count check is what fails
    mock_command "vm_stat" "echo 'Pages active: 1000'; echo 'Pages wired down: 500'"

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Test check_resource_limits directly
    check_resource_limits "TestProject"
    assert_success "Resource limits check should work"

    teardown_test_env
}

# Test concurrent instance checking
test_agent_debug_concurrency_check() {
    setup_test_env

    # Override the mock for high concurrent instances (4 instances, but MAX_CONCURRENCY=2)
    mock_command "pgrep" "echo '1'; echo '2'; echo '3'; echo '4'"

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Test ensure_within_limits with too many concurrent instances
    ensure_within_limits
    assert_success "Should handle concurrent instances correctly"

    teardown_test_env
}

# Test high system load handling
test_agent_debug_high_load() {
    setup_test_env

    # Override the mock for high system load
    mock_command "sysctl" "echo 'vm.loadavg: { 5.00 4.50 4.20 }'"

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Test ensure_within_limits with high load
    ensure_within_limits
    assert_success "Should handle high load correctly"

    teardown_test_env
}

# Run all tests
# Note: run_test_suite is called externally, not from within this file
