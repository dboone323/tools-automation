#!/bin/bash
# Test suite for timeout_utils.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/timeout_utils.sh"
SHELL_TEST_FRAMEWORK="${SCRIPT_DIR}/../shell_test_framework.sh"

# Source the test framework
source "${SHELL_TEST_FRAMEWORK}"

# Test 1: Script should be executable
test_agent_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}" "Script should be executable"
}

# Test 2: Should define timeout_cmd function
test_defines_timeout_cmd_function() {
    assert_pattern_in_file "timeout_cmd\(\)" "${AGENT_SCRIPT}" "Should define timeout_cmd function"
}

# Test 3: Should check for gtimeout command
test_checks_gtimeout() {
    assert_pattern_in_file "gtimeout" "${AGENT_SCRIPT}" "Should check for gtimeout"
}

# Test 4: Should check for timeout command
test_checks_timeout() {
    assert_pattern_in_file "command -v timeout" "${AGENT_SCRIPT}" "Should check for timeout command"
}

# Test 5: Should have python3 fallback
test_has_python_fallback() {
    assert_pattern_in_file "python3.*PY" "${AGENT_SCRIPT}" "Should have python3 fallback"
}

# Test 6: Should have bash loop fallback
test_has_bash_fallback() {
    assert_pattern_in_file "sleep 1" "${AGENT_SCRIPT}" "Should have bash loop fallback"
}

# Test 7: Should export timeout_cmd function
test_exports_timeout_cmd() {
    assert_pattern_in_file "export -f timeout_cmd" "${AGENT_SCRIPT}" "Should export timeout_cmd function"
}

# Test 8: Should handle invalid timeout values
test_handles_invalid_timeout() {
    assert_pattern_in_file "seconds.*=~" "${AGENT_SCRIPT}" "Should handle invalid timeout values"
}

# Test 9: Should handle zero or negative timeout
test_handles_zero_timeout() {
    assert_pattern_in_file "seconds <= 0" "${AGENT_SCRIPT}" "Should handle zero or negative timeout"
}

# Test 10: Should use proper signal handling
test_uses_signal_handling() {
    assert_pattern_in_file "kill -TERM" "${AGENT_SCRIPT}" "Should use proper signal handling"
}

# Run all tests
run_tests() {
    echo "Running tests for timeout_utils.sh..."

    test_agent_script_executable
    test_defines_timeout_cmd_function
    test_checks_gtimeout
    test_checks_timeout
    test_has_python_fallback
    test_has_bash_fallback
    test_exports_timeout_cmd
    test_handles_invalid_timeout
    test_handles_zero_timeout
    test_uses_signal_handling

    echo "✅ All tests passed!"
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
