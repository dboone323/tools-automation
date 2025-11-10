#!/bin/bash
# Test suite for task_processor.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS_FILE="${SCRIPT_DIR}/test_results_task_processor.txt"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/task_processor.sh"

# Function to run all tests
run_tests() {
    echo "Running tests for task_processor.sh..."
    echo "Test Results for task_processor.sh" >"${TEST_RESULTS_FILE}"
    echo "Generated: $(date)" >>"${TEST_RESULTS_FILE}"
    echo "==========================================" >>"${TEST_RESULTS_FILE}"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: task_processor.sh is executable"
        echo "✅ Test 1 PASSED: task_processor.sh is executable" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: task_processor.sh is not executable"
        echo "❌ Test 1 FAILED: task_processor.sh is not executable" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 2: Should source shared_functions.sh
    ((total_tests++))
    if assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Sources shared_functions.sh"
        echo "✅ Test 2 PASSED: Sources shared_functions.sh" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not source shared_functions.sh"
        echo "❌ Test 2 FAILED: Does not source shared_functions.sh" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 3: Should define ACCELERATOR variable
    ((total_tests++))
    if assert_pattern_in_file "ACCELERATOR=.*task_accelerator.py" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Defines ACCELERATOR variable"
        echo "✅ Test 3 PASSED: Defines ACCELERATOR variable" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not define ACCELERATOR variable"
        echo "❌ Test 3 FAILED: Does not define ACCELERATOR variable" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 4: Should define LOG_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "LOG_FILE=.*task_processor.log" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines LOG_FILE variable"
        echo "✅ Test 4 PASSED: Defines LOG_FILE variable" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define LOG_FILE variable"
        echo "❌ Test 4 FAILED: Does not define LOG_FILE variable" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 5: Should define PID_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "PID_FILE=.*task_processor.pid" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Defines PID_FILE variable"
        echo "✅ Test 5 PASSED: Defines PID_FILE variable" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not define PID_FILE variable"
        echo "❌ Test 5 FAILED: Does not define PID_FILE variable" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 6: Should define log function
    ((total_tests++))
    if assert_pattern_in_file "log\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Defines log function"
        echo "✅ Test 6 PASSED: Defines log function" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not define log function"
        echo "❌ Test 6 FAILED: Does not define log function" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 7: Should define start_processor function
    ((total_tests++))
    if assert_pattern_in_file "start_processor\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Defines start_processor function"
        echo "✅ Test 7 PASSED: Defines start_processor function" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not define start_processor function"
        echo "❌ Test 7 FAILED: Does not define start_processor function" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 8: Should define stop_processor function
    ((total_tests++))
    if assert_pattern_in_file "stop_processor\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Defines stop_processor function"
        echo "✅ Test 8 PASSED: Defines stop_processor function" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Does not define stop_processor function"
        echo "❌ Test 8 FAILED: Does not define stop_processor function" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 9: Should define status_processor function
    ((total_tests++))
    if assert_pattern_in_file "status_processor\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Defines status_processor function"
        echo "✅ Test 9 PASSED: Defines status_processor function" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Does not define status_processor function"
        echo "❌ Test 9 FAILED: Does not define status_processor function" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 10: Should have case statement for command handling
    ((total_tests++))
    if assert_pattern_in_file "case.*start" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Has case statement for commands"
        echo "✅ Test 10 PASSED: Has case statement for commands" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not have case statement for commands"
        echo "❌ Test 10 FAILED: Does not have case statement for commands" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 11: Should check if already running in start_processor
    ((total_tests++))
    if assert_pattern_in_file "already running" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Checks if already running"
        echo "✅ Test 11 PASSED: Checks if already running" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not check if already running"
        echo "❌ Test 11 FAILED: Does not check if already running" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 12: Should start background process
    ((total_tests++))
    if assert_pattern_in_file "echo.*PID_FILE" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Starts background process"
        echo "✅ Test 12 PASSED: Starts background process" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not start background process"
        echo "❌ Test 12 FAILED: Does not start background process" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 13: Should run acceleration cycle
    ((total_tests++))
    if assert_pattern_in_file "python3.*ACCELERATOR.*cycle" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Runs acceleration cycle"
        echo "✅ Test 13 PASSED: Runs acceleration cycle" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not run acceleration cycle"
        echo "❌ Test 13 FAILED: Does not run acceleration cycle" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 14: Should run acceleration report
    ((total_tests++))
    if assert_pattern_in_file "python3.*ACCELERATOR.*report" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Runs acceleration report"
        echo "✅ Test 14 PASSED: Runs acceleration report" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not run acceleration report"
        echo "❌ Test 14 FAILED: Does not run acceleration report" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 15: Should sleep between cycles
    ((total_tests++))
    if assert_pattern_in_file "sleep 30" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Sleeps between cycles"
        echo "✅ Test 15 PASSED: Sleeps between cycles" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not sleep between cycles"
        echo "❌ Test 15 FAILED: Does not sleep between cycles" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 16: Should handle stop command
    ((total_tests++))
    if assert_pattern_in_file "stop_processor" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Handles stop command"
        echo "✅ Test 16 PASSED: Handles stop command" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Does not handle stop command"
        echo "❌ Test 16 FAILED: Does not handle stop command" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 17: Should handle restart command
    ((total_tests++))
    if assert_pattern_in_file "restart)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Handles restart command"
        echo "✅ Test 17 PASSED: Handles restart command" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Does not handle restart command"
        echo "❌ Test 17 FAILED: Does not handle restart command" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 18: Should handle status command
    ((total_tests++))
    if assert_pattern_in_file "status_processor" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Handles status command"
        echo "✅ Test 18 PASSED: Handles status command" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Does not handle status command"
        echo "❌ Test 18 FAILED: Does not handle status command" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 19: Should show usage for invalid command
    ((total_tests++))
    if assert_pattern_in_file "Usage.*start.*stop.*restart.*status" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Shows usage for invalid command"
        echo "✅ Test 19 PASSED: Shows usage for invalid command" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Does not show usage for invalid command"
        echo "❌ Test 19 FAILED: Does not show usage for invalid command" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 20: Should log processor started message
    ((total_tests++))
    if assert_pattern_in_file "Task processor started" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Logs processor started message"
        echo "✅ Test 20 PASSED: Logs processor started message" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Does not log processor started message"
        echo "❌ Test 20 FAILED: Does not log processor started message" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for task_processor.sh:"
    echo "Total tests: ${total_tests}"
    echo "Passed: ${passed_tests}"
    echo "Failed: ${failed_tests}"
    echo "Success rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${TEST_RESULTS_FILE}"
    echo "==========================================" >>"${TEST_RESULTS_FILE}"
    echo "Test Summary:" >>"${TEST_RESULTS_FILE}"
    echo "Total tests: ${total_tests}" >>"${TEST_RESULTS_FILE}"
    echo "Passed: ${passed_tests}" >>"${TEST_RESULTS_FILE}"
    echo "Failed: ${failed_tests}" >>"${TEST_RESULTS_FILE}"
    echo "Success rate: $((passed_tests * 100 / total_tests))%" >>"${TEST_RESULTS_FILE}"
    echo "==========================================" >>"${TEST_RESULTS_FILE}"

    # Return success if all tests passed
    if [[ ${failed_tests} -eq 0 ]]; then
        echo "✅ All tests PASSED for task_processor.sh"
        echo "✅ All tests PASSED for task_processor.sh" >>"${TEST_RESULTS_FILE}"
        return 0
    else
        echo "❌ ${failed_tests} test(s) FAILED for task_processor.sh"
        echo "❌ ${failed_tests} test(s) FAILED for task_processor.sh" >>"${TEST_RESULTS_FILE}"
        return 1
    fi
}

# Run the tests
run_tests
