#!/bin/bash
# Comprehensive test suite for ai_client.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/ai_client.sh"

# Source shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "$AGENT_SCRIPT" "ai_client.sh should be executable"
}

# Test 2: Script should have proper shebang
test_shebang() {
    assert_pattern_in_file "#!/bin/bash" "$AGENT_SCRIPT" "Should have bash shebang"
}

# Test 3: Should define TOOLS_ROOT variable
test_tools_root_definition() {
    assert_pattern_in_file "TOOLS_ROOT=" "$AGENT_SCRIPT" "Should define TOOLS_ROOT variable"
}

# Test 4: Should define AI_CLIENT_DEFAULT variable
test_ai_client_default_definition() {
    assert_pattern_in_file "AI_CLIENT_DEFAULT=" "$AGENT_SCRIPT" "Should define AI_CLIENT_DEFAULT variable"
}

# Test 5: Should have ai_task_for_script function
test_ai_task_for_script_function() {
    assert_pattern_in_file "ai_task_for_script\(\)" "$AGENT_SCRIPT" "Should have ai_task_for_script function"
}

# Test 6: Should have ai_generate function
test_ai_generate_function() {
    assert_pattern_in_file "ai_generate\(\)" "$AGENT_SCRIPT" "Should have ai_generate function"
}

# Test 7: Should have ai_text function
test_ai_text_function() {
    assert_pattern_in_file "ai_text\(\)" "$AGENT_SCRIPT" "Should have ai_text function"
}

# Test 8: Should have set -euo pipefail
test_strict_mode() {
    assert_pattern_in_file "set -euo pipefail" "$AGENT_SCRIPT" "Should have strict mode enabled"
}

# Test 9: Should have case statement for task mapping
test_case_statement() {
    assert_pattern_in_file "case.*script_name" "$AGENT_SCRIPT" "Should have case statement for task mapping"
}

# Test 10: Should have error handling for missing client
test_error_handling() {
    assert_pattern_in_file "ERROR.*client not found" "$AGENT_SCRIPT" "Should have error handling for missing client"
}

# Run all tests
run_tests() {
    echo "Running comprehensive tests for ai_client.sh..."
    echo "================================================================="

    test_script_executable
    test_shebang
    test_tools_root_definition
    test_ai_client_default_definition
    test_ai_task_for_script_function
    test_ai_generate_function
    test_ai_text_function
    test_strict_mode
    test_case_statement
    test_error_handling

    echo "✅ All tests passed!"
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
