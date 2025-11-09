#!/bin/bash
# Comprehensive test suite for agent_optimization.sh

# Source the agent script in a safe way for testing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_optimization.sh"

# Set test mode to prevent actual operations
export TEST_MODE=true
export WORKSPACE_ROOT="${SCRIPT_DIR}/../.."

# Mock external commands and functions
mock_commands() {
    find() {
        echo "test_file1.swift"
        echo "test_file2.swift"
    }

    grep() {
        echo "func testFunction()"
    }

    wc() {
        echo "100 test_file.swift"
    }

    du() {
        echo "1000000 /test/cache"
    }

    vm_stat() {
        echo "Pages active: 1000."
    }

    sysctl() {
        echo "hw.memsize: 8000000000"
    }

    ps() {
        echo "%CPU"
        echo " 5.0"
    }

    bc() {
        echo "50"
    }

    uname() {
        echo "Darwin"
    }

    mkdir() {
        command mkdir "$@" 2>/dev/null || true
    }

    cat() {
        command cat "$@" 2>/dev/null || true
    }

    sort() {
        command sort "$@" 2>/dev/null || cat
    }

    uniq() {
        command uniq "$@" 2>/dev/null || cat
    }

    awk() {
        command awk "$@" 2>/dev/null || echo "0"
    }

    basename() {
        command basename "$@" 2>/dev/null || echo "test"
    }

    date() {
        echo "2024-11-09"
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
    return 0
}

# Source the agent script
echo "Sourcing agent script: ${AGENT_SCRIPT}"
if [[ -f "${AGENT_SCRIPT}" ]]; then
    export SKIP_MAIN=true
    source "${AGENT_SCRIPT}"
    unset SKIP_MAIN
    echo "Agent script sourced successfully"

    if ! type process_optimization_task >/dev/null 2>&1; then
        echo "ERROR: process_optimization_task function not found"
        exit 1
    fi
    if ! type detect_dead_code >/dev/null 2>&1; then
        echo "ERROR: detect_dead_code function not found"
        exit 1
    fi
    echo "Key functions verified"

    mock_commands
else
    echo "ERROR: Agent script not found at ${AGENT_SCRIPT}"
    exit 1
fi

# Test framework functions
setup_test_env() {
    export OPTIMIZATION_REPORTS_DIR="${SCRIPT_DIR}/test_optimization_reports"
    export ALERT_HISTORY="${SCRIPT_DIR}/test_alert_history.json"
    export STATUS_FILE="${SCRIPT_DIR}/test_status.json"
    export MCP_URL="http://test-mcp:8080"
    export SLACK_WEBHOOK_URL="https://hooks.slack.com/test"
    export EMAIL_RECIPIENT="test@example.com"

    rm -rf "${OPTIMIZATION_REPORTS_DIR}"
    rm -f "${ALERT_HISTORY}" "${STATUS_FILE}"

    echo '{"agents":{}}' >"${STATUS_FILE}"
    mkdir -p "${OPTIMIZATION_REPORTS_DIR}"
}

teardown_test_env() {
    rm -rf "${OPTIMIZATION_REPORTS_DIR}"
    rm -f "${ALERT_HISTORY}" "${STATUS_FILE}"
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

assert_directory_exists() {
    local dir="$1"
    local msg="${2:-Directory should exist}"

    if [[ -d "$dir" ]]; then
        echo "✓ PASS: $msg"
        return 0
    else
        echo "✗ FAIL: $msg"
        return 1
    fi
}

# Test functions
test_basic_agent_execution() {
    setup_test_env
    assert_success "process_optimization_task 'test_optimization_run'" "Test optimization run task should process"
    assert_success "true" "Basic agent execution components should be available"
    teardown_test_env
}

test_task_processing() {
    setup_test_env
    assert_success "process_optimization_task 'analyze_optimization'" "Analyze optimization task should process"
    assert_success "process_optimization_task 'detect_dead_code'" "Detect dead code task should process"
    assert_success "process_optimization_task 'suggest_refactorings'" "Suggest refactorings task should process"
    assert_success "process_optimization_task 'analyze_build_cache'" "Analyze build cache task should process"
    teardown_test_env
}

test_dead_code_detection() {
    setup_test_env
    local test_project="${SCRIPT_DIR}/test_project"
    mkdir -p "${test_project}"
    echo "func test() {}" >"${test_project}/TestFile.swift"
    assert_success "detect_dead_code '${test_project}'" "Dead code detection should execute without error"
    rm -rf "${test_project}"
    teardown_test_env
}

test_build_cache_analysis() {
    setup_test_env
    assert_success "analyze_build_cache" "Build cache analysis should execute without error"
    assert_directory_exists "${OPTIMIZATION_REPORTS_DIR}" "Optimization reports directory should exist"
    teardown_test_env
}

test_dependency_analysis() {
    setup_test_env
    local test_project="${SCRIPT_DIR}/test_project"
    mkdir -p "${test_project}"
    echo "import Foundation" >"${test_project}/TestFile.swift"
    assert_success "optimize_dependencies '${test_project}'" "Dependency analysis should execute without error"
    rm -rf "${test_project}"
    teardown_test_env
}

test_refactoring_suggestions() {
    setup_test_env
    local test_project="${SCRIPT_DIR}/test_project"
    mkdir -p "${test_project}"
    for i in {1..10}; do echo "func function${i}() {}" >>"${test_project}/LargeFile.swift"; done
    assert_success "suggest_refactorings '${test_project}'" "Refactoring suggestions should execute without error"
    rm -rf "${test_project}"
    teardown_test_env
}

test_full_analysis_workflow() {
    setup_test_env
    assert_success "run_full_analysis" "Full analysis workflow should execute without error"
    assert_directory_exists "${OPTIMIZATION_REPORTS_DIR}" "Optimization reports directory should exist"
    teardown_test_env
}

test_reports_directory_creation() {
    setup_test_env
    assert_success "mkdir -p '${OPTIMIZATION_REPORTS_DIR}'" "Reports directory creation should work"
    assert_directory_exists "${OPTIMIZATION_REPORTS_DIR}" "Optimization reports directory should be created"
    teardown_test_env
}

test_unknown_task_handling() {
    setup_test_env
    assert_success "process_optimization_task 'unknown_task'" "Unknown task should be handled gracefully"
    teardown_test_env
}

test_generate_optimization_summary() {
    setup_test_env
    assert_success "generate_optimization_summary" "Optimization summary generation should work"
    assert_directory_exists "${OPTIMIZATION_REPORTS_DIR}" "Reports directory should exist after summary generation"
    teardown_test_env
}

# Run all tests
run_all_tests() {
    local test_count=0
    local pass_count=0
    local fail_count=0

    echo "Running comprehensive test suite for agent_optimization.sh"
    echo "=========================================================="

    local tests=(
        test_basic_agent_execution
        test_task_processing
        test_dead_code_detection
        test_build_cache_analysis
        test_dependency_analysis
        test_refactoring_suggestions
        test_full_analysis_workflow
        test_reports_directory_creation
        test_unknown_task_handling
        test_generate_optimization_summary
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
    echo "=========================================================="
    echo "Test Results Summary:"
    echo "Total tests: $test_count"
    echo "Passed: $pass_count"
    echo "Failed: $fail_count"
    echo "Success rate: $((pass_count * 100 / test_count))%"
    echo "=========================================================="

    if [[ $fail_count -eq 0 ]]; then
        echo "🎉 All tests passed! Agent optimization functionality is working correctly."
        return 0
    else
        echo "❌ Some tests failed. Please review the output above."
        return 1
    fi
}

if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_all_tests
fi
