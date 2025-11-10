#!/bin/bash
# Test suite for show_alerts.sh
# Tests alert display and long-running process monitoring functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/show_alerts.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing show_alerts.sh..."

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Should define script directory
test_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

# Test 3: Should define task queue file
test_defines_task_queue_file() {
    assert_pattern_in_file "TASK_QUEUE_FILE=" "${AGENT_SCRIPT}"
}

# Test 4: Should define alert log file
test_defines_alert_log_file() {
    assert_pattern_in_file "ALERT_LOG=" "${AGENT_SCRIPT}"
}

# Test 5: Should check for task queue file
test_checks_task_queue_file() {
    assert_pattern_in_file "if.*-f.*TASK_QUEUE_FILE" "${AGENT_SCRIPT}"
}

# Test 6: Should use Python to parse alerts
test_uses_python_for_alerts() {
    assert_pattern_in_file "python3.*TASK_QUEUE_FILE" "${AGENT_SCRIPT}"
}

# Test 7: Should check for long-running processes
test_checks_long_running_processes() {
    assert_pattern_in_file "ps.*-eo.*pid.*comm.*etime" "${AGENT_SCRIPT}"
}

# Test 8: Should filter system processes
test_filters_system_processes() {
    assert_pattern_in_file "pid.*<.*100" "${AGENT_SCRIPT}"
}

# Test 9: Should parse elapsed time
test_parses_elapsed_time() {
    assert_pattern_in_file "total_minutes.*>" "${AGENT_SCRIPT}"
}

# Test 10: Should show completion message
test_shows_completion_message() {
    assert_pattern_in_file "clear_alerts.sh" "${AGENT_SCRIPT}"
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
        test_defines_task_queue_file
        test_defines_alert_log_file
        test_checks_task_queue_file
        test_uses_python_for_alerts
        test_checks_long_running_processes
        test_filters_system_processes
        test_parses_elapsed_time
        test_shows_completion_message
    )

    echo "Running ${#tests[@]} tests for show_alerts.sh..."
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
    local result_file="${TEST_RESULTS_DIR}/test_show_alerts_results.txt"
    {
        echo "show_alerts.sh Test Results"
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
