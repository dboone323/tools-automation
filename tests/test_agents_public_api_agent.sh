        #!/usr/bin/env bash
        # Auto-injected health & reliability shim

        DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer shared helpers when available
if [[ -f "$DIR/shared_functions.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/shared_functions.sh"
fi

if [[ -f "$DIR/agent_helpers.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/agent_helpers.sh"
fi

set -euo pipefail

AGENT_NAME="test_agents_public_api_agent.sh"
LOG_FILE="${LOG_FILE:-$DIR/${AGENT_NAME}.log}"
PID=$$

if type update_agent_status >/dev/null 2>&1; then
  trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; exit 0' SIGTERM SIGINT
else
  trap 'exit 0' SIGTERM SIGINT
fi

if [[ "${1-}" == "--health" || "${1-}" == "health" || "${1-}" == "-h" ]]; then
  if type agent_health_check >/dev/null 2>&1; then
    agent_health_check
    exit $?
  fi
  issues=()
  if [[ ! -w "/tmp" ]]; then
    issues+=("tmp_not_writable")
  fi
  if [[ ! -d "$DIR" ]]; then
    issues+=("cwd_missing")
  fi
  if [[ ${#issues[@]} -gt 0 ]]; then
    printf '{"ok":false,"issues":["%s"]}\n' "${issues[*]}"
    exit 2
  fi
  printf '{"ok":true}\n'
  exit 0
fi

# Original agent script continues below
#!/bin/bash
# Comprehensive test suite for public_api_agent.sh
# Tests API management, rate limiting, and caching functionality

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/public_api_agent.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing public_api_agent.sh structural validation..."

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
    assert_pattern_in_file 'AGENT_NAME="PublicApiAgent"' "${AGENT_SCRIPT}"
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

# Test 7: API_CACHE_FILE variable definition
test_api_cache_file_variable() {
    assert_pattern_in_file 'API_CACHE_FILE=' "${AGENT_SCRIPT}"
}

# Test 8: RATE_LIMIT_FILE variable definition
test_rate_limit_file_variable() {
    assert_pattern_in_file 'RATE_LIMIT_FILE=' "${AGENT_SCRIPT}"
}

# Test 9: PUBLIC_APIS associative array
test_public_apis_array() {
    assert_pattern_in_file 'declare -A PUBLIC_APIS' "${AGENT_SCRIPT}"
}

# Test 10: RATE_LIMITS associative array
test_rate_limits_array() {
    assert_pattern_in_file 'declare -A RATE_LIMITS' "${AGENT_SCRIPT}"
}

# Test 11: CACHE_DURATION variable
test_cache_duration_variable() {
    assert_pattern_in_file 'CACHE_DURATION=' "${AGENT_SCRIPT}"
}

# Test 12: MAX_CACHE_SIZE variable
test_max_cache_size_variable() {
    assert_pattern_in_file 'MAX_CACHE_SIZE=' "${AGENT_SCRIPT}"
}

# Test 13: log_message function declaration
test_log_message_function() {
    assert_pattern_in_file 'log_message\(\)' "${AGENT_SCRIPT}"
}

# Test 14: notify_completion function declaration
test_notify_completion_function() {
    assert_pattern_in_file 'notify_completion\(\)' "${AGENT_SCRIPT}"
}

# Test 15: make_api_request function declaration
test_make_api_request_function() {
    assert_pattern_in_file 'make_api_request\(\)' "${AGENT_SCRIPT}"
}

# Test 16: check_rate_limit function declaration
test_check_rate_limit_function() {
    assert_pattern_in_file 'check_rate_limit\(\)' "${AGENT_SCRIPT}"
}

# Test 17: get_current_usage function declaration
test_get_current_usage_function() {
    assert_pattern_in_file 'get_current_usage\(\)' "${AGENT_SCRIPT}"
}

# Test 18: update_rate_limit function declaration
test_update_rate_limit_function() {
    assert_pattern_in_file 'update_rate_limit\(\)' "${AGENT_SCRIPT}"
}

# Test 19: get_cached_response function declaration
test_get_cached_response_function() {
    assert_pattern_in_file 'get_cached_response\(\)' "${AGENT_SCRIPT}"
}

# Test 20: cache_response function declaration
test_cache_response_function() {
    assert_pattern_in_file 'cache_response\(\)' "${AGENT_SCRIPT}"
}

# Test 21: cleanup_cache function declaration
test_cleanup_cache_function() {
    assert_pattern_in_file 'cleanup_cache\(\)' "${AGENT_SCRIPT}"
}

# Test 22: github_api_call function declaration
test_github_api_call_function() {
    assert_pattern_in_file 'github_api_call\(\)' "${AGENT_SCRIPT}"
}

# Test 23: get_swift_version_info function declaration
test_get_swift_version_info_function() {
    assert_pattern_in_file 'get_swift_version_info\(\)' "${AGENT_SCRIPT}"
}

# Test 24: batch_api_requests function declaration
test_batch_api_requests_function() {
    assert_pattern_in_file 'batch_api_requests\(\)' "${AGENT_SCRIPT}"
}

# Test 25: generate_api_report function declaration
test_generate_api_report_function() {
    assert_pattern_in_file 'generate_api_report\(\)' "${AGENT_SCRIPT}"
}

# Test 26: process_notifications function declaration
test_process_notifications_function() {
    assert_pattern_in_file 'process_notifications\(\)' "${AGENT_SCRIPT}"
}

# Test 27: curl usage in make_api_request
test_curl_usage() {
    assert_pattern_in_file 'curl.*-s.*-w' "${AGENT_SCRIPT}"
}

# Test 28: jq usage for JSON processing
test_jq_usage() {
    assert_pattern_in_file 'jq.*-r' "${AGENT_SCRIPT}"
}

# Test 29: md5 for cache key generation
test_md5_usage() {
    assert_pattern_in_file 'md5' "${AGENT_SCRIPT}"
}

# Test 30: Case statement for HTTP methods
test_case_statement_http_methods() {
    assert_pattern_in_file 'case.*method' "${AGENT_SCRIPT}"
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
    assert_pattern_in_file 'sleep 300' "${AGENT_SCRIPT}"
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
    test_api_cache_file_variable
    test_rate_limit_file_variable
    test_public_apis_array
    test_rate_limits_array
    test_cache_duration_variable
    test_max_cache_size_variable
    test_log_message_function
    test_notify_completion_function
    test_make_api_request_function
    test_check_rate_limit_function
    test_get_current_usage_function
    test_update_rate_limit_function
    test_get_cached_response_function
    test_cache_response_function
    test_cleanup_cache_function
    test_github_api_call_function
    test_get_swift_version_info_function
    test_batch_api_requests_function
    test_generate_api_report_function
    test_process_notifications_function
    test_curl_usage
    test_jq_usage
    test_md5_usage
    test_case_statement_http_methods
    test_main_loop
    test_notification_file_processing
    test_sleep_interval
    test_shared_functions_source
    test_directory_creation
)

echo "Running ${#tests[@]} tests for public_api_agent.sh..."

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
echo "public_api_agent.sh Test Results"
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
RESULTS_FILE="${TEST_RESULTS_DIR}/test_public_api_agent_results.txt"
{
    echo "public_api_agent.sh Test Results"
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

echo "public_api_agent.sh structural validation complete."
