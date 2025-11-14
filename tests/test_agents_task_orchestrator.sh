#!/bin/bash
# Test suite for task_orchestrator.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS_FILE="${SCRIPT_DIR}/test_results_task_orchestrator.txt"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/task_orchestrator.sh"

# Function to run all tests
run_tests() {
    echo "Running tests for task_orchestrator.sh..."
    echo "Test Results for task_orchestrator.sh" >"${TEST_RESULTS_FILE}"
    echo "Generated: $(date)" >>"${TEST_RESULTS_FILE}"
    echo "==========================================" >>"${TEST_RESULTS_FILE}"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: task_orchestrator.sh is executable"
        echo "✅ Test 1 PASSED: task_orchestrator.sh is executable" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: task_orchestrator.sh is not executable"
        echo "❌ Test 1 FAILED: task_orchestrator.sh is not executable" >>"${TEST_RESULTS_FILE}"
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

    # Test 3: Should define AGENT_NAME variable
    ((total_tests++))
    if assert_pattern_in_file "AGENT_NAME=\"TaskOrchestrator\"" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Defines AGENT_NAME variable"
        echo "✅ Test 3 PASSED: Defines AGENT_NAME variable" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not define AGENT_NAME variable"
        echo "❌ Test 3 FAILED: Does not define AGENT_NAME variable" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 4: Should define LOG_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "LOG_FILE=.*task_orchestrator.log" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines LOG_FILE variable"
        echo "✅ Test 4 PASSED: Defines LOG_FILE variable" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define LOG_FILE variable"
        echo "❌ Test 4 FAILED: Does not define LOG_FILE variable" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 5: Should define TASK_QUEUE_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "TASK_QUEUE_FILE=.*task_queue.json" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Defines TASK_QUEUE_FILE variable"
        echo "✅ Test 5 PASSED: Defines TASK_QUEUE_FILE variable" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not define TASK_QUEUE_FILE variable"
        echo "❌ Test 5 FAILED: Does not define TASK_QUEUE_FILE variable" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 6: Should define AGENT_STATUS_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "AGENT_STATUS_FILE=.*agent_status.json" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Defines AGENT_STATUS_FILE variable"
        echo "✅ Test 6 PASSED: Defines AGENT_STATUS_FILE variable" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not define AGENT_STATUS_FILE variable"
        echo "❌ Test 6 FAILED: Does not define AGENT_STATUS_FILE variable" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 7: Should define AGENT_CAPABILITIES associative array
    ((total_tests++))
    if assert_pattern_in_file "declare -A AGENT_CAPABILITIES" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Defines AGENT_CAPABILITIES array"
        echo "✅ Test 7 PASSED: Defines AGENT_CAPABILITIES array" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not define AGENT_CAPABILITIES array"
        echo "❌ Test 7 FAILED: Does not define AGENT_CAPABILITIES array" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 8: Should define AGENT_PRIORITY associative array
    ((total_tests++))
    if assert_pattern_in_file "declare -A AGENT_PRIORITY" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Defines AGENT_PRIORITY array"
        echo "✅ Test 8 PASSED: Defines AGENT_PRIORITY array" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Does not define AGENT_PRIORITY array"
        echo "❌ Test 8 FAILED: Does not define AGENT_PRIORITY array" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 9: Should define TASK_REQUIREMENTS associative array
    ((total_tests++))
    if assert_pattern_in_file "declare -A TASK_REQUIREMENTS" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Defines TASK_REQUIREMENTS array"
        echo "✅ Test 9 PASSED: Defines TASK_REQUIREMENTS array" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Does not define TASK_REQUIREMENTS array"
        echo "❌ Test 9 FAILED: Does not define TASK_REQUIREMENTS array" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 10: Should create COMMUNICATION_DIR
    ((total_tests++))
    if assert_pattern_in_file "mkdir -p.*COMMUNICATION_DIR" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Creates COMMUNICATION_DIR"
        echo "✅ Test 10 PASSED: Creates COMMUNICATION_DIR" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not create COMMUNICATION_DIR"
        echo "❌ Test 10 FAILED: Does not create COMMUNICATION_DIR" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 11: Should initialize task queue JSON file
    ((total_tests++))
    if assert_pattern_in_file "echo.*tasks.*completed.*failed" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Initializes task queue JSON"
        echo "✅ Test 11 PASSED: Initializes task queue JSON" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not initialize task queue JSON"
        echo "❌ Test 11 FAILED: Does not initialize task queue JSON" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 12: Should initialize agent status JSON file
    ((total_tests++))
    if assert_pattern_in_file "echo.*agents" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Initializes agent status JSON"
        echo "✅ Test 12 PASSED: Initializes agent status JSON" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not initialize agent status JSON"
        echo "❌ Test 12 FAILED: Does not initialize agent status JSON" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 13: Should define log_message function
    ((total_tests++))
    if assert_pattern_in_file "log_message\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Defines log_message function"
        echo "✅ Test 13 PASSED: Defines log_message function" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not define log_message function"
        echo "❌ Test 13 FAILED: Does not define log_message function" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 14: Should define update_agent_status function
    ((total_tests++))
    if assert_pattern_in_file "update_agent_status\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Defines update_agent_status function"
        echo "✅ Test 14 PASSED: Defines update_agent_status function" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not define update_agent_status function"
        echo "❌ Test 14 FAILED: Does not define update_agent_status function" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 15: Should define add_task function
    ((total_tests++))
    if assert_pattern_in_file "add_task\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Defines add_task function"
        echo "✅ Test 15 PASSED: Defines add_task function" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not define add_task function"
        echo "❌ Test 15 FAILED: Does not define add_task function" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 16: Should define select_best_agent function
    ((total_tests++))
    if assert_pattern_in_file "select_best_agent\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Defines select_best_agent function"
        echo "✅ Test 16 PASSED: Defines select_best_agent function" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Does not define select_best_agent function"
        echo "❌ Test 16 FAILED: Does not define select_best_agent function" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 17: Should define get_agent_status function
    ((total_tests++))
    if assert_pattern_in_file "get_agent_status\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Defines get_agent_status function"
        echo "✅ Test 17 PASSED: Defines get_agent_status function" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Does not define get_agent_status function"
        echo "❌ Test 17 FAILED: Does not define get_agent_status function" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 18: Should define notify_agent function
    ((total_tests++))
    if assert_pattern_in_file "notify_agent\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Defines notify_agent function"
        echo "✅ Test 18 PASSED: Defines notify_agent function" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Does not define notify_agent function"
        echo "❌ Test 18 FAILED: Does not define notify_agent function" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 19: Should have main orchestration loop
    ((total_tests++))
    if assert_pattern_in_file "while true; do" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Has main orchestration loop"
        echo "✅ Test 19 PASSED: Has main orchestration loop" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Does not have main orchestration loop"
        echo "❌ Test 19 FAILED: Does not have main orchestration loop" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 20: Should log startup message
    ((total_tests++))
    if assert_pattern_in_file "Task Orchestrator starting" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Logs startup message"
        echo "✅ Test 20 PASSED: Logs startup message" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Does not log startup message"
        echo "❌ Test 20 FAILED: Does not log startup message" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for task_orchestrator.sh:"
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
        echo "✅ All tests PASSED for task_orchestrator.sh"
        echo "✅ All tests PASSED for task_orchestrator.sh" >>"${TEST_RESULTS_FILE}"
        return 0
    else
        echo "❌ ${failed_tests} test(s) FAILED for task_orchestrator.sh"
        echo "❌ ${failed_tests} test(s) FAILED for task_orchestrator.sh" >>"${TEST_RESULTS_FILE}"
        return 1
    fi
}

# Run the tests
run_tests
