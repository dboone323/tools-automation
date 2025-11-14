#!/bin/bash
# Test suite for clear_alerts.sh
# This test suite validates the alert clearing functionality

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shell_test_framework.sh
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/clear_alerts.sh"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Script should define SCRIPT_DIR variable
test_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

# Test 3: Script should define TASK_QUEUE_FILE variable
test_defines_task_queue_file() {
    assert_pattern_in_file "TASK_QUEUE_FILE=" "${AGENT_SCRIPT}"
}

# Test 4: Script should define ALERT_LOG variable
test_defines_alert_log() {
    assert_pattern_in_file "ALERT_LOG=" "${AGENT_SCRIPT}"
}

# Test 5: Script should check if task queue file exists
test_checks_task_queue_exists() {
    assert_pattern_in_file '\[\[ -f "\$TASK_QUEUE_FILE" \]\]' "${AGENT_SCRIPT}"
}

# Test 6: Script should use python3 for JSON processing
test_uses_python3_for_json() {
    assert_pattern_in_file "python3 -" "${AGENT_SCRIPT}"
}

# Test 7: Script should load JSON data from task queue
test_loads_json_data() {
    assert_pattern_in_file "json\.load" "${AGENT_SCRIPT}"
}

# Test 8: Script should filter out alert tasks
test_filters_alert_tasks() {
    assert_pattern_in_file "type.*alert" "${AGENT_SCRIPT}"
}

# Test 9: Script should check for assigned_agent user_attention
test_checks_assigned_agent() {
    assert_pattern_in_file "assigned_agent.*user_attention" "${AGENT_SCRIPT}"
}

# Test 10: Script should use tempfile for safe writing
test_uses_tempfile() {
    assert_pattern_in_file "NamedTemporaryFile" "${AGENT_SCRIPT}"
}

# Test 11: Script should use atomic file operations
test_uses_atomic_operations() {
    assert_pattern_in_file "os\.rename" "${AGENT_SCRIPT}"
}

# Test 12: Script should provide feedback on cleared tasks
test_provides_feedback() {
    assert_pattern_in_file "Cleared.*alert tasks" "${AGENT_SCRIPT}"
}

# Test 13: Script should handle case when no alerts to clear
test_handles_no_alerts() {
    assert_pattern_in_file "No alert tasks to clear" "${AGENT_SCRIPT}"
}

# Test 14: Script should handle missing tasks in queue
test_handles_missing_tasks() {
    assert_pattern_in_file "No tasks in queue" "${AGENT_SCRIPT}"
}

# Test 15: Script should handle missing task queue file
test_handles_missing_queue_file() {
    assert_pattern_in_file "No task queue file found" "${AGENT_SCRIPT}"
}

# Test 16: Script should archive alert log
test_archives_alert_log() {
    assert_pattern_in_file "mv.*ALERT_LOG" "${AGENT_SCRIPT}"
}

# Test 17: Script should check if alert log exists before archiving
test_checks_alert_log_exists() {
    assert_pattern_in_file '\[\[ -f "\$ALERT_LOG" \]\]' "${AGENT_SCRIPT}"
}

# Test 18: Script should use timestamp in backup filename
test_uses_timestamp_in_backup() {
    assert_pattern_in_file "\$\(date" "${AGENT_SCRIPT}"
}

# Test 19: Script should provide confirmation when archiving
test_provides_archive_confirmation() {
    assert_pattern_in_file "Archived alert log" "${AGENT_SCRIPT}"
}

# Test 20: Script should end with completion message
test_ends_with_completion() {
    assert_pattern_in_file "echo \"Done.\"" "${AGENT_SCRIPT}"
}

# Run all tests
run_tests() {
    echo "Running tests for clear_alerts.sh..."
    echo "Test Results for clear_alerts.sh" >"${SCRIPT_DIR}/test_results_clear_alerts.txt"
    echo "Generated: $(date)" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: clear_alerts.sh is executable"
        echo "✅ Test 1 PASSED: clear_alerts.sh is executable" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: clear_alerts.sh is not executable"
        echo "❌ Test 1 FAILED: clear_alerts.sh is not executable" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 2: Should define SCRIPT_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable"
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable"
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 3: Should define TASK_QUEUE_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "TASK_QUEUE_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Defines TASK_QUEUE_FILE variable"
        echo "✅ Test 3 PASSED: Defines TASK_QUEUE_FILE variable" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not define TASK_QUEUE_FILE variable"
        echo "❌ Test 3 FAILED: Does not define TASK_QUEUE_FILE variable" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 4: Should define ALERT_LOG variable
    ((total_tests++))
    if assert_pattern_in_file "ALERT_LOG=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines ALERT_LOG variable"
        echo "✅ Test 4 PASSED: Defines ALERT_LOG variable" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define ALERT_LOG variable"
        echo "❌ Test 4 FAILED: Does not define ALERT_LOG variable" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 5: Should check if task queue file exists
    ((total_tests++))
    if assert_pattern_in_file '\[\[ -f "\$TASK_QUEUE_FILE" \]\]' "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Checks if task queue file exists"
        echo "✅ Test 5 PASSED: Checks if task queue file exists" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not check if task queue file exists"
        echo "❌ Test 5 FAILED: Does not check if task queue file exists" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 6: Should use python3 for JSON processing
    ((total_tests++))
    if assert_pattern_in_file "python3 -" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Uses python3 for JSON processing"
        echo "✅ Test 6 PASSED: Uses python3 for JSON processing" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not use python3 for JSON processing"
        echo "❌ Test 6 FAILED: Does not use python3 for JSON processing" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 7: Should load JSON data from task queue
    ((total_tests++))
    if assert_pattern_in_file "json\.load" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Loads JSON data from task queue"
        echo "✅ Test 7 PASSED: Loads JSON data from task queue" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not load JSON data from task queue"
        echo "❌ Test 7 FAILED: Does not load JSON data from task queue" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 8: Should filter out alert tasks
    ((total_tests++))
    if assert_pattern_in_file "type.*alert" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Filters out alert tasks"
        echo "✅ Test 8 PASSED: Filters out alert tasks" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Does not filter out alert tasks"
        echo "❌ Test 8 FAILED: Does not filter out alert tasks" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 9: Should check for assigned_agent user_attention
    ((total_tests++))
    if assert_pattern_in_file "assigned_agent.*user_attention" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Checks for assigned_agent user_attention"
        echo "✅ Test 9 PASSED: Checks for assigned_agent user_attention" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Does not check for assigned_agent user_attention"
        echo "❌ Test 9 FAILED: Does not check for assigned_agent user_attention" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 10: Should use tempfile for safe writing
    ((total_tests++))
    if assert_pattern_in_file "NamedTemporaryFile" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Uses tempfile for safe writing"
        echo "✅ Test 10 PASSED: Uses tempfile for safe writing" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not use tempfile for safe writing"
        echo "❌ Test 10 FAILED: Does not use tempfile for safe writing" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 11: Should use atomic file operations
    ((total_tests++))
    if assert_pattern_in_file "os\.rename" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Uses atomic file operations"
        echo "✅ Test 11 PASSED: Uses atomic file operations" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not use atomic file operations"
        echo "❌ Test 11 FAILED: Does not use atomic file operations" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 12: Should provide feedback on cleared tasks
    ((total_tests++))
    if assert_pattern_in_file "Cleared.*alert tasks" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Provides feedback on cleared tasks"
        echo "✅ Test 12 PASSED: Provides feedback on cleared tasks" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not provide feedback on cleared tasks"
        echo "❌ Test 12 FAILED: Does not provide feedback on cleared tasks" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 13: Should handle case when no alerts to clear
    ((total_tests++))
    if assert_pattern_in_file "No alert tasks to clear" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Handles case when no alerts to clear"
        echo "✅ Test 13 PASSED: Handles case when no alerts to clear" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not handle case when no alerts to clear"
        echo "❌ Test 13 FAILED: Does not handle case when no alerts to clear" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 14: Should handle missing tasks in queue
    ((total_tests++))
    if assert_pattern_in_file "No tasks in queue" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Handles missing tasks in queue"
        echo "✅ Test 14 PASSED: Handles missing tasks in queue" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not handle missing tasks in queue"
        echo "❌ Test 14 FAILED: Does not handle missing tasks in queue" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 15: Should handle missing task queue file
    ((total_tests++))
    if assert_pattern_in_file "No task queue file found" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Handles missing task queue file"
        echo "✅ Test 15 PASSED: Handles missing task queue file" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not handle missing task queue file"
        echo "❌ Test 15 FAILED: Does not handle missing task queue file" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 16: Should archive alert log
    ((total_tests++))
    if assert_pattern_in_file "mv.*ALERT_LOG" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Archives alert log"
        echo "✅ Test 16 PASSED: Archives alert log" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Does not archive alert log"
        echo "❌ Test 16 FAILED: Does not archive alert log" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 17: Should check if alert log exists before archiving
    ((total_tests++))
    if assert_pattern_in_file '\[\[ -f "\$ALERT_LOG" \]\]' "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Checks if alert log exists before archiving"
        echo "✅ Test 17 PASSED: Checks if alert log exists before archiving" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Does not check if alert log exists before archiving"
        echo "❌ Test 17 FAILED: Does not check if alert log exists before archiving" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 18: Should use timestamp in backup filename
    ((total_tests++))
    if assert_pattern_in_file "date" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Uses timestamp in backup filename"
        echo "✅ Test 18 PASSED: Uses timestamp in backup filename" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Does not use timestamp in backup filename"
        echo "❌ Test 18 FAILED: Does not use timestamp in backup filename" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 19: Should provide confirmation when archiving
    ((total_tests++))
    if assert_pattern_in_file "Archived alert log" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Provides confirmation when archiving"
        echo "✅ Test 19 PASSED: Provides confirmation when archiving" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Does not provide confirmation when archiving"
        echo "❌ Test 19 FAILED: Does not provide confirmation when archiving" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Test 20: Should end with completion message
    ((total_tests++))
    if assert_pattern_in_file "echo \"Done.\"" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Ends with completion message"
        echo "✅ Test 20 PASSED: Ends with completion message" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Does not end with completion message"
        echo "❌ Test 20 FAILED: Does not end with completion message" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for clear_alerts.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_clear_alerts.txt"
    fi
}

# Run the tests
run_tests
