#!/bin/bash

# Test Runner for Shell Script Agent Tests
# Usage: ./run_shell_tests.sh [test_file]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
FRAMEWORK_FILE="$SCRIPT_DIR/shell_test_framework.sh"

# Check if framework exists
if [[ ! -f "$FRAMEWORK_FILE" ]]; then
    echo "Error: Test framework not found at $FRAMEWORK_FILE"
    exit 1
fi

# Source the framework
source "$FRAMEWORK_FILE"

# If a specific test file is provided, run it
if [[ $# -eq 1 ]]; then
    TEST_FILE="$1"
    if [[ ! -f "$TEST_FILE" ]]; then
        echo "Error: Test file not found: $TEST_FILE"
        exit 1
    fi

    echo "Running specific test file: $TEST_FILE"
    run_test_suite "$TEST_FILE"

# Otherwise, find and run all test files
else
    echo "Running all shell script agent tests..."

    # Find all test files (test_*.sh)
    TEST_FILES=$(find "$SCRIPT_DIR" -name "test_*.sh" -type f | sort)

    if [[ -z "$TEST_FILES" ]]; then
        echo "No test files found in $SCRIPT_DIR"
        exit 1
    fi

    TOTAL_TESTS_RUN=0
    TOTAL_TESTS_PASSED=0
    TOTAL_TESTS_FAILED=0

    for test_file in $TEST_FILES; do
        echo ""
        echo "========================================"
        echo "Running tests from: $(basename "$test_file")"
        echo "========================================"

        # Reset counters for this test file
        TESTS_RUN=0
        TESTS_PASSED=0
        TESTS_FAILED=0

        # Run the test suite
        run_test_suite "$test_file"

        # Accumulate totals
        TOTAL_TESTS_RUN=$((TOTAL_TESTS_RUN + TESTS_RUN))
        TOTAL_TESTS_PASSED=$((TOTAL_TESTS_PASSED + TESTS_PASSED))
        TOTAL_TESTS_FAILED=$((TOTAL_TESTS_FAILED + TESTS_FAILED))
    done

    echo ""
    echo "=========================================="
    echo "OVERALL TEST RESULTS:"
    echo "Total Test Files: $(echo "$TEST_FILES" | wc -l | tr -d ' ')"
    echo "Total Tests Run: $TOTAL_TESTS_RUN"
    echo -e "Total Passed: ${GREEN}$TOTAL_TESTS_PASSED${NC}"
    echo -e "Total Failed: ${RED}$TOTAL_TESTS_FAILED${NC}"
    echo "=========================================="

    # Exit with failure if any tests failed
    if [[ $TOTAL_TESTS_FAILED -gt 0 ]]; then
        exit 1
    fi
fi
