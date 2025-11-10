#!/bin/bash
# Test suite for update_all_agents.sh
# This test suite validates the comprehensive agent update functionality

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shell_test_framework.sh
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/update_all_agents.sh"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Script should have set -euo pipefail
test_has_strict_mode() {
    assert_pattern_in_file "set -euo pipefail" "${AGENT_SCRIPT}"
}

# Test 3: Script should define SCRIPT_DIR variable
test_has_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

# Test 4: Script should define WORKSPACE_ROOT variable
test_has_workspace_root() {
    assert_pattern_in_file "WORKSPACE_ROOT=" "${AGENT_SCRIPT}"
}

# Test 5: Script should define AGENTS_DIR variable
test_has_agents_dir() {
    assert_pattern_in_file "AGENTS_DIR=" "${AGENT_SCRIPT}"
}

# Test 6: Script should define BACKUP_DIR variable
test_has_backup_dir() {
    assert_pattern_in_file "BACKUP_DIR=" "${AGENT_SCRIPT}"
}

# Test 7: Script should have log function
test_has_log_function() {
    assert_pattern_in_file "log\(\)" "${AGENT_SCRIPT}"
}

# Test 8: Script should have success function
test_has_success_function() {
    assert_pattern_in_file "success\(\)" "${AGENT_SCRIPT}"
}

# Test 9: Script should have warning function
test_has_warning_function() {
    assert_pattern_in_file "warning\(\)" "${AGENT_SCRIPT}"
}

# Test 10: Script should have error function
test_has_error_function() {
    assert_pattern_in_file "error\(\)" "${AGENT_SCRIPT}"
}

# Test 11: Script should have update_agents_to_use_shared_functions function
test_has_update_agents_function() {
    assert_pattern_in_file "update_agents_to_use_shared_functions\(\)" "${AGENT_SCRIPT}"
}

# Test 12: Script should have check_jq_errors function
test_has_check_jq_errors() {
    assert_pattern_in_file "check_jq_errors\(\)" "${AGENT_SCRIPT}"
}

# Test 13: Script should have verify_analytics_json function
test_has_verify_analytics_json() {
    assert_pattern_in_file "verify_analytics_json\(\)" "${AGENT_SCRIPT}"
}

# Test 14: Script should have check_agent_availability function
test_has_check_agent_availability() {
    assert_pattern_in_file "check_agent_availability\(\)" "${AGENT_SCRIPT}"
}

# Test 15: Script should have setup_lock_monitoring function
test_has_setup_lock_monitoring() {
    assert_pattern_in_file "setup_lock_monitoring\(\)" "${AGENT_SCRIPT}"
}

# Test 16: Script should have setup_auto_restart function
test_has_setup_auto_restart() {
    assert_pattern_in_file "setup_auto_restart\(\)" "${AGENT_SCRIPT}"
}

# Test 17: Script should have create_final_report function
test_has_create_final_report() {
    assert_pattern_in_file "create_final_report\(\)" "${AGENT_SCRIPT}"
}

# Test 18: Script should have main function
test_has_main_function() {
    assert_pattern_in_file "main\(\)" "${AGENT_SCRIPT}"
}

# Test 19: Script should call main function at the end
test_calls_main() {
    assert_pattern_in_file "main \"\$@\"" "${AGENT_SCRIPT}"
}

# Test 20: Script should use color codes for output
test_uses_colors() {
    assert_pattern_in_file "RED=" "${AGENT_SCRIPT}"
}

# Run all tests
run_tests() {
    echo "Running tests for update_all_agents.sh..."
    echo "Test Results for update_all_agents.sh" >"${SCRIPT_DIR}/test_results_update_all_agents.txt"
    echo "Generated: $(date)" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: update_all_agents.sh is executable"
        echo "✅ Test 1 PASSED: update_all_agents.sh is executable" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: update_all_agents.sh is not executable"
        echo "❌ Test 1 FAILED: update_all_agents.sh is not executable" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 2: Should have set -euo pipefail
    ((total_tests++))
    if assert_pattern_in_file "set -euo pipefail" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Has strict mode set -euo pipefail"
        echo "✅ Test 2 PASSED: Has strict mode set -euo pipefail" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Missing strict mode"
        echo "❌ Test 2 FAILED: Missing strict mode" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 3: Should define SCRIPT_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Defines SCRIPT_DIR variable"
        echo "✅ Test 3 PASSED: Defines SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not define SCRIPT_DIR variable"
        echo "❌ Test 3 FAILED: Does not define SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 4: Should define WORKSPACE_ROOT variable
    ((total_tests++))
    if assert_pattern_in_file "WORKSPACE_ROOT=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines WORKSPACE_ROOT variable"
        echo "✅ Test 4 PASSED: Defines WORKSPACE_ROOT variable" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define WORKSPACE_ROOT variable"
        echo "❌ Test 4 FAILED: Does not define WORKSPACE_ROOT variable" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 5: Should define AGENTS_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "AGENTS_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Defines AGENTS_DIR variable"
        echo "✅ Test 5 PASSED: Defines AGENTS_DIR variable" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not define AGENTS_DIR variable"
        echo "❌ Test 5 FAILED: Does not define AGENTS_DIR variable" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 6: Should define BACKUP_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "BACKUP_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Defines BACKUP_DIR variable"
        echo "✅ Test 6 PASSED: Defines BACKUP_DIR variable" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not define BACKUP_DIR variable"
        echo "❌ Test 6 FAILED: Does not define BACKUP_DIR variable" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 7: Should have log function
    ((total_tests++))
    if assert_pattern_in_file "log\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Has log function"
        echo "✅ Test 7 PASSED: Has log function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Missing log function"
        echo "❌ Test 7 FAILED: Missing log function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 8: Should have success function
    ((total_tests++))
    if assert_pattern_in_file "success\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Has success function"
        echo "✅ Test 8 PASSED: Has success function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Missing success function"
        echo "❌ Test 8 FAILED: Missing success function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 9: Should have warning function
    ((total_tests++))
    if assert_pattern_in_file "warning\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Has warning function"
        echo "✅ Test 9 PASSED: Has warning function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Missing warning function"
        echo "❌ Test 9 FAILED: Missing warning function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 10: Should have error function
    ((total_tests++))
    if assert_pattern_in_file "error\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Has error function"
        echo "✅ Test 10 PASSED: Has error function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Missing error function"
        echo "❌ Test 10 FAILED: Missing error function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 11: Should have update_agents_to_use_shared_functions function
    ((total_tests++))
    if assert_pattern_in_file "update_agents_to_use_shared_functions\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Has update_agents_to_use_shared_functions function"
        echo "✅ Test 11 PASSED: Has update_agents_to_use_shared_functions function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Missing update_agents_to_use_shared_functions function"
        echo "❌ Test 11 FAILED: Missing update_agents_to_use_shared_functions function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 12: Should have check_jq_errors function
    ((total_tests++))
    if assert_pattern_in_file "check_jq_errors\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Has check_jq_errors function"
        echo "✅ Test 12 PASSED: Has check_jq_errors function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Missing check_jq_errors function"
        echo "❌ Test 12 FAILED: Missing check_jq_errors function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 13: Should have verify_analytics_json function
    ((total_tests++))
    if assert_pattern_in_file "verify_analytics_json\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Has verify_analytics_json function"
        echo "✅ Test 13 PASSED: Has verify_analytics_json function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Missing verify_analytics_json function"
        echo "❌ Test 13 FAILED: Missing verify_analytics_json function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 14: Should have check_agent_availability function
    ((total_tests++))
    if assert_pattern_in_file "check_agent_availability\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Has check_agent_availability function"
        echo "✅ Test 14 PASSED: Has check_agent_availability function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Missing check_agent_availability function"
        echo "❌ Test 14 FAILED: Missing check_agent_availability function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 15: Should have setup_lock_monitoring function
    ((total_tests++))
    if assert_pattern_in_file "setup_lock_monitoring\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Has setup_lock_monitoring function"
        echo "✅ Test 15 PASSED: Has setup_lock_monitoring function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Missing setup_lock_monitoring function"
        echo "❌ Test 15 FAILED: Missing setup_lock_monitoring function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 16: Should have setup_auto_restart function
    ((total_tests++))
    if assert_pattern_in_file "setup_auto_restart\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Has setup_auto_restart function"
        echo "✅ Test 16 PASSED: Has setup_auto_restart function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Missing setup_auto_restart function"
        echo "❌ Test 16 FAILED: Missing setup_auto_restart function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 17: Should have create_final_report function
    ((total_tests++))
    if assert_pattern_in_file "create_final_report\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Has create_final_report function"
        echo "✅ Test 17 PASSED: Has create_final_report function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Missing create_final_report function"
        echo "❌ Test 17 FAILED: Missing create_final_report function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 18: Should have main function
    ((total_tests++))
    if assert_pattern_in_file "main\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Has main function"
        echo "✅ Test 18 PASSED: Has main function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Missing main function"
        echo "❌ Test 18 FAILED: Missing main function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 19: Should call main function at the end
    ((total_tests++))
    if assert_pattern_in_file "main \"\$@\"" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Calls main function with arguments"
        echo "✅ Test 19 PASSED: Calls main function with arguments" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Does not call main function"
        echo "❌ Test 19 FAILED: Does not call main function" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Test 20: Should use color codes for output
    ((total_tests++))
    if assert_pattern_in_file "RED=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Uses color codes for output"
        echo "✅ Test 20 PASSED: Uses color codes for output" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Does not use color codes"
        echo "❌ Test 20 FAILED: Does not use color codes" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for update_all_agents.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_update_all_agents.txt"
    fi
}

# Run the tests
run_tests
