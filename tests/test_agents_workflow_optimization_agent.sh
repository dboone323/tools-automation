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

AGENT_NAME="test_agents_workflow_optimization_agent.sh"
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
# Test suite for workflow_optimization_agent.sh
# Tests workflow optimization functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/workflow_optimization_agent.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Testing workflow_optimization_agent.sh..."

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Should define SCRIPT_DIR variable
test_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

# Test 3: Should define OLLAMA_CLIENT variable
test_defines_ollama_client() {
    assert_pattern_in_file "OLLAMA_CLIENT=" "${AGENT_SCRIPT}"
}

# Test 4: Should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_SCRIPT}"
}

# Test 5: Should define AGENT_NAME variable
test_defines_agent_name() {
    assert_pattern_in_file "AGENT_NAME=" "${AGENT_SCRIPT}"
}

# Test 6: Should define LOG_FILE variable
test_defines_log_file() {
    assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"
}

# Test 7: Should define WORKSPACE_ROOT variable
test_defines_workspace_root() {
    assert_pattern_in_file "WORKSPACE_ROOT=" "${AGENT_SCRIPT}"
}

# Test 8: Should define TODO_FILE variable
test_defines_todo_file() {
    assert_pattern_in_file "TODO_FILE=" "${AGENT_SCRIPT}"
}

# Test 9: Should define analysis interval variables
test_defines_intervals() {
    assert_pattern_in_file "MANUAL_PROCESS_CHECK_INTERVAL=" "${AGENT_SCRIPT}"
    assert_pattern_in_file "CICD_CHECK_INTERVAL=" "${AGENT_SCRIPT}"
    assert_pattern_in_file "REDUNDANCY_CHECK_INTERVAL=" "${AGENT_SCRIPT}"
}

# Test 10: Should define threshold variables
test_defines_thresholds() {
    assert_pattern_in_file "MIN_AUTOMATION_RATIO=" "${AGENT_SCRIPT}"
    assert_pattern_in_file "MAX_CICD_STEPS=" "${AGENT_SCRIPT}"
    assert_pattern_in_file "DUPLICATE_CODE_THRESHOLD=" "${AGENT_SCRIPT}"
}

# Test 11: Should define log_message function
test_defines_log_message() {
    assert_pattern_in_file "log_message\(\)" "${AGENT_SCRIPT}"
}

# Test 12: Should define create_todo function
test_defines_create_todo() {
    assert_pattern_in_file "create_todo\(\)" "${AGENT_SCRIPT}"
}

# Test 13: Should define identify_manual_processes function
test_defines_identify_manual_processes() {
    assert_pattern_in_file "identify_manual_processes\(\)" "${AGENT_SCRIPT}"
}

# Test 14: Should define analyze_cicd_pipelines function
test_defines_analyze_cicd_pipelines() {
    assert_pattern_in_file "analyze_cicd_pipelines\(\)" "${AGENT_SCRIPT}"
}

# Test 15: Should define detect_redundancy function
test_defines_detect_redundancy() {
    assert_pattern_in_file "detect_redundancy\(\)" "${AGENT_SCRIPT}"
}

# Test 16: Should define run_ai_workflow_analysis function
test_defines_run_ai_workflow_analysis() {
    assert_pattern_in_file "run_ai_workflow_analysis\(\)" "${AGENT_SCRIPT}"
}

# Test 17: Should have main agent loop
test_has_main_loop() {
    assert_pattern_in_file "while true; do" "${AGENT_SCRIPT}"
}

# Test 18: Should check manual processes in loop
test_checks_manual_processes() {
    assert_pattern_in_file "identify_manual_processes" "${AGENT_SCRIPT}"
}

# Test 19: Should analyze CI/CD pipelines in loop
test_analyzes_cicd_pipelines() {
    assert_pattern_in_file "analyze_cicd_pipelines" "${AGENT_SCRIPT}"
}

# Test 20: Should detect redundancy in loop
test_detects_redundancy() {
    assert_pattern_in_file "detect_redundancy" "${AGENT_SCRIPT}"
}

# Run all tests
run_tests() {
    local test_count=0
    local pass_count=0
    local fail_count=0

    # Array of test functions
    local tests=(
        test_script_executable
        test_defines_script_dir
        test_defines_ollama_client
        test_sources_shared_functions
        test_defines_agent_name
        test_defines_log_file
        test_defines_workspace_root
        test_defines_todo_file
        test_defines_intervals
        test_defines_thresholds
        test_defines_log_message
        test_defines_create_todo
        test_defines_identify_manual_processes
        test_defines_analyze_cicd_pipelines
        test_defines_detect_redundancy
        test_defines_run_ai_workflow_analysis
        test_has_main_loop
        test_checks_manual_processes
        test_analyzes_cicd_pipelines
        test_detects_redundancy
    )

    echo "Running ${#tests[@]} tests for workflow_optimization_agent.sh..."
    echo

    for test_func in "${tests[@]}"; do
        test_count=$((test_count + 1))
        echo -n "Test $test_count: $test_func... "

        if $test_func; then
            echo -e "${GREEN}PASS${NC}"
            pass_count=$((pass_count + 1))
        else
            echo -e "${RED}FAIL${NC}"
            fail_count=$((fail_count + 1))
        fi
    done

    echo
    echo "Results: $pass_count passed, $fail_count failed out of $test_count tests"

    # Save results
    local result_file="${TEST_RESULTS_DIR}/test_workflow_optimization_agent_results.txt"
    {
        echo "workflow_optimization_agent.sh Test Results"
        echo "Generated: $(date)"
        echo "Tests run: $test_count"
        echo "Passed: $pass_count"
        echo "Failed: $fail_count"
        echo "Success rate: $((pass_count * 100 / test_count))%"
    } >"$result_file"

    if [[ $fail_count -eq 0 ]]; then
        echo -e "${GREEN}✅ All tests passed!${NC}"
        return 0
    else
        echo -e "${RED}❌ $fail_count tests failed${NC}"
        return 1
    fi
}

# Run the tests
run_tests
