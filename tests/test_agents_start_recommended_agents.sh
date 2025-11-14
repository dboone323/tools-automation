#!/bin/bash
# Test suite for start_recommended_agents.sh
# Tests recommended agent startup with capabilities

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/start_recommended_agents.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing start_recommended_agents.sh..."

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_SCRIPT}"
}

# Test 3: Should use set options for error handling
test_uses_set_options() {
    assert_pattern_in_file "set -euo pipefail" "${AGENT_SCRIPT}"
}

# Test 4: Should define script directory
test_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

# Test 5: Should define root directory
test_defines_root_dir() {
    assert_pattern_in_file "ROOT=" "${AGENT_SCRIPT}"
}

# Test 6: Should define venv path
test_defines_venv_path() {
    assert_pattern_in_file "VENV=" "${AGENT_SCRIPT}"
}

# Test 7: Should define log directory
test_defines_log_dir() {
    assert_pattern_in_file "LOGDIR=" "${AGENT_SCRIPT}"
}

# Test 8: Should define agents array
test_defines_agents_array() {
    assert_pattern_in_file "subproc-agent" "${AGENT_SCRIPT}"
}

# Test 9: Should start agents with nohup
test_starts_agents_nohup() {
    assert_pattern_in_file "nohup.*VENV.*run_agent.py" "${AGENT_SCRIPT}"
}

# Test 10: Should save pid files
test_saves_pid_files() {
    assert_pattern_in_file "echo.*>.*pid" "${AGENT_SCRIPT}"
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
        test_uses_set_options
        test_defines_script_dir
        test_defines_root_dir
        test_defines_venv_path
        test_defines_log_dir
        test_defines_agents_array
        test_starts_agents_nohup
        test_saves_pid_files
    )

    echo "Running ${#tests[@]} tests for start_recommended_agents.sh..."
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
    local result_file="${TEST_RESULTS_DIR}/test_start_recommended_agents_results.txt"
    {
        echo "start_recommended_agents.sh Test Results"
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
