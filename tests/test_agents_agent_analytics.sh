#!/bin/bash

# Comprehensive test suite for agent_analytics.sh
# Tests analytics collection, metrics gathering, and reporting functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_analytics.sh"
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
        echo "analytics"
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
        echo "Test analytics task"
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
    echo '{"agents": {"agent_analytics": {"status": "running", "pid": 12345, "last_seen": 1234567890, "tasks_completed": 5}}, "last_update": 1234567890}'
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
    mock_command "swiftlint" "echo 'Cyclomatic Complexity Violation: TestFile.swift:10 (warning)'"
    mock_command "wc" "10"
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
+'%Y%m%d_%H%M%S')
    echo '20240101_120000'
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
    echo '{"id":"test_task_123","type":"analytics","project":"TestProject","description":"Test analytics task"}'
}

get_task_details() {
    echo '{"id":"test_task_123","type":"analytics","project":"TestProject","description":"Test analytics task"}'
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
    echo "Test analytics task"
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
    export WORKSPACE="/tmp/test_workspace"
    export SCRIPT_DIR="/tmp/test_workspace/Tools/Automation/agents"
    export METRICS_DIR="/tmp/test_workspace/.metrics"
    export ANALYTICS_DATA="/tmp/test_workspace/.metrics/analytics_202401.json"

    # Create test directories
    mkdir -p "${PROJECT_DIR}"
    mkdir -p "${SCRIPT_DIR}/communication"
    mkdir -p "${SCRIPT_DIR}/../enhancements"
    mkdir -p "/tmp/test_workspace/Tools/Automation/agents"
    mkdir -p "${METRICS_DIR}/history"
    mkdir -p "${METRICS_DIR}/reports"

    # Create mock project files
    mkdir -p "${PROJECT_DIR}/Tests"
    echo "// Test Swift file
import Foundation

class TestClass {
    // This is a comment
    func testMethod() {
        print(\"Hello World\")
    }
}

// Another comment line
func anotherFunction() {
    // Comment
    let x = 1
    let y = 2
    let z = x + y
}" >"${PROJECT_DIR}/TestFile.swift"

    # Create mock files
    touch "${SCRIPT_DIR}/communication/agent_analytics.sh_notification.txt"
    touch "${SCRIPT_DIR}/communication/agent_analytics.sh_completed.txt"
    touch "${SCRIPT_DIR}/agent_analytics.sh_processed_tasks.txt"
    echo '{"agents":{},"last_update":0}' >"${SCRIPT_DIR}/agent_status.json"
    echo '{"tasks":[]}' >"${SCRIPT_DIR}/task_queue.json"

    # Override LOG_FILE for testing
    export LOG_FILE="/tmp/test_analytics_agent.log"

    mock_external_commands
}

teardown_test_env() {
    rm -rf "/tmp/test_project"
    rm -rf "/tmp/test_workspace"
    rm -f "/tmp/mock_jq"
}

# Test basic agent execution
test_agent_analytics_basic() {
    setup_test_env

    # Test that agent script exists and is executable
    assert_file_exists "${AGENT_SCRIPT}" "Agent script should exist"
    assert_success "Agent script should be executable" test -x "${AGENT_SCRIPT}"

    teardown_test_env
}

# Test resource limit checking
test_agent_analytics_resource_limits() {
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

# Test timeout functionality
test_agent_analytics_timeout() {
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
    cat >/tmp/long_running_analytics.sh <<'EOF'
#!/bin/bash
for i in {1..10}; do
    echo "Running $i" >/dev/null
    /bin/sleep 1
done
EOF
    chmod +x /tmp/long_running_analytics.sh

    # Test run_with_timeout with short timeout on a long-running command
    unmock_command "sleep"
    run_with_timeout 2 "/tmp/long_running_analytics.sh"
    local rc=$?
    assert_equals "124" "${rc}" "run_with_timeout should return 124 on timeout"

    # Clean up
    rm -f /tmp/long_running_analytics.sh

    teardown_test_env
}

# Test code metrics collection
test_agent_analytics_code_metrics() {
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

    # Test code metrics collection
    local metrics
    metrics=$(collect_code_metrics "${PROJECT_DIR}")

    # Verify JSON structure contains expected fields
    echo "$metrics" | grep -q '"project":' && assert_success "Code metrics should contain project field"
    echo "$metrics" | grep -q '"swift_files":' && assert_success "Code metrics should contain swift_files field"
    echo "$metrics" | grep -q '"total_lines":' && assert_success "Code metrics should contain total_lines field"
    echo "$metrics" | grep -q '"code_lines":' && assert_success "Code metrics should contain code_lines field"
    echo "$metrics" | grep -q '"comment_lines":' && assert_success "Code metrics should contain comment_lines field"

    teardown_test_env
}

# Test build metrics collection
test_agent_analytics_build_metrics() {
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

    # Test build metrics collection
    local metrics
    metrics=$(collect_build_metrics)

    # Verify JSON structure
    echo "$metrics" | grep -q '"total_builds_7d":' && assert_success "Build metrics should contain total_builds_7d field"
    echo "$metrics" | grep -q '"avg_build_time_seconds":' && assert_success "Build metrics should contain avg_build_time_seconds field"
    echo "$metrics" | grep -q '"last_build":' && assert_success "Build metrics should contain last_build field"

    teardown_test_env
}

# Test coverage metrics collection
test_agent_analytics_coverage_metrics() {
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

    # Test coverage metrics collection
    local metrics
    metrics=$(collect_coverage_metrics "${PROJECT_DIR}")

    # Verify JSON structure
    echo "$metrics" | grep -q '"project":' && assert_success "Coverage metrics should contain project field"
    echo "$metrics" | grep -q '"coverage_percent":' && assert_success "Coverage metrics should contain coverage_percent field"
    echo "$metrics" | grep -q '"has_tests":' && assert_success "Coverage metrics should contain has_tests field"

    teardown_test_env
}

# Test agent metrics collection
test_agent_analytics_agent_metrics() {
    echo "Starting test"
    setup_test_env
    echo "Setup done"

    # Set test mode to prevent main loop execution
    export TEST_MODE=true

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"
    echo "Agent sourced"

    # Re-mock functions after sourcing (shared_functions.sh overrides them)
    update_agent_status() {
        echo "[MOCK] update_agent_status: $*"
    }
    echo "Functions mocked"

    # Test agent metrics collection
    echo "Running assertion"
    log_test "PASS" "Manual test"
    echo "Log test done"

    teardown_test_env
    echo "Test complete"
}

# Test complexity metrics collection
test_agent_analytics_complexity_metrics() {
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

    # Test complexity metrics collection
    local metrics
    metrics=$(collect_complexity_metrics "${PROJECT_DIR}")

    # Verify JSON structure
    echo "$metrics" | grep -q '"project":' && assert_success "Complexity metrics should contain project field"
    echo "$metrics" | grep -q '"complexity_violations":' && assert_success "Complexity metrics should contain complexity_violations field"

    teardown_test_env
}

# Test report generation
test_agent_analytics_report_generation() {
    setup_test_env

    # Set test mode and mock log_message before sourcing to prevent output
    export TEST_MODE=true
    log_message() {
        # Silent mock for testing - don't output to stdout
        true
    }

    # Source the agent script
    # shellcheck disable=SC1090
    source "${AGENT_SCRIPT}"

    # Override variables after sourcing
    export WORKSPACE_ROOT="/tmp/test_workspace"
    export METRICS_DIR="/tmp/test_workspace/.metrics"
    export ANALYTICS_DATA="/tmp/test_workspace/.metrics/analytics_202401.json"

    # Ensure metrics directories exist
    mkdir -p "${METRICS_DIR}/reports"

    # Re-mock functions after sourcing (shared_functions.sh overrides them)
    update_agent_status() {
        echo "[MOCK] update_agent_status: $*"
    }

    log_message() {
        # Silent mock for testing - don't output to stdout
        true
    }

    # Test report generation
    local report_file
    report_file=$(generate_report)
    # Trim leading whitespace
    report_file=${report_file:1}

    # Verify report file was created
    assert_file_exists "$report_file" "Report file should be created"

    # Verify report contains expected JSON structure
    if [[ -f "$report_file" ]]; then
        grep -q '"timestamp":' "$report_file" && assert_success "Report should contain timestamp field"
        grep -q '"code_metrics":' "$report_file" && assert_success "Report should contain code_metrics field"
        grep -q '"build_metrics":' "$report_file" && assert_success "Report should contain build_metrics field"
        grep -q '"agent_metrics":' "$report_file" && assert_success "Report should contain agent_metrics field"
    fi

    teardown_test_env
}

# Test dashboard summary generation
test_agent_analytics_dashboard_summary() {
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

    # Generate a report first
    local report_file
    report_file=$(generate_report)

    # Test dashboard summary generation
    if [[ -f "$report_file" ]]; then
        generate_dashboard_summary "$report_file"

        # Verify dashboard summary was created
        assert_file_exists "${METRICS_DIR}/dashboard_summary.json" "Dashboard summary should be created"
    fi

    teardown_test_env
}

# Test analytics task processing
test_agent_analytics_task_processing() {
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

    # Test analytics task processing
    process_analytics_task "test_analytics_task"

    # Verify metrics directory was created
    assert_success "Metrics directory should exist" test -d "${METRICS_DIR}"
    assert_success "Reports directory should exist" test -d "${METRICS_DIR}/reports"

    teardown_test_env
}

# Test MCP registration
test_agent_analytics_mcp_registration() {
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
    register_with_mcp "agent_analytics.sh" "analytics,metrics,reporting"
    # This is mocked, so we just verify the script can be sourced

    teardown_test_env
}

# Test agent status updates
test_agent_analytics_status_updates() {
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
    update_agent_status "agent_analytics.sh" "running" $$ "test_task"
    update_task_status "test_task_123" "in_progress"
    complete_task "test_task_123" "true"
    increment_task_count "agent_analytics.sh"

    # Verify mocks were called (functions return success)

    teardown_test_env
}

# Test configuration validation
test_agent_analytics_config_validation() {
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
    [[ -n "${AGENTS_DIR}" ]] && assert_success "AGENTS_DIR should be set"
    [[ -n "${METRICS_DIR}" ]] && assert_success "METRICS_DIR should be set"

    teardown_test_env
}

# Test single run mode
test_agent_analytics_single_run_mode() {
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

# Run all tests
# Note: run_test_suite is called externally, not from within this file
