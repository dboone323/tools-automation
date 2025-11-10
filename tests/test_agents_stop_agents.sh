#!/bin/bash
# Test suite for stop_agents.sh
# Tests graceful agent shutdown functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/stop_agents.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing stop_agents.sh..."

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_SCRIPT}"
}

# Test 3: Should define status file
test_defines_status_file() {
    assert_pattern_in_file "STATUS_FILE=" "${AGENT_SCRIPT}"
}

# Test 4: Should define agent names array
test_defines_agent_names_array() {
    assert_pattern_in_file "AGENT_NAMES=.*build_agent" "${AGENT_SCRIPT}"
}

# Test 5: Should check for status file existence
test_checks_status_file_exists() {
    assert_pattern_in_file "if.*!.*-f.*STATUS_FILE" "${AGENT_SCRIPT}"
}

# Test 6: Should extract pid using jq
test_extracts_pid_jq() {
    assert_pattern_in_file "jq.*pid" "${AGENT_SCRIPT}"
}

# Test 7: Should check if process is running
test_checks_process_running() {
    assert_pattern_in_file "kill.*-0.*PID" "${AGENT_SCRIPT}"
}

# Test 8: Should kill running processes
test_kills_running_processes() {
    assert_pattern_in_file "kill.*PID" "${AGENT_SCRIPT}"
}

# Test 9: Should update status to stopped
test_updates_status_stopped() {
    assert_pattern_in_file "status.*stopped" "${AGENT_SCRIPT}"
}

# Test 10: Should handle null pids
test_handles_null_pids() {
    assert_pattern_in_file "PID.*!=.*null" "${AGENT_SCRIPT}"
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
        test_defines_status_file
        test_defines_agent_names_array
        test_checks_status_file_exists
        test_extracts_pid_jq
        test_checks_process_running
        test_kills_running_processes
        test_updates_status_stopped
        test_handles_null_pids
    )

    echo "Running ${#tests[@]} tests for stop_agents.sh..."
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
    local result_file="${TEST_RESULTS_DIR}/test_stop_agents_results.txt"
    {
        echo "stop_agents.sh Test Results"
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
