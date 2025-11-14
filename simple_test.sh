#!/bin/bash
source tests/shell_test_framework.sh

# Simple test function
test_simple() {
    echo "Running simple test"
    assert_success "This should pass"
    echo "Test completed"
}

# Run the test
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

before_failed=$TESTS_FAILED
test_simple
after_failed=$TESTS_FAILED

echo "Tests run: $TESTS_RUN"
echo "Tests passed: $TESTS_PASSED"
echo "Tests failed: $TESTS_FAILED"
echo "Before failed: $before_failed"
echo "After failed: $after_failed"
