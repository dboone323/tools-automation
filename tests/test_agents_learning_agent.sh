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

AGENT_NAME="test_agents_learning_agent.sh"
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
# Comprehensive test suite for learning_agent.sh
# Tests structural validation and core functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/learning_agent.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing learning_agent.sh structural validation..."

# Test 1: Script exists and is executable
test_script_exists_and_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: SCRIPT_DIR variable definition
test_script_dir_variable() {
    assert_pattern_in_file 'SCRIPT_DIR=' "${AGENT_SCRIPT}"
}

# Test 3: AGENT_NAME variable definition
test_agent_name_variable() {
    assert_pattern_in_file 'AGENT_NAME="learning_agent\.sh"' "${AGENT_SCRIPT}"
}

# Test 4: LOG_FILE variable definition
test_log_file_variable() {
    assert_pattern_in_file 'LOG_FILE=' "${AGENT_SCRIPT}"
}

# Test 5: NOTIFICATION_FILE variable definition
test_notification_file_variable() {
    assert_pattern_in_file 'NOTIFICATION_FILE=' "${AGENT_SCRIPT}"
}

# Test 6: AGENT_STATUS_FILE variable definition
test_agent_status_file_variable() {
    assert_pattern_in_file 'AGENT_STATUS_FILE=' "${AGENT_SCRIPT}"
}

# Test 7: TASK_QUEUE_FILE variable definition
test_task_queue_file_variable() {
    assert_pattern_in_file 'TASK_QUEUE_FILE=' "${AGENT_SCRIPT}"
}

# Test 8: update_status function declaration
test_update_status_function() {
    assert_pattern_in_file 'update_status\(\)' "${AGENT_SCRIPT}"
}

# Test 9: process_task function declaration
test_process_task_function() {
    assert_pattern_in_file 'process_task\(\)' "${AGENT_SCRIPT}"
}

# Test 10: update_task_status function declaration
test_update_task_status_function() {
    assert_pattern_in_file 'update_task_status\(\)' "${AGENT_SCRIPT}"
}

# Test 11: run_pattern_analysis function declaration
test_run_pattern_analysis_function() {
    assert_pattern_in_file 'run_pattern_analysis\(\)' "${AGENT_SCRIPT}"
}

# Test 12: jq command checks in update_status
test_jq_usage_in_update_status() {
    assert_pattern_in_file 'command -v jq' "${AGENT_SCRIPT}"
}

# Test 13: jq usage in process_task for task details
test_jq_usage_in_process_task() {
    assert_pattern_in_file 'jq -r' "${AGENT_SCRIPT}"
}

# Test 14: jq usage in update_task_status
test_jq_usage_in_update_task_status() {
    assert_pattern_in_file 'jq ' "${AGENT_SCRIPT}"
}

# Test 15: Case statement for task types
test_case_statement_task_types() {
    assert_pattern_in_file 'case ' "${AGENT_SCRIPT}"
}

# Test 16: Task type patterns (learn|analyze|pattern)
test_task_type_patterns() {
    assert_pattern_in_file 'learn.*analyze.*pattern' "${AGENT_SCRIPT}"
}

# Test 17: Projects array definition
test_projects_array() {
    assert_pattern_in_file 'local projects=' "${AGENT_SCRIPT}"
}

# Test 18: Directory check for projects
test_project_directory_check() {
    assert_pattern_in_file 'if.*-d.*Projects' "${AGENT_SCRIPT}"
}

# Test 19: Swift file pattern matching
test_swift_file_patterns() {
    assert_pattern_in_file 'find.*swift' "${AGENT_SCRIPT}"
}

# Test 20: Main loop with while true
test_main_loop() {
    assert_pattern_in_file 'while true' "${AGENT_SCRIPT}"
}

# Test 21: Notification file processing
test_notification_file_processing() {
    assert_pattern_in_file 'if.*-f.*NOTIFICATION_FILE' "${AGENT_SCRIPT}"
}

# Test 22: Processed tasks associative array
test_processed_tasks_array() {
    assert_pattern_in_file 'declare -A processed_tasks' "${AGENT_SCRIPT}"
}

# Test 23: Sleep interval
test_sleep_interval() {
    assert_pattern_in_file 'sleep 30' "${AGENT_SCRIPT}"
}

# Test 24: Shared functions sourcing
test_shared_functions_source() {
    assert_pattern_in_file 'source.*shared_functions' "${AGENT_SCRIPT}"
}

# Test 25: Log message pattern
test_log_message_pattern() {
    assert_pattern_in_file 'echo.*date.*AGENT_NAME' "${AGENT_SCRIPT}"
}

# Array of all test functions
tests=(
    test_script_exists_and_executable
    test_script_dir_variable
    test_agent_name_variable
    test_log_file_variable
    test_notification_file_variable
    test_agent_status_file_variable
    test_task_queue_file_variable
    test_update_status_function
    test_process_task_function
    test_update_task_status_function
    test_run_pattern_analysis_function
    test_jq_usage_in_update_status
    test_jq_usage_in_process_task
    test_jq_usage_in_update_task_status
    test_case_statement_task_types
    test_task_type_patterns
    test_projects_array
    test_project_directory_check
    test_swift_file_patterns
    test_main_loop
    test_notification_file_processing
    test_processed_tasks_array
    test_sleep_interval
    test_shared_functions_source
    test_log_message_pattern
)

echo "Running ${#tests[@]} tests for learning_agent.sh..."

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
echo "learning_agent.sh Test Results"
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
RESULTS_FILE="${TEST_RESULTS_DIR}/test_learning_agent_results.txt"
{
    echo "learning_agent.sh Test Results"
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

echo "learning_agent.sh structural validation complete."
