#!/bin/bash
# Test suite for plugin scripts
# Tests all plugin functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PLUGINS_DIR="${SCRIPT_DIR}/../agents/plugins"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing plugin scripts..."

# Test 1: apple_pro_apply.sh should be executable
test_apple_pro_apply_executable() {
    assert_file_executable "${PLUGINS_DIR}/apple_pro_apply.sh"
}

# Test 2: apple_pro_check.sh should be executable
test_apple_pro_check_executable() {
    assert_file_executable "${PLUGINS_DIR}/apple_pro_check.sh"
}

# Test 3: apple_pro_suggest.sh should be executable
test_apple_pro_suggest_executable() {
    assert_file_executable "${PLUGINS_DIR}/apple_pro_suggest.sh"
}

# Test 4: collab_analyze.sh should be executable
test_collab_analyze_executable() {
    assert_file_executable "${PLUGINS_DIR}/collab_analyze.sh"
}

# Test 5: sample_hello.sh should be executable
test_sample_hello_executable() {
    assert_file_executable "${PLUGINS_DIR}/sample_hello.sh"
}

# Test 6: uiux_analysis.sh should be executable
test_uiux_analysis_executable() {
    assert_file_executable "${PLUGINS_DIR}/uiux_analysis.sh"
}

# Test 7: uiux_apply.sh should be executable
test_uiux_apply_executable() {
    assert_file_executable "${PLUGINS_DIR}/uiux_apply.sh"
}

# Test 8: uiux_suggest.sh should be executable
test_uiux_suggest_executable() {
    assert_file_executable "${PLUGINS_DIR}/uiux_suggest.sh"
}

# Test 9: sample_hello.sh should output hello message
test_sample_hello_output() {
    local output
    output=$("${PLUGINS_DIR}/sample_hello.sh" 2>&1)
    assert_contains "$output" "Hello from the sample plugin"
}

# Test 10: sample_hello.sh should handle arguments
test_sample_hello_with_args() {
    local output
    output=$("${PLUGINS_DIR}/sample_hello.sh" arg1 arg2 2>&1)
    assert_contains "$output" "Args: arg1 arg2"
}

# Test 11: sample_hello.sh should handle no arguments
test_sample_hello_no_args() {
    local output
    output=$("${PLUGINS_DIR}/sample_hello.sh" 2>&1)
    assert_contains "$output" "Args: (none)"
}

# Test 12: apple_pro_apply.sh should accept project argument
test_apple_pro_apply_with_project() {
    local output
    output=$("${PLUGINS_DIR}/apple_pro_apply.sh" "TestProject" 2>&1)
    assert_contains "$output" "Auto-applying Apple Pro best practices for TestProject"
}

# Test 13: apple_pro_check.sh should be executable and run
test_apple_pro_check_runs() {
    local output
    output=$("${PLUGINS_DIR}/apple_pro_check.sh" 2>&1)
    # Should not fail
    [[ $? -eq 0 ]]
}

# Test 14: apple_pro_suggest.sh should be executable and run
test_apple_pro_suggest_runs() {
    local output
    output=$("${PLUGINS_DIR}/apple_pro_suggest.sh" 2>&1)
    # Should not fail
    [[ $? -eq 0 ]]
}

# Test 15: collab_analyze.sh should be executable and run
test_collab_analyze_runs() {
    local output
    output=$("${PLUGINS_DIR}/collab_analyze.sh" 2>&1)
    # Should not fail
    [[ $? -eq 0 ]]
}

# Test 16: uiux_analysis.sh should accept project argument
test_uiux_analysis_with_project() {
    local output
    output=$("${PLUGINS_DIR}/uiux_analysis.sh" "TestProject" 2>&1)
    assert_contains "$output" "Analyzing TestProject for UI/UX best practices"
}

# Test 17: uiux_apply.sh should be executable and run
test_uiux_apply_runs() {
    local output
    output=$("${PLUGINS_DIR}/uiux_apply.sh" 2>&1)
    # Should not fail
    [[ $? -eq 0 ]]
}

# Test 18: uiux_suggest.sh should be executable and run
test_uiux_suggest_runs() {
    local output
    output=$("${PLUGINS_DIR}/uiux_suggest.sh" 2>&1)
    # Should not fail
    [[ $? -eq 0 ]]
}

# Test 19: All plugins should exit with code 0
test_all_plugins_exit_success() {
    local plugins=("apple_pro_apply.sh" "apple_pro_check.sh" "apple_pro_suggest.sh" "collab_analyze.sh" "sample_hello.sh" "uiux_analysis.sh" "uiux_apply.sh" "uiux_suggest.sh")
    for plugin in "${plugins[@]}"; do
        if ! "${PLUGINS_DIR}/${plugin}" >/dev/null 2>&1; then
            test_failed "assertion" "Plugin ${plugin} should exit successfully"
            return 1
        fi
    done
    return 0
}

# Test 20: All plugin files should exist
test_all_plugins_exist() {
    local plugins=("apple_pro_apply.sh" "apple_pro_check.sh" "apple_pro_suggest.sh" "collab_analyze.sh" "sample_hello.sh" "uiux_analysis.sh" "uiux_apply.sh" "uiux_suggest.sh")
    for plugin in "${plugins[@]}"; do
        assert_file_exists "${PLUGINS_DIR}/${plugin}"
    done
}

# Run all tests
run_tests() {
    local test_count=0
    local pass_count=0
    local fail_count=0

    # Array of test functions
    local tests=(
        test_apple_pro_apply_executable
        test_apple_pro_check_executable
        test_apple_pro_suggest_executable
        test_collab_analyze_executable
        test_sample_hello_executable
        test_uiux_analysis_executable
        test_uiux_apply_executable
        test_uiux_suggest_executable
        test_sample_hello_output
        test_sample_hello_with_args
        test_sample_hello_no_args
        test_apple_pro_apply_with_project
        test_apple_pro_check_runs
        test_apple_pro_suggest_runs
        test_collab_analyze_runs
        test_uiux_analysis_with_project
        test_uiux_apply_runs
        test_uiux_suggest_runs
        test_all_plugins_exit_success
        test_all_plugins_exist
    )

    echo "Running ${#tests[@]} tests for plugin scripts..."
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
    local result_file="${TEST_RESULTS_DIR}/test_plugins_results.txt"
    {
        echo "Plugin Scripts Test Results"
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
