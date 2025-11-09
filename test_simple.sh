#!/bin/bash
source shell_test_framework.sh

test_error_line_detection() {
    local test_name="test_error_line_detection"
    announce_test "$test_name"
    
    # Source the agent script to get functions
    source "agents/error_learning_agent.sh" 2>/dev/null || true
    
    # Test error line detection
    if is_error_line "[ERROR] SwiftPM build failed"; then
        assert_true true "Should detect ERROR lines"
    else
        assert_true false "Should detect ERROR lines"
    fi
    
    test_passed "$test_name"
}

test_error_line_detection
echo "Total tests: $(get_total_tests)"
echo "Passed: $(get_passed_tests)"
echo "Failed: $(get_failed_tests)"
