#!/bin/bash
# Test suite for auto_rollback.sh
# This test suite validates the auto-rollback system functionality

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shell_test_framework.sh
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/auto_rollback.sh"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Script should define SCRIPT_DIR variable
test_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

# Test 3: Script should define ROOT_DIR variable
test_defines_root_dir() {
    assert_pattern_in_file "ROOT_DIR=" "${AGENT_SCRIPT}"
}

# Test 4: Script should define CHECKPOINTS_DIR variable
test_defines_checkpoints_dir() {
    assert_pattern_in_file "CHECKPOINTS_DIR=" "${AGENT_SCRIPT}"
}

# Test 5: Script should define ROLLBACK_LOG variable
test_defines_rollback_log() {
    assert_pattern_in_file "ROLLBACK_LOG=" "${AGENT_SCRIPT}"
}

# Test 6: Script should define color variables
test_defines_color_variables() {
    assert_pattern_in_file "RED=" "${AGENT_SCRIPT}"
}

# Test 7: Script should have log function
test_has_log_function() {
    assert_pattern_in_file "log\(\)" "${AGENT_SCRIPT}"
}

# Test 8: Script should have warn function
test_has_warn_function() {
    assert_pattern_in_file "warn\(\)" "${AGENT_SCRIPT}"
}

# Test 9: Script should have error function
test_has_error_function() {
    assert_pattern_in_file "error\(\)" "${AGENT_SCRIPT}"
}

# Test 10: Script should have init_checkpoints function
test_has_init_checkpoints_function() {
    assert_pattern_in_file "init_checkpoints\(\)" "${AGENT_SCRIPT}"
}

# Test 11: Script should have create_checkpoint function
test_has_create_checkpoint_function() {
    assert_pattern_in_file "create_checkpoint\(\)" "${AGENT_SCRIPT}"
}

# Test 12: Script should have restore_checkpoint function
test_has_restore_checkpoint_function() {
    assert_pattern_in_file "restore_checkpoint\(\)" "${AGENT_SCRIPT}"
}

# Test 13: Script should have monitor_validation function
test_has_monitor_validation_function() {
    assert_pattern_in_file "monitor_validation\(\)" "${AGENT_SCRIPT}"
}

# Test 14: Script should have try_alternative function
test_has_try_alternative_function() {
    assert_pattern_in_file "try_alternative\(\)" "${AGENT_SCRIPT}"
}

# Test 15: Script should have log_failure function
test_has_log_failure_function() {
    assert_pattern_in_file "log_failure\(\)" "${AGENT_SCRIPT}"
}

# Test 16: Script should have list_checkpoints function
test_has_list_checkpoints_function() {
    assert_pattern_in_file "list_checkpoints\(\)" "${AGENT_SCRIPT}"
}

# Test 17: Script should have clean_checkpoints function
test_has_clean_checkpoints_function() {
    assert_pattern_in_file "clean_checkpoints\(\)" "${AGENT_SCRIPT}"
}

# Test 18: Script should have main function
test_has_main_function() {
    assert_pattern_in_file "main\(\)" "${AGENT_SCRIPT}"
}

# Test 19: Script should have case statement for commands
test_has_case_statement() {
    assert_pattern_in_file "case.*command.*in" "${AGENT_SCRIPT}"
}

# Test 20: Script should have help command
test_has_help_command() {
    assert_pattern_in_file "help.*--help.*-h" "${AGENT_SCRIPT}"
}

# Run all tests
run_tests() {
    echo "Running tests for auto_rollback.sh..."
    echo "Test Results for auto_rollback.sh" >"${SCRIPT_DIR}/test_results_auto_rollback.txt"
    echo "Generated: $(date)" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: auto_rollback.sh is executable"
        echo "✅ Test 1 PASSED: auto_rollback.sh is executable" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: auto_rollback.sh is not executable"
        echo "❌ Test 1 FAILED: auto_rollback.sh is not executable" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 2: Should define SCRIPT_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable"
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable"
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 3: Should define ROOT_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "ROOT_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Defines ROOT_DIR variable"
        echo "✅ Test 3 PASSED: Defines ROOT_DIR variable" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not define ROOT_DIR variable"
        echo "❌ Test 3 FAILED: Does not define ROOT_DIR variable" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 4: Should define CHECKPOINTS_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "CHECKPOINTS_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines CHECKPOINTS_DIR variable"
        echo "✅ Test 4 PASSED: Defines CHECKPOINTS_DIR variable" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define CHECKPOINTS_DIR variable"
        echo "❌ Test 4 FAILED: Does not define CHECKPOINTS_DIR variable" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 5: Should define ROLLBACK_LOG variable
    ((total_tests++))
    if assert_pattern_in_file "ROLLBACK_LOG=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Defines ROLLBACK_LOG variable"
        echo "✅ Test 5 PASSED: Defines ROLLBACK_LOG variable" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not define ROLLBACK_LOG variable"
        echo "❌ Test 5 FAILED: Does not define ROLLBACK_LOG variable" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 6: Should define color variables
    ((total_tests++))
    if assert_pattern_in_file "RED=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Defines color variables"
        echo "✅ Test 6 PASSED: Defines color variables" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not define color variables"
        echo "❌ Test 6 FAILED: Does not define color variables" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 7: Should have log function
    ((total_tests++))
    if assert_pattern_in_file "log\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Has log function"
        echo "✅ Test 7 PASSED: Has log function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Missing log function"
        echo "❌ Test 7 FAILED: Missing log function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 8: Should have warn function
    ((total_tests++))
    if assert_pattern_in_file "warn\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Has warn function"
        echo "✅ Test 8 PASSED: Has warn function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Missing warn function"
        echo "❌ Test 8 FAILED: Missing warn function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 9: Should have error function
    ((total_tests++))
    if assert_pattern_in_file "error\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Has error function"
        echo "✅ Test 9 PASSED: Has error function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Missing error function"
        echo "❌ Test 9 FAILED: Missing error function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 10: Should have init_checkpoints function
    ((total_tests++))
    if assert_pattern_in_file "init_checkpoints\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Has init_checkpoints function"
        echo "✅ Test 10 PASSED: Has init_checkpoints function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Missing init_checkpoints function"
        echo "❌ Test 10 FAILED: Missing init_checkpoints function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 11: Should have create_checkpoint function
    ((total_tests++))
    if assert_pattern_in_file "create_checkpoint\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Has create_checkpoint function"
        echo "✅ Test 11 PASSED: Has create_checkpoint function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Missing create_checkpoint function"
        echo "❌ Test 11 FAILED: Missing create_checkpoint function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 12: Should have restore_checkpoint function
    ((total_tests++))
    if assert_pattern_in_file "restore_checkpoint\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Has restore_checkpoint function"
        echo "✅ Test 12 PASSED: Has restore_checkpoint function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Missing restore_checkpoint function"
        echo "❌ Test 12 FAILED: Missing restore_checkpoint function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 13: Should have monitor_validation function
    ((total_tests++))
    if assert_pattern_in_file "monitor_validation\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Has monitor_validation function"
        echo "✅ Test 13 PASSED: Has monitor_validation function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Missing monitor_validation function"
        echo "❌ Test 13 FAILED: Missing monitor_validation function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 14: Should have try_alternative function
    ((total_tests++))
    if assert_pattern_in_file "try_alternative\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Has try_alternative function"
        echo "✅ Test 14 PASSED: Has try_alternative function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Missing try_alternative function"
        echo "❌ Test 14 FAILED: Missing try_alternative function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 15: Should have log_failure function
    ((total_tests++))
    if assert_pattern_in_file "log_failure\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Has log_failure function"
        echo "✅ Test 15 PASSED: Has log_failure function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Missing log_failure function"
        echo "❌ Test 15 FAILED: Missing log_failure function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 16: Should have list_checkpoints function
    ((total_tests++))
    if assert_pattern_in_file "list_checkpoints\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Has list_checkpoints function"
        echo "✅ Test 16 PASSED: Has list_checkpoints function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Missing list_checkpoints function"
        echo "❌ Test 16 FAILED: Missing list_checkpoints function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 17: Should have clean_checkpoints function
    ((total_tests++))
    if assert_pattern_in_file "clean_checkpoints\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Has clean_checkpoints function"
        echo "✅ Test 17 PASSED: Has clean_checkpoints function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Missing clean_checkpoints function"
        echo "❌ Test 17 FAILED: Missing clean_checkpoints function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 18: Should have main function
    ((total_tests++))
    if assert_pattern_in_file "main\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Has main function"
        echo "✅ Test 18 PASSED: Has main function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Missing main function"
        echo "❌ Test 18 FAILED: Missing main function" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 19: Should have case statement for commands
    ((total_tests++))
    if assert_pattern_in_file "case.*command.*in" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Has case statement for commands"
        echo "✅ Test 19 PASSED: Has case statement for commands" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Missing case statement for commands"
        echo "❌ Test 19 FAILED: Missing case statement for commands" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Test 20: Should have help command
    ((total_tests++))
    if assert_pattern_in_file "help.*--help.*-h" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Has help command"
        echo "✅ Test 20 PASSED: Has help command" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Missing help command"
        echo "❌ Test 20 FAILED: Missing help command" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for auto_rollback.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_auto_rollback.txt"
    fi
}

# Run the tests
run_tests
