#!/bin/bash
# Comprehensive test suite for pull_request_agent.sh
# Tests PR management, risk assessment, and automated merging

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/pull_request_agent.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing pull_request_agent.sh structural validation..."

# Test 1: Script exists and is executable
test_script_exists_and_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: SCRIPT_DIR variable definition
test_script_dir_variable() {
    assert_pattern_in_file 'SCRIPT_DIR=' "${AGENT_SCRIPT}"
}

# Test 3: AGENT_NAME variable definition
test_agent_name_variable() {
    assert_pattern_in_file 'AGENT_NAME="PullRequestAgent"' "${AGENT_SCRIPT}"
}

# Test 4: LOG_FILE variable definition
test_log_file_variable() {
    assert_pattern_in_file 'LOG_FILE=' "${AGENT_SCRIPT}"
}

# Test 5: NOTIFICATION_FILE variable definition
test_notification_file_variable() {
    assert_pattern_in_file 'NOTIFICATION_FILE=' "${AGENT_SCRIPT}"
}

# Test 6: COMPLETED_FILE variable definition
test_completed_file_variable() {
    assert_pattern_in_file 'COMPLETED_FILE=' "${AGENT_SCRIPT}"
}

# Test 7: PR_QUEUE_FILE variable definition
test_pr_queue_file_variable() {
    assert_pattern_in_file 'PR_QUEUE_FILE=' "${AGENT_SCRIPT}"
}

# Test 8: RISK_ASSESSMENT_FILE variable definition
test_risk_assessment_file_variable() {
    assert_pattern_in_file 'RISK_ASSESSMENT_FILE=' "${AGENT_SCRIPT}"
}

# Test 9: Risk threshold variables
test_risk_thresholds() {
    assert_pattern_in_file 'LOW_RISK_THRESHOLD=' "${AGENT_SCRIPT}"
}

# Test 10: AUTO_MERGE_ENABLED variable
test_auto_merge_enabled() {
    assert_pattern_in_file 'AUTO_MERGE_ENABLED=' "${AGENT_SCRIPT}"
}

# Test 11: log_message function declaration
test_log_message_function() {
    assert_pattern_in_file 'log_message\(\)' "${AGENT_SCRIPT}"
}

# Test 12: notify_completion function declaration
test_notify_completion_function() {
    assert_pattern_in_file 'notify_completion\(\)' "${AGENT_SCRIPT}"
}

# Test 13: assess_risk function declaration
test_assess_risk_function() {
    assert_pattern_in_file 'assess_risk\(\)' "${AGENT_SCRIPT}"
}

# Test 14: get_risk_level function declaration
test_get_risk_level_function() {
    assert_pattern_in_file 'get_risk_level\(\)' "${AGENT_SCRIPT}"
}

# Test 15: create_pull_request function declaration
test_create_pull_request_function() {
    assert_pattern_in_file 'create_pull_request\(\)' "${AGENT_SCRIPT}"
}

# Test 16: review_pull_request function declaration
test_review_pull_request_function() {
    assert_pattern_in_file 'review_pull_request\(\)' "${AGENT_SCRIPT}"
}

# Test 17: check_build_status function declaration
test_check_build_status_function() {
    assert_pattern_in_file 'check_build_status\(\)' "${AGENT_SCRIPT}"
}

# Test 18: check_test_status function declaration
test_check_test_status_function() {
    assert_pattern_in_file 'check_test_status\(\)' "${AGENT_SCRIPT}"
}

# Test 19: check_code_quality function declaration
test_check_code_quality_function() {
    assert_pattern_in_file 'check_code_quality\(\)' "${AGENT_SCRIPT}"
}

# Test 20: check_security function declaration
test_check_security_function() {
    assert_pattern_in_file 'check_security\(\)' "${AGENT_SCRIPT}"
}

# Test 21: merge_pull_request function declaration
test_merge_pull_request_function() {
    assert_pattern_in_file 'merge_pull_request\(\)' "${AGENT_SCRIPT}"
}

# Test 22: update_pr_status function declaration
test_update_pr_status_function() {
    assert_pattern_in_file 'update_pr_status\(\)' "${AGENT_SCRIPT}"
}

# Test 23: generate_review_report function declaration
test_generate_review_report_function() {
    assert_pattern_in_file 'generate_review_report\(\)' "${AGENT_SCRIPT}"
}

# Test 24: process_notifications function declaration
test_process_notifications_function() {
    assert_pattern_in_file 'process_notifications\(\)' "${AGENT_SCRIPT}"
}

# Test 25: jq usage for JSON processing
test_jq_usage() {
    assert_pattern_in_file 'jq.*-r' "${AGENT_SCRIPT}"
}

# Test 26: git commands usage
test_git_usage() {
    assert_pattern_in_file 'git checkout' "${AGENT_SCRIPT}"
}

# Test 27: xcodebuild usage
test_xcodebuild_usage() {
    assert_pattern_in_file 'xcodebuild' "${AGENT_SCRIPT}"
}

# Test 28: swift build/test usage
test_swift_usage() {
    assert_pattern_in_file 'swift build' "${AGENT_SCRIPT}"
}

# Test 29: grep usage for pattern matching
test_grep_usage() {
    assert_pattern_in_file 'grep -qi' "${AGENT_SCRIPT}"
}

# Test 30: Case statement for notification types
test_case_statement_notifications() {
    assert_pattern_in_file 'case.*notification_type' "${AGENT_SCRIPT}"
}

# Test 31: Main loop with while true
test_main_loop() {
    assert_pattern_in_file 'while true' "${AGENT_SCRIPT}"
}

# Test 32: Notification file processing
test_notification_file_processing() {
    assert_pattern_in_file 'if.*NOTIFICATION_FILE' "${AGENT_SCRIPT}"
}

# Test 33: Sleep interval
test_sleep_interval() {
    assert_pattern_in_file 'sleep 60' "${AGENT_SCRIPT}"
}

# Test 34: Shared functions sourcing
test_shared_functions_source() {
    assert_pattern_in_file 'source.*shared_functions' "${AGENT_SCRIPT}"
}

# Test 35: Directory creation for communication
test_directory_creation() {
    assert_pattern_in_file 'mkdir -p.*communication' "${AGENT_SCRIPT}"
}

# Array of all test functions
tests=(
    test_script_exists_and_executable
    test_script_dir_variable
    test_agent_name_variable
    test_log_file_variable
    test_notification_file_variable
    test_completed_file_variable
    test_pr_queue_file_variable
    test_risk_assessment_file_variable
    test_risk_thresholds
    test_auto_merge_enabled
    test_log_message_function
    test_notify_completion_function
    test_assess_risk_function
    test_get_risk_level_function
    test_create_pull_request_function
    test_review_pull_request_function
    test_check_build_status_function
    test_check_test_status_function
    test_check_code_quality_function
    test_check_security_function
    test_merge_pull_request_function
    test_update_pr_status_function
    test_generate_review_report_function
    test_process_notifications_function
    test_jq_usage
    test_git_usage
    test_xcodebuild_usage
    test_swift_usage
    test_grep_usage
    test_case_statement_notifications
    test_main_loop
    test_notification_file_processing
    test_sleep_interval
    test_shared_functions_source
    test_directory_creation
)

echo "Running ${#tests[@]} tests for pull_request_agent.sh..."

passed=0
failed=0
results=()

for test in "${tests[@]}"; do
    echo -n "Running $test... "
    if $test; then
        echo -e "${GREEN}PASSED${NC}"
        ((passed++))
        results+=("$test: PASSED")
    else
        echo -e "${RED}FAILED${NC}"
        ((failed++))
        results+=("$test: FAILED")
    fi
done

echo ""
echo "pull_request_agent.sh Test Results"
echo "=========================="
echo "Total tests: ${#tests[@]}"
echo -e "Passed: ${GREEN}$passed${NC}"
echo -e "Failed: ${RED}$failed${NC}"
echo ""

if [[ $failed -gt 0 ]]; then
    echo "Failed tests:"
    for result in "${results[@]}"; do
        if [[ $result == *": FAILED" ]]; then
            echo -e "${RED}$result${NC}"
        fi
    done
fi

# Save results to file
RESULTS_FILE="${TEST_RESULTS_DIR}/test_pull_request_agent_results.txt"
{
    echo "pull_request_agent.sh Test Results"
    echo "=========================="
    echo "Total tests: ${#tests[@]}"
    echo "Passed: $passed"
    echo "Failed: $failed"
    echo ""
    echo "Detailed Results:"
    for result in "${results[@]}"; do
        echo "$result"
    done
} >"$RESULTS_FILE"

echo "Results saved to: $RESULTS_FILE"

# Exit with failure if any tests failed
if [[ $failed -gt 0 ]]; then
    exit 1
fi

echo "pull_request_agent.sh structural validation complete."
