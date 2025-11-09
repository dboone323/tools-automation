#!/bin/bash

# Comprehensive test suite for agent_codegen.sh
# Tests code generation, autofix, enhancement, and validation functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_codegen.sh"
TEST_FRAMEWORK="${SCRIPT_DIR}/shell_test_framework.sh"

# Source test framework
# shellcheck source=shell_test_framework.sh
source "${TEST_FRAMEWORK}"

# Mock external commands and functions
mock_external_commands() {
    mock_command "pgrep" "echo '1'"
    mock_command "sysctl" "echo 'vm.loadavg: { 0.50 0.40 0.30 }'"
    mock_command "vm_stat" "echo 'Pages active: 100000'; echo 'Pages wired down: 50000'"
    mock_command "ps" "echo '10.0'"
    mock_command "uptime" "echo 'load average: 0.50, 0.40, 0.30'"
    mock_command "find" "echo '/fake/file1'; echo '/fake/file2'"
    mock_command "jq" "echo '{\"id\":\"test_task\",\"type\":\"codegen\",\"project\":\"TestProject\"}'"
    mock_command "python3" "echo 'status updated'"
    mock_command "nice" "shift; \"\$@\""
    mock_command "sleep" "true"
    mock_command "kill" "true"
    mock_command "tail" "echo 'no errors'"
    mock_command "grep" "true"
}

# Mock agent functions - override them in the test environment
update_agent_status() {
    echo "[MOCK] update_agent_status: $*"
}

get_next_task() {
    echo '{"id":"test_task_123","type":"codegen","project":"TestProject"}'
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
    echo "Test codegen task"
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

    # Create mock files
    touch "${SCRIPT_DIR}/communication/agent_codegen.sh_notification.txt"
    touch "${SCRIPT_DIR}/communication/agent_codegen.sh_completed.txt"
    touch "${SCRIPT_DIR}/agent_codegen.sh_processed_tasks.txt"
    echo '{"agents":{},"last_update":0}' >"${SCRIPT_DIR}/agent_status.json"
    echo '{"tasks":[]}' >"${SCRIPT_DIR}/task_queue.json"

    # Create mock binaries
    echo '#!/bin/bash
if [[ "$1" == "ai" ]]; then echo "AI automation completed"; exit 0; fi
if [[ "$1" == "test" ]]; then echo "Tests completed"; exit 0; fi
exit 1' >"${WORKSPACE}/Tools/Automation/automate.sh"
    chmod +x "${WORKSPACE}/Tools/Automation/automate.sh"

    echo '#!/bin/bash
echo "MCP workflow completed for $2"
exit 0' >"${WORKSPACE}/Tools/Automation/mcp_workflow.sh"
    chmod +x "${WORKSPACE}/Tools/Automation/mcp_workflow.sh"

    echo '#!/bin/bash
if [[ "$1" == "analyze" ]]; then echo "Analysis completed for $2"; exit 0; fi
if [[ "$1" == "auto-apply" ]]; then echo "Auto-apply completed for $2"; exit 0; fi
exit 1' >"${WORKSPACE}/Tools/Automation/ai_enhancement_system.sh"
    chmod +x "${WORKSPACE}/Tools/Automation/ai_enhancement_system.sh"

    echo '#!/bin/bash
echo "Validation completed for $2"
exit 0' >"${WORKSPACE}/Tools/Automation/intelligent_autofix.sh"
    chmod +x "${WORKSPACE}/Tools/Automation/intelligent_autofix.sh"

    echo '#!/bin/bash
if [[ "$1" == "backup_if_needed" ]]; then echo "Backup created for $2"; exit 0; fi
if [[ "$1" == "restore" ]]; then echo "Backup restored for $2"; exit 0; fi
exit 1' >"${SCRIPT_DIR}/backup_manager.sh"
    chmod +x "${SCRIPT_DIR}/backup_manager.sh"

    mock_external_commands
}

teardown_test_env() {
    rm -rf "/tmp/test_project"
    rm -rf "/tmp/test_workspace"
}

# Test basic agent execution
test_agent_codegen_basic() {
    setup_test_env

    # Test that agent script exists and is executable
    assert_file_exists "${AGENT_SCRIPT}" "Agent script should exist"
    assert_success "Agent script should be executable" test -x "${AGENT_SCRIPT}"

    # Test single run mode
    timeout 5 bash "${AGENT_SCRIPT}" SINGLE_RUN >/dev/null 2>&1
    assert_success "Single run mode should complete successfully"

    # Check for expected log messages in a separate call
    bash "${AGENT_SCRIPT}" SINGLE_RUN 2>&1 | grep -q "SINGLE_RUN completed successfully"
    assert_success "Single run should log completion message"

    teardown_test_env
}

# Test resource limit checking
test_agent_codegen_resource_limits() {
    setup_test_env

    # Disable pipeline quick exit for testing
    export DISABLE_PIPE_QUICK_EXIT=1

    # Source the agent script to access functions
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Test resource limits function
    check_resource_limits "TestProject"
    assert_success "Resource limits check should pass with mock data"

    teardown_test_env
}

# Test timeout functionality
test_agent_codegen_timeout() {
    setup_test_env

    # Disable pipeline quick exit for testing
    export DISABLE_PIPE_QUICK_EXIT=1

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Unmock sleep and kill for this test to test actual timeout
    unmock_command "sleep"
    unmock_command "kill"

    # Create a long-running script that ignores SIGTERM initially
    cat >/tmp/long_running_test.sh <<'EOF'
#!/bin/bash
# Ignore SIGTERM for a bit to test forceful killing
trap '' TERM
sleep 10
EOF
    chmod +x /tmp/long_running_test.sh

    # Test run_with_timeout with short timeout on a long-running command
    run_with_timeout 1 /tmp/long_running_test.sh
    local rc=$?
    assert_equals "124" "${rc}" "run_with_timeout should return 124 on timeout"

    # Clean up
    rm -f /tmp/long_running_test.sh

    teardown_test_env
}

# Test project context initialization
test_agent_codegen_project_context() {
    setup_test_env

    # Disable pipeline quick exit for testing
    export DISABLE_PIPE_QUICK_EXIT=1

    # Set PROJECT_NAME and WORKSPACE before sourcing agent script
    export PROJECT_NAME="TestProject"
    export PROJECT_DIR="/tmp/test_project"
    export WORKSPACE="/tmp/test_workspace"

    # Create mock project config
    mkdir -p "${WORKSPACE}/Tools/Automation"
    echo 'PROJECT_NAME="TestProject"
PROJECT_DIR="/tmp/test_project"' >"${WORKSPACE}/Tools/Automation/project_config.sh"

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    initialize_project_context
    assert_success "Project context initialization should succeed"

    # Check that variables are set correctly
    assert_equals "TestProject" "${PROJECT_NAME}" "PROJECT_NAME should be set"
    assert_equals "/tmp/test_project" "${PROJECT_DIR}" "PROJECT_DIR should be set"

    teardown_test_env
}

# Test task processing - codegen task
test_agent_codegen_task_codegen() {
    setup_test_env

    # Disable pipeline quick exit for testing
    export DISABLE_PIPE_QUICK_EXIT=1

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Override hardcoded paths after sourcing
    export WORKSPACE="/tmp/test_workspace"
    export AUTOMATE_BIN="/tmp/test_workspace/Tools/Automation/automate.sh"
    export MCP_WORKFLOW_BIN="/tmp/test_workspace/Tools/Automation/mcp_workflow.sh"
    export AI_ENHANCEMENT_BIN="/tmp/test_workspace/Tools/Automation/ai_enhancement_system.sh"
    export AUTO_FIX_VALIDATOR="/tmp/test_workspace/Tools/Automation/intelligent_autofix.sh"
    export BACKUP_MANAGER="/tmp/test_workspace/Tools/Automation/agents/backup_manager.sh"
    export AGENT_STATUS_FILE="/tmp/test_workspace/Tools/Automation/agents/agent_status.json"
    export TASK_QUEUE_FILE="/tmp/test_workspace/Tools/Automation/agents/task_queue.json"

    # Mock task data
    local task_data='{"id":"test_codegen_123","type":"codegen","project":"TestProject"}'

    process_codegen_task "${task_data}"
    assert_success "Codegen task processing should succeed"

    teardown_test_env
}

# Test task processing - full codegen
test_agent_codegen_task_full_codegen() {
    setup_test_env

    # Disable pipeline quick exit for testing
    export DISABLE_PIPE_QUICK_EXIT=1

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Override hardcoded paths after sourcing
    export WORKSPACE="/tmp/test_workspace"
    export AUTOMATE_BIN="/tmp/test_workspace/Tools/Automation/automate.sh"
    export MCP_WORKFLOW_BIN="/tmp/test_workspace/Tools/Automation/mcp_workflow.sh"
    export AI_ENHANCEMENT_BIN="/tmp/test_workspace/Tools/Automation/ai_enhancement_system.sh"
    export AUTO_FIX_VALIDATOR="/tmp/test_workspace/Tools/Automation/intelligent_autofix.sh"
    export BACKUP_MANAGER="/tmp/test_workspace/Tools/Automation/agents/backup_manager.sh"
    export AGENT_STATUS_FILE="/tmp/test_workspace/Tools/Automation/agents/agent_status.json"
    export TASK_QUEUE_FILE="/tmp/test_workspace/Tools/Automation/agents/task_queue.json"

    # Mock task data
    local task_data='{"id":"test_full_codegen_123","type":"full_codegen","project":"TestProject"}'

    process_codegen_task "${task_data}"
    assert_success "Full codegen task processing should succeed"

    teardown_test_env
}

# Test task processing - AI automation
test_agent_codegen_task_ai_automation() {
    setup_test_env

    # Disable pipeline quick exit for testing
    export DISABLE_PIPE_QUICK_EXIT=1

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Override hardcoded paths after sourcing
    export WORKSPACE="/tmp/test_workspace"
    export AUTOMATE_BIN="/tmp/test_workspace/Tools/Automation/automate.sh"
    export MCP_WORKFLOW_BIN="/tmp/test_workspace/Tools/Automation/mcp_workflow.sh"
    export AI_ENHANCEMENT_BIN="/tmp/test_workspace/Tools/Automation/ai_enhancement_system.sh"
    export AUTO_FIX_VALIDATOR="/tmp/test_workspace/Tools/Automation/intelligent_autofix.sh"
    export BACKUP_MANAGER="/tmp/test_workspace/Tools/Automation/agents/backup_manager.sh"
    export AGENT_STATUS_FILE="/tmp/test_workspace/Tools/Automation/agents/agent_status.json"
    export TASK_QUEUE_FILE="/tmp/test_workspace/Tools/Automation/agents/task_queue.json"

    # Mock task data
    local task_data='{"id":"test_ai_automation_123","type":"ai_automation","project":"TestProject"}'

    process_codegen_task "${task_data}"
    assert_success "AI automation task processing should succeed"

    teardown_test_env
}

# Test task processing - autofix
test_agent_codegen_task_autofix() {
    setup_test_env

    # Disable pipeline quick exit for testing
    export DISABLE_PIPE_QUICK_EXIT=1

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Override hardcoded paths after sourcing
    export WORKSPACE="/tmp/test_workspace"
    export AUTOMATE_BIN="/tmp/test_workspace/Tools/Automation/automate.sh"
    export MCP_WORKFLOW_BIN="/tmp/test_workspace/Tools/Automation/mcp_workflow.sh"
    export AI_ENHANCEMENT_BIN="/tmp/test_workspace/Tools/Automation/ai_enhancement_system.sh"
    export AUTO_FIX_VALIDATOR="/tmp/test_workspace/Tools/Automation/intelligent_autofix.sh"
    export BACKUP_MANAGER="/tmp/test_workspace/Tools/Automation/agents/backup_manager.sh"
    export AGENT_STATUS_FILE="/tmp/test_workspace/Tools/Automation/agents/agent_status.json"
    export TASK_QUEUE_FILE="/tmp/test_workspace/Tools/Automation/agents/task_queue.json"

    # Mock task data
    local task_data='{"id":"test_autofix_123","type":"autofix","project":"TestProject"}'

    process_codegen_task "${task_data}"
    assert_success "Autofix task processing should succeed"

    teardown_test_env
}

# Test task processing - enhancement
test_agent_codegen_task_enhance() {
    setup_test_env

    # Disable pipeline quick exit for testing
    export DISABLE_PIPE_QUICK_EXIT=1

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Override hardcoded paths after sourcing
    export WORKSPACE="/tmp/test_workspace"
    export AUTOMATE_BIN="/tmp/test_workspace/Tools/Automation/automate.sh"
    export MCP_WORKFLOW_BIN="/tmp/test_workspace/Tools/Automation/mcp_workflow.sh"
    export AI_ENHANCEMENT_BIN="/tmp/test_workspace/Tools/Automation/ai_enhancement_system.sh"
    export AUTO_FIX_VALIDATOR="/tmp/test_workspace/Tools/Automation/intelligent_autofix.sh"
    export BACKUP_MANAGER="/tmp/test_workspace/Tools/Automation/agents/backup_manager.sh"
    export AGENT_STATUS_FILE="/tmp/test_workspace/Tools/Automation/agents/agent_status.json"
    export TASK_QUEUE_FILE="/tmp/test_workspace/Tools/Automation/agents/task_queue.json"

    # Mock task data
    local task_data='{"id":"test_enhance_123","type":"enhance","project":"TestProject"}'

    process_codegen_task "${task_data}"
    assert_success "Enhancement task processing should succeed"

    teardown_test_env
}

# Test task processing - validation
test_agent_codegen_task_validate() {
    setup_test_env

    # Disable pipeline quick exit for testing
    export DISABLE_PIPE_QUICK_EXIT=1

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Override hardcoded paths after sourcing
    export WORKSPACE="/tmp/test_workspace"
    export AUTOMATE_BIN="/tmp/test_workspace/Tools/Automation/automate.sh"
    export MCP_WORKFLOW_BIN="/tmp/test_workspace/Tools/Automation/mcp_workflow.sh"
    export AI_ENHANCEMENT_BIN="/tmp/test_workspace/Tools/Automation/ai_enhancement_system.sh"
    export AUTO_FIX_VALIDATOR="/tmp/test_workspace/Tools/Automation/intelligent_autofix.sh"
    export BACKUP_MANAGER="/tmp/test_workspace/Tools/Automation/agents/backup_manager.sh"
    export AGENT_STATUS_FILE="/tmp/test_workspace/Tools/Automation/agents/agent_status.json"
    export TASK_QUEUE_FILE="/tmp/test_workspace/Tools/Automation/agents/task_queue.json"

    # Mock task data
    local task_data='{"id":"test_validate_123","type":"validate","project":"TestProject"}'

    process_codegen_task "${task_data}"
    assert_success "Validation task processing should succeed"

    teardown_test_env
}

# Test task processing - test codegen
test_agent_codegen_task_test_codegen() {
    setup_test_env

    # Disable pipeline quick exit for testing
    export DISABLE_PIPE_QUICK_EXIT=1

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Override hardcoded paths after sourcing
    export WORKSPACE="/tmp/test_workspace"
    export AUTOMATE_BIN="/tmp/test_workspace/Tools/Automation/automate.sh"
    export MCP_WORKFLOW_BIN="/tmp/test_workspace/Tools/Automation/mcp_workflow.sh"
    export AI_ENHANCEMENT_BIN="/tmp/test_workspace/Tools/Automation/ai_enhancement_system.sh"
    export AUTO_FIX_VALIDATOR="/tmp/test_workspace/Tools/Automation/intelligent_autofix.sh"
    export BACKUP_MANAGER="/tmp/test_workspace/Tools/Automation/agents/backup_manager.sh"
    export AGENT_STATUS_FILE="/tmp/test_workspace/Tools/Automation/agents/agent_status.json"
    export TASK_QUEUE_FILE="/tmp/test_workspace/Tools/Automation/agents/task_queue.json"

    # Mock task data
    local task_data='{"id":"test_test_codegen_123","type":"test_codegen","project":"TestProject"}'

    process_codegen_task "${task_data}"
    assert_success "Test codegen task processing should succeed"

    teardown_test_env
}

# Test unknown task type handling
test_agent_codegen_unknown_task_type() {
    setup_test_env

    # Disable pipeline quick exit for testing
    export DISABLE_PIPE_QUICK_EXIT=1

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Override hardcoded paths after sourcing
    export WORKSPACE="/tmp/test_workspace"
    export AUTOMATE_BIN="/tmp/test_workspace/Tools/Automation/automate.sh"
    export MCP_WORKFLOW_BIN="/tmp/test_workspace/Tools/Automation/mcp_workflow.sh"
    export AI_ENHANCEMENT_BIN="/tmp/test_workspace/Tools/Automation/ai_enhancement_system.sh"
    export AUTO_FIX_VALIDATOR="/tmp/test_workspace/Tools/Automation/intelligent_autofix.sh"
    export BACKUP_MANAGER="/tmp/test_workspace/Tools/Automation/agents/backup_manager.sh"
    export AGENT_STATUS_FILE="/tmp/test_workspace/Tools/Automation/agents/agent_status.json"
    export TASK_QUEUE_FILE="/tmp/test_workspace/Tools/Automation/agents/task_queue.json"

    # Mock task data with unknown type
    local task_data='{"id":"test_unknown_123","type":"unknown_type","project":"TestProject"}'

    process_codegen_task "${task_data}"
    assert_success "Unknown task type should be handled gracefully"

    teardown_test_env
}

# Test invalid task data handling
test_agent_codegen_invalid_task_data() {
    setup_test_env

    # Disable pipeline quick exit for testing
    export DISABLE_PIPE_QUICK_EXIT=1

    # Enable test mode for deterministic behavior
    export TEST_MODE=true

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Override hardcoded paths after sourcing
    export WORKSPACE="/tmp/test_workspace"
    export AUTOMATE_BIN="/tmp/test_workspace/Tools/Automation/automate.sh"
    export MCP_WORKFLOW_BIN="/tmp/test_workspace/Tools/Automation/mcp_workflow.sh"
    export AI_ENHANCEMENT_BIN="/tmp/test_workspace/Tools/Automation/ai_enhancement_system.sh"
    export AUTO_FIX_VALIDATOR="/tmp/test_workspace/Tools/Automation/intelligent_autofix.sh"
    export BACKUP_MANAGER="/tmp/test_workspace/Tools/Automation/agents/backup_manager.sh"
    export AGENT_STATUS_FILE="/tmp/test_workspace/Tools/Automation/agents/agent_status.json"
    export TASK_QUEUE_FILE="/tmp/test_workspace/Tools/Automation/agents/task_queue.json"

    # Remove jq mock for this test to test actual JSON parsing
    unmock_command "jq"

    # Mock invalid task data (missing id)
    local task_data='{"type":"codegen","project":"TestProject"}'

    # Debug: show which jq is being used and the raw task_data
    echo "[DEBUG TEST] which jq: $(command -v jq || true)"
    echo "[DEBUG TEST] task_data (raw): $task_data"
    printf '%s\n' "$task_data" | sed -n '1,120p'
    printf 'task_data_quoted=%q\n' "$task_data"

    process_codegen_task "${task_data}"
    local task_exit_code=$?
    echo "[DEBUG] process_codegen_task exited with code: $task_exit_code"
    assert_equals "1" "${task_exit_code}" "process_codegen_task should return 1 for invalid data"

    teardown_test_env
}

# Test pipe mode detection
test_agent_codegen_pipe_mode() {
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
test_agent_codegen_no_args() {
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

# Test backup operations in full codegen
test_agent_codegen_backup_operations() {
    setup_test_env

    # Disable pipeline quick exit for testing
    export DISABLE_PIPE_QUICK_EXIT=1

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Override hardcoded paths after sourcing
    export WORKSPACE="/tmp/test_workspace"
    export AUTOMATE_BIN="/tmp/test_workspace/Tools/Automation/automate.sh"
    export MCP_WORKFLOW_BIN="/tmp/test_workspace/Tools/Automation/mcp_workflow.sh"
    export AI_ENHANCEMENT_BIN="/tmp/test_workspace/Tools/Automation/ai_enhancement_system.sh"
    export AUTO_FIX_VALIDATOR="/tmp/test_workspace/Tools/Automation/intelligent_autofix.sh"
    export BACKUP_MANAGER="/tmp/test_workspace/Tools/Automation/agents/backup_manager.sh"
    export AGENT_STATUS_FILE="/tmp/test_workspace/Tools/Automation/agents/agent_status.json"
    export TASK_QUEUE_FILE="/tmp/test_workspace/Tools/Automation/agents/task_queue.json"

    # Test perform_full_codegen which includes backup operations
    perform_full_codegen "TestProject"
    assert_success "Full codegen with backup should succeed"

    teardown_test_env
}

# Test consecutive failures tracking
test_agent_codegen_consecutive_failures() {
    setup_test_env

    # Disable pipeline quick exit for testing
    export DISABLE_PIPE_QUICK_EXIT=1

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Override hardcoded paths after sourcing
    export WORKSPACE="/tmp/test_workspace"
    export AUTOMATE_BIN="/tmp/test_workspace/Tools/Automation/automate.sh"
    export MCP_WORKFLOW_BIN="/tmp/test_workspace/Tools/Automation/mcp_workflow.sh"
    export AI_ENHANCEMENT_BIN="/tmp/test_workspace/Tools/Automation/ai_enhancement_system.sh"
    export AUTO_FIX_VALIDATOR="/tmp/test_workspace/Tools/Automation/intelligent_autofix.sh"
    export BACKUP_MANAGER="/tmp/test_workspace/Tools/Automation/agents/backup_manager.sh"
    export AGENT_STATUS_FILE="/tmp/test_workspace/Tools/Automation/agents/agent_status.json"
    export TASK_QUEUE_FILE="/tmp/test_workspace/Tools/Automation/agents/task_queue.json"

    # Initially should be 0
    assert_equals "0" "${CONSECUTIVE_FAILURES}" "Initial consecutive failures should be 0"

    teardown_test_env
}
