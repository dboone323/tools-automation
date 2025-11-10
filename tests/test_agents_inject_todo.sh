#!/bin/bash
# Test suite for inject_todo.sh
# Tests manual TODO injection functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/inject_todo.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing inject_todo.sh..."

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Should define SCRIPT_DIR variable
test_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

# Test 3: Should define AGENTS_DIR variable
test_defines_agents_dir() {
    assert_pattern_in_file "AGENTS_DIR=" "${AGENT_SCRIPT}"
}

# Test 4: Should source agent_todo.sh
test_sources_agent_todo() {
    assert_pattern_in_file "source.*agent_todo.sh" "${AGENT_SCRIPT}"
}

# Test 5: Should check argument count
test_checks_argument_count() {
    assert_pattern_in_file "if \[\[ \$\# -lt 3 \]\]" "${AGENT_SCRIPT}"
}

# Test 6: Should define FILE_PATH variable
test_defines_file_path() {
    assert_pattern_in_file "FILE_PATH=" "${AGENT_SCRIPT}"
}

# Test 7: Should define LINE_NUMBER variable
test_defines_line_number() {
    assert_pattern_in_file "LINE_NUMBER=" "${AGENT_SCRIPT}"
}

# Test 8: Should define TODO_TEXT variable
test_defines_todo_text() {
    assert_pattern_in_file "TODO_TEXT=" "${AGENT_SCRIPT}"
}

# Test 9: Should define PRIORITY variable with default
test_defines_priority() {
    assert_pattern_in_file "PRIORITY=" "${AGENT_SCRIPT}"
}

# Test 10: Should define PROJECT variable with default
test_defines_project() {
    assert_pattern_in_file "PROJECT=" "${AGENT_SCRIPT}"
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
        test_defines_agents_dir
        test_sources_agent_todo
        test_checks_argument_count
        test_defines_file_path
        test_defines_line_number
        test_defines_todo_text
        test_defines_priority
        test_defines_project
    )

    echo "Running ${#tests[@]} tests for inject_todo.sh..."
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
    local result_file="${TEST_RESULTS_DIR}/test_inject_todo_results.txt"
    {
        echo "inject_todo.sh Test Results"
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
