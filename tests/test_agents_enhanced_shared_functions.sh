#!/bin/bash

# Test script for enhanced_shared_functions.sh

set -e

# Get the absolute path to the test script directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/enhanced_shared_functions.sh"

# Ensure we're in the right directory
cd "${SCRIPT_DIR}" || exit 1

# Colors
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

PASSED=0
FAILED=0

assert_file_exists() {
    local file="$1"
    local test_name="$2"

    if [[ -f "${file}" ]]; then
        echo -e "${GREEN}✅ Test ${test_name} PASSED: ${file} exists${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}❌ Test ${test_name} FAILED: ${file} does not exist${NC}"
        FAILED=$((FAILED + 1))
    fi
}

assert_file_executable() {
    local file="$1"
    local test_name="$2"

    if [[ -x "${file}" ]]; then
        echo -e "${GREEN}✅ Test ${test_name} PASSED: ${file} is executable${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}❌ Test ${test_name} FAILED: ${file} is not executable${NC}"
        FAILED=$((FAILED + 1))
    fi
}

assert_pattern_in_file() {
    local file="$1"
    local pattern="$2"
    local test_name="$3"

    if grep -q "${pattern}" "${file}"; then
        echo -e "${GREEN}✅ Test ${test_name} PASSED: Pattern '${pattern}' found in ${file}${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}❌ Test ${test_name} FAILED: Pattern '${pattern}' not found in ${file}${NC}"
        FAILED=$((FAILED + 1))
    fi
}

assert_command_exits_success() {
    local command="$1"
    local test_name="$2"

    if eval "${command}" >/dev/null 2>&1; then
        echo -e "${GREEN}✅ Test ${test_name} PASSED: Command executed successfully${NC}"
        PASSED=$((PASSED + 1))
    else
        echo -e "${RED}❌ Test ${test_name} FAILED: Command failed${NC}"
        FAILED=$((FAILED + 1))
    fi
}

echo "Running tests for enhanced_shared_functions.sh..."
echo "==========================================="

# Test 1: Script exists
assert_file_exists "${AGENT_SCRIPT}" "1"

# Test 2: Script is executable
assert_file_executable "${AGENT_SCRIPT}" "2"

# Test 3: Defines SCRIPT_DIR variable
assert_pattern_in_file "${AGENT_SCRIPT}" "SCRIPT_DIR=" "3"

# Test 4: Defines STATUS_DIR variable
assert_pattern_in_file "${AGENT_SCRIPT}" "STATUS_DIR=" "4"

# Test 5: Defines LOG_DIR variable
assert_pattern_in_file "${AGENT_SCRIPT}" "LOG_DIR=" "5"

# Test 6: Defines CONFIG_DIR variable
assert_pattern_in_file "${AGENT_SCRIPT}" "CONFIG_DIR=" "6"

# Test 7: Defines TEMP_DIR variable
assert_pattern_in_file "${AGENT_SCRIPT}" "TEMP_DIR=" "7"

# Test 8: Defines LOG_FILE variable
assert_pattern_in_file "${AGENT_SCRIPT}" "LOG_FILE=" "8"

# Test 9: Defines STATUS_FILE variable
assert_pattern_in_file "${AGENT_SCRIPT}" "STATUS_FILE=" "9"

# Test 10: Defines CONFIG_FILE variable
assert_pattern_in_file "${AGENT_SCRIPT}" "CONFIG_FILE=" "10"

# Test 11: Has enhanced_log function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_log()" "11"

# Test 12: Has enhanced_error_handler function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_error_handler()" "12"

# Test 13: Has performance_track function
assert_pattern_in_file "${AGENT_SCRIPT}" "performance_track()" "13"

# Test 14: Has get_performance_stats function
assert_pattern_in_file "${AGENT_SCRIPT}" "get_performance_stats()" "14"

# Test 15: Has enhanced_read_file function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_read_file()" "15"

# Test 16: Has enhanced_write_file function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_write_file()" "16"

# Test 17: Has enhanced_json_get function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_json_get()" "17"

# Test 18: Has enhanced_json_set function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_json_set()" "18"

# Test 19: Has enhanced_process_check function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_process_check()" "19"

# Test 20: Has enhanced_process_start function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_process_start()" "20"

# Test 21: Has enhanced_process_stop function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_process_stop()" "21"

# Test 22: Has enhanced_http_get function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_http_get()" "22"

# Test 23: Has enhanced_http_post function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_http_post()" "23"

# Test 24: Has enhanced_system_info function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_system_info()" "24"

# Test 25: Has enhanced_memory_usage function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_memory_usage()" "25"

# Test 26: Has enhanced_validate_email function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_validate_email()" "26"

# Test 27: Has enhanced_validate_url function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_validate_url()" "27"

# Test 28: Has enhanced_validate_json function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_validate_json()" "28"

# Test 29: Has enhanced_string_escape function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_string_escape()" "29"

# Test 30: Has enhanced_string_truncate function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_string_truncate()" "30"

# Test 31: Has enhanced_string_slugify function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_string_slugify()" "31"

# Test 32: Has enhanced_array_contains function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_array_contains()" "32"

# Test 33: Has enhanced_array_unique function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_array_unique()" "33"

# Test 34: Has enhanced_date_format function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_date_format()" "34"

# Test 35: Has enhanced_date_add function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_date_add()" "35"

# Test 36: Has enhanced_config_load function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_config_load()" "36"

# Test 37: Has enhanced_config_save function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_config_save()" "37"

# Test 38: Has enhanced_cleanup_temp function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_cleanup_temp()" "38"

# Test 39: Has enhanced_cleanup_logs function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_cleanup_logs()" "39"

# Test 40: Has enhanced_initialize function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_initialize()" "40"

# Test 41: Has enhanced_status function
assert_pattern_in_file "${AGENT_SCRIPT}" "enhanced_status()" "41"

# Test 42: Has main function
assert_pattern_in_file "${AGENT_SCRIPT}" "main()" "42"

# Test 43: Has trap command for signal handling
assert_pattern_in_file "${AGENT_SCRIPT}" "trap" "43"

# Test 44: Has proper shebang
assert_pattern_in_file "${AGENT_SCRIPT}" "#!/bin/bash" "44"

# Test 45: Has case statement for command line arguments
assert_pattern_in_file "${AGENT_SCRIPT}" "case" "45"

# Test 46: Has mkdir commands for directory creation
assert_pattern_in_file "${AGENT_SCRIPT}" "mkdir -p" "46"

echo "==========================================="
echo "Test Summary for enhanced_shared_functions.sh:"
echo "Total Tests: $((PASSED + FAILED))"
echo "Passed: ${PASSED}"
echo "Failed: ${FAILED}"
echo "Success Rate: $((PASSED * 100 / (PASSED + FAILED)))%"
echo "==========================================="

if [[ ${FAILED} -eq 0 ]]; then
    echo -e "${GREEN}🎉 All tests passed!${NC}"
    exit 0
else
    echo -e "${RED}❌ Some tests failed${NC}"
    exit 1
fi

    # Test 4: Should define STATUS_FILE variable
    ((total_tests++))
    if assert_pattern_in_file "STATUS_FILE=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 4 PASSED: Defines STATUS_FILE variable"
        echo "✅ Test 4 PASSED: Defines STATUS_FILE variable" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((passed_tests++))
    else
        echo "❌ Test 4 FAILED: Does not define STATUS_FILE variable"
        echo "❌ Test 4 FAILED: Does not define STATUS_FILE variable" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((failed_tests++))
    fi

    # Test 5: Should define MAX_RETRIES variable
    ((total_tests++))
    if assert_pattern_in_file "MAX_RETRIES=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 5 PASSED: Defines MAX_RETRIES variable"
        echo "✅ Test 5 PASSED: Defines MAX_RETRIES variable" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((passed_tests++))
    else
        echo "❌ Test 5 FAILED: Does not define MAX_RETRIES variable"
        echo "❌ Test 5 FAILED: Does not define MAX_RETRIES variable" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((failed_tests++))
    fi

    # Test 6: Should define RETRY_DELAY variable
    ((total_tests++))
    if assert_pattern_in_file "RETRY_DELAY=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 6 PASSED: Defines RETRY_DELAY variable"
        echo "✅ Test 6 PASSED: Defines RETRY_DELAY variable" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((passed_tests++))
    else
        echo "❌ Test 6 FAILED: Does not define RETRY_DELAY variable"
        echo "❌ Test 6 FAILED: Does not define RETRY_DELAY variable" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((failed_tests++))
    fi

    # Test 7: Should define LOCK_TIMEOUT variable
    ((total_tests++))
    if assert_pattern_in_file "LOCK_TIMEOUT=" "${AGENT_SCRIPT}"; then
        echo "✅ Test 7 PASSED: Defines LOCK_TIMEOUT variable"
        echo "✅ Test 7 PASSED: Defines LOCK_TIMEOUT variable" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((passed_tests++))
    else
        echo "❌ Test 7 FAILED: Does not define LOCK_TIMEOUT variable"
        echo "❌ Test 7 FAILED: Does not define LOCK_TIMEOUT variable" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((failed_tests++))
    fi

    # Test 8: Should define init_monitoring function
    ((total_tests++))
    if assert_pattern_in_file "init_monitoring\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 8 PASSED: Defines init_monitoring function"
        echo "✅ Test 8 PASSED: Defines init_monitoring function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((passed_tests++))
    else
        echo "❌ Test 8 FAILED: Does not define init_monitoring function"
        echo "❌ Test 8 FAILED: Does not define init_monitoring function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((failed_tests++))
    fi

    # Test 9: Should define log_lock_timeout function
    ((total_tests++))
    if assert_pattern_in_file "log_lock_timeout\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 9 PASSED: Defines log_lock_timeout function"
        echo "✅ Test 9 PASSED: Defines log_lock_timeout function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((passed_tests++))
    else
        echo "❌ Test 9 FAILED: Does not define log_lock_timeout function"
        echo "❌ Test 9 FAILED: Does not define log_lock_timeout function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((failed_tests++))
    fi

    # Test 10: Should define update_agent_status function
    ((total_tests++))
    if assert_pattern_in_file "update_agent_status\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 10 PASSED: Defines update_agent_status function"
        echo "✅ Test 10 PASSED: Defines update_agent_status function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((passed_tests++))
    else
        echo "❌ Test 10 FAILED: Does not define update_agent_status function"
        echo "❌ Test 10 FAILED: Does not define update_agent_status function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((failed_tests++))
    fi

    # Test 11: Should define _update_agent_status_locked function
    ((total_tests++))
    if assert_pattern_in_file "_update_agent_status_locked\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 11 PASSED: Defines _update_agent_status_locked function"
        echo "✅ Test 11 PASSED: Defines _update_agent_status_locked function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((passed_tests++))
    else
        echo "❌ Test 11 FAILED: Does not define _update_agent_status_locked function"
        echo "❌ Test 11 FAILED: Does not define _update_agent_status_locked function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((failed_tests++))
    fi

    # Test 12: Should define increment_task_count function
    ((total_tests++))
    if assert_pattern_in_file "increment_task_count\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 12 PASSED: Defines increment_task_count function"
        echo "✅ Test 12 PASSED: Defines increment_task_count function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((passed_tests++))
    else
        echo "❌ Test 12 FAILED: Does not define increment_task_count function"
        echo "❌ Test 12 FAILED: Does not define increment_task_count function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((failed_tests++))
    fi

    # Test 13: Should define should_auto_restart function
    ((total_tests++))
    if assert_pattern_in_file "should_auto_restart\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 13 PASSED: Defines should_auto_restart function"
        echo "✅ Test 13 PASSED: Defines should_auto_restart function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((passed_tests++))
    else
        echo "❌ Test 13 FAILED: Does not define should_auto_restart function"
        echo "❌ Test 13 FAILED: Does not define should_auto_restart function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((failed_tests++))
    fi

    # Test 14: Should define enable_auto_restart function
    ((total_tests++))
    if assert_pattern_in_file "enable_auto_restart\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 14 PASSED: Defines enable_auto_restart function"
        echo "✅ Test 14 PASSED: Defines enable_auto_restart function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((passed_tests++))
    else
        echo "❌ Test 14 FAILED: Does not define enable_auto_restart function"
        echo "❌ Test 14 FAILED: Does not define enable_auto_restart function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((failed_tests++))
    fi

    # Test 15: Should define disable_auto_restart function
    ((total_tests++))
    if assert_pattern_in_file "disable_auto_restart\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 15 PASSED: Defines disable_auto_restart function"
        echo "✅ Test 15 PASSED: Defines disable_auto_restart function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((passed_tests++))
    else
        echo "❌ Test 15 FAILED: Does not define disable_auto_restart function"
        echo "❌ Test 15 FAILED: Does not define disable_auto_restart function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((failed_tests++))
    fi

    # Test 16: Should define handle_agent_failure function
    ((total_tests++))
    if assert_pattern_in_file "handle_agent_failure\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 16 PASSED: Defines handle_agent_failure function"
        echo "✅ Test 16 PASSED: Defines handle_agent_failure function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((passed_tests++))
    else
        echo "❌ Test 16 FAILED: Does not define handle_agent_failure function"
        echo "❌ Test 16 FAILED: Does not define handle_agent_failure function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((failed_tests++))
    fi

    # Test 17: Should define get_lock_timeout_count function
    ((total_tests++))
    if assert_pattern_in_file "get_lock_timeout_count\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 17 PASSED: Defines get_lock_timeout_count function"
        echo "✅ Test 17 PASSED: Defines get_lock_timeout_count function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((passed_tests++))
    else
        echo "❌ Test 17 FAILED: Does not define get_lock_timeout_count function"
        echo "❌ Test 17 FAILED: Does not define get_lock_timeout_count function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((failed_tests++))
    fi

    # Test 18: Should define get_recent_lock_timeouts function
    ((total_tests++))
    if assert_pattern_in_file "get_recent_lock_timeouts\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 18 PASSED: Defines get_recent_lock_timeouts function"
        echo "✅ Test 18 PASSED: Defines get_recent_lock_timeouts function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((passed_tests++))
    else
        echo "❌ Test 18 FAILED: Does not define get_recent_lock_timeouts function"
        echo "❌ Test 18 FAILED: Does not define get_recent_lock_timeouts function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((failed_tests++))
    fi

    # Test 19: Should define clear_old_lock_logs function
    ((total_tests++))
    if assert_pattern_in_file "clear_old_lock_logs\(\)" "${AGENT_SCRIPT}"; then
        echo "✅ Test 19 PASSED: Defines clear_old_lock_logs function"
        echo "✅ Test 19 PASSED: Defines clear_old_lock_logs function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((passed_tests++))
    else
        echo "❌ Test 19 FAILED: Does not define clear_old_lock_logs function"
        echo "❌ Test 19 FAILED: Does not define clear_old_lock_logs function" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((failed_tests++))
    fi

    # Test 20: Should export functions
    ((total_tests++))
    if assert_pattern_in_file "export -f" "${AGENT_SCRIPT}"; then
        echo "✅ Test 20 PASSED: Exports functions"
        echo "✅ Test 20 PASSED: Exports functions" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((passed_tests++))
    else
        echo "❌ Test 20 FAILED: Does not export functions"
        echo "❌ Test 20 FAILED: Does not export functions" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
        ((failed_tests++))
    fi

    # Summary
    echo ""
    echo "=========================================="
    echo "Test Summary for enhanced_shared_functions.sh:"
    echo "Total Tests: $total_tests"
    echo "Passed: $passed_tests"
    echo "Failed: $failed_tests"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%"
    echo "=========================================="

    echo "" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
    echo "Test Summary:" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
    echo "Total Tests: $total_tests" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
    echo "Passed: $passed_tests" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
    echo "Failed: $failed_tests" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
    echo "Success Rate: $((passed_tests * 100 / total_tests))%" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
    echo "==========================================" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"

    if [[ $failed_tests -eq 0 ]]; then
        echo "🎉 All tests passed!"
        echo "🎉 All tests passed!" >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
    else
        echo "⚠️  Some tests failed. Check the log for details."
        echo "⚠️  Some tests failed. Check the log for details." >>"${SCRIPT_DIR}/test_results_enhanced_shared_functions.txt"
    fi
}

# Run the tests
run_tests
