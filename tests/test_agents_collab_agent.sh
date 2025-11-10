#!/bin/bash
# Test suite for collab_agent.sh
# Tests collaboration agent that coordinates all agents and aggregates plans

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/collab_agent.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing collab_agent.sh..."

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

# Test 5: Script should define LOG_FILE variable
test_defines_log_file() {
    assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"
}

# Test 6: Script should define PLANS_DIR variable
test_defines_plans_dir() {
    assert_pattern_in_file "PLANS_DIR=" "${AGENT_SCRIPT}"
}

# Test 7: Script should define SLEEP_INTERVAL variable
test_defines_sleep_interval() {
    assert_pattern_in_file "SLEEP_INTERVAL=" "${AGENT_SCRIPT}"
}

# Test 8: Script should define MIN_INTERVAL variable
test_defines_min_interval() {
    assert_pattern_in_file "MIN_INTERVAL=" "${AGENT_SCRIPT}"
}

# Test 9: Script should define MAX_INTERVAL variable
test_defines_max_interval() {
    assert_pattern_in_file "MAX_INTERVAL=" "${AGENT_SCRIPT}"
}

# Test 10: Script should have main loop with while true
test_has_main_loop() {
    assert_pattern_in_file "while true; do" "${AGENT_SCRIPT}"
}

# Test 11: Script should create PLANS_DIR
test_creates_plans_dir() {
    assert_pattern_in_file "mkdir.*PLANS_DIR" "${AGENT_SCRIPT}"
}

# Test 12: Script should aggregate agent plans
test_aggregates_plans() {
    assert_pattern_in_file "cat.*PLANS_DIR.*plan" "${AGENT_SCRIPT}"
}

# Test 13: Script should call collab_analyze.sh plugin
test_calls_collab_analyze() {
    assert_pattern_in_file "collab_analyze.sh" "${AGENT_SCRIPT}"
}

# Test 14: Script should call auto_generate_knowledge_base.py
test_calls_knowledge_base() {
    assert_pattern_in_file "auto_generate_knowledge_base.py" "${AGENT_SCRIPT}"
}

# Test 15: Script should use dynamic sleep interval
test_uses_dynamic_sleep() {
    assert_pattern_in_file "SLEEP_INTERVAL.*next_sleep" "${AGENT_SCRIPT}"
}

# Test 16: Script should log agent activity
test_logs_activity() {
    assert_pattern_in_file "echo.*AGENT_NAME.*Aggregating" "${AGENT_SCRIPT}"
}

# Test 17: Script should log completion message
test_logs_completion() {
    assert_pattern_in_file "echo.*AGENT_NAME.*complete" "${AGENT_SCRIPT}"
}

# Test 18: Script should log sleep duration
test_logs_sleep_duration() {
    assert_pattern_in_file "printf.*Sleeping for.*seconds" "${AGENT_SCRIPT}"
}

# Test 19: Script should redirect output to log file
test_redirects_output() {
    assert_pattern_in_file ">>.*LOG_FILE" "${AGENT_SCRIPT}"
}

# Test 20: Script should handle sleep interval bounds
test_handles_sleep_bounds() {
    assert_pattern_in_file "if.*next_sleep.*MAX_INTERVAL" "${AGENT_SCRIPT}"
}

# Run all tests
tests=(
    test_script_executable
    test_defines_script_dir
    test_sources_shared_functions
    test_defines_agent_name
    test_defines_log_file
    test_defines_plans_dir
    test_defines_sleep_interval
    test_defines_min_interval
    test_defines_max_interval
    test_has_main_loop
    test_creates_plans_dir
    test_aggregates_plans
    test_calls_collab_analyze
    test_calls_knowledge_base
    test_uses_dynamic_sleep
    test_logs_activity
    test_logs_completion
    test_logs_sleep_duration
    test_redirects_output
    test_handles_sleep_bounds
)

echo "Running ${#tests[@]} tests for collab_agent.sh..."

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
echo "collab_agent.sh Test Results"
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
RESULTS_FILE="${TEST_RESULTS_DIR}/test_collab_agent_results.txt"
{
    echo "collab_agent.sh Test Results"
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
