#!/bin/bash
# Test suite for onboard.sh
# Tests agent system onboarding functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/onboard.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing onboard.sh..."

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Should define SCRIPT_DIR variable
test_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

# Test 3: Should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_SCRIPT}"
}

# Test 4: Should define AGENTS_DIR variable
test_defines_agents_dir() {
    assert_pattern_in_file "AGENTS_DIR=" "${AGENT_SCRIPT}"
}

# Test 5: Should define LOGS_DIR variable
test_defines_logs_dir() {
    assert_pattern_in_file "LOGS_DIR=" "${AGENT_SCRIPT}"
}

# Test 6: Should define PLUGINS_DIR variable
test_defines_plugins_dir() {
    assert_pattern_in_file "PLUGINS_DIR=" "${AGENT_SCRIPT}"
}

# Test 7: Should create directories
test_creates_directories() {
    assert_pattern_in_file "mkdir -p" "${AGENT_SCRIPT}"
}

# Test 8: Should make scripts executable
test_makes_scripts_executable() {
    assert_pattern_in_file "chmod +x" "${AGENT_SCRIPT}"
}

# Test 9: Should print quickstart info
test_prints_quickstart_info() {
    assert_pattern_in_file "cat <<EOF" "${AGENT_SCRIPT}"
}

# Test 10: Should mention key scripts
test_mentions_key_scripts() {
    assert_pattern_in_file "agent_build.sh" "${AGENT_SCRIPT}"
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
        test_sources_shared_functions
        test_defines_agents_dir
        test_defines_logs_dir
        test_defines_plugins_dir
        test_creates_directories
        test_makes_scripts_executable
        test_prints_quickstart_info
        test_mentions_key_scripts
    )

    echo "Running ${#tests[@]} tests for onboard.sh..."
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
    local result_file="${TEST_RESULTS_DIR}/test_onboard_results.txt"
    {
        echo "onboard.sh Test Results"
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
