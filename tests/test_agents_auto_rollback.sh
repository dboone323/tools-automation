#!/bin/bash
# Test suite for auto_rollback.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_PATH="${SCRIPT_DIR}/../agents/auto_rollback.sh"
SHELL_TEST_FRAMEWORK="${SCRIPT_DIR}/../shell_test_framework.sh"

# Source the test framework
source "${SHELL_TEST_FRAMEWORK}"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_PATH}"
}

# Test 2: Script should define SCRIPT_DIR variable
test_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_PATH}"
}

# Test 3: Script should define ROOT_DIR variable
test_defines_root_dir() {
    assert_pattern_in_file "ROOT_DIR=" "${AGENT_PATH}"
}

# Test 4: Script should define CHECKPOINTS_DIR variable
test_defines_checkpoints_dir() {
    assert_pattern_in_file "CHECKPOINTS_DIR=" "${AGENT_PATH}"
}

# Test 5: Script should define ROLLBACK_LOG variable
test_defines_rollback_log() {
    assert_pattern_in_file "ROLLBACK_LOG=" "${AGENT_PATH}"
}

# Test 6: Script should define init_checkpoints function
test_defines_init_checkpoints_function() {
    assert_pattern_in_file "init_checkpoints\(\)" "${AGENT_PATH}"
}

# Test 7: Script should define create_checkpoint function
test_defines_create_checkpoint_function() {
    assert_pattern_in_file "create_checkpoint\(\)" "${AGENT_PATH}"
}

# Test 8: Script should define restore_checkpoint function
test_defines_restore_checkpoint_function() {
    assert_pattern_in_file "restore_checkpoint\(\)" "${AGENT_PATH}"
}

# Test 9: Script should define main function
test_defines_main_function() {
    assert_pattern_in_file "main\(\)" "${AGENT_PATH}"
}

# Test 10: Script should have case statement for commands
test_has_case_statement() {
    assert_pattern_in_file "case.*command.*in" "${AGENT_PATH}"
}

# Run all tests
run_auto_rollback_tests() {
    echo "🧪 Running tests for auto_rollback.sh"
    echo "===================================="

    test_script_executable
    test_defines_script_dir
    test_defines_root_dir
    test_defines_checkpoints_dir
    test_defines_rollback_log
    test_defines_init_checkpoints_function
    test_defines_create_checkpoint_function
    test_defines_restore_checkpoint_function
    test_defines_main_function
    test_has_case_statement

    echo ""
    echo "✅ All tests passed!"
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_auto_rollback_tests
fi
