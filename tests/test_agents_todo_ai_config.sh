#!/bin/bash
# Test suite for todo_ai_config.sh
# This test suite validates the AI configuration settings

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shell_test_framework.sh
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/todo_ai_config.sh"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Script should define AI_MODEL variable
test_has_ai_model() {
    assert_pattern_in_file "export AI_MODEL=" "${AGENT_SCRIPT}"
}

# Test 3: Script should define AI_ENDPOINT variable
test_has_ai_endpoint() {
    assert_pattern_in_file "export AI_ENDPOINT=" "${AGENT_SCRIPT}"
}

# Test 4: Script should define AI_TIMEOUT variable
test_has_ai_timeout() {
    assert_pattern_in_file "export AI_TIMEOUT=" "${AGENT_SCRIPT}"
}

# Test 5: Script should define AI_MAX_FILE_SIZE variable
test_has_ai_max_file_size() {
    assert_pattern_in_file "export AI_MAX_FILE_SIZE=" "${AGENT_SCRIPT}"
}

# Test 6: Script should define AI_ANALYSIS_CYCLE variable
test_has_ai_analysis_cycle() {
    assert_pattern_in_file "export AI_ANALYSIS_CYCLE=" "${AGENT_SCRIPT}"
}

# Test 7: Script should define AI_CODE_REVIEW_LIMIT variable
test_has_ai_code_review_limit() {
    assert_pattern_in_file "export AI_CODE_REVIEW_LIMIT=" "${AGENT_SCRIPT}"
}

# Test 8: Script should define AI_SUGGESTION_PRIORITY_DEFAULT variable
test_has_ai_suggestion_priority_default() {
    assert_pattern_in_file "export AI_SUGGESTION_PRIORITY_DEFAULT=" "${AGENT_SCRIPT}"
}

# Test 9: Script should define PROJECT_ANALYSIS_TIMEOUT variable
test_has_project_analysis_timeout() {
    assert_pattern_in_file "export PROJECT_ANALYSIS_TIMEOUT=" "${AGENT_SCRIPT}"
}

# Test 10: Script should define PROJECT_ANALYSIS_MAX_FILES variable
test_has_project_analysis_max_files() {
    assert_pattern_in_file "export PROJECT_ANALYSIS_MAX_FILES=" "${AGENT_SCRIPT}"
}

# Test 11: Script should define AI_TODO_PREFIX variable
test_has_ai_todo_prefix() {
    assert_pattern_in_file "export AI_TODO_PREFIX=" "${AGENT_SCRIPT}"
}

# Test 12: Script should define AI_PROJECT_TODO_PREFIX variable
test_has_ai_project_todo_prefix() {
    assert_pattern_in_file "export AI_PROJECT_TODO_PREFIX=" "${AGENT_SCRIPT}"
}

# Test 13: Script should define AI_TODO_DEDUPLICATION variable
test_has_ai_todo_deduplication() {
    assert_pattern_in_file "export AI_TODO_DEDUPLICATION=" "${AGENT_SCRIPT}"
}

# Test 14: Script should define AI_LOG_LEVEL variable
test_has_ai_log_level() {
    assert_pattern_in_file "export AI_LOG_LEVEL=" "${AGENT_SCRIPT}"
}

# Test 15: Script should define AI_LOG_FILE variable
test_has_ai_log_file() {
    assert_pattern_in_file "export AI_LOG_FILE=" "${AGENT_SCRIPT}"
}

# Test 16: Script should define ENABLE_AI_CODE_REVIEW variable
test_has_enable_ai_code_review() {
    assert_pattern_in_file "export ENABLE_AI_CODE_REVIEW=" "${AGENT_SCRIPT}"
}

# Test 17: Script should define ENABLE_AI_PROJECT_ANALYSIS variable
test_has_enable_ai_project_analysis() {
    assert_pattern_in_file "export ENABLE_AI_PROJECT_ANALYSIS=" "${AGENT_SCRIPT}"
}

# Test 18: Script should define ENABLE_AI_TODO_GENERATION variable
test_has_enable_ai_todo_generation() {
    assert_pattern_in_file "export ENABLE_AI_TODO_GENERATION=" "${AGENT_SCRIPT}"
}

# Test 19: Script should define ENABLE_AI_DEDUPLICATION variable
test_has_enable_ai_deduplication() {
    assert_pattern_in_file "export ENABLE_AI_DEDUPLICATION=" "${AGENT_SCRIPT}"
}

# Test 20: Script should define TODO_SCAN_CYCLE variable
test_has_todo_scan_cycle() {
    assert_pattern_in_file "export TODO_SCAN_CYCLE=" "${AGENT_SCRIPT}"
}

# Run all tests
run_tests() {
    echo "Running tests for todo_ai_config.sh..."
    echo "Test Results for todo_ai_config.sh" >"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
    echo "Generated: $(date)" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: todo_ai_config.sh is executable"
        echo "✅ Test 1 PASSED: todo_ai_config.sh is executable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: todo_ai_config.sh is not executable"
        echo "❌ Test 1 FAILED: todo_ai_config.sh is not executable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 2: Should define AI_MODEL variable
    ((total_tests++))
    if assert_pattern_in_file "export AI_MODEL=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Defines AI_MODEL variable"
        echo "✅ Test 2 PASSED: Defines AI_MODEL variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not define AI_MODEL variable"
        echo "❌ Test 2 FAILED: Does not define AI_MODEL variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 3: Should define AI_ENDPOINT variable
    ((total_tests++))
    if assert_pattern_in_file "export AI_ENDPOINT=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Defines AI_ENDPOINT variable"
        echo "✅ Test 3 PASSED: Defines AI_ENDPOINT variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not define AI_ENDPOINT variable"
        echo "❌ Test 3 FAILED: Does not define AI_ENDPOINT variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 4: Should define AI_TIMEOUT variable
    ((total_tests++))
    if assert_pattern_in_file "export AI_TIMEOUT=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines AI_TIMEOUT variable"
        echo "✅ Test 4 PASSED: Defines AI_TIMEOUT variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define AI_TIMEOUT variable"
        echo "❌ Test 4 FAILED: Does not define AI_TIMEOUT variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 5: Should define AI_MAX_FILE_SIZE variable
    ((total_tests++))
    if assert_pattern_in_file "export AI_MAX_FILE_SIZE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Defines AI_MAX_FILE_SIZE variable"
        echo "✅ Test 5 PASSED: Defines AI_MAX_FILE_SIZE variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not define AI_MAX_FILE_SIZE variable"
        echo "❌ Test 5 FAILED: Does not define AI_MAX_FILE_SIZE variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 6: Should define AI_ANALYSIS_CYCLE variable
    ((total_tests++))
    if assert_pattern_in_file "export AI_ANALYSIS_CYCLE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Defines AI_ANALYSIS_CYCLE variable"
        echo "✅ Test 6 PASSED: Defines AI_ANALYSIS_CYCLE variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not define AI_ANALYSIS_CYCLE variable"
        echo "❌ Test 6 FAILED: Does not define AI_ANALYSIS_CYCLE variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 7: Should define AI_CODE_REVIEW_LIMIT variable
    ((total_tests++))
    if assert_pattern_in_file "export AI_CODE_REVIEW_LIMIT=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Defines AI_CODE_REVIEW_LIMIT variable"
        echo "✅ Test 7 PASSED: Defines AI_CODE_REVIEW_LIMIT variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not define AI_CODE_REVIEW_LIMIT variable"
        echo "❌ Test 7 FAILED: Does not define AI_CODE_REVIEW_LIMIT variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 8: Should define AI_SUGGESTION_PRIORITY_DEFAULT variable
    ((total_tests++))
    if assert_pattern_in_file "export AI_SUGGESTION_PRIORITY_DEFAULT=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Defines AI_SUGGESTION_PRIORITY_DEFAULT variable"
        echo "✅ Test 8 PASSED: Defines AI_SUGGESTION_PRIORITY_DEFAULT variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Does not define AI_SUGGESTION_PRIORITY_DEFAULT variable"
        echo "❌ Test 8 FAILED: Does not define AI_SUGGESTION_PRIORITY_DEFAULT variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 9: Should define PROJECT_ANALYSIS_TIMEOUT variable
    ((total_tests++))
    if assert_pattern_in_file "export PROJECT_ANALYSIS_TIMEOUT=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Defines PROJECT_ANALYSIS_TIMEOUT variable"
        echo "✅ Test 9 PASSED: Defines PROJECT_ANALYSIS_TIMEOUT variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Does not define PROJECT_ANALYSIS_TIMEOUT variable"
        echo "❌ Test 9 FAILED: Does not define PROJECT_ANALYSIS_TIMEOUT variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 10: Should define PROJECT_ANALYSIS_MAX_FILES variable
    ((total_tests++))
    if assert_pattern_in_file "export PROJECT_ANALYSIS_MAX_FILES=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Defines PROJECT_ANALYSIS_MAX_FILES variable"
        echo "✅ Test 10 PASSED: Defines PROJECT_ANALYSIS_MAX_FILES variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not define PROJECT_ANALYSIS_MAX_FILES variable"
        echo "❌ Test 10 FAILED: Does not define PROJECT_ANALYSIS_MAX_FILES variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 11: Should define AI_TODO_PREFIX variable
    ((total_tests++))
    if assert_pattern_in_file "export AI_TODO_PREFIX=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Defines AI_TODO_PREFIX variable"
        echo "✅ Test 11 PASSED: Defines AI_TODO_PREFIX variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not define AI_TODO_PREFIX variable"
        echo "❌ Test 11 FAILED: Does not define AI_TODO_PREFIX variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 12: Should define AI_PROJECT_TODO_PREFIX variable
    ((total_tests++))
    if assert_pattern_in_file "export AI_PROJECT_TODO_PREFIX=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Defines AI_PROJECT_TODO_PREFIX variable"
        echo "✅ Test 12 PASSED: Defines AI_PROJECT_TODO_PREFIX variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not define AI_PROJECT_TODO_PREFIX variable"
        echo "❌ Test 12 FAILED: Does not define AI_PROJECT_TODO_PREFIX variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 13: Should define AI_TODO_DEDUPLICATION variable
    ((total_tests++))
    if assert_pattern_in_file "export AI_TODO_DEDUPLICATION=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Defines AI_TODO_DEDUPLICATION variable"
        echo "✅ Test 13 PASSED: Defines AI_TODO_DEDUPLICATION variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not define AI_TODO_DEDUPLICATION variable"
        echo "❌ Test 13 FAILED: Does not define AI_TODO_DEDUPLICATION variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 14: Should define AI_LOG_LEVEL variable
    ((total_tests++))
    if assert_pattern_in_file "export AI_LOG_LEVEL=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Defines AI_LOG_LEVEL variable"
        echo "✅ Test 14 PASSED: Defines AI_LOG_LEVEL variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not define AI_LOG_LEVEL variable"
        echo "❌ Test 14 FAILED: Does not define AI_LOG_LEVEL variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 15: Should define AI_LOG_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "export AI_LOG_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Defines AI_LOG_FILE variable"
        echo "✅ Test 15 PASSED: Defines AI_LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not define AI_LOG_FILE variable"
        echo "❌ Test 15 FAILED: Does not define AI_LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 16: Should define ENABLE_AI_CODE_REVIEW variable
    ((total_tests++))
    if assert_pattern_in_file "export ENABLE_AI_CODE_REVIEW=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Defines ENABLE_AI_CODE_REVIEW variable"
        echo "✅ Test 16 PASSED: Defines ENABLE_AI_CODE_REVIEW variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Does not define ENABLE_AI_CODE_REVIEW variable"
        echo "❌ Test 16 FAILED: Does not define ENABLE_AI_CODE_REVIEW variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 17: Should define ENABLE_AI_PROJECT_ANALYSIS variable
    ((total_tests++))
    if assert_pattern_in_file "export ENABLE_AI_PROJECT_ANALYSIS=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Defines ENABLE_AI_PROJECT_ANALYSIS variable"
        echo "✅ Test 17 PASSED: Defines ENABLE_AI_PROJECT_ANALYSIS variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Does not define ENABLE_AI_PROJECT_ANALYSIS variable"
        echo "❌ Test 17 FAILED: Does not define ENABLE_AI_PROJECT_ANALYSIS variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 18: Should define ENABLE_AI_TODO_GENERATION variable
    ((total_tests++))
    if assert_pattern_in_file "export ENABLE_AI_TODO_GENERATION=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Defines ENABLE_AI_TODO_GENERATION variable"
        echo "✅ Test 18 PASSED: Defines ENABLE_AI_TODO_GENERATION variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Does not define ENABLE_AI_TODO_GENERATION variable"
        echo "❌ Test 18 FAILED: Does not define ENABLE_AI_TODO_GENERATION variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 19: Should define ENABLE_AI_DEDUPLICATION variable
    ((total_tests++))
    if assert_pattern_in_file "export ENABLE_AI_DEDUPLICATION=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Defines ENABLE_AI_DEDUPLICATION variable"
        echo "✅ Test 19 PASSED: Defines ENABLE_AI_DEDUPLICATION variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Does not define ENABLE_AI_DEDUPLICATION variable"
        echo "❌ Test 19 FAILED: Does not define ENABLE_AI_DEDUPLICATION variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Test 20: Should define TODO_SCAN_CYCLE variable
    ((total_tests++))
    if assert_pattern_in_file "export TODO_SCAN_CYCLE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Defines TODO_SCAN_CYCLE variable"
        echo "✅ Test 20 PASSED: Defines TODO_SCAN_CYCLE variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Does not define TODO_SCAN_CYCLE variable"
        echo "❌ Test 20 FAILED: Does not define TODO_SCAN_CYCLE variable" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for todo_ai_config.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_todo_ai_config.txt"
    fi
}

# Run the tests
run_tests
