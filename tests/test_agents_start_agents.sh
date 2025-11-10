#!/bin/bash
# Test suite for start_agents.sh
# Tests agent startup and status initialization functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/start_agents.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing start_agents.sh..."

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_SCRIPT}"
}

# Test 3: Should define agents array
test_defines_agents_array() {
    assert_pattern_in_file "AGENTS=.*agent_build.sh" "${AGENT_SCRIPT}"
}

# Test 4: Should define agent pids array
test_defines_agent_pids_array() {
    assert_pattern_in_file "AGENT_PIDS=" "${AGENT_SCRIPT}"
}

# Test 5: Should define status file
test_defines_status_file() {
    assert_pattern_in_file "STATUS_FILE=" "${AGENT_SCRIPT}"
}

# Test 6: Should initialize agent status json
test_initializes_agent_status_json() {
    assert_pattern_in_file "agent_status.json" "${AGENT_SCRIPT}"
}

# Test 7: Should start agents in background
test_starts_agents_background() {
    assert_pattern_in_file "bash.*AGENT_PATH.*&" "${AGENT_SCRIPT}"
}

# Test 8: Should record pids
test_records_pids() {
    assert_pattern_in_file "PID=.*!" "${AGENT_SCRIPT}"
}

# Test 9: Should use jq to update status
test_uses_jq_update_status() {
    assert_pattern_in_file "running" "${AGENT_SCRIPT}"
}

# Test 10: Should show completion message
test_shows_completion_message() {
    assert_pattern_in_file "stop_agents.sh" "${AGENT_SCRIPT}"
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
        test_defines_agents_array
        test_defines_agent_pids_array
        test_defines_status_file
        test_initializes_agent_status_json
        test_starts_agents_background
        test_records_pids
        test_uses_jq_update_status
        test_shows_completion_message
    )

    echo "Running ${#tests[@]} tests for start_agents.sh..."
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
    local result_file="${TEST_RESULTS_DIR}/test_start_agents_results.txt"
    {
        echo "start_agents.sh Test Results"
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
