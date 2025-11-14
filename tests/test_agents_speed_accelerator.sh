#!/bin/bash
# Test suite for speed_accelerator.sh
# Tests quantum workspace speed acceleration functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/speed_accelerator.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing speed_accelerator.sh..."

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_SCRIPT}"
}

# Test 3: Should define run_with_timeout function
test_defines_run_with_timeout() {
    assert_pattern_in_file "^run_with_timeout\(\)" "${AGENT_SCRIPT}"
}

# Test 4: Should kill stuck processes
test_kills_stuck_processes() {
    assert_pattern_in_file "pkill.*agent_.*\.sh" "${AGENT_SCRIPT}"
}

# Test 5: Should restart agents
test_restarts_agents() {
    assert_pattern_in_file "Restarting all agents" "${AGENT_SCRIPT}"
}

# Test 6: Should start agents in parallel
test_starts_agents_parallel() {
    assert_pattern_in_file "for agent in.*agent_scripts" "${AGENT_SCRIPT}"
}

# Test 7: Should create performance config
test_creates_performance_config() {
    assert_pattern_in_file "performance_config.json" "${AGENT_SCRIPT}"
}

# Test 8: Should enable parallel processing
test_enables_parallel_processing() {
    assert_pattern_in_file "parallel_processing.*true" "${AGENT_SCRIPT}"
}

# Test 9: Should start continuous optimization
test_starts_continuous_optimization() {
    assert_pattern_in_file "continuous optimization" "${AGENT_SCRIPT}"
}

# Test 10: Should show completion message
test_shows_completion_message() {
    assert_pattern_in_file "ACCELERATION COMPLETE" "${AGENT_SCRIPT}"
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
        test_defines_run_with_timeout
        test_kills_stuck_processes
        test_restarts_agents
        test_starts_agents_parallel
        test_creates_performance_config
        test_enables_parallel_processing
        test_starts_continuous_optimization
        test_shows_completion_message
    )

    echo "Running ${#tests[@]} tests for speed_accelerator.sh..."
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
    local result_file="${TEST_RESULTS_DIR}/test_speed_accelerator_results.txt"
    {
        echo "speed_accelerator.sh Test Results"
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
