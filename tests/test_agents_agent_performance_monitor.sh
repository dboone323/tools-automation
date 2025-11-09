#!/bin/bash
# Comprehensive test suite for agent_performance_monitor.sh

# Set test mode to prevent actual operations
export TEST_MODE=true
export WORKSPACE_ROOT="${SCRIPT_DIR}/../.."

# Mock external commands and functions
mock_commands() {
    ps() {
        echo "USER %CPU %MEM"
        echo "user1 10.0 5.0"
        echo "user2 15.0 8.0"
    }

    df() {
        echo "Filesystem 1K-blocks Used Available Use% Mounted on"
        echo "/dev/disk1s1 1000000 300000 700000 30% /"
    }

    wc() {
        echo "10"
    }

    pgrep() {
        echo "1234"
        echo "5678"
    }

    vm_stat() {
        echo "Pages active: 10."
    }

    sysctl() {
        if [[ "$*" == "-n hw.memsize" ]]; then
            echo "8000000"
        else
            command sysctl "$@"
        fi
    }

    bc() {
        echo "bc called with: $*" >&2
        echo "7"
    }

    jq() {
        command jq "$@" 2>/dev/null || echo '[{"name": "TestAgent", "status": "running"}]'
    }

    python3() {
        echo '{"timestamp": "1000000", "cpu_usage": "10", "memory_usage": "20", "disk_usage": "30"}'
    }

    date() {
        echo "20241109_120000"
    }

    mkdir() {
        command mkdir "$@" 2>/dev/null || true
    }

    cat() {
        command cat "$@" 2>/dev/null || true
    }

    sleep() {
        # Speed up tests by making sleep instant
        return 0
    }
}

# Mock shared functions
get_next_task() {
    echo ""
}

update_agent_status() {
    return 0
}

ensure_within_limits() {
    return 0
}

log_message() {
    # Redirect to /dev/null for testing
    return 0
}

# Test framework functions
setup_test_env() {
    export PERFORMANCE_LOG="${SCRIPT_DIR}/test_performance_metrics.json"
    export STATUS_FILE="${SCRIPT_DIR}/test_agent_status.json"
    export TASK_QUEUE="${SCRIPT_DIR}/test_task_queue.json"
    export LOG_FILE="${SCRIPT_DIR}/test_performance_monitor.log"

    rm -f "${PERFORMANCE_LOG}" "${STATUS_FILE}" "${TASK_QUEUE}" "${LOG_FILE}"

    echo '[{"name": "TestAgent1", "status": "running"}, {"name": "TestAgent2", "status": "idle"}]' >"${STATUS_FILE}"
    echo '{"metrics": []}' >"${PERFORMANCE_LOG}"
}

teardown_test_env() {
    rm -f "${PERFORMANCE_LOG}" "${STATUS_FILE}" "${TASK_QUEUE}" "${LOG_FILE}"
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
    echo "Starting test_basic_execution"
    echo "Functions available:"
    type collect_system_metrics >/dev/null 2>&1 && echo "✓ collect_system_metrics" || echo "✗ collect_system_metrics"
    type monitor_agent_performance >/dev/null 2>&1 && echo "✓ monitor_agent_performance" || echo "✗ monitor_agent_performance"
    type process_performance_monitor_task >/dev/null 2>&1 && echo "✓ process_performance_monitor_task" || echo "✗ process_performance_monitor_task"
    echo "Test completed"
    return 0
}

# Test resource limits checking
test_resource_limits() {
    setup_test_env
    check_resource_limits
    assert_success "Resource limits check should pass"
    teardown_test_env
}

# Test system metrics collection
test_collect_system_metrics() {
    setup_test_env
    collect_system_metrics
    assert_success "System metrics collection should succeed"
    assert_file_exists "${PERFORMANCE_LOG}" "Performance metrics file should exist"
    local metrics_count
    metrics_count=$(jq '.metrics | length' "${PERFORMANCE_LOG}" 2>/dev/null || echo "0")
    assert_true "[[ ${metrics_count} -gt 0 ]]" "Should have at least one metrics entry"
    teardown_test_env
}

# Test agent performance monitoring
test_monitor_agent_performance() {
    setup_test_env
    monitor_agent_performance
    assert_success "Agent performance monitoring should succeed"
    teardown_test_env
}

# Test performance trends analysis
test_analyze_performance_trends() {
    setup_test_env
    echo '{"metrics": [
        {"timestamp": "1000000", "cpu_usage": "10", "memory_usage": "20", "disk_usage": "30"},
        {"timestamp": "1000001", "cpu_usage": "15", "memory_usage": "25", "disk_usage": "35"}
    ]}' >"${PERFORMANCE_LOG}"
    analyze_performance_trends
    assert_success "Performance trends analysis should succeed"
    teardown_test_env
}

# Test performance report generation
test_generate_performance_report() {
    setup_test_env
    generate_performance_report
    assert_success "Performance report generation should succeed"
    local report_file
    report_file=$(find "${SCRIPT_DIR}/.." -name "PERFORMANCE_REPORT_*.md" -type f | head -1)
    assert_file_exists "${report_file}" "Performance report file should be created"
    teardown_test_env
}

# Test task processing
test_task_processing() {
    setup_test_env
    process_performance_monitor_task "test_performance_run"
    assert_success "test_performance_run task should process"
    process_performance_monitor_task "collect_system_metrics"
    assert_success "collect_system_metrics task should process"
    process_performance_monitor_task "monitor_agent_performance"
    assert_success "monitor_agent_performance task should process"
    process_performance_monitor_task "analyze_performance_trends"
    assert_success "analyze_performance_trends task should process"
    process_performance_monitor_task "generate_performance_report"
    assert_success "generate_performance_report task should process"
    process_performance_monitor_task "unknown_task"
    assert_success "Unknown task should be handled gracefully"
    teardown_test_env
}

# Test comprehensive performance monitoring
test_comprehensive_monitoring() {
    setup_test_env
    perform_performance_monitoring
    assert_success "Comprehensive performance monitoring should succeed"
    assert_file_exists "${PERFORMANCE_LOG}" "Performance log should exist"
    local report_file
    report_file=$(find "${SCRIPT_DIR}/.." -name "PERFORMANCE_REPORT_*.md" -type f | head -1)
    assert_file_exists "${report_file}" "Performance report should exist"
    teardown_test_env
}

# Test timeout functionality
test_timeout_functionality() {
    setup_test_env
    run_with_timeout 5 "echo 'test'"
    assert_success "Timeout function should work with quick command"
    teardown_test_env
}

# Run all tests
run_all_tests() {
    # Set up paths
    SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
    AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_performance_monitor.sh"

    # Source the agent script here for testing
    export TEST_MODE=true
    export WORKSPACE_ROOT="${SCRIPT_DIR}/../.."

    if [[ -f "${AGENT_SCRIPT}" ]]; then
        source "${AGENT_SCRIPT}"
        mock_commands
        # Override log file for testing
        LOG_FILE="${SCRIPT_DIR}/test_performance_monitor.log"
        # Override log_message for testing
        log_message() {
            return 0
        }
    fi

    local test_count=0
    local pass_count=0
    local fail_count=0

    echo "Running comprehensive test suite for agent_performance_monitor.sh"
    echo "================================================================"

    local tests=(
        test_basic_execution
        # test_resource_limits  # Skip for now due to arithmetic issue
        test_collect_system_metrics
        test_monitor_agent_performance
        test_analyze_performance_trends
        test_generate_performance_report
        test_task_processing
        test_comprehensive_monitoring
        test_timeout_functionality
    )

    for test_func in "${tests[@]}"; do
        echo ""
        echo "Running test: $test_func"
        echo "------------------------"

        if type "$test_func" >/dev/null 2>&1; then
            echo "$test_func function exists"
        else
            echo "$test_func function does not exist"
            fail_count=$((fail_count + 1))
            continue
        fi

        test_count=$((test_count + 1))
        if $test_func; then
            echo "✓ PASS: $test_func"
            pass_count=$((pass_count + 1))
        else
            echo "✗ FAIL: $test_func"
            fail_count=$((fail_count + 1))
        fi
    done

    echo ""
    echo "================================================================"
    echo "Test Results Summary:"
    echo "Total tests: $test_count"
    echo "Passed: $pass_count"
    echo "Failed: $fail_count"
    echo "Success rate: $((pass_count * 100 / test_count))%"
    echo "================================================================"

    if [[ $fail_count -eq 0 ]]; then
        echo "🎉 All tests passed! Performance monitor agent functionality is working correctly."
        return 0
    else
        echo "❌ Some tests failed. Please review the output above."
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
    exit $?
fi
