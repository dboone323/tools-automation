#!/bin/bash
# Test suite for cron_setup.sh
# This test suite validates the cron job setup functionality

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shell_test_framework.sh
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/cron_setup.sh"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Script should define SCRIPT_DIR variable
test_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

# Test 3: Script should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"
}

# Test 4: Script should display header comment
test_displays_header_comment() {
    assert_pattern_in_file "# Agent Health Monitoring Cron Jobs" "${AGENT_SCRIPT}"
}

# Test 5: Script should show installation timestamp
test_shows_installation_timestamp() {
    assert_pattern_in_file "# Installed:" "${AGENT_SCRIPT}"
}

# Test 6: Script should preserve existing crontab
test_preserves_existing_crontab() {
    assert_pattern_in_file "crontab -l" "${AGENT_SCRIPT}"
}

# Test 7: Script should filter out existing agent monitoring jobs
test_filters_existing_jobs() {
    assert_pattern_in_file "grep -v.*Agent Health Monitoring" "${AGENT_SCRIPT}"
}

# Test 8: Script should filter out agent_analytics.sh jobs
test_filters_analytics_jobs() {
    assert_pattern_in_file "grep -v.*agent_analytics\.sh" "${AGENT_SCRIPT}"
}

# Test 9: Script should filter out health_check.sh jobs
test_filters_health_check_jobs() {
    assert_pattern_in_file "grep -v.*health_check\.sh" "${AGENT_SCRIPT}"
}

# Test 10: Script should filter out monitor_lock_timeouts.sh jobs
test_filters_lock_monitor_jobs() {
    assert_pattern_in_file "grep -v.*monitor_lock_timeouts\.sh" "${AGENT_SCRIPT}"
}

# Test 11: Script should add health check cron job
test_adds_health_check_cron() {
    assert_pattern_in_file "health_check\.sh" "${AGENT_SCRIPT}"
}

# Test 12: Script should schedule health checks hourly
test_schedules_health_checks_hourly() {
    assert_pattern_in_file "0 \* \* \* \*" "${AGENT_SCRIPT}"
}

# Test 13: Script should add lock timeout monitoring
test_adds_lock_timeout_monitoring() {
    assert_pattern_in_file "monitor_lock_timeouts\.sh" "${AGENT_SCRIPT}"
}

# Test 14: Script should schedule lock monitoring every 6 hours
test_schedules_lock_monitoring() {
    assert_pattern_in_file "0 \*/6 \* \* \*" "${AGENT_SCRIPT}"
}

# Test 15: Script should add analytics generation
test_adds_analytics_generation() {
    assert_pattern_in_file "agent_analytics\.sh" "${AGENT_SCRIPT}"
}

# Test 16: Script should schedule analytics daily at 2 AM
test_schedules_analytics_daily() {
    assert_pattern_in_file "0 2 \* \* \*" "${AGENT_SCRIPT}"
}

# Test 17: Script should use date command in analytics filename
test_uses_date_in_analytics_filename() {
    assert_pattern_in_file "date \+" "${AGENT_SCRIPT}"
}

# Test 18: Script should redirect health check output to log
test_redirects_health_check_output() {
    assert_pattern_in_file "health_check_cron\.log" "${AGENT_SCRIPT}"
}

# Test 19: Script should redirect lock monitor output to log
test_redirects_lock_monitor_output() {
    assert_pattern_in_file "lock_monitor_cron\.log" "${AGENT_SCRIPT}"
}

# Test 20: Script should redirect analytics output to log
test_redirects_analytics_output() {
    assert_pattern_in_file "analytics_cron\.log" "${AGENT_SCRIPT}"
}

# Run all tests
run_tests() {
    echo "Running tests for cron_setup.sh..."
    echo "Test Results for cron_setup.sh" >"${SCRIPT_DIR}/test_results_cron_setup.txt"
    echo "Generated: $(date)" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: cron_setup.sh is executable"
        echo "✅ Test 1 PASSED: cron_setup.sh is executable" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: cron_setup.sh is not executable"
        echo "❌ Test 1 FAILED: cron_setup.sh is not executable" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 2: Should define SCRIPT_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable"
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable"
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 3: Should source shared_functions.sh
    ((total_tests++))
    if assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Sources shared_functions.sh"
        echo "✅ Test 3 PASSED: Sources shared_functions.sh" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not source shared_functions.sh"
        echo "❌ Test 3 FAILED: Does not source shared_functions.sh" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 4: Should display header comment
    ((total_tests++))
    if assert_pattern_in_file "# Agent Health Monitoring Cron Jobs" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Displays header comment"
        echo "✅ Test 4 PASSED: Displays header comment" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not display header comment"
        echo "❌ Test 4 FAILED: Does not display header comment" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 5: Should show installation timestamp
    ((total_tests++))
    if assert_pattern_in_file "# Installed:" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Shows installation timestamp"
        echo "✅ Test 5 PASSED: Shows installation timestamp" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not show installation timestamp"
        echo "❌ Test 5 FAILED: Does not show installation timestamp" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 6: Should preserve existing crontab
    ((total_tests++))
    if assert_pattern_in_file "crontab -l" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Preserves existing crontab"
        echo "✅ Test 6 PASSED: Preserves existing crontab" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not preserve existing crontab"
        echo "❌ Test 6 FAILED: Does not preserve existing crontab" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 7: Should filter out existing agent monitoring jobs
    ((total_tests++))
    if assert_pattern_in_file "grep -v.*Agent Health Monitoring" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Filters out existing agent monitoring jobs"
        echo "✅ Test 7 PASSED: Filters out existing agent monitoring jobs" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not filter out existing agent monitoring jobs"
        echo "❌ Test 7 FAILED: Does not filter out existing agent monitoring jobs" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 8: Should filter out agent_analytics.sh jobs
    ((total_tests++))
    if assert_pattern_in_file "grep -v.*agent_analytics\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Filters out agent_analytics.sh jobs"
        echo "✅ Test 8 PASSED: Filters out agent_analytics.sh jobs" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Does not filter out agent_analytics.sh jobs"
        echo "❌ Test 8 FAILED: Does not filter out agent_analytics.sh jobs" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 9: Should filter out health_check.sh jobs
    ((total_tests++))
    if assert_pattern_in_file "grep -v.*health_check\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Filters out health_check.sh jobs"
        echo "✅ Test 9 PASSED: Filters out health_check.sh jobs" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Does not filter out health_check.sh jobs"
        echo "❌ Test 9 FAILED: Does not filter out health_check.sh jobs" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 10: Should filter out monitor_lock_timeouts.sh jobs
    ((total_tests++))
    if assert_pattern_in_file "grep -v.*monitor_lock_timeouts\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Filters out monitor_lock_timeouts.sh jobs"
        echo "✅ Test 10 PASSED: Filters out monitor_lock_timeouts.sh jobs" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not filter out monitor_lock_timeouts.sh jobs"
        echo "❌ Test 10 FAILED: Does not filter out monitor_lock_timeouts.sh jobs" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 11: Should add health check cron job
    ((total_tests++))
    if assert_pattern_in_file "health_check\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Adds health check cron job"
        echo "✅ Test 11 PASSED: Adds health check cron job" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not add health check cron job"
        echo "❌ Test 11 FAILED: Does not add health check cron job" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 12: Should schedule health checks hourly
    ((total_tests++))
    if assert_pattern_in_file "0 \* \* \* \*" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Schedules health checks hourly"
        echo "✅ Test 12 PASSED: Schedules health checks hourly" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not schedule health checks hourly"
        echo "❌ Test 12 FAILED: Does not schedule health checks hourly" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 13: Should add lock timeout monitoring
    ((total_tests++))
    if assert_pattern_in_file "monitor_lock_timeouts\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Adds lock timeout monitoring"
        echo "✅ Test 13 PASSED: Adds lock timeout monitoring" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not add lock timeout monitoring"
        echo "❌ Test 13 FAILED: Does not add lock timeout monitoring" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 14: Should schedule lock monitoring every 6 hours
    ((total_tests++))
    if assert_pattern_in_file "0 \*/6 \* \* \*" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Schedules lock monitoring every 6 hours"
        echo "✅ Test 14 PASSED: Schedules lock monitoring every 6 hours" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not schedule lock monitoring every 6 hours"
        echo "❌ Test 14 FAILED: Does not schedule lock monitoring every 6 hours" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 15: Should add analytics generation
    ((total_tests++))
    if assert_pattern_in_file "agent_analytics\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Adds analytics generation"
        echo "✅ Test 15 PASSED: Adds analytics generation" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not add analytics generation"
        echo "❌ Test 15 FAILED: Does not add analytics generation" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 16: Should schedule analytics daily at 2 AM
    ((total_tests++))
    if assert_pattern_in_file "0 2 \* \* \*" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Schedules analytics daily at 2 AM"
        echo "✅ Test 16 PASSED: Schedules analytics daily at 2 AM" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Does not schedule analytics daily at 2 AM"
        echo "❌ Test 16 FAILED: Does not schedule analytics daily at 2 AM" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 17: Should use date command in analytics filename
    ((total_tests++))
    if assert_pattern_in_file "date \+" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Uses date command in analytics filename"
        echo "✅ Test 17 PASSED: Uses date command in analytics filename" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Does not use date command in analytics filename"
        echo "❌ Test 17 FAILED: Does not use date command in analytics filename" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 18: Should redirect health check output to log
    ((total_tests++))
    if assert_pattern_in_file "health_check_cron\.log" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Redirects health check output to log"
        echo "✅ Test 18 PASSED: Redirects health check output to log" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Does not redirect health check output to log"
        echo "❌ Test 18 FAILED: Does not redirect health check output to log" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 19: Should redirect lock monitor output to log
    ((total_tests++))
    if assert_pattern_in_file "lock_monitor_cron\.log" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Redirects lock monitor output to log"
        echo "✅ Test 19 PASSED: Redirects lock monitor output to log" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Does not redirect lock monitor output to log"
        echo "❌ Test 19 FAILED: Does not redirect lock monitor output to log" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Test 20: Should redirect analytics output to log
    ((total_tests++))
    if assert_pattern_in_file "analytics_cron\.log" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Redirects analytics output to log"
        echo "✅ Test 20 PASSED: Redirects analytics output to log" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Does not redirect analytics output to log"
        echo "❌ Test 20 FAILED: Does not redirect analytics output to log" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for cron_setup.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_cron_setup.txt"
    fi
}

# Run the tests
run_tests
