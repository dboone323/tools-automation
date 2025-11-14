#!/bin/bash
# Test suite for check_persistence.sh
# This test suite validates the persistence status check functionality

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shell_test_framework.sh
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/check_persistence.sh"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Script should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"
}

# Test 3: Script should define SCRIPT_DIR variable
test_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

# Test 4: Script should define LOG_FILE variable
test_defines_log_file() {
    assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"
}

# Test 5: Script should check launch daemon status
test_checks_launch_daemon_status() {
    assert_pattern_in_file "launchctl list" "${AGENT_SCRIPT}"
}

# Test 6: Script should check auto-restart monitor process
test_checks_auto_restart_monitor() {
    assert_pattern_in_file "auto_restart_monitor" "${AGENT_SCRIPT}"
}

# Test 7: Script should check core agent status
test_checks_core_agent_status() {
    assert_pattern_in_file "agent_build\.sh.*agent_debug\.sh.*agent_codegen\.sh" "${AGENT_SCRIPT}"
}

# Test 8: Script should check task queue status
test_checks_task_queue_status() {
    assert_pattern_in_file "task_queue\.json" "${AGENT_SCRIPT}"
}

# Test 9: Script should use jq for JSON parsing
test_uses_jq_for_json_parsing() {
    assert_pattern_in_file "jq " "${AGENT_SCRIPT}"
}

# Test 10: Script should check Ollama integration status
test_checks_ollama_integration() {
    assert_pattern_in_file "ollama serve" "${AGENT_SCRIPT}"
}

# Test 11: Script should check available Ollama models
test_checks_ollama_models() {
    assert_pattern_in_file "ollama list" "${AGENT_SCRIPT}"
}

# Test 12: Script should generate status report
test_generates_status_report() {
    assert_pattern_in_file "Status Report" "${AGENT_SCRIPT}"
}

# Test 13: Script should display summary to console
test_displays_summary_to_console() {
    assert_pattern_in_file "echo.*Status:" "${AGENT_SCRIPT}"
}

# Test 14: Script should check for quantum launch daemons
test_checks_quantum_launch_daemons() {
    assert_pattern_in_file "grep quantum" "${AGENT_SCRIPT}"
}

# Test 15: Script should use pgrep to check processes
test_uses_pgrep_to_check_processes() {
    assert_pattern_in_file "pgrep -f" "${AGENT_SCRIPT}"
}

# Test 16: Script should check task status counts
test_checks_task_status_counts() {
    assert_pattern_in_file "completed.*in_progress.*queued" "${AGENT_SCRIPT}"
}

# Test 17: Script should handle missing task queue file
test_handles_missing_task_queue_file() {
    assert_pattern_in_file "not found" "${AGENT_SCRIPT}"
}

# Test 18: Script should display agent process count
test_displays_agent_process_count() {
    assert_pattern_in_file "Agent processes running:" "${AGENT_SCRIPT}"
}

# Test 19: Script should save report to log file
test_saves_report_to_log_file() {
    assert_pattern_in_file "Report saved to:" "${AGENT_SCRIPT}"
}

# Test 20: Script should have end report marker
test_has_end_report_marker() {
    assert_pattern_in_file "End Report" "${AGENT_SCRIPT}"
}

# Run all tests
run_tests() {
    echo "Running tests for check_persistence.sh..."
    echo "Test Results for check_persistence.sh" >"${SCRIPT_DIR}/test_results_check_persistence.txt"
    echo "Generated: $(date)" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: check_persistence.sh is executable"
        echo "✅ Test 1 PASSED: check_persistence.sh is executable" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: check_persistence.sh is not executable"
        echo "❌ Test 1 FAILED: check_persistence.sh is not executable" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 2: Should source shared_functions.sh
    ((total_tests++))
    if assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Sources shared_functions.sh"
        echo "✅ Test 2 PASSED: Sources shared_functions.sh" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not source shared_functions.sh"
        echo "❌ Test 2 FAILED: Does not source shared_functions.sh" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 3: Should define SCRIPT_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Defines SCRIPT_DIR variable"
        echo "✅ Test 3 PASSED: Defines SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not define SCRIPT_DIR variable"
        echo "❌ Test 3 FAILED: Does not define SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 4: Should define LOG_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines LOG_FILE variable"
        echo "✅ Test 4 PASSED: Defines LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define LOG_FILE variable"
        echo "❌ Test 4 FAILED: Does not define LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 5: Should check launch daemon status
    ((total_tests++))
    if assert_pattern_in_file "launchctl list" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Checks launch daemon status"
        echo "✅ Test 5 PASSED: Checks launch daemon status" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not check launch daemon status"
        echo "❌ Test 5 FAILED: Does not check launch daemon status" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 6: Should check auto-restart monitor process
    ((total_tests++))
    if assert_pattern_in_file "auto_restart_monitor" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Checks auto-restart monitor process"
        echo "✅ Test 6 PASSED: Checks auto-restart monitor process" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not check auto-restart monitor process"
        echo "❌ Test 6 FAILED: Does not check auto-restart monitor process" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 7: Should check core agent status
    ((total_tests++))
    if assert_pattern_in_file "agent_build\.sh.*agent_debug\.sh.*agent_codegen\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Checks core agent status"
        echo "✅ Test 7 PASSED: Checks core agent status" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not check core agent status"
        echo "❌ Test 7 FAILED: Does not check core agent status" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 8: Should check task queue status
    ((total_tests++))
    if assert_pattern_in_file "task_queue\.json" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Checks task queue status"
        echo "✅ Test 8 PASSED: Checks task queue status" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Does not check task queue status"
        echo "❌ Test 8 FAILED: Does not check task queue status" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 9: Should use jq for JSON parsing
    ((total_tests++))
    if assert_pattern_in_file "jq " "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Uses jq for JSON parsing"
        echo "✅ Test 9 PASSED: Uses jq for JSON parsing" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Does not use jq for JSON parsing"
        echo "❌ Test 9 FAILED: Does not use jq for JSON parsing" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 10: Should check Ollama integration status
    ((total_tests++))
    if assert_pattern_in_file "ollama serve" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Checks Ollama integration status"
        echo "✅ Test 10 PASSED: Checks Ollama integration status" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not check Ollama integration status"
        echo "❌ Test 10 FAILED: Does not check Ollama integration status" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 11: Should check available Ollama models
    ((total_tests++))
    if assert_pattern_in_file "ollama list" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Checks available Ollama models"
        echo "✅ Test 11 PASSED: Checks available Ollama models" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not check available Ollama models"
        echo "❌ Test 11 FAILED: Does not check available Ollama models" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 12: Should generate status report
    ((total_tests++))
    if assert_pattern_in_file "Status Report" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Generates status report"
        echo "✅ Test 12 PASSED: Generates status report" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not generate status report"
        echo "❌ Test 12 FAILED: Does not generate status report" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 13: Should display summary to console
    ((total_tests++))
    if assert_pattern_in_file "echo.*Status:" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Displays summary to console"
        echo "✅ Test 13 PASSED: Displays summary to console" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not display summary to console"
        echo "❌ Test 13 FAILED: Does not display summary to console" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 14: Should check for quantum launch daemons
    ((total_tests++))
    if assert_pattern_in_file "grep quantum" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Checks for quantum launch daemons"
        echo "✅ Test 14 PASSED: Checks for quantum launch daemons" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not check for quantum launch daemons"
        echo "❌ Test 14 FAILED: Does not check for quantum launch daemons" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 15: Should use pgrep to check processes
    ((total_tests++))
    if assert_pattern_in_file "pgrep -f" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Uses pgrep to check processes"
        echo "✅ Test 15 PASSED: Uses pgrep to check processes" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not use pgrep to check processes"
        echo "❌ Test 15 FAILED: Does not use pgrep to check processes" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 16: Should check task status counts
    ((total_tests++))
    if assert_pattern_in_file "completed.*in_progress.*queued" "${AGENT_SCRIPT}" || (assert_pattern_in_file "completed=" "${AGENT_SCRIPT}" && assert_pattern_in_file "in_progress=" "${AGENT_SCRIPT}" && assert_pattern_in_file "queued=" "${AGENT_SCRIPT}"); then
        echo "✅ Test 16 PASSED: Checks task status counts"
        echo "✅ Test 16 PASSED: Checks task status counts" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Does not check task status counts"
        echo "❌ Test 16 FAILED: Does not check task status counts" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 17: Should handle missing task queue file
    ((total_tests++))
    if assert_pattern_in_file "not found" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Handles missing task queue file"
        echo "✅ Test 17 PASSED: Handles missing task queue file" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Does not handle missing task queue file"
        echo "❌ Test 17 FAILED: Does not handle missing task queue file" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 18: Should display agent process count
    ((total_tests++))
    if assert_pattern_in_file "Agent processes running:" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Displays agent process count"
        echo "✅ Test 18 PASSED: Displays agent process count" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Does not display agent process count"
        echo "❌ Test 18 FAILED: Does not display agent process count" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 19: Should save report to log file
    ((total_tests++))
    if assert_pattern_in_file "Report saved to:" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Saves report to log file"
        echo "✅ Test 19 PASSED: Saves report to log file" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Does not save report to log file"
        echo "❌ Test 19 FAILED: Does not save report to log file" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Test 20: Should have end report marker
    ((total_tests++))
    if assert_pattern_in_file "End Report" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Has end report marker"
        echo "✅ Test 20 PASSED: Has end report marker" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Missing end report marker"
        echo "❌ Test 20 FAILED: Missing end report marker" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for check_persistence.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_check_persistence.txt"
    fi
}

# Run the tests
run_tests
