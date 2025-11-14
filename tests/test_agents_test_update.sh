#!/bin/bash
# Test suite for test_update.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS_FILE="${SCRIPT_DIR}/test_results_test_update.txt"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../agents/test_update.sh"

# Function to run all tests
run_tests() {
    echo "Running tests for test_update.sh..."
    echo "Test Results for test_update.sh" >"${TEST_RESULTS_FILE}"
    echo "Generated: $(date)" >>"${TEST_RESULTS_FILE}"
    echo "==========================================" >>"${TEST_RESULTS_FILE}"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: test_update.sh is executable"
        echo "✅ Test 1 PASSED: test_update.sh is executable" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: test_update.sh is not executable"
        echo "❌ Test 1 FAILED: test_update.sh is not executable" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 2: Should source shared_functions.sh
    ((total_tests++))
    if assert_pattern_in_file "source shared_functions.sh" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Sources shared_functions.sh"
        echo "✅ Test 2 PASSED: Sources shared_functions.sh" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not source shared_functions.sh"
        echo "❌ Test 2 FAILED: Does not source shared_functions.sh" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 3: Should echo testing message
    ((total_tests++))
    if assert_pattern_in_file "echo.*Testing update_agent_status" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Echoes testing message"
        echo "✅ Test 3 PASSED: Echoes testing message" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not echo testing message"
        echo "❌ Test 3 FAILED: Does not echo testing message" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 4: Should call update_agent_status function
    ((total_tests++))
    if assert_pattern_in_file "update_agent_status" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Calls update_agent_status function"
        echo "✅ Test 4 PASSED: Calls update_agent_status function" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not call update_agent_status function"
        echo "❌ Test 4 FAILED: Does not call update_agent_status function" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 5: Should pass test_agent as first argument
    ((total_tests++))
    if assert_pattern_in_file "test_agent" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Passes test_agent as first argument"
        echo "✅ Test 5 PASSED: Passes test_agent as first argument" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not pass test_agent as first argument"
        echo "❌ Test 5 FAILED: Does not pass test_agent as first argument" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 6: Should pass running as second argument
    ((total_tests++))
    if assert_pattern_in_file "\"running\"" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Passes running as second argument"
        echo "✅ Test 6 PASSED: Passes running as second argument" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not pass running as second argument"
        echo "❌ Test 6 FAILED: Does not pass running as second argument" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 7: Should pass \$\$ as third argument
    ((total_tests++))
    if assert_pattern_in_file "\\$\\$" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Passes \$\$ as third argument"
        echo "✅ Test 7 PASSED: Passes \$\$ as third argument" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not pass \$\$ as third argument"
        echo "❌ Test 7 FAILED: Does not pass \$\$ as third argument" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 8: Should pass test_task as fourth argument
    ((total_tests++))
    if assert_pattern_in_file "\"test_task\"" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Passes test_task as fourth argument"
        echo "✅ Test 8 PASSED: Passes test_task as fourth argument" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Does not pass test_task as fourth argument"
        echo "❌ Test 8 FAILED: Does not pass test_task as fourth argument" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 9: Should echo Done message
    ((total_tests++))
    if assert_pattern_in_file "echo.*Done" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Echoes Done message"
        echo "✅ Test 9 PASSED: Echoes Done message" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Does not echo Done message"
        echo "❌ Test 9 FAILED: Does not echo Done message" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 10: Should use #!/bin/bash shebang
    ((total_tests++))
    if assert_pattern_in_file "#!/bin/bash" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Uses #!/bin/bash shebang"
        echo "✅ Test 10 PASSED: Uses #!/bin/bash shebang" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not use #!/bin/bash shebang"
        echo "❌ Test 10 FAILED: Does not use #!/bin/bash shebang" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 11: Should have exactly 4 arguments to update_agent_status
    ((total_tests++))
    if assert_pattern_in_file "update_agent_status.*test_agent.*running.*\\$\\$.*test_task" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Has correct arguments to update_agent_status"
        echo "✅ Test 11 PASSED: Has correct arguments to update_agent_status" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not have correct arguments to update_agent_status"
        echo "❌ Test 11 FAILED: Does not have correct arguments to update_agent_status" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 12: Should have simple structure
    ((total_tests++))
    if assert_pattern_in_file "^source shared_functions.sh$" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Has simple structure"
        echo "✅ Test 12 PASSED: Has simple structure" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not have simple structure"
        echo "❌ Test 12 FAILED: Does not have simple structure" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 13: Should test agent status update functionality
    ((total_tests++))
    if assert_pattern_in_file "update_agent_status.*test_agent" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Tests agent status update functionality"
        echo "✅ Test 13 PASSED: Tests agent status update functionality" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not test agent status update functionality"
        echo "❌ Test 13 FAILED: Does not test agent status update functionality" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 14: Should use double quotes for string arguments
    ((total_tests++))
    if assert_pattern_in_file "\"test_agent\".*\"running\".*\"test_task\"" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Uses double quotes for string arguments"
        echo "✅ Test 14 PASSED: Uses double quotes for string arguments" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not use double quotes for string arguments"
        echo "❌ Test 14 FAILED: Does not use double quotes for string arguments" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 15: Should have minimal script structure
    ((total_tests++))
    if [[ $(wc -l <"${AGENT_SCRIPT}") -le 10 ]]; then
        echo "✅ Test 15 PASSED: Has minimal script structure"
        echo "✅ Test 15 PASSED: Has minimal script structure" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not have minimal script structure"
        echo "❌ Test 15 FAILED: Does not have minimal script structure" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 16: Should not have complex logic
    ((total_tests++))
    if ! assert_pattern_in_file "if\|while\|for\|case" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Does not have complex logic"
        echo "✅ Test 16 PASSED: Does not have complex logic" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Has complex logic"
        echo "❌ Test 16 FAILED: Has complex logic" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 17: Should be a simple test script
    ((total_tests++))
    if assert_pattern_in_file "Testing update_agent_status" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Is a simple test script"
        echo "✅ Test 17 PASSED: Is a simple test script" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Is not a simple test script"
        echo "❌ Test 17 FAILED: Is not a simple test script" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 18: Should call function with proper syntax
    ((total_tests++))
    if assert_pattern_in_file "update_agent_status " "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Calls function with proper syntax"
        echo "✅ Test 18 PASSED: Calls function with proper syntax" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Does not call function with proper syntax"
        echo "❌ Test 18 FAILED: Does not call function with proper syntax" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 19: Should end with Done message
    ((total_tests++))
    if assert_pattern_in_file "^echo \"Done\"$" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Ends with Done message"
        echo "✅ Test 19 PASSED: Ends with Done message" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Does not end with Done message"
        echo "❌ Test 19 FAILED: Does not end with Done message" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 20: Should be a focused test script
    ((total_tests++))
    if [[ $(grep -c "^update_agent_status" "${AGENT_SCRIPT}") -eq 1 ]]; then
        echo "✅ Test 20 PASSED: Is a focused test script"
        echo "✅ Test 20 PASSED: Is a focused test script" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Is not a focused test script"
        echo "❌ Test 20 FAILED: Is not a focused test script" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for test_update.sh:"
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
        echo "✅ All tests PASSED for test_update.sh"
        echo "✅ All tests PASSED for test_update.sh" >>"${TEST_RESULTS_FILE}"
        return 0
    else
        echo "❌ ${failed_tests} test(s) FAILED for test_update.sh"
        echo "❌ ${failed_tests} test(s) FAILED for test_update.sh" >>"${TEST_RESULTS_FILE}"
        return 1
    fi
}

# Run the tests
run_tests
