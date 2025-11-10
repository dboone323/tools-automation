#!/bin/bash
# Comprehensive test suite for search_agent.sh
# Tests structural validation and core functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/search_agent.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing search_agent.sh structural validation..."

# Test functions
test_search_agent_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

test_search_agent_shebang() {
    assert_pattern_in_file "^#!/bin/bash" "${AGENT_SCRIPT}"
}

test_search_agent_shared_functions_source() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_SCRIPT}"
}

test_search_agent_script_dir_variable() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

test_search_agent_workspace_variable() {
    assert_pattern_in_file "WORKSPACE=" "${AGENT_SCRIPT}"
}

test_search_agent_name_variable() {
    assert_pattern_in_file "AGENT_NAME=\"search_agent\"" "${AGENT_SCRIPT}"
}

test_search_agent_label_variable() {
    assert_pattern_in_file "AGENT_LABEL=\"SearchAgent\"" "${AGENT_SCRIPT}"
}

test_search_agent_log_file_variable() {
    assert_pattern_in_file "LOG_FILE=" "${AGENT_SCRIPT}"
}

test_search_agent_comm_dir_variable() {
    assert_pattern_in_file "COMM_DIR=" "${AGENT_SCRIPT}"
}

test_search_agent_notification_file_variable() {
    assert_pattern_in_file "NOTIFICATION_FILE=" "${AGENT_SCRIPT}"
}

test_search_agent_completed_file_variable() {
    assert_pattern_in_file "COMPLETED_FILE=" "${AGENT_SCRIPT}"
}

test_search_agent_results_dir_variable() {
    assert_pattern_in_file "RESULTS_DIR=" "${AGENT_SCRIPT}"
}

test_search_agent_query_dir_variable() {
    assert_pattern_in_file "QUERY_DIR=" "${AGENT_SCRIPT}"
}

test_search_agent_status_file_variable() {
    assert_pattern_in_file "AGENT_STATUS_FILE=" "${AGENT_SCRIPT}"
}

test_search_agent_task_queue_file_variable() {
    assert_pattern_in_file "TASK_QUEUE_FILE=" "${AGENT_SCRIPT}"
}

test_search_agent_processed_tasks_file_variable() {
    assert_pattern_in_file "PROCESSED_TASKS_FILE=" "${AGENT_SCRIPT}"
}

test_search_agent_status_update_interval_variable() {
    assert_pattern_in_file "STATUS_UPDATE_INTERVAL=" "${AGENT_SCRIPT}"
}

test_search_agent_status_util_variable() {
    assert_pattern_in_file "STATUS_UTIL=" "${AGENT_SCRIPT}"
}

test_search_agent_status_keys_variable() {
    assert_pattern_in_file "STATUS_KEYS=" "${AGENT_SCRIPT}"
}

test_search_agent_base_sleep_interval_variable() {
    assert_pattern_in_file "BASE_SLEEP_INTERVAL=" "${AGENT_SCRIPT}"
}

test_search_agent_min_sleep_interval_variable() {
    assert_pattern_in_file "MIN_SLEEP_INTERVAL=" "${AGENT_SCRIPT}"
}

test_search_agent_max_sleep_interval_variable() {
    assert_pattern_in_file "MAX_SLEEP_INTERVAL=" "${AGENT_SCRIPT}"
}

test_search_agent_context_lines_variable() {
    assert_pattern_in_file "CONTEXT_LINES=" "${AGENT_SCRIPT}"
}

test_search_agent_tmp_root_variable() {
    assert_pattern_in_file "TMP_ROOT=" "${AGENT_SCRIPT}"
}

test_search_agent_mkdir_commands() {
    assert_pattern_in_file "mkdir -p.*COMM_DIR.*RESULTS_DIR.*QUERY_DIR" "${AGENT_SCRIPT}"
}

test_search_agent_touch_commands() {
    assert_pattern_in_file "touch.*NOTIFICATION_FILE.*COMPLETED_FILE.*PROCESSED_TASKS_FILE" "${AGENT_SCRIPT}"
}

test_search_agent_log_message_function() {
    assert_pattern_in_file "log_message\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_legacy_update_status_function() {
    assert_pattern_in_file "legacy_update_status\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_update_status_function() {
    assert_pattern_in_file "update_status\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_update_agent_pid_function() {
    assert_pattern_in_file "update_agent_pid\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_maybe_update_status_function() {
    assert_pattern_in_file "maybe_update_status\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_update_task_status_function() {
    assert_pattern_in_file "update_task_status\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_notify_completion_function() {
    assert_pattern_in_file "notify_completion\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_has_processed_task_function() {
    assert_pattern_in_file "has_processed_task\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_fetch_task_description_function() {
    assert_pattern_in_file "fetch_task_description\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_fetch_task_payload_value_function() {
    assert_pattern_in_file "fetch_task_payload_value\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_extract_query_from_task_function() {
    assert_pattern_in_file "extract_query_from_task\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_safely_trim_output_function() {
    assert_pattern_in_file "safely_trim_output\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_perform_local_search_function() {
    assert_pattern_in_file "perform_local_search\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_summarize_results_function() {
    assert_pattern_in_file "summarize_results\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_generate_search_report_function() {
    assert_pattern_in_file "generate_search_report\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_process_search_task_function() {
    assert_pattern_in_file "process_search_task\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_process_task_function() {
    assert_pattern_in_file "process_task\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_process_assigned_tasks_function() {
    assert_pattern_in_file "process_assigned_tasks\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_process_notification_query_function() {
    assert_pattern_in_file "process_notification_query\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_process_notifications_function() {
    assert_pattern_in_file "process_notifications\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_run_discovery_cycle_function() {
    assert_pattern_in_file "run_discovery_cycle\(\)" "${AGENT_SCRIPT}"
}

test_search_agent_main_loop() {
    assert_pattern_in_file "while true; do" "${AGENT_SCRIPT}"
}

test_search_agent_maybe_update_status_calls() {
    assert_pattern_in_file "maybe_update_status" "${AGENT_SCRIPT}"
}

test_search_agent_process_notifications_call() {
    assert_pattern_in_file "process_notifications" "${AGENT_SCRIPT}"
}

test_search_agent_process_assigned_tasks_call() {
    assert_pattern_in_file "process_assigned_tasks" "${AGENT_SCRIPT}"
}

test_search_agent_run_discovery_cycle_call() {
    assert_pattern_in_file "run_discovery_cycle" "${AGENT_SCRIPT}"
}

test_search_agent_sleep_command() {
    assert_pattern_in_file "sleep.*sleep_interval" "${AGENT_SCRIPT}"
}

test_search_agent_log_message_calls() {
    assert_pattern_in_file "log_message.*INFO.*Search agent starting" "${AGENT_SCRIPT}"
}

test_search_agent_update_status_calls() {
    assert_pattern_in_file "update_status.*starting" "${AGENT_SCRIPT}"
    assert_pattern_in_file "update_status.*available" "${AGENT_SCRIPT}"
}

test_search_agent_update_agent_pid_call() {
    assert_pattern_in_file 'update_agent_pid "\$\$"' "${AGENT_SCRIPT}"
}

test_search_agent_run_discovery_cycle_initial_call() {
    assert_pattern_in_file "run_discovery_cycle" "${AGENT_SCRIPT}"
}

# Array of all test functions
tests=(
    test_search_agent_script_executable
    test_search_agent_shebang
    test_search_agent_shared_functions_source
    test_search_agent_script_dir_variable
    test_search_agent_workspace_variable
    test_search_agent_name_variable
    test_search_agent_label_variable
    test_search_agent_log_file_variable
    test_search_agent_comm_dir_variable
    test_search_agent_notification_file_variable
    test_search_agent_completed_file_variable
    test_search_agent_results_dir_variable
    test_search_agent_query_dir_variable
    test_search_agent_status_file_variable
    test_search_agent_task_queue_file_variable
    test_search_agent_processed_tasks_file_variable
    test_search_agent_status_update_interval_variable
    test_search_agent_status_util_variable
    test_search_agent_status_keys_variable
    test_search_agent_base_sleep_interval_variable
    test_search_agent_min_sleep_interval_variable
    test_search_agent_max_sleep_interval_variable
    test_search_agent_context_lines_variable
    test_search_agent_tmp_root_variable
    test_search_agent_mkdir_commands
    test_search_agent_touch_commands
    test_search_agent_log_message_function
    test_search_agent_legacy_update_status_function
    test_search_agent_update_status_function
    test_search_agent_update_agent_pid_function
    test_search_agent_maybe_update_status_function
    test_search_agent_update_task_status_function
    test_search_agent_notify_completion_function
    test_search_agent_has_processed_task_function
    test_search_agent_fetch_task_description_function
    test_search_agent_fetch_task_payload_value_function
    test_search_agent_extract_query_from_task_function
    test_search_agent_safely_trim_output_function
    test_search_agent_perform_local_search_function
    test_search_agent_summarize_results_function
    test_search_agent_generate_search_report_function
    test_search_agent_process_search_task_function
    test_search_agent_process_task_function
    test_search_agent_process_assigned_tasks_function
    test_search_agent_process_notification_query_function
    test_search_agent_process_notifications_function
    test_search_agent_run_discovery_cycle_function
    test_search_agent_main_loop
    test_search_agent_maybe_update_status_calls
    test_search_agent_process_notifications_call
    test_search_agent_process_assigned_tasks_call
    test_search_agent_run_discovery_cycle_call
    test_search_agent_sleep_command
    test_search_agent_log_message_calls
    test_search_agent_update_status_calls
    test_search_agent_update_agent_pid_call
    test_search_agent_run_discovery_cycle_initial_call
)

echo "Running ${#tests[@]} tests for search_agent.sh..."

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
echo "search_agent.sh Test Results"
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
RESULTS_FILE="${TEST_RESULTS_DIR}/test_search_agent_results.txt"
{
    echo "search_agent.sh Test Results"
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

echo "search_agent.sh structural validation complete."
