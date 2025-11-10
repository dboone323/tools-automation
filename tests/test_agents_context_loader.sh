#!/bin/bash
# Test suite for context_loader.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_PATH="${SCRIPT_DIR}/../agents/context_loader.sh"
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

# Test 3: Script should define CONTEXT_DIR variable
test_defines_context_dir() {
    assert_pattern_in_file "CONTEXT_DIR=" "${AGENT_PATH}"
}

# Test 4: Script should define PROJECT_MEMORY variable
test_defines_project_memory() {
    assert_pattern_in_file "PROJECT_MEMORY=" "${AGENT_PATH}"
}

# Test 5: Script should define ROOT_DIR variable
test_defines_root_dir() {
    assert_pattern_in_file "ROOT_DIR=" "${AGENT_PATH}"
}

# Test 6: Script should define log function
test_defines_log_function() {
    assert_pattern_in_file "log\(\)" "${AGENT_PATH}"
}

# Test 7: Script should define init_context function
test_defines_init_context_function() {
    assert_pattern_in_file "init_context\(\)" "${AGENT_PATH}"
}

# Test 8: Script should define load_memory function
test_defines_load_memory_function() {
    assert_pattern_in_file "load_memory\(\)" "${AGENT_PATH}"
}

# Test 9: Script should define main function
test_defines_main_function() {
    assert_pattern_in_file "main\(\)" "${AGENT_PATH}"
}

# Test 10: Script should use case statement for commands
test_uses_case_statement() {
    assert_pattern_in_file "case.*command.*in" "${AGENT_PATH}"
}

# Run all tests
run_context_loader_tests() {
    echo "🧪 Running tests for context_loader.sh"
    echo "======================================"

    test_script_executable
    test_defines_script_dir
    test_defines_context_dir
    test_defines_project_memory
    test_defines_root_dir
    test_defines_log_function
    test_defines_init_context_function
    test_defines_load_memory_function
    test_defines_main_function
    test_uses_case_statement

    echo ""
    echo "✅ All tests passed!"
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_context_loader_tests
fi
