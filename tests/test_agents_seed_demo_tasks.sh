#!/bin/bash
# Test suite for seed_demo_tasks.sh
# Tests demo task seeding functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/seed_demo_tasks.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing seed_demo_tasks.sh..."

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_SCRIPT}"
}

# Test 3: Should define task queue file
test_defines_task_queue_file() {
    assert_pattern_in_file "TASK_QUEUE_FILE=" "${AGENT_SCRIPT}"
}

# Test 4: Should check for jq dependency
test_checks_jq_dependency() {
    assert_pattern_in_file "jq is required" "${AGENT_SCRIPT}"
}

# Test 5: Should initialize task queue if not exists
test_initializes_task_queue() {
    assert_pattern_in_file "tasks.*completed.*failed" "${AGENT_SCRIPT}"
}

# Test 6: Should seed demo tasks in loop
test_seeds_demo_tasks_loop() {
    assert_pattern_in_file "for i in.*seq" "${AGENT_SCRIPT}"
}

# Test 7: Should create different task types
test_creates_different_task_types() {
    assert_pattern_in_file "type=.*build" "${AGENT_SCRIPT}"
}

# Test 8: Should set task priorities
test_sets_task_priorities() {
    assert_pattern_in_file "priority=.*RANDOM" "${AGENT_SCRIPT}"
}

# Test 9: Should use jq to add tasks
test_uses_jq_to_add_tasks() {
    assert_pattern_in_file "tasks += " "${AGENT_SCRIPT}"
}

# Test 10: Should print completion message
test_prints_completion_message() {
    assert_pattern_in_file "Done\." "${AGENT_SCRIPT}"
}

# Run all tests
run_tests() {
    local test_count=0
    local pass_count=0
    local fail_count=0

    # Array of test functions
    local tests=(
        test_script_executable
        test_sources_shared_functions
        test_defines_task_queue_file
        test_checks_jq_dependency
        test_initializes_task_queue
        test_seeds_demo_tasks_loop
        test_creates_different_task_types
        test_sets_task_priorities
        test_uses_jq_to_add_tasks
        test_prints_completion_message
    )

    echo "Running ${#tests[@]} tests for seed_demo_tasks.sh..."
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
    local result_file="${TEST_RESULTS_DIR}/test_seed_demo_tasks_results.txt"
    {
        echo "seed_demo_tasks.sh Test Results"
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
