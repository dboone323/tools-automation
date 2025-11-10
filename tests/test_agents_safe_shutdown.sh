#!/bin/bash
# Test suite for safe_shutdown.sh
# Tests safe shutdown functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/safe_shutdown.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing safe_shutdown.sh..."

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_SCRIPT}"
}

# Test 3: Should define stop_agent function
test_defines_stop_agent_function() {
    assert_pattern_in_file "^stop_agent\(\)" "${AGENT_SCRIPT}"
}

# Test 4: Should stop running agents
test_stops_running_agents() {
    assert_pattern_in_file "Stopping running agents" "${AGENT_SCRIPT}"
}

# Test 5: Should clean up lock files
test_cleans_lock_files() {
    assert_pattern_in_file "Cleaning up lock files" "${AGENT_SCRIPT}"
}

# Test 6: Should save final agent status
test_saves_final_status() {
    assert_pattern_in_file "Saving final agent status" "${AGENT_SCRIPT}"
}

# Test 7: Should clean temporary files
test_cleans_temporary_files() {
    assert_pattern_in_file "Cleaning temporary files" "${AGENT_SCRIPT}"
}

# Test 8: Should remove agent_status.lock
test_removes_agent_status_lock() {
    assert_pattern_in_file "agent_status.lock" "${AGENT_SCRIPT}"
}

# Test 9: Should backup agent status
test_backups_agent_status() {
    assert_pattern_in_file "agent_status.json.shutdown" "${AGENT_SCRIPT}"
}

# Test 10: Should print shutdown complete message
test_prints_shutdown_complete() {
    assert_pattern_in_file "SHUTDOWN COMPLETE" "${AGENT_SCRIPT}"
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
        test_defines_stop_agent_function
        test_stops_running_agents
        test_cleans_lock_files
        test_saves_final_status
        test_cleans_temporary_files
        test_removes_agent_status_lock
        test_backups_agent_status
        test_prints_shutdown_complete
    )

    echo "Running ${#tests[@]} tests for safe_shutdown.sh..."
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
    local result_file="${TEST_RESULTS_DIR}/test_safe_shutdown_results.txt"
    {
        echo "safe_shutdown.sh Test Results"
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
