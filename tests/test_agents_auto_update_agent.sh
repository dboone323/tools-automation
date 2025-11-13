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

AGENT_NAME="test_agents_auto_update_agent.sh"
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
# Test suite for auto_update_agent.sh
# This test suite validates the auto-update agent functionality

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shell_test_framework.sh
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/auto_update_agent.sh"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Script should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"
}

# Test 3: Script should define AGENT_NAME variable
test_defines_agent_name() {
    assert_pattern_in_file "AGENT_NAME=" "${AGENT_SCRIPT}"
}

# Test 4: Script should define LOG_FILE variable
test_defines_log_file() {
    assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"
}

# Test 5: Script should define NOTIFICATION_FILE variable
test_defines_notification_file() {
    assert_pattern_in_file "NOTIFICATION_FILE=" "${AGENT_SCRIPT}"
}

# Test 6: Script should define COMPLETED_FILE variable
test_defines_completed_file() {
    assert_pattern_in_file "COMPLETED_FILE=" "${AGENT_SCRIPT}"
}

# Test 7: Script should define UPDATE_QUEUE_FILE variable
test_defines_update_queue_file() {
    assert_pattern_in_file "UPDATE_QUEUE_FILE=" "${AGENT_SCRIPT}"
}

# Test 8: Script should define BEST_PRACTICES_FILE variable
test_defines_best_practices_file() {
    assert_pattern_in_file "BEST_PRACTICES_FILE=" "${AGENT_SCRIPT}"
}

# Test 9: Script should define CHECK_INTERVAL variable
test_defines_check_interval() {
    assert_pattern_in_file "CHECK_INTERVAL=" "${AGENT_SCRIPT}"
}

# Test 10: Script should define APPLY_INTERVAL variable
test_defines_apply_interval() {
    assert_pattern_in_file "APPLY_INTERVAL=" "${AGENT_SCRIPT}"
}

# Test 11: Script should define BACKUP_RETENTION variable
test_defines_backup_retention() {
    assert_pattern_in_file "BACKUP_RETENTION=" "${AGENT_SCRIPT}"
}

# Test 12: Script should define risk level variables
test_defines_risk_levels() {
    assert_pattern_in_file "CONSERVATIVE_RISK=" "${AGENT_SCRIPT}"
}

# Test 13: Script should define CURRENT_RISK_LEVEL variable
test_defines_current_risk_level() {
    assert_pattern_in_file "CURRENT_RISK_LEVEL=" "${AGENT_SCRIPT}"
}

# Test 14: Script should have log_message function
test_has_log_message_function() {
    assert_pattern_in_file "log_message\(\)" "${AGENT_SCRIPT}"
}

# Test 15: Script should have notify_completion function
test_has_notify_completion_function() {
    assert_pattern_in_file "notify_completion\(\)" "${AGENT_SCRIPT}"
}

# Test 16: Script should have check_for_updates function
test_has_check_for_updates_function() {
    assert_pattern_in_file "check_for_updates\(\)" "${AGENT_SCRIPT}"
}

# Test 17: Script should have queue_update function
test_has_queue_update_function() {
    assert_pattern_in_file "queue_update\(\)" "${AGENT_SCRIPT}"
}

# Test 18: Script should have apply_updates function
test_has_apply_updates_function() {
    assert_pattern_in_file "apply_updates\(\)" "${AGENT_SCRIPT}"
}

# Test 19: Script should have should_apply_update function
test_has_should_apply_update_function() {
    assert_pattern_in_file "should_apply_update\(\)" "${AGENT_SCRIPT}"
}

# Test 20: Script should have apply_specific_update function
test_has_apply_specific_update_function() {
    assert_pattern_in_file "apply_specific_update\(\)" "${AGENT_SCRIPT}"
}

# Run all tests
run_tests() {
    echo "Running tests for auto_update_agent.sh..."
    echo "Test Results for auto_update_agent.sh" >"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
    echo "Generated: $(date)" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: auto_update_agent.sh is executable"
        echo "✅ Test 1 PASSED: auto_update_agent.sh is executable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: auto_update_agent.sh is not executable"
        echo "❌ Test 1 FAILED: auto_update_agent.sh is not executable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 2: Should source shared_functions.sh
    ((total_tests++))
    if assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Sources shared_functions.sh"
        echo "✅ Test 2 PASSED: Sources shared_functions.sh" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not source shared_functions.sh"
        echo "❌ Test 2 FAILED: Does not source shared_functions.sh" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 3: Should define AGENT_NAME variable
    ((total_tests++))
    if assert_pattern_in_file "AGENT_NAME=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Defines AGENT_NAME variable"
        echo "✅ Test 3 PASSED: Defines AGENT_NAME variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not define AGENT_NAME variable"
        echo "❌ Test 3 FAILED: Does not define AGENT_NAME variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 4: Should define LOG_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines LOG_FILE variable"
        echo "✅ Test 4 PASSED: Defines LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define LOG_FILE variable"
        echo "❌ Test 4 FAILED: Does not define LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 5: Should define NOTIFICATION_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "NOTIFICATION_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Defines NOTIFICATION_FILE variable"
        echo "✅ Test 5 PASSED: Defines NOTIFICATION_FILE variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not define NOTIFICATION_FILE variable"
        echo "❌ Test 5 FAILED: Does not define NOTIFICATION_FILE variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 6: Should define COMPLETED_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "COMPLETED_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Defines COMPLETED_FILE variable"
        echo "✅ Test 6 PASSED: Defines COMPLETED_FILE variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not define COMPLETED_FILE variable"
        echo "❌ Test 6 FAILED: Does not define COMPLETED_FILE variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 7: Should define UPDATE_QUEUE_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "UPDATE_QUEUE_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Defines UPDATE_QUEUE_FILE variable"
        echo "✅ Test 7 PASSED: Defines UPDATE_QUEUE_FILE variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not define UPDATE_QUEUE_FILE variable"
        echo "❌ Test 7 FAILED: Does not define UPDATE_QUEUE_FILE variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 8: Should define BEST_PRACTICES_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "BEST_PRACTICES_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Defines BEST_PRACTICES_FILE variable"
        echo "✅ Test 8 PASSED: Defines BEST_PRACTICES_FILE variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Does not define BEST_PRACTICES_FILE variable"
        echo "❌ Test 8 FAILED: Does not define BEST_PRACTICES_FILE variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 9: Should define CHECK_INTERVAL variable
    ((total_tests++))
    if assert_pattern_in_file "CHECK_INTERVAL=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Defines CHECK_INTERVAL variable"
        echo "✅ Test 9 PASSED: Defines CHECK_INTERVAL variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Does not define CHECK_INTERVAL variable"
        echo "❌ Test 9 FAILED: Does not define CHECK_INTERVAL variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 10: Should define APPLY_INTERVAL variable
    ((total_tests++))
    if assert_pattern_in_file "APPLY_INTERVAL=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Defines APPLY_INTERVAL variable"
        echo "✅ Test 10 PASSED: Defines APPLY_INTERVAL variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not define APPLY_INTERVAL variable"
        echo "❌ Test 10 FAILED: Does not define APPLY_INTERVAL variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 11: Should define BACKUP_RETENTION variable
    ((total_tests++))
    if assert_pattern_in_file "BACKUP_RETENTION=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Defines BACKUP_RETENTION variable"
        echo "✅ Test 11 PASSED: Defines BACKUP_RETENTION variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not define BACKUP_RETENTION variable"
        echo "❌ Test 11 FAILED: Does not define BACKUP_RETENTION variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 12: Should define risk level variables
    ((total_tests++))
    if assert_pattern_in_file "CONSERVATIVE_RISK=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Defines risk level variables"
        echo "✅ Test 12 PASSED: Defines risk level variables" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not define risk level variables"
        echo "❌ Test 12 FAILED: Does not define risk level variables" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 13: Should define CURRENT_RISK_LEVEL variable
    ((total_tests++))
    if assert_pattern_in_file "CURRENT_RISK_LEVEL=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Defines CURRENT_RISK_LEVEL variable"
        echo "✅ Test 13 PASSED: Defines CURRENT_RISK_LEVEL variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not define CURRENT_RISK_LEVEL variable"
        echo "❌ Test 13 FAILED: Does not define CURRENT_RISK_LEVEL variable" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 14: Should have log_message function
    ((total_tests++))
    if assert_pattern_in_file "log_message\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Has log_message function"
        echo "✅ Test 14 PASSED: Has log_message function" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Missing log_message function"
        echo "❌ Test 14 FAILED: Missing log_message function" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 15: Should have notify_completion function
    ((total_tests++))
    if assert_pattern_in_file "notify_completion\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Has notify_completion function"
        echo "✅ Test 15 PASSED: Has notify_completion function" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Missing notify_completion function"
        echo "❌ Test 15 FAILED: Missing notify_completion function" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 16: Should have check_for_updates function
    ((total_tests++))
    if assert_pattern_in_file "check_for_updates\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Has check_for_updates function"
        echo "✅ Test 16 PASSED: Has check_for_updates function" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Missing check_for_updates function"
        echo "❌ Test 16 FAILED: Missing check_for_updates function" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 17: Should have queue_update function
    ((total_tests++))
    if assert_pattern_in_file "queue_update\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Has queue_update function"
        echo "✅ Test 17 PASSED: Has queue_update function" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Missing queue_update function"
        echo "❌ Test 17 FAILED: Missing queue_update function" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 18: Should have apply_updates function
    ((total_tests++))
    if assert_pattern_in_file "apply_updates\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Has apply_updates function"
        echo "✅ Test 18 PASSED: Has apply_updates function" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Missing apply_updates function"
        echo "❌ Test 18 FAILED: Missing apply_updates function" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 19: Should have should_apply_update function
    ((total_tests++))
    if assert_pattern_in_file "should_apply_update\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Has should_apply_update function"
        echo "✅ Test 19 PASSED: Has should_apply_update function" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Missing should_apply_update function"
        echo "❌ Test 19 FAILED: Missing should_apply_update function" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Test 20: Should have apply_specific_update function
    ((total_tests++))
    if assert_pattern_in_file "apply_specific_update\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Has apply_specific_update function"
        echo "✅ Test 20 PASSED: Has apply_specific_update function" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Missing apply_specific_update function"
        echo "❌ Test 20 FAILED: Missing apply_specific_update function" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for auto_update_agent.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_auto_update_agent.txt"
    fi
}

# Run the tests
run_tests
