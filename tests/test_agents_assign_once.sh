#!/bin/bash
# Test suite for assign_once.sh
# This test suite validates the one-shot task assigner functionality

# Source the shell test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=../shell_test_framework.sh
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/assign_once.sh"

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Script should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"
}

# Test 3: Script should define ROOT_DIR variable
test_defines_root_dir() {
    assert_pattern_in_file "ROOT_DIR=" "${AGENT_SCRIPT}"
}

# Test 4: Script should define TASK_QUEUE_FILE variable
test_defines_task_queue_file() {
    assert_pattern_in_file "TASK_QUEUE_FILE=" "${AGENT_SCRIPT}"
}

# Test 5: Script should define AGENT_STATUS_FILE variable
test_defines_agent_status_file() {
    assert_pattern_in_file "AGENT_STATUS_FILE=" "${AGENT_SCRIPT}"
}

# Test 6: Script should define COMM_DIR variable
test_defines_comm_dir() {
    assert_pattern_in_file "COMM_DIR=" "${AGENT_SCRIPT}"
}

# Test 7: Script should define KNOWN_AGENTS array
test_defines_known_agents() {
    assert_pattern_in_file "KNOWN_AGENTS=" "${AGENT_SCRIPT}"
}

# Test 8: Script should have is_known_agent function
test_has_is_known_agent_function() {
    assert_pattern_in_file "is_known_agent\(\)" "${AGENT_SCRIPT}"
}

# Test 9: Script should have map_alias function
test_has_map_alias_function() {
    assert_pattern_in_file "map_alias\(\)" "${AGENT_SCRIPT}"
}

# Test 10: Script should check for jq command
test_checks_jq_command() {
    assert_pattern_in_file "command -v jq" "${AGENT_SCRIPT}"
}

# Test 11: Script should initialize assigned_count variable
test_initializes_assigned_count() {
    assert_pattern_in_file "assigned_count=0" "${AGENT_SCRIPT}"
}

# Test 12: Script should initialize skipped_count variable
test_initializes_skipped_count() {
    assert_pattern_in_file "skipped_count=0" "${AGENT_SCRIPT}"
}

# Test 13: Script should use jq to get queued task IDs
test_uses_jq_for_queued_ids() {
    assert_pattern_in_file "jq -r.*queued.*id" "${AGENT_SCRIPT}"
}

# Test 14: Script should loop through queued task IDs
test_loops_through_queued_ids() {
    assert_pattern_in_file "for task_id in.*queued_ids" "${AGENT_SCRIPT}"
}

# Test 15: Script should get assigned_agent from task
test_gets_assigned_agent() {
    assert_pattern_in_file "assigned_agent=.*jq.*assigned_agent" "${AGENT_SCRIPT}"
}

# Test 16: Script should call map_alias function
test_calls_map_alias() {
    assert_pattern_in_file "normalized_agent=.*map_alias" "${AGENT_SCRIPT}"
}

# Test 17: Script should check agent status
test_checks_agent_status() {
    assert_pattern_in_file "agent_status=.*jq.*agents.*status" "${AGENT_SCRIPT}"
}

# Test 18: Script should check for available agents
test_checks_available_agents() {
    assert_pattern_in_file "agent_status.*available" "${AGENT_SCRIPT}"
}

# Test 19: Script should create notification files
test_creates_notifications() {
    assert_pattern_in_file "echo.*execute_task.*notification\.txt" "${AGENT_SCRIPT}"
}

# Test 20: Script should update task status to assigned
test_updates_task_status() {
    assert_pattern_in_file "jq.*status.*assigned" "${AGENT_SCRIPT}"
}

# Run all tests
run_tests() {
    echo "Running tests for assign_once.sh..."
    echo "Test Results for assign_once.sh" >"${SCRIPT_DIR}/test_results_assign_once.txt"
    echo "Generated: $(date)" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_assign_once.txt"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: assign_once.sh is executable"
        echo "✅ Test 1 PASSED: assign_once.sh is executable" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: assign_once.sh is not executable"
        echo "❌ Test 1 FAILED: assign_once.sh is not executable" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 2: Should source shared_functions.sh
    ((total_tests++))
    if assert_pattern_in_file "source.*shared_functions\.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Sources shared_functions.sh"
        echo "✅ Test 2 PASSED: Sources shared_functions.sh" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not source shared_functions.sh"
        echo "❌ Test 2 FAILED: Does not source shared_functions.sh" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 3: Should define ROOT_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "ROOT_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Defines ROOT_DIR variable"
        echo "✅ Test 3 PASSED: Defines ROOT_DIR variable" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not define ROOT_DIR variable"
        echo "❌ Test 3 FAILED: Does not define ROOT_DIR variable" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 4: Should define TASK_QUEUE_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "TASK_QUEUE_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines TASK_QUEUE_FILE variable"
        echo "✅ Test 4 PASSED: Defines TASK_QUEUE_FILE variable" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define TASK_QUEUE_FILE variable"
        echo "❌ Test 4 FAILED: Does not define TASK_QUEUE_FILE variable" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 5: Should define AGENT_STATUS_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "AGENT_STATUS_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Defines AGENT_STATUS_FILE variable"
        echo "✅ Test 5 PASSED: Defines AGENT_STATUS_FILE variable" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not define AGENT_STATUS_FILE variable"
        echo "❌ Test 5 FAILED: Does not define AGENT_STATUS_FILE variable" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 6: Script should define COMM_DIR variable
    ((total_tests++))
    if assert_pattern_in_file "COMM_DIR=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Defines COMM_DIR variable"
        echo "✅ Test 6 PASSED: Defines COMM_DIR variable" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not define COMM_DIR variable"
        echo "❌ Test 6 FAILED: Does not define COMM_DIR variable" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 7: Should define KNOWN_AGENTS array
    ((total_tests++))
    if assert_pattern_in_file "KNOWN_AGENTS=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Defines KNOWN_AGENTS array"
        echo "✅ Test 7 PASSED: Defines KNOWN_AGENTS array" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not define KNOWN_AGENTS array"
        echo "❌ Test 7 FAILED: Does not define KNOWN_AGENTS array" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 8: Should have is_known_agent function
    ((total_tests++))
    if assert_pattern_in_file "is_known_agent\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Has is_known_agent function"
        echo "✅ Test 8 PASSED: Has is_known_agent function" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Missing is_known_agent function"
        echo "❌ Test 8 FAILED: Missing is_known_agent function" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 9: Should have map_alias function
    ((total_tests++))
    if assert_pattern_in_file "map_alias\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Has map_alias function"
        echo "✅ Test 9 PASSED: Has map_alias function" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Missing map_alias function"
        echo "❌ Test 9 FAILED: Missing map_alias function" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 10: Should check for jq command
    ((total_tests++))
    if assert_pattern_in_file "command -v jq" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Checks for jq command availability"
        echo "✅ Test 10 PASSED: Checks for jq command availability" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not check for jq command"
        echo "❌ Test 10 FAILED: Does not check for jq command" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 11: Should initialize assigned_count variable
    ((total_tests++))
    if assert_pattern_in_file "assigned_count=0" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Initializes assigned_count variable"
        echo "✅ Test 11 PASSED: Initializes assigned_count variable" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not initialize assigned_count"
        echo "❌ Test 11 FAILED: Does not initialize assigned_count" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 12: Should initialize skipped_count variable
    ((total_tests++))
    if assert_pattern_in_file "skipped_count=0" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Initializes skipped_count variable"
        echo "✅ Test 12 PASSED: Initializes skipped_count variable" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not initialize skipped_count"
        echo "❌ Test 12 FAILED: Does not initialize skipped_count" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 13: Should use jq to get queued task IDs
    ((total_tests++))
    if assert_pattern_in_file "jq -r.*queued.*id" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Uses jq to get queued task IDs"
        echo "✅ Test 13 PASSED: Uses jq to get queued task IDs" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not use jq for queued task IDs"
        echo "❌ Test 13 FAILED: Does not use jq for queued task IDs" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 14: Should loop through queued task IDs
    ((total_tests++))
    if assert_pattern_in_file "for task_id in.*queued_ids" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Loops through queued task IDs"
        echo "✅ Test 14 PASSED: Loops through queued task IDs" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not loop through queued task IDs"
        echo "❌ Test 14 FAILED: Does not loop through queued task IDs" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 15: Should get assigned_agent from task
    ((total_tests++))
    if assert_pattern_in_file "assigned_agent=.*jq.*assigned_agent" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Gets assigned_agent from task data"
        echo "✅ Test 15 PASSED: Gets assigned_agent from task data" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not get assigned_agent from task"
        echo "❌ Test 15 FAILED: Does not get assigned_agent from task" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 16: Should call map_alias function
    ((total_tests++))
    if assert_pattern_in_file "normalized_agent=.*map_alias" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Calls map_alias function to normalize agent names"
        echo "✅ Test 16 PASSED: Calls map_alias function to normalize agent names" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Does not call map_alias function"
        echo "❌ Test 16 FAILED: Does not call map_alias function" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 17: Should check agent status
    ((total_tests++))
    if assert_pattern_in_file "agent_status=.*jq.*agents.*status" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Checks agent status from status file"
        echo "✅ Test 17 PASSED: Checks agent status from status file" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Does not check agent status"
        echo "❌ Test 17 FAILED: Does not check agent status" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 18: Should check for available agents
    ((total_tests++))
    if assert_pattern_in_file "agent_status.*available" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Checks if agent status is available"
        echo "✅ Test 18 PASSED: Checks if agent status is available" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Does not check for available agents"
        echo "❌ Test 18 FAILED: Does not check for available agents" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 19: Should create notification files
    ((total_tests++))
    if assert_pattern_in_file "echo.*execute_task.*notification\.txt" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Creates notification files for available agents"
        echo "✅ Test 19 PASSED: Creates notification files for available agents" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Does not create notification files"
        echo "❌ Test 19 FAILED: Does not create notification files" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Test 20: Should update task status to assigned
    ((total_tests++))
    if assert_pattern_in_file "jq.*status.*assigned" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Updates task status to assigned"
        echo "✅ Test 20 PASSED: Updates task status to assigned" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Does not update task status to assigned"
        echo "❌ Test 20 FAILED: Does not update task status to assigned" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for assign_once.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_assign_once.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_assign_once.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_assign_once.txt"
    fi
}

# Run the tests
run_tests
