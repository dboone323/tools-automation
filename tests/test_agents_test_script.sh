#!/bin/bash
# Test suite for test_script.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TEST_RESULTS_FILE="${SCRIPT_DIR}/test_results_test_script.txt"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${SCRIPT_DIR}/../test_script.sh"

# Function to run all tests
run_tests() {
    echo "Running tests for test_script.sh..."
    echo "Test Results for test_script.sh" >"${TEST_RESULTS_FILE}"
    echo "Generated: $(date)" >>"${TEST_RESULTS_FILE}"
    echo "==========================================" >>"${TEST_RESULTS_FILE}"

    local total_tests=0
    local passed_tests=0
    local failed_tests=0

    # Test 1: Should be executable
    ((total_tests++))
    if assert_file_executable "${AGENT_SCRIPT}"; then
        echo "✅ Test 1 PASSED: test_script.sh is executable"
        echo "✅ Test 1 PASSED: test_script.sh is executable" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 1 FAILED: test_script.sh is not executable"
        echo "❌ Test 1 FAILED: test_script.sh is not executable" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 2: Should have set -euo pipefail
    ((total_tests++))
    if assert_pattern_in_file "set -euo pipefail" "${AGENT_SCRIPT}"; then
        echo "✅ Test 2 PASSED: Has strict error handling"
        echo "✅ Test 2 PASSED: Has strict error handling" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 2 FAILED: Does not have strict error handling"
        echo "❌ Test 2 FAILED: Does not have strict error handling" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 3: Should echo testing message
    ((total_tests++))
    if assert_pattern_in_file "echo.*Testing script" "${AGENT_SCRIPT}"; then
        echo "✅ Test 3 PASSED: Echoes testing message"
        echo "✅ Test 3 PASSED: Echoes testing message" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 3 FAILED: Does not echo testing message"
        echo "❌ Test 3 FAILED: Does not echo testing message" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 4: Should define swift_tests function
    ((total_tests++))
    if assert_pattern_in_file "swift_tests\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines swift_tests function"
        echo "✅ Test 4 PASSED: Defines swift_tests function" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define swift_tests function"
        echo "❌ Test 4 FAILED: Does not define swift_tests function" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 5: Should check if swift is installed
    ((total_tests++))
    if assert_pattern_in_file "hash swift" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Checks if swift is installed"
        echo "✅ Test 5 PASSED: Checks if swift is installed" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not check if swift is installed"
        echo "❌ Test 5 FAILED: Does not check if swift is installed" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 6: Should skip if swift not installed
    ((total_tests++))
    if assert_pattern_in_file "swift not installed" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Skips if swift not installed"
        echo "✅ Test 6 PASSED: Skips if swift not installed" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not skip if swift not installed"
        echo "❌ Test 6 FAILED: Does not skip if swift not installed" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 7: Should echo Swift found message
    ((total_tests++))
    if assert_pattern_in_file "Swift found" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Echoes Swift found message"
        echo "✅ Test 7 PASSED: Echoes Swift found message" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not echo Swift found message"
        echo "❌ Test 7 FAILED: Does not echo Swift found message" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 8: Should call swift_tests function
    ((total_tests++))
    if assert_pattern_in_file "swift_tests" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Calls swift_tests function"
        echo "✅ Test 8 PASSED: Calls swift_tests function" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Does not call swift_tests function"
        echo "❌ Test 8 FAILED: Does not call swift_tests function" >>"${TEST_RESULTS_FILE}"
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

    # Test 10: Should have phase marker
    ((total_tests++))
    if assert_pattern_in_file "\[phase\]" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Has phase marker"
        echo "✅ Test 10 PASSED: Has phase marker" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not have phase marker"
        echo "❌ Test 10 FAILED: Does not have phase marker" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 11: Should have skip marker
    ((total_tests++))
    if assert_pattern_in_file "\[skip\]" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Has skip marker"
        echo "✅ Test 11 PASSED: Has skip marker" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not have skip marker"
        echo "❌ Test 11 FAILED: Does not have skip marker" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 12: Should return 0 when skipping
    ((total_tests++))
    if assert_pattern_in_file "return 0" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Returns 0 when skipping"
        echo "✅ Test 12 PASSED: Returns 0 when skipping" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not return 0 when skipping"
        echo "❌ Test 12 FAILED: Does not return 0 when skipping" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 13: Should use /usr/bin/env bash
    ((total_tests++))
    if assert_pattern_in_file "#!/usr/bin/env bash" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Uses /usr/bin/env bash"
        echo "✅ Test 13 PASSED: Uses /usr/bin/env bash" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not use /usr/bin/env bash"
        echo "❌ Test 13 FAILED: Does not use /usr/bin/env bash" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 14: Should check hash with 2>/dev/null
    ((total_tests++))
    if assert_pattern_in_file "hash swift 2>/dev/null" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Checks hash with error suppression"
        echo "✅ Test 14 PASSED: Checks hash with error suppression" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not check hash with error suppression"
        echo "❌ Test 14 FAILED: Does not check hash with error suppression" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 15: Should have Swift tests phase message
    ((total_tests++))
    if assert_pattern_in_file "Swift tests" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Has Swift tests phase message"
        echo "✅ Test 15 PASSED: Has Swift tests phase message" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not have Swift tests phase message"
        echo "❌ Test 15 FAILED: Does not have Swift tests phase message" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 16: Should have skipping message
    ((total_tests++))
    if assert_pattern_in_file "skipping Swift tests" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Has skipping message"
        echo "✅ Test 16 PASSED: Has skipping message" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Does not have skipping message"
        echo "❌ Test 16 FAILED: Does not have skipping message" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 17: Should have Swift found message
    ((total_tests++))
    if assert_pattern_in_file "Swift found" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Has Swift found message"
        echo "✅ Test 17 PASSED: Has Swift found message" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Does not have Swift found message"
        echo "❌ Test 17 FAILED: Does not have Swift found message" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 18: Should have Done message
    ((total_tests++))
    if assert_pattern_in_file "Done" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Has Done message"
        echo "✅ Test 18 PASSED: Has Done message" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Does not have Done message"
        echo "❌ Test 18 FAILED: Does not have Done message" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 19: Should have function definition
    ((total_tests++))
    if assert_pattern_in_file "swift_tests\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Has function definition"
        echo "✅ Test 19 PASSED: Has function definition" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Does not have function definition"
        echo "❌ Test 19 FAILED: Does not have function definition" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Test 20: Should call function at end
    ((total_tests++))
    if assert_pattern_in_file "^swift_tests$" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Calls function at end"
        echo "✅ Test 20 PASSED: Calls function at end" >>"${TEST_RESULTS_FILE}"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Does not call function at end"
        echo "❌ Test 20 FAILED: Does not call function at end" >>"${TEST_RESULTS_FILE}"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for test_script.sh:"
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
        echo "✅ All tests PASSED for test_script.sh"
        echo "✅ All tests PASSED for test_script.sh" >>"${TEST_RESULTS_FILE}"
        return 0
    else
        echo "❌ ${failed_tests} test(s) FAILED for test_script.sh"
        echo "❌ ${failed_tests} test(s) FAILED for test_script.sh" >>"${TEST_RESULTS_FILE}"
        return 1
    fi
}

# Run the tests
run_tests
