#!/bin/bash
# Test suite for scheduled_inventory.sh
# Tests scheduled inventory management functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/scheduled_inventory.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing scheduled_inventory.sh..."

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_SCRIPT}"
}

# Test 3: Should run workspace inventory
test_runs_workspace_inventory() {
    assert_pattern_in_file "workspace_inventory.sh" "${AGENT_SCRIPT}"
}

# Test 4: Should run documentation generation
test_runs_documentation_generation() {
    assert_pattern_in_file "gen_docs.sh" "${AGENT_SCRIPT}"
}

# Test 5: Should set root directory
test_sets_root_directory() {
    assert_pattern_in_file "ROOT_DIR=" "${AGENT_SCRIPT}"
}

# Test 6: Should change to root directory
test_changes_to_root_directory() {
    assert_pattern_in_file "cd.*ROOT_DIR" "${AGENT_SCRIPT}"
}

# Test 7: Should use set options for error handling
test_uses_set_options() {
    assert_pattern_in_file "set -euo pipefail" "${AGENT_SCRIPT}"
}

# Test 8: Should print completion message
test_prints_completion_message() {
    assert_pattern_in_file "scheduled_inventory: completed" "${AGENT_SCRIPT}"
}

# Test 9: Should source shared functions
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_SCRIPT}"
}

# Test 10: Should be executable
test_is_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
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
        test_runs_workspace_inventory
        test_runs_documentation_generation
        test_sets_root_directory
        test_changes_to_root_directory
        test_uses_set_options
        test_prints_completion_message
        test_is_executable
    )

    echo "Running ${#tests[@]} tests for scheduled_inventory.sh..."
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
    local result_file="${TEST_RESULTS_DIR}/test_scheduled_inventory_results.txt"
    {
        echo "scheduled_inventory.sh Test Results"
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
