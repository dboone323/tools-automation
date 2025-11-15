#!/usr/bin/env bash
        # Auto-injected health & reliability shim

        DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer shared helpers when available
if [[ -f "$DIR/shared_functions.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/shared_functions.sh"
fi

if [[ -f "$DIR/agent_helpers.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/agent_helpers.sh"
fi

set -euo pipefail

AGENT_NAME="test_agents_audit_agent.sh"
LOG_FILE="${LOG_FILE:-$DIR/${AGENT_NAME}.log}"
PID=$$

if type update_agent_status >/dev/null 2>&1; then
  trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; exit 0' SIGTERM SIGINT
else
  trap 'exit 0' SIGTERM SIGINT
fi

if [[ "${1-}" == "--health" || "${1-}" == "health" || "${1-}" == "-h" ]]; then
  if type agent_health_check >/dev/null 2>&1; then
    agent_health_check
    exit $?
  fi
  issues=()
  if [[ ! -w "/tmp" ]]; then
    issues+=("tmp_not_writable")
  fi
  if [[ ! -d "$DIR" ]]; then
    issues+=("cwd_missing")
  fi
  if [[ ${#issues[@]} -gt 0 ]]; then
    printf '{"ok":false,"issues":["%s"]}\n' "${issues[*]}"
    exit 2
  fi
  printf '{"ok":true}\n'
  exit 0
fi

# Original agent script continues below
#!/bin/bash
# Test suite for audit_agent.sh
# This test suite validates the audit trail agent functionality

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shell_test_framework.sh
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/audit_agent.sh"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Script should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"
}

# Test 3: Script should define MAX_CONCURRENCY variable
test_defines_max_concurrency() {
    assert_pattern_in_file "MAX_CONCURRENCY=" "${AGENT_SCRIPT}"
}

# Test 4: Script should define LOAD_THRESHOLD variable
test_defines_load_threshold() {
    assert_pattern_in_file "LOAD_THRESHOLD=" "${AGENT_SCRIPT}"
}

# Test 5: Script should define WAIT_WHEN_BUSY variable
test_defines_wait_when_busy() {
    assert_pattern_in_file "WAIT_WHEN_BUSY=" "${AGENT_SCRIPT}"
}

# Test 6: Script should have ensure_within_limits function
test_has_ensure_within_limits_function() {
    assert_pattern_in_file "ensure_within_limits\(\)" "${AGENT_SCRIPT}"
}

# Test 7: Script should define AGENT_NAME variable
test_defines_agent_name() {
    assert_pattern_in_file "AGENT_NAME=" "${AGENT_SCRIPT}"
}

# Test 8: Script should define WORKSPACE variable
test_defines_workspace() {
    assert_pattern_in_file "WORKSPACE=" "${AGENT_SCRIPT}"
}

# Test 9: Script should define LOG_FILE variable
test_defines_log_file() {
    assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"
}

# Test 10: Script should define NOTIFICATION_FILE variable
test_defines_notification_file() {
    assert_pattern_in_file "NOTIFICATION_FILE=" "${AGENT_SCRIPT}"
}

# Test 11: Script should define AGENT_STATUS_FILE variable
test_defines_agent_status_file() {
    assert_pattern_in_file "AGENT_STATUS_FILE=" "${AGENT_SCRIPT}"
}

# Test 12: Script should define TASK_QUEUE_FILE variable
test_defines_task_queue_file() {
    assert_pattern_in_file "TASK_QUEUE_FILE=" "${AGENT_SCRIPT}"
}

# Test 13: Script should define OLLAMA_ENDPOINT variable
test_defines_ollama_endpoint() {
    assert_pattern_in_file "OLLAMA_ENDPOINT=" "${AGENT_SCRIPT}"
}

# Test 14: Script should define AUDIT_LOG_DIR variable
test_defines_audit_log_dir() {
    assert_pattern_in_file "AUDIT_LOG_DIR=" "${AGENT_SCRIPT}"
}

# Test 15: Script should define AUDIT_CONFIG_FILE variable
test_defines_audit_config_file() {
    assert_pattern_in_file "AUDIT_CONFIG_FILE=" "${AGENT_SCRIPT}"
}

# Test 16: Script should have log function
test_has_log_function() {
    assert_pattern_in_file "log\(\)" "${AGENT_SCRIPT}"
}

# Test 17: Script should have ollama_query function
test_has_ollama_query_function() {
    assert_pattern_in_file "ollama_query\(\)" "${AGENT_SCRIPT}"
}

# Test 18: Script should have update_status function
test_has_update_status_function() {
    assert_pattern_in_file "update_status\(\)" "${AGENT_SCRIPT}"
}

# Test 19: Script should have process_task function
test_has_process_task_function() {
    assert_pattern_in_file "process_task\(\)" "${AGENT_SCRIPT}"
}

# Test 20: Script should have update_task_status function
test_has_update_task_status_function() {
    assert_pattern_in_file "update_task_status\(\)" "${AGENT_SCRIPT}"
}

# Run all tests
run_tests() {
    echo "Running tests for audit_agent.sh..."
    echo "Test Results for audit_agent.sh" >"${SCRIPT_DIR}/test_results_audit_agent.txt"
    echo "Generated: $(date)" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: audit_agent.sh is executable"
        echo "✅ Test 1 PASSED: audit_agent.sh is executable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: audit_agent.sh is not executable"
        echo "❌ Test 1 FAILED: audit_agent.sh is not executable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 2: Should source shared_functions.sh
    ((total_tests++))
    if assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Sources shared_functions.sh"
        echo "✅ Test 2 PASSED: Sources shared_functions.sh" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not source shared_functions.sh"
        echo "❌ Test 2 FAILED: Does not source shared_functions.sh" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 3: Should define MAX_CONCURRENCY variable
    ((total_tests++))
    if assert_pattern_in_file "MAX_CONCURRENCY=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Defines MAX_CONCURRENCY variable"
        echo "✅ Test 3 PASSED: Defines MAX_CONCURRENCY variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not define MAX_CONCURRENCY variable"
        echo "❌ Test 3 FAILED: Does not define MAX_CONCURRENCY variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 4: Should define LOAD_THRESHOLD variable
    ((total_tests++))
    if assert_pattern_in_file "LOAD_THRESHOLD=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines LOAD_THRESHOLD variable"
        echo "✅ Test 4 PASSED: Defines LOAD_THRESHOLD variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define LOAD_THRESHOLD variable"
        echo "❌ Test 4 FAILED: Does not define LOAD_THRESHOLD variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 5: Should define WAIT_WHEN_BUSY variable
    ((total_tests++))
    if assert_pattern_in_file "WAIT_WHEN_BUSY=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Defines WAIT_WHEN_BUSY variable"
        echo "✅ Test 5 PASSED: Defines WAIT_WHEN_BUSY variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not define WAIT_WHEN_BUSY variable"
        echo "❌ Test 5 FAILED: Does not define WAIT_WHEN_BUSY variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 6: Should have ensure_within_limits function
    ((total_tests++))
    if assert_pattern_in_file "ensure_within_limits\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Has ensure_within_limits function"
        echo "✅ Test 6 PASSED: Has ensure_within_limits function" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Missing ensure_within_limits function"
        echo "❌ Test 6 FAILED: Missing ensure_within_limits function" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 7: Should define AGENT_NAME variable
    ((total_tests++))
    if assert_pattern_in_file "AGENT_NAME=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Defines AGENT_NAME variable"
        echo "✅ Test 7 PASSED: Defines AGENT_NAME variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not define AGENT_NAME variable"
        echo "❌ Test 7 FAILED: Does not define AGENT_NAME variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 8: Should define WORKSPACE variable
    ((total_tests++))
    if assert_pattern_in_file "WORKSPACE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Defines WORKSPACE variable"
        echo "✅ Test 8 PASSED: Defines WORKSPACE variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Does not define WORKSPACE variable"
        echo "❌ Test 8 FAILED: Does not define WORKSPACE variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 9: Should define LOG_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Defines LOG_FILE variable"
        echo "✅ Test 9 PASSED: Defines LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Does not define LOG_FILE variable"
        echo "❌ Test 9 FAILED: Does not define LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 10: Should define NOTIFICATION_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "NOTIFICATION_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Defines NOTIFICATION_FILE variable"
        echo "✅ Test 10 PASSED: Defines NOTIFICATION_FILE variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not define NOTIFICATION_FILE variable"
        echo "❌ Test 10 FAILED: Does not define NOTIFICATION_FILE variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 11: Should define AGENT_STATUS_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "AGENT_STATUS_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Defines AGENT_STATUS_FILE variable"
        echo "✅ Test 11 PASSED: Defines AGENT_STATUS_FILE variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not define AGENT_STATUS_FILE variable"
        echo "❌ Test 11 FAILED: Does not define AGENT_STATUS_FILE variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 12: Should define TASK_QUEUE_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "TASK_QUEUE_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Defines TASK_QUEUE_FILE variable"
        echo "✅ Test 12 PASSED: Defines TASK_QUEUE_FILE variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not define TASK_QUEUE_FILE variable"
        echo "❌ Test 12 FAILED: Does not define TASK_QUEUE_FILE variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 13: Should define OLLAMA_ENDPOINT variable
    ((total_tests++))
    if assert_pattern_in_file "OLLAMA_ENDPOINT=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Defines OLLAMA_ENDPOINT variable"
        echo "✅ Test 13 PASSED: Defines OLLAMA_ENDPOINT variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not define OLLAMA_ENDPOINT variable"
        echo "❌ Test 13 FAILED: Does not define OLLAMA_ENDPOINT variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 14: Should define AUDIT_LOG_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "AUDIT_LOG_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Defines AUDIT_LOG_DIR variable"
        echo "✅ Test 14 PASSED: Defines AUDIT_LOG_DIR variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not define AUDIT_LOG_DIR variable"
        echo "❌ Test 14 FAILED: Does not define AUDIT_LOG_DIR variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 15: Should define AUDIT_CONFIG_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "AUDIT_CONFIG_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Defines AUDIT_CONFIG_FILE variable"
        echo "✅ Test 15 PASSED: Defines AUDIT_CONFIG_FILE variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not define AUDIT_CONFIG_FILE variable"
        echo "❌ Test 15 FAILED: Does not define AUDIT_CONFIG_FILE variable" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 16: Should have log function
    ((total_tests++))
    if assert_pattern_in_file "log\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Has log function"
        echo "✅ Test 16 PASSED: Has log function" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Missing log function"
        echo "❌ Test 16 FAILED: Missing log function" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 17: Should have ollama_query function
    ((total_tests++))
    if assert_pattern_in_file "ollama_query\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Has ollama_query function"
        echo "✅ Test 17 PASSED: Has ollama_query function" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Missing ollama_query function"
        echo "❌ Test 17 FAILED: Missing ollama_query function" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 18: Should have update_status function
    ((total_tests++))
    if assert_pattern_in_file "update_status\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Has update_status function"
        echo "✅ Test 18 PASSED: Has update_status function" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Missing update_status function"
        echo "❌ Test 18 FAILED: Missing update_status function" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 19: Should have process_task function
    ((total_tests++))
    if assert_pattern_in_file "process_task\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Has process_task function"
        echo "✅ Test 19 PASSED: Has process_task function" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Missing process_task function"
        echo "❌ Test 19 FAILED: Missing process_task function" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Test 20: Should have update_task_status function
    ((total_tests++))
    if assert_pattern_in_file "update_task_status\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Has update_task_status function"
        echo "✅ Test 20 PASSED: Has update_task_status function" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Missing update_task_status function"
        echo "❌ Test 20 FAILED: Missing update_task_status function" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for audit_agent.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_audit_agent.txt"
    fi
}

# Run the tests
run_tests
