#!/bin/bash
# Test Suite for monitor_agents.sh
# Comprehensive structural validation tests

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/../shell_test_framework.sh"

AGENT_SCRIPT="$SCRIPT_DIR/../agents/monitor_agents.sh"

run_tests() {
    echo "Running tests for monitor_agents.sh..."

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: monitor_agents.sh is executable"
        echo "✅ Test 1 PASSED: monitor_agents.sh is executable" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: monitor_agents.sh is not executable"
        echo "❌ Test 1 FAILED: monitor_agents.sh is not executable" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 2: Should define SCRIPT_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable"
        echo "✅ Test 2 PASSED: Defines SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable"
        echo "❌ Test 2 FAILED: Does not define SCRIPT_DIR variable" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 3: Should define LOG_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Defines LOG_FILE variable"
        echo "✅ Test 3 PASSED: Defines LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not define LOG_FILE variable"
        echo "❌ Test 3 FAILED: Does not define LOG_FILE variable" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 4: Should define STATUS_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "STATUS_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines STATUS_FILE variable"
        echo "✅ Test 4 PASSED: Defines STATUS_FILE variable" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define STATUS_FILE variable"
        echo "❌ Test 4 FAILED: Does not define STATUS_FILE variable" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 5: Should define TASK_QUEUE_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "TASK_QUEUE_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Defines TASK_QUEUE_FILE variable"
        echo "✅ Test 5 PASSED: Defines TASK_QUEUE_FILE variable" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not define TASK_QUEUE_FILE variable"
        echo "❌ Test 5 FAILED: Does not define TASK_QUEUE_FILE variable" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 6: Should define AGENTS array
    ((total_tests++))
    if assert_pattern_in_file "AGENTS=(" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Defines AGENTS array"
        echo "✅ Test 6 PASSED: Defines AGENTS array" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not define AGENTS array"
        echo "❌ Test 6 FAILED: Does not define AGENTS array" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 7: Should define start_agent function
    ((total_tests++))
    if assert_pattern_in_file "start_agent\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Defines start_agent function"
        echo "✅ Test 7 PASSED: Defines start_agent function" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not define start_agent function"
        echo "❌ Test 7 FAILED: Does not define start_agent function" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 8: Should define ensure_agents_running function
    ((total_tests++))
    if assert_pattern_in_file "ensure_agents_running\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Defines ensure_agents_running function"
        echo "✅ Test 8 PASSED: Defines ensure_agents_running function" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Does not define ensure_agents_running function"
        echo "❌ Test 8 FAILED: Does not define ensure_agents_running function" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 9: Should define check_repeated_failures function
    ((total_tests++))
    if assert_pattern_in_file "check_repeated_failures\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Defines check_repeated_failures function"
        echo "✅ Test 9 PASSED: Defines check_repeated_failures function" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Does not define check_repeated_failures function"
        echo "❌ Test 9 FAILED: Does not define check_repeated_failures function" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 10: Should define handle_stuck_tasks function
    ((total_tests++))
    if assert_pattern_in_file "handle_stuck_tasks\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Defines handle_stuck_tasks function"
        echo "✅ Test 10 PASSED: Defines handle_stuck_tasks function" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not define handle_stuck_tasks function"
        echo "❌ Test 10 FAILED: Does not define handle_stuck_tasks function" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 11: Should define monitor_long_running_processes function
    ((total_tests++))
    if assert_pattern_in_file "monitor_long_running_processes\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Defines monitor_long_running_processes function"
        echo "✅ Test 11 PASSED: Defines monitor_long_running_processes function" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not define monitor_long_running_processes function"
        echo "❌ Test 11 FAILED: Does not define monitor_long_running_processes function" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 12: Should source shared_functions.sh
    ((total_tests++))
    if assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Sources shared_functions.sh"
        echo "✅ Test 12 PASSED: Sources shared_functions.sh" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not source shared_functions.sh"
        echo "❌ Test 12 FAILED: Does not source shared_functions.sh" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 13: Should have pgrep command for process checking
    ((total_tests++))
    if assert_pattern_in_file "pgrep" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Has pgrep command for process checking"
        echo "✅ Test 13 PASSED: Has pgrep command for process checking" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not have pgrep command for process checking"
        echo "❌ Test 13 FAILED: Does not have pgrep command for process checking" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 14: Should have grep command for failure detection
    ((total_tests++))
    if assert_pattern_in_file "grep.*failures" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Has grep command for failure detection"
        echo "✅ Test 14 PASSED: Has grep command for failure detection" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not have grep command for failure detection"
        echo "❌ Test 14 FAILED: Does not have grep command for failure detection" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 15: Should have ps command for process monitoring
    ((total_tests++))
    if assert_pattern_in_file "ps -eo" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Has ps command for process monitoring"
        echo "✅ Test 15 PASSED: Has ps command for process monitoring" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not have ps command for process monitoring"
        echo "❌ Test 15 FAILED: Does not have ps command for process monitoring" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 16: Should have Python code for stuck task handling
    ((total_tests++))
    if assert_pattern_in_file "python3.*TASK_QUEUE_FILE" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Has Python code for stuck task handling"
        echo "✅ Test 16 PASSED: Has Python code for stuck task handling" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Does not have Python code for stuck task handling"
        echo "❌ Test 16 FAILED: Does not have Python code for stuck task handling" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 17: Should have Python code for status summary
    ((total_tests++))
    if assert_pattern_in_file "python3.*STATUS_FILE" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Has Python code for status summary"
        echo "✅ Test 17 PASSED: Has Python code for status summary" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Does not have Python code for status summary"
        echo "❌ Test 17 FAILED: Does not have Python code for status summary" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 18: Should have add_task_to_queue function calls
    ((total_tests++))
    if assert_pattern_in_file "add_task_to_queue" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Has add_task_to_queue function calls"
        echo "✅ Test 18 PASSED: Has add_task_to_queue function calls" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Does not have add_task_to_queue function calls"
        echo "❌ Test 18 FAILED: Does not have add_task_to_queue function calls" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 19: Should have update_agent_status function calls
    ((total_tests++))
    if assert_pattern_in_file "update_agent_status" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Has update_agent_status function calls"
        echo "✅ Test 19 PASSED: Has update_agent_status function calls" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Does not have update_agent_status function calls"
        echo "❌ Test 19 FAILED: Does not have update_agent_status function calls" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Test 20: Should have function calls at the end
    ((total_tests++))
    if assert_pattern_in_file "ensure_agents_running" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Has function calls at the end"
        echo "✅ Test 20 PASSED: Has function calls at the end" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Does not have function calls at the end"
        echo "❌ Test 20 FAILED: Does not have function calls at the end" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for monitor_agents.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_monitor_agents.txt"
    fi
}

# Run the tests
run_tests
