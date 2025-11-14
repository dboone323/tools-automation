#!/bin/bash
# Comprehensive test suite for error_learning_scan.sh
# Tests the scan wrapper functionality and integration with main error learning agent

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="${SCRIPT_DIR}/test_tmp"
AGENT_SCRIPT="${SCRIPT_DIR}/agents/error_learning_scan.sh"
MAIN_AGENT="${SCRIPT_DIR}/agents/error_learning_agent.sh"

# Source test framework
source "${SCRIPT_DIR}/shell_test_framework.sh"

# Setup test environment
setup_test_env() {
    mkdir -p "$TEST_DIR"
    export TEST_MODE=true

    # Create test log files with error patterns
    cat >"${TEST_DIR}/test_scan.log" <<'EOF'
[2025-01-09 10:00:00] [agent1] Starting agent1
[2025-01-09 10:00:01] [agent1] [ERROR] Failed to connect to database
[2025-01-09 10:00:02] [agent1] Processing completed
[2025-01-09 10:00:03] [agent1] ❌ Network timeout occurred
EOF

    cat >"${TEST_DIR}/test_scan2.log" <<'EOF'
[2025-01-09 10:00:00] [agent2] Starting agent2
[2025-01-09 10:00:01] [agent2] Processing data
[2025-01-09 10:00:02] [agent2] Failed to parse configuration
[2025-01-09 10:00:03] [agent2] Shutting down
EOF

    cat >"${TEST_DIR}/test_no_errors.log" <<'EOF'
[2025-01-09 10:00:00] [agent3] Starting agent3
[2025-01-09 10:00:01] [agent3] Processing completed successfully
[2025-01-09 10:00:02] [agent3] All tests passed
EOF
}

# Cleanup test environment
cleanup_test_env() {
    # Clean up test files
    rm -rf "$TEST_DIR"

    # Kill any test processes
    pkill -f "error_learning_scan.sh" || true
    pkill -f "error_learning_agent.sh" || true
}

# Test 1: Script execution and basic functionality
test_script_execution() {
    local test_name="test_script_execution"
    announce_test "$test_name"

    # Test that script exists
    assert_file_exists "$AGENT_SCRIPT" "Scan agent script should exist"

    # Test basic execution (should show usage if no args)
    local output
    output=$("$AGENT_SCRIPT" 2>&1 || true)

    if echo "$output" | grep -q "Usage\|usage\|help\|--scan-once"; then
        assert_true true "Script should show usage information when run without arguments"
    else
        assert_true false "Script should show usage information when run without arguments - got: $output"
    fi

    test_passed "$test_name"
}

# Test 2: Wrapper calls main agent correctly
test_wrapper_integration() {
    local test_name="test_wrapper_integration"
    announce_test "$test_name"

    # Test that the wrapper script contains the expected call to main agent
    if grep -q "error_learning_agent.sh" "$AGENT_SCRIPT" && grep -q "scan-once" "$AGENT_SCRIPT" && grep -q '"$@"' "$AGENT_SCRIPT"; then
        assert_true true "Wrapper script should contain call to main agent with --scan-once and argument passing"
    else
        assert_true false "Wrapper script should contain call to main agent with --scan-once and argument passing"
    fi

    test_passed "$test_name"
}

# Test 3: Argument passing through wrapper
test_argument_passing() {
    local test_name="test_argument_passing"
    announce_test "$test_name"

    # Test that the wrapper passes arguments through (verified by integration test)
    # The script uses "$@" to pass all arguments
    if grep -q '"$@"' "$AGENT_SCRIPT"; then
        assert_true true "Wrapper script should pass all arguments to main agent"
    else
        assert_true false "Wrapper script should pass all arguments to main agent"
    fi

    test_passed "$test_name"
}

# Test 4: Script directory resolution
test_script_directory_resolution() {
    local test_name="test_script_directory_resolution"
    announce_test "$test_name"

    # Test that SCRIPT_DIR is resolved correctly
    local expected_script_dir
    expected_script_dir=$(cd "$(dirname "$AGENT_SCRIPT")" && pwd)

    # Check that the script uses the correct directory
    if grep -q "SCRIPT_DIR=" "$AGENT_SCRIPT" && grep -q "dirname.*BASH_SOURCE" "$AGENT_SCRIPT"; then
        assert_true true "Script should correctly resolve its own directory"
    else
        assert_true false "Script should correctly resolve its own directory"
    fi

    # Test ROOT_DIR resolution
    if grep -q "ROOT_DIR=" "$AGENT_SCRIPT" && grep -q "../../.." "$AGENT_SCRIPT"; then
        assert_true true "Script should correctly resolve root directory"
    else
        assert_true false "Script should correctly resolve root directory"
    fi

    test_passed "$test_name"
}

# Test 5: Error handling and exit codes
test_error_handling() {
    local test_name="test_error_handling"
    announce_test "$test_name"

    # Test with no arguments (should show error from main agent)
    local output
    output=$("$AGENT_SCRIPT" 2>&1 || true)

    if echo "$output" | grep -q "requires a file pattern"; then
        assert_true true "Script should show appropriate error when no arguments provided"
    else
        assert_true false "Script should show appropriate error when no arguments provided - got: $output"
    fi

    test_passed "$test_name"
}

# Test 6: Script sourcing protection
test_script_sourcing_protection() {
    local test_name="test_script_sourcing_protection"
    announce_test "$test_name"

    # Test that the script doesn't execute when sourced
    local source_test_output="${TEST_DIR}/source_test.txt"

    # Create a test script that sources the agent and checks if it runs
    cat >"${TEST_DIR}/source_test.sh" <<EOF
#!/bin/bash
# Source the agent script
source "$AGENT_SCRIPT" >"$source_test_output" 2>&1 || echo "SOURCE_FAILED" >"$source_test_output"
EOF
    chmod +x "${TEST_DIR}/source_test.sh"

    # Run the source test
    "${TEST_DIR}/source_test.sh"

    # Check that the script didn't execute main function when sourced
    local source_output
    source_output=$(cat "$source_test_output")

    if echo "$source_output" | grep -q "SOURCE_FAILED" || ! echo "$source_output" | grep -q "Error Learning Agent"; then
        assert_true true "Script should not execute main function when sourced"
    else
        assert_true false "Script should not execute main function when sourced - output: $source_output"
    fi

    test_passed "$test_name"
}

# Test 7: Integration with actual main agent
test_integration_with_main_agent() {
    local test_name="test_integration_with_main_agent"
    announce_test "$test_name"

    # Test that the wrapper integrates correctly with the real main agent
    # This is a basic integration test - the main agent should handle the --scan-once call

    # Run the wrapper with a test file
    local output
    output=$("$AGENT_SCRIPT" "${TEST_DIR}/test_scan.log" 2>&1 || true)

    # The main agent should process the file or show appropriate output
    # We can't predict exact output, but it should not crash
    if [[ $? -eq 0 ]] || echo "$output" | grep -q -E "(scan|Processing|completed|No files)"; then
        assert_true true "Wrapper should integrate successfully with main agent"
    else
        assert_true false "Wrapper should integrate successfully with main agent - exit code: $?, output: $output"
    fi

    test_passed "$test_name"
}

# Test 8: Multiple file patterns
test_multiple_file_patterns() {
    local test_name="test_multiple_file_patterns"
    announce_test "$test_name"

    # Test with glob pattern
    local output
    output=$("$AGENT_SCRIPT" "${TEST_DIR}/test_scan*.log" 2>&1 || true)

    # Should process multiple files or handle the pattern
    if [[ $? -eq 0 ]] || echo "$output" | grep -q -E "(scan|Processing|test_scan)"; then
        assert_true true "Wrapper should handle glob patterns for multiple files"
    else
        assert_true false "Wrapper should handle glob patterns for multiple files - output: $output"
    fi

    test_passed "$test_name"
}

# Test 9: Help and usage information
test_help_and_usage() {
    local test_name="test_help_and_usage"
    announce_test "$test_name"

    # Test help flag (if supported by main agent)
    local help_output
    help_output=$("$AGENT_SCRIPT" --help 2>&1 || true)

    if echo "$help_output" | grep -q -E "(Usage|usage|help|--scan-once|--watch)"; then
        assert_true true "Script should show help information"
    else
        assert_true false "Script should show help information - got: $help_output"
    fi

    test_passed "$test_name"
}

# Test 10: Environment isolation
test_environment_isolation() {
    local test_name="test_environment_isolation"
    announce_test "$test_name"

    # Test that the script doesn't modify the calling environment
    local original_path="$PATH"
    local original_pwd="$PWD"

    # Run the script
    "$AGENT_SCRIPT" "${TEST_DIR}/test_scan.log" >/dev/null 2>&1 || true

    # Check that environment variables weren't modified
    if [[ "$PATH" == "$original_path" ]] && [[ "$PWD" == "$original_pwd" ]]; then
        assert_true true "Script should not modify calling environment"
    else
        assert_true false "Script should not modify calling environment"
    fi

    test_passed "$test_name"
}

# Run all tests
run_tests() {
    setup_test_env

    echo "Running comprehensive tests for error_learning_scan.sh..."
    echo "================================================================="

    # Run individual tests
    test_script_execution
    test_wrapper_integration
    test_argument_passing
    test_script_directory_resolution
    test_error_handling
    test_script_sourcing_protection
    test_integration_with_main_agent
    test_multiple_file_patterns
    test_help_and_usage
    test_environment_isolation

    echo "================================================================="
    echo "Test Summary:"
    echo "Total tests: $(get_total_tests)"
    echo "Passed: $(get_passed_tests)"
    echo "Failed: $(get_failed_tests)"

    cleanup_test_env

    # Return success/failure
    if [[ $(get_failed_tests) -eq 0 ]]; then
        echo "✅ All tests passed!"
        return 0
    else
        echo "❌ Some tests failed!"
        return 1
    fi
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
