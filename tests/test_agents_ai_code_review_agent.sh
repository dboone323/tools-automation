#!/bin/bash
# Comprehensive test suite for ai_code_review_agent.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/ai_code_review_agent.sh"

# Source shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "$AGENT_SCRIPT" "ai_code_review_agent.sh should be executable"
}

# Test 2: Script should have proper shebang
test_shebang() {
    assert_pattern_in_file "#!/bin/bash" "$AGENT_SCRIPT" "Should have bash shebang"
}

# Test 3: Should source shared_functions.sh
test_shared_functions_source() {
    assert_pattern_in_file "source.*shared_functions.sh" "$AGENT_SCRIPT" "Should source shared_functions.sh"
}

# Test 4: Should define AGENT_NAME variable
test_agent_name_definition() {
    assert_pattern_in_file "AGENT_NAME=" "$AGENT_SCRIPT" "Should define AGENT_NAME variable"
}

# Test 5: Should have ensure_within_limits function
test_ensure_within_limits_function() {
    assert_pattern_in_file "ensure_within_limits\(\)" "$AGENT_SCRIPT" "Should have ensure_within_limits function"
}

# Test 6: Should have log function
test_log_function() {
    assert_pattern_in_file "log\(\)" "$AGENT_SCRIPT" "Should have log function"
}

# Test 7: Should have ollama_query function
test_ollama_query_function() {
    assert_pattern_in_file "ollama_query\(\)" "$AGENT_SCRIPT" "Should have ollama_query function"
}

# Test 8: Should have update_status function
test_update_status_function() {
    assert_pattern_in_file "update_status\(\)" "$AGENT_SCRIPT" "Should have update_status function"
}

# Test 9: Should have process_task function
test_process_task_function() {
    assert_pattern_in_file "process_task\(\)" "$AGENT_SCRIPT" "Should have process_task function"
}

# Test 10: Should have main loop with while true
test_main_loop() {
    assert_pattern_in_file "while true" "$AGENT_SCRIPT" "Should have main loop"
}

# Run all tests
run_tests() {
    echo "Running comprehensive tests for ai_code_review_agent.sh..."
    echo "================================================================="

    test_script_executable
    test_shebang
    test_shared_functions_source
    test_agent_name_definition
    test_ensure_within_limits_function
    test_log_function
    test_ollama_query_function
    test_update_status_function
    test_process_task_function
    test_main_loop

    echo "✅ All tests passed!"
}

# Execute tests if run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
