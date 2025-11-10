#!/bin/bash
# Test suite for execute_all_tasks.sh
# Tests comprehensive task execution functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/execute_all_tasks.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing execute_all_tasks.sh..."

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Should define SCRIPT_DIR variable
test_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

# Test 3: Should define WORKSPACE_ROOT variable
test_defines_workspace_root() {
    assert_pattern_in_file "WORKSPACE_ROOT=" "${AGENT_SCRIPT}"
}

# Test 4: Should define color variables
test_defines_color_variables() {
    assert_pattern_in_file "RED=" "${AGENT_SCRIPT}"
}

# Test 5: Should define REPORT_FILE variable
test_defines_report_file() {
    assert_pattern_in_file "REPORT_FILE=" "${AGENT_SCRIPT}"
}

# Test 6: Should define log function
test_defines_log_function() {
    assert_pattern_in_file "^log\(\)" "${AGENT_SCRIPT}"
}

# Test 7: Should define success function
test_defines_success_function() {
    assert_pattern_in_file "^success\(\)" "${AGENT_SCRIPT}"
}

# Test 8: Should define warning function
test_defines_warning_function() {
    assert_pattern_in_file "^warning\(\)" "${AGENT_SCRIPT}"
}

# Test 9: Should define error function
test_defines_error_function() {
    assert_pattern_in_file "^error\(\)" "${AGENT_SCRIPT}"
}

# Test 10: Should define section function
test_defines_section_function() {
    assert_pattern_in_file "^section\(\)" "${AGENT_SCRIPT}"
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
        test_defines_workspace_root
        test_defines_color_variables
        test_defines_report_file
        test_defines_log_function
        test_defines_success_function
        test_defines_warning_function
        test_defines_error_function
        test_defines_section_function
    )

    echo "Running ${#tests[@]} tests for execute_all_tasks.sh..."
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
    local result_file="${TEST_RESULTS_DIR}/test_execute_all_tasks_results.txt"
    {
        echo "execute_all_tasks.sh Test Results"
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
