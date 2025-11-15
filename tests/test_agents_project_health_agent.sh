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

AGENT_NAME="test_agents_project_health_agent.sh"
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
# Comprehensive test suite for project_health_agent.sh
# Tests structural validation and core functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/project_health_agent.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing project_health_agent.sh structural validation..."

# Test functions
test_project_health_agent_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

test_project_health_agent_shebang() {
    assert_pattern_in_file "^#!/bin/bash" "${AGENT_SCRIPT}"
}

test_project_health_agent_shared_functions_source() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_SCRIPT}"
}

test_project_health_agent_script_dir_variable() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

test_project_health_agent_agent_name_variable() {
    assert_pattern_in_file "AGENT_NAME=\"project_health_agent.sh\"" "${AGENT_SCRIPT}"
}

test_project_health_agent_log_file_variable() {
    assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"
}

test_project_health_agent_todo_file_variable() {
    assert_pattern_in_file "TODO_FILE=" "${AGENT_SCRIPT}"
}

test_project_health_agent_workspace_root_variable() {
    assert_pattern_in_file "WORKSPACE_ROOT=" "${AGENT_SCRIPT}"
}

test_project_health_agent_ollama_client_variable() {
    assert_pattern_in_file "OLLAMA_CLIENT=" "${AGENT_SCRIPT}"
}

test_project_health_agent_coverage_check_interval_variable() {
    assert_pattern_in_file "COVERAGE_CHECK_INTERVAL=" "${AGENT_SCRIPT}"
}

test_project_health_agent_dependency_check_interval_variable() {
    assert_pattern_in_file "DEPENDENCY_CHECK_INTERVAL=" "${AGENT_SCRIPT}"
}

test_project_health_agent_build_check_interval_variable() {
    assert_pattern_in_file "BUILD_CHECK_INTERVAL=" "${AGENT_SCRIPT}"
}

test_project_health_agent_doc_check_interval_variable() {
    assert_pattern_in_file "DOC_CHECK_INTERVAL=" "${AGENT_SCRIPT}"
}

test_project_health_agent_min_coverage_threshold_variable() {
    assert_pattern_in_file "MIN_COVERAGE_THRESHOLD=" "${AGENT_SCRIPT}"
}

test_project_health_agent_dependency_age_threshold_variable() {
    assert_pattern_in_file "DEPENDENCY_AGE_THRESHOLD=" "${AGENT_SCRIPT}"
}

test_project_health_agent_max_build_failures_variable() {
    assert_pattern_in_file "MAX_BUILD_FAILURES=" "${AGENT_SCRIPT}"
}

test_project_health_agent_log_message_function() {
    assert_pattern_in_file "log_message\(\)" "${AGENT_SCRIPT}"
}

test_project_health_agent_create_todo_function() {
    assert_pattern_in_file "create_todo\(\)" "${AGENT_SCRIPT}"
}

test_project_health_agent_check_test_coverage_function() {
    assert_pattern_in_file "check_test_coverage\(\)" "${AGENT_SCRIPT}"
}

test_project_health_agent_check_dependencies_function() {
    assert_pattern_in_file "check_dependencies\(\)" "${AGENT_SCRIPT}"
}

test_project_health_agent_check_build_failures_function() {
    assert_pattern_in_file "check_build_failures\(\)" "${AGENT_SCRIPT}"
}

test_project_health_agent_check_documentation_function() {
    assert_pattern_in_file "check_documentation\(\)" "${AGENT_SCRIPT}"
}

test_project_health_agent_run_ai_health_analysis_function() {
    assert_pattern_in_file "run_ai_health_analysis\(\)" "${AGENT_SCRIPT}"
}

test_project_health_agent_main_loop() {
    assert_pattern_in_file "while true; do" "${AGENT_SCRIPT}"
}

test_project_health_agent_coverage_check_counter() {
    assert_pattern_in_file "coverage_check_counter" "${AGENT_SCRIPT}"
}

test_project_health_agent_dependency_check_counter() {
    assert_pattern_in_file "dependency_check_counter" "${AGENT_SCRIPT}"
}

test_project_health_agent_build_check_counter() {
    assert_pattern_in_file "build_check_counter" "${AGENT_SCRIPT}"
}

test_project_health_agent_doc_check_counter() {
    assert_pattern_in_file "doc_check_counter" "${AGENT_SCRIPT}"
}

test_project_health_agent_check_test_coverage_call() {
    assert_pattern_in_file "check_test_coverage" "${AGENT_SCRIPT}"
}

test_project_health_agent_check_dependencies_call() {
    assert_pattern_in_file "check_dependencies" "${AGENT_SCRIPT}"
}

test_project_health_agent_check_build_failures_call() {
    assert_pattern_in_file "check_build_failures" "${AGENT_SCRIPT}"
}

test_project_health_agent_check_documentation_call() {
    assert_pattern_in_file "check_documentation" "${AGENT_SCRIPT}"
}

test_project_health_agent_run_ai_health_analysis_call() {
    assert_pattern_in_file "run_ai_health_analysis" "${AGENT_SCRIPT}"
}

test_project_health_agent_log_message_calls() {
    assert_pattern_in_file "log_message.*DEBUG.*Health check cycle completed" "${AGENT_SCRIPT}"
}

test_project_health_agent_sleep_command() {
    assert_pattern_in_file "sleep 60" "${AGENT_SCRIPT}"
}

# Array of all test functions
tests=(
    test_project_health_agent_script_executable
    test_project_health_agent_shebang
    test_project_health_agent_shared_functions_source
    test_project_health_agent_script_dir_variable
    test_project_health_agent_agent_name_variable
    test_project_health_agent_log_file_variable
    test_project_health_agent_todo_file_variable
    test_project_health_agent_workspace_root_variable
    test_project_health_agent_ollama_client_variable
    test_project_health_agent_coverage_check_interval_variable
    test_project_health_agent_dependency_check_interval_variable
    test_project_health_agent_build_check_interval_variable
    test_project_health_agent_doc_check_interval_variable
    test_project_health_agent_min_coverage_threshold_variable
    test_project_health_agent_dependency_age_threshold_variable
    test_project_health_agent_max_build_failures_variable
    test_project_health_agent_log_message_function
    test_project_health_agent_create_todo_function
    test_project_health_agent_check_test_coverage_function
    test_project_health_agent_check_dependencies_function
    test_project_health_agent_check_build_failures_function
    test_project_health_agent_check_documentation_function
    test_project_health_agent_run_ai_health_analysis_function
    test_project_health_agent_main_loop
    test_project_health_agent_coverage_check_counter
    test_project_health_agent_dependency_check_counter
    test_project_health_agent_build_check_counter
    test_project_health_agent_doc_check_counter
    test_project_health_agent_check_test_coverage_call
    test_project_health_agent_check_dependencies_call
    test_project_health_agent_check_build_failures_call
    test_project_health_agent_check_documentation_call
    test_project_health_agent_run_ai_health_analysis_call
    test_project_health_agent_log_message_calls
    test_project_health_agent_sleep_command
)

echo "Running ${#tests[@]} tests for project_health_agent.sh..."

passed=0
failed=0
results=()

for test in "${tests[@]}"; do
    echo -n "Running $test... "
    if $test; then
        echo -e "${GREEN}PASSED${NC}"
        ((passed++))
        results+=("$test: PASSED")
    else
        echo -e "${RED}FAILED${NC}"
        ((failed++))
        results+=("$test: FAILED")
    fi
done

echo ""
echo "project_health_agent.sh Test Results"
echo "=========================="
echo "Total tests: ${#tests[@]}"
echo -e "Passed: ${GREEN}$passed${NC}"
echo -e "Failed: ${RED}$failed${NC}"
echo ""

if [[ $failed -gt 0 ]]; then
    echo "Failed tests:"
    for result in "${results[@]}"; do
        if [[ $result == *": FAILED" ]]; then
            echo -e "${RED}$result${NC}"
        fi
    done
fi

# Save results to file
RESULTS_FILE="${TEST_RESULTS_DIR}/test_project_health_agent_results.txt"
{
    echo "project_health_agent.sh Test Results"
    echo "=========================="
    echo "Total tests: ${#tests[@]}"
    echo "Passed: $passed"
    echo "Failed: $failed"
    echo ""
    echo "Detailed Results:"
    for result in "${results[@]}"; do
        echo "$result"
    done
} >"$RESULTS_FILE"

echo "Results saved to: $RESULTS_FILE"

# Exit with failure if any tests failed
if [[ $failed -gt 0 ]]; then
    exit 1
fi

echo "project_health_agent.sh structural validation complete."
