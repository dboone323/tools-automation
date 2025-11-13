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

AGENT_NAME="test_agents_code_review_agent.sh"
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
# Test suite for code_review_agent.sh
# Tests AI-powered code analysis and improvement suggestions

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/code_review_agent.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing code_review_agent.sh..."

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Script should define SCRIPT_DIR variable
test_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

# Test 3: Script should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_SCRIPT}"
}

# Test 4: Script should define AGENT_NAME variable
test_defines_agent_name() {
    assert_pattern_in_file "AGENT_NAME=" "${AGENT_SCRIPT}"
}

# Test 5: Script should define WORKSPACE variable
test_defines_workspace() {
    assert_pattern_in_file "WORKSPACE=" "${AGENT_SCRIPT}"
}

# Test 6: Script should define LOG_FILE variable
test_defines_log_file() {
    assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"
}

# Test 7: Script should define NOTIFICATION_FILE variable
test_defines_notification_file() {
    assert_pattern_in_file "NOTIFICATION_FILE=" "${AGENT_SCRIPT}"
}

# Test 8: Script should define AGENT_STATUS_FILE variable
test_defines_agent_status_file() {
    assert_pattern_in_file "AGENT_STATUS_FILE=" "${AGENT_SCRIPT}"
}

# Test 9: Script should define TASK_QUEUE_FILE variable
test_defines_task_queue_file() {
    assert_pattern_in_file "TASK_QUEUE_FILE=" "${AGENT_SCRIPT}"
}

# Test 10: Script should define OLLAMA_ENDPOINT variable
test_defines_ollama_endpoint() {
    assert_pattern_in_file "OLLAMA_ENDPOINT=" "${AGENT_SCRIPT}"
}

# Test 11: Script should have update_status function
test_has_update_status_function() {
    assert_pattern_in_file "update_status\(\)" "${AGENT_SCRIPT}"
}

# Test 12: Script should have process_task function
test_has_process_task_function() {
    assert_pattern_in_file "process_task\(\)" "${AGENT_SCRIPT}"
}

# Test 13: Script should have update_task_status function
test_has_update_task_status_function() {
    assert_pattern_in_file "update_task_status\(\)" "${AGENT_SCRIPT}"
}

# Test 14: Script should have run_code_review function
test_has_run_code_review_function() {
    assert_pattern_in_file "run_code_review\(\)" "${AGENT_SCRIPT}"
}

# Test 15: Script should have generate_automated_fixes function
test_has_generate_automated_fixes_function() {
    assert_pattern_in_file "generate_automated_fixes\(\)" "${AGENT_SCRIPT}"
}

# Test 16: Script should have run_quality_assessment function
test_has_run_quality_assessment_function() {
    assert_pattern_in_file "run_quality_assessment\(\)" "${AGENT_SCRIPT}"
}

# Test 17: Script should have main loop with while true
test_has_main_loop() {
    assert_pattern_in_file "while true; do" "${AGENT_SCRIPT}"
}

# Test 18: Script should use curl for Ollama API calls
test_uses_curl_for_ollama() {
    assert_pattern_in_file "curl.*OLLAMA_ENDPOINT" "${AGENT_SCRIPT}"
}

# Test 19: Script should use jq for JSON processing
test_uses_jq_for_json() {
    assert_pattern_in_file "jq" "${AGENT_SCRIPT}"
}

# Test 20: Script should handle different task types
test_handles_task_types() {
    assert_pattern_in_file "case.*task_type" "${AGENT_SCRIPT}"
}

# Run all tests
tests=(
    test_script_executable
    test_defines_script_dir
    test_sources_shared_functions
    test_defines_agent_name
    test_defines_workspace
    test_defines_log_file
    test_defines_notification_file
    test_defines_agent_status_file
    test_defines_task_queue_file
    test_defines_ollama_endpoint
    test_has_update_status_function
    test_has_process_task_function
    test_has_update_task_status_function
    test_has_run_code_review_function
    test_has_generate_automated_fixes_function
    test_has_run_quality_assessment_function
    test_has_main_loop
    test_uses_curl_for_ollama
    test_uses_jq_for_json
    test_handles_task_types
)

echo "Running ${#tests[@]} tests for code_review_agent.sh..."

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
echo "code_review_agent.sh Test Results"
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
RESULTS_FILE="${TEST_RESULTS_DIR}/test_code_review_agent_results.txt"
{
    echo "code_review_agent.sh Test Results"
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
