#!/bin/bash
# Test suite for knowledge_sync.sh
# Tests knowledge synchronization functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/knowledge_sync.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing knowledge_sync.sh..."

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Should define SCRIPT_DIR variable
test_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

# Test 3: Should define KNOWLEDGE_DIR variable
test_defines_knowledge_dir() {
    assert_pattern_in_file "KNOWLEDGE_DIR=" "${AGENT_SCRIPT}"
}

# Test 4: Should define CENTRAL_HUB variable
test_defines_central_hub() {
    assert_pattern_in_file "CENTRAL_HUB=" "${AGENT_SCRIPT}"
}

# Test 5: Should define SYNC_INTERVAL variable
test_defines_sync_interval() {
    assert_pattern_in_file "SYNC_INTERVAL=" "${AGENT_SCRIPT}"
}

# Test 6: Should define log function
test_defines_log_function() {
    assert_pattern_in_file "^log\(\)" "${AGENT_SCRIPT}"
}

# Test 7: Should define error function
test_defines_error_function() {
    assert_pattern_in_file "^error\(\)" "${AGENT_SCRIPT}"
}

# Test 8: Should define init_central_hub function
test_defines_init_central_hub_function() {
    assert_pattern_in_file "^init_central_hub\(\)" "${AGENT_SCRIPT}"
}

# Test 9: Should define collect_agent_insights function
test_defines_collect_agent_insights_function() {
    assert_pattern_in_file "^collect_agent_insights\(\)" "${AGENT_SCRIPT}"
}

# Test 10: Should define main function
test_defines_main_function() {
    assert_pattern_in_file "^main\(\)" "${AGENT_SCRIPT}"
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
        test_defines_knowledge_dir
        test_defines_central_hub
        test_defines_sync_interval
        test_defines_log_function
        test_defines_error_function
        test_defines_init_central_hub_function
        test_defines_collect_agent_insights_function
        test_defines_main_function
    )

    echo "Running ${#tests[@]} tests for knowledge_sync.sh..."
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
    local result_file="${TEST_RESULTS_DIR}/test_knowledge_sync_results.txt"
    {
        echo "knowledge_sync.sh Test Results"
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
