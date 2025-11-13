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

AGENT_NAME="test_agents_error_learning_agent.sh"
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
# Test Suite for error_learning_agent.sh
# Comprehensive structural validation tests

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shell_test_framework.sh"

AGENT_SCRIPT="$SCRIPT_DIR/../agents/error_learning_agent.sh"

run_tests() {
    echo "Running tests for error_learning_agent.sh..."

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: error_learning_agent.sh is executable"
        echo "✅ Test 1 PASSED: error_learning_agent.sh is executable" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: error_learning_agent.sh is not executable"
        echo "❌ Test 1 FAILED: error_learning_agent.sh is not executable" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 2: Should define SCRIPT_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable"
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable"
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 3: Should define ROOT_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "ROOT_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Defines ROOT_DIR variable"
        echo "✅ Test 3 PASSED: Defines ROOT_DIR variable" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not define ROOT_DIR variable"
        echo "❌ Test 3 FAILED: Does not define ROOT_DIR variable" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 4: Should define PY_RECOGNIZER variable
    ((total_tests++))
    if assert_pattern_in_file "PY_RECOGNIZER=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines PY_RECOGNIZER variable"
        echo "✅ Test 4 PASSED: Defines PY_RECOGNIZER variable" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define PY_RECOGNIZER variable"
        echo "❌ Test 4 FAILED: Does not define PY_RECOGNIZER variable" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 5: Should define PY_UPDATER variable
    ((total_tests++))
    if assert_pattern_in_file "PY_UPDATER=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Defines PY_UPDATER variable"
        echo "✅ Test 5 PASSED: Defines PY_UPDATER variable" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not define PY_UPDATER variable"
        echo "❌ Test 5 FAILED: Does not define PY_UPDATER variable" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 6: Should define usage function
    ((total_tests++))
    if assert_pattern_in_file "usage\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Defines usage function"
        echo "✅ Test 6 PASSED: Defines usage function" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not define usage function"
        echo "❌ Test 6 FAILED: Does not define usage function" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 7: Should define is_error_line function
    ((total_tests++))
    if assert_pattern_in_file "is_error_line\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Defines is_error_line function"
        echo "✅ Test 7 PASSED: Defines is_error_line function" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not define is_error_line function"
        echo "❌ Test 7 FAILED: Does not define is_error_line function" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 8: Should define process_file function
    ((total_tests++))
    if assert_pattern_in_file "process_file\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Defines process_file function"
        echo "✅ Test 8 PASSED: Defines process_file function" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Does not define process_file function"
        echo "❌ Test 8 FAILED: Does not define process_file function" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 9: Should define scan_once function
    ((total_tests++))
    if assert_pattern_in_file "scan_once\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Defines scan_once function"
        echo "✅ Test 9 PASSED: Defines scan_once function" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Does not define scan_once function"
        echo "❌ Test 9 FAILED: Does not define scan_once function" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 10: Should define watch_dir function
    ((total_tests++))
    if assert_pattern_in_file "watch_dir\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Defines watch_dir function"
        echo "✅ Test 10 PASSED: Defines watch_dir function" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not define watch_dir function"
        echo "❌ Test 10 FAILED: Does not define watch_dir function" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 11: Should define main function
    ((total_tests++))
    if assert_pattern_in_file "main\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Defines main function"
        echo "✅ Test 11 PASSED: Defines main function" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not define main function"
        echo "❌ Test 11 FAILED: Does not define main function" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 12: Should have --scan-once option in main
    ((total_tests++))
    if assert_pattern_in_file "scan-once" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Has --scan-once option"
        echo "✅ Test 12 PASSED: Has --scan-once option" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not have --scan-once option"
        echo "❌ Test 12 FAILED: Does not have --scan-once option" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 13: Should have --watch option in main
    ((total_tests++))
    if assert_pattern_in_file "watch" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Has --watch option"
        echo "✅ Test 13 PASSED: Has --watch option" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not have --watch option"
        echo "❌ Test 13 FAILED: Does not have --watch option" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 14: Should have --help option in main
    ((total_tests++))
    if assert_pattern_in_file "help" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Has --help option"
        echo "✅ Test 14 PASSED: Has --help option" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not have --help option"
        echo "❌ Test 14 FAILED: Does not have --help option" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 15: Should have case statement in main
    ((total_tests++))
    if assert_pattern_in_file "case " "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Has case statement in main"
        echo "✅ Test 15 PASSED: Has case statement in main" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not have case statement in main"
        echo "❌ Test 15 FAILED: Does not have case statement in main" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 16: Should have error pattern matching for [ERROR]
    ((total_tests++))
    if assert_pattern_in_file "ERROR" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Has [ERROR] pattern matching"
        echo "✅ Test 16 PASSED: Has [ERROR] pattern matching" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Does not have [ERROR] pattern matching"
        echo "❌ Test 16 FAILED: Does not have [ERROR] pattern matching" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 17: Should have error pattern matching for ❌
    ((total_tests++))
    if assert_pattern_in_file "❌" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Has ❌ pattern matching"
        echo "✅ Test 17 PASSED: Has ❌ pattern matching" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Does not have ❌ pattern matching"
        echo "❌ Test 17 FAILED: Does not have ❌ pattern matching" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 18: Should have error pattern matching for failed
    ((total_tests++))
    if assert_pattern_in_file "\\[Ff\\]ailed" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Has failed pattern matching"
        echo "✅ Test 18 PASSED: Has failed pattern matching" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Does not have failed pattern matching"
        echo "❌ Test 18 FAILED: Does not have failed pattern matching" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 19: Should have Python script calls
    ((total_tests++))
    if assert_pattern_in_file "PY_RECOGNIZER" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Has Python recognizer calls"
        echo "✅ Test 19 PASSED: Has Python recognizer calls" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Does not have Python recognizer calls"
        echo "❌ Test 19 FAILED: Does not have Python recognizer calls" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Test 20: Should have main execution guard
    ((total_tests++))
    if assert_pattern_in_file "BASH_SOURCE" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Has main execution guard"
        echo "✅ Test 20 PASSED: Has main execution guard" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Does not have main execution guard"
        echo "❌ Test 20 FAILED: Does not have main execution guard" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for error_learning_agent.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_error_learning_agent.txt"
    fi
}

# Run the tests
run_tests
