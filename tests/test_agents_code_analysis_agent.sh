#!/bin/bash
# Test suite for code_analysis_agent.sh
# Tests code analysis for smells, anti-patterns, error handling, performance, and security

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/code_analysis_agent.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
NC='\033[0m'

echo "Testing code_analysis_agent.sh..."

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

# Test 6: Script should define WORKSPACE_ROOT variable
test_defines_workspace_root() {
    assert_pattern_in_file "WORKSPACE_ROOT=" "${AGENT_SCRIPT}"
}

# Test 7: Script should define TODO_FILE variable
test_defines_todo_file() {
    assert_pattern_in_file "TODO_FILE=" "${AGENT_SCRIPT}"
}

# Test 8: Script should define OLLAMA_CLIENT variable
test_defines_ollama_client() {
    assert_pattern_in_file "OLLAMA_CLIENT=" "${AGENT_SCRIPT}"
}

# Test 9: Script should define CODE_ANALYSIS_INTERVAL variable
test_defines_code_analysis_interval() {
    assert_pattern_in_file "CODE_ANALYSIS_INTERVAL=" "${AGENT_SCRIPT}"
}

# Test 10: Script should define SECURITY_SCAN_INTERVAL variable
test_defines_security_scan_interval() {
    assert_pattern_in_file "SECURITY_SCAN_INTERVAL=" "${AGENT_SCRIPT}"
}

# Test 11: Script should define PERFORMANCE_SCAN_INTERVAL variable
test_defines_performance_scan_interval() {
    assert_pattern_in_file "PERFORMANCE_SCAN_INTERVAL=" "${AGENT_SCRIPT}"
}

# Test 12: Script should define COMPLEXITY_THRESHOLD variable
test_defines_complexity_threshold() {
    assert_pattern_in_file "COMPLEXITY_THRESHOLD=" "${AGENT_SCRIPT}"
}

# Test 13: Script should define FORCE_UNWRAP_LIMIT variable
test_defines_force_unwrap_limit() {
    assert_pattern_in_file "FORCE_UNWRAP_LIMIT=" "${AGENT_SCRIPT}"
}

# Test 14: Script should define PRINT_STATEMENTS_LIMIT variable
test_defines_print_statements_limit() {
    assert_pattern_in_file "PRINT_STATEMENTS_LIMIT=" "${AGENT_SCRIPT}"
}

# Test 15: Script should have log_message function
test_has_log_message_function() {
    assert_pattern_in_file "log_message\(\)" "${AGENT_SCRIPT}"
}

# Test 16: Script should have create_todo function
test_has_create_todo_function() {
    assert_pattern_in_file "create_todo\(\)" "${AGENT_SCRIPT}"
}

# Test 17: Script should have scan_code_smells function
test_has_scan_code_smells_function() {
    assert_pattern_in_file "scan_code_smells\(\)" "${AGENT_SCRIPT}"
}

# Test 18: Script should have scan_error_handling function
test_has_scan_error_handling_function() {
    assert_pattern_in_file "scan_error_handling\(\)" "${AGENT_SCRIPT}"
}

# Test 19: Script should have scan_performance_bottlenecks function
test_has_scan_performance_bottlenecks_function() {
    assert_pattern_in_file "scan_performance_bottlenecks\(\)" "${AGENT_SCRIPT}"
}

# Test 20: Script should have scan_security_vulnerabilities function
test_has_scan_security_vulnerabilities_function() {
    assert_pattern_in_file "scan_security_vulnerabilities\(\)" "${AGENT_SCRIPT}"
}

# Test 21: Script should have run_ai_code_analysis function
test_has_run_ai_code_analysis_function() {
    assert_pattern_in_file "run_ai_code_analysis\(\)" "${AGENT_SCRIPT}"
}

# Test 22: Script should have main loop with while true
test_has_main_loop() {
    assert_pattern_in_file "while true; do" "${AGENT_SCRIPT}"
}

# Test 23: Script should have main loop with while true
test_has_main_loop() {
    assert_pattern_in_file "while true; do" "${AGENT_SCRIPT}"
}

# Test 20: Script should use log_message function for logging
test_uses_log_message() {
    assert_pattern_in_file "log_message" "${AGENT_SCRIPT}"
}

# Run all tests
tests=(
    test_script_executable
    test_defines_script_dir
    test_sources_shared_functions
    test_defines_agent_name
    test_defines_log_file
    test_defines_workspace_root
    test_defines_todo_file
    test_defines_ollama_client
    test_defines_code_analysis_interval
    test_defines_security_scan_interval
    test_defines_performance_scan_interval
    test_defines_complexity_threshold
    test_defines_force_unwrap_limit
    test_defines_print_statements_limit
    test_has_log_message_function
    test_has_create_todo_function
    test_has_scan_code_smells_function
    test_has_scan_error_handling_function
    test_has_scan_performance_bottlenecks_function
    test_uses_log_message
)

echo "Running ${#tests[@]} tests for code_analysis_agent.sh..."

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
echo "code_analysis_agent.sh Test Results"
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
RESULTS_FILE="${TEST_RESULTS_DIR}/test_code_analysis_agent_results.txt"
{
    echo "code_analysis_agent.sh Test Results"
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
