#!/bin/bash

# Test script for monitor_lock_timeouts.sh

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/monitor_lock_timeouts.sh"

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
        ((PASSED++))
    else
        echo -e "${RED}❌ Test ${test_name} FAILED: ${file} does not exist${NC}"
        ((FAILED++))
    fi
}

assert_file_executable() {
    local file="$1"
    local test_name="$2"

    if [[ -x "${file}" ]]; then
        echo -e "${GREEN}✅ Test ${test_name} PASSED: ${file} is executable${NC}"
        ((PASSED++))
    else
        echo -e "${RED}❌ Test ${test_name} FAILED: ${file} is not executable${NC}"
        ((FAILED++))
    fi
}

assert_pattern_in_file() {
    local file="$1"
    local pattern="$2"
    local test_name="$3"

    if grep -q "${pattern}" "${file}"; then
        echo -e "${GREEN}✅ Test ${test_name} PASSED: Pattern '${pattern}' found in ${file}${NC}"
        ((PASSED++))
    else
        echo -e "${RED}❌ Test ${test_name} FAILED: Pattern '${pattern}' not found in ${file}${NC}"
        ((FAILED++))
    fi
}

echo "Running tests for monitor_lock_timeouts.sh..."
echo "==========================================="

# Test 1: Script exists
assert_file_exists "${AGENT_SCRIPT}" "1"

# Test 2: Script is executable
assert_file_executable "${AGENT_SCRIPT}" "2"

# Test 3: Defines SCRIPT_DIR variable
assert_pattern_in_file "${AGENT_SCRIPT}" "SCRIPT_DIR=" "3"

# Test 4: Defines LOG_FILE variable
assert_pattern_in_file "${AGENT_SCRIPT}" "LOG_FILE=" "4"

# Test 5: Defines STATUS_FILE variable
assert_pattern_in_file "${AGENT_SCRIPT}" "STATUS_FILE=" "5"

# Test 6: Defines LOCK_DIR variable
assert_pattern_in_file "${AGENT_SCRIPT}" "LOCK_DIR=" "6"

# Test 7: Defines TIMEOUT_THRESHOLD variable
assert_pattern_in_file "${AGENT_SCRIPT}" "TIMEOUT_THRESHOLD=" "7"

# Test 8: Has log function
assert_pattern_in_file "${AGENT_SCRIPT}" "log()" "8"

# Test 9: Has update_status function
assert_pattern_in_file "${AGENT_SCRIPT}" "update_status()" "9"

# Test 10: Has check_lock_timeouts function
assert_pattern_in_file "${AGENT_SCRIPT}" "check_lock_timeouts()" "10"

# Test 11: Has monitor_active_locks function
assert_pattern_in_file "${AGENT_SCRIPT}" "monitor_active_locks()" "11"

# Test 12: Has prevent_deadlocks function
assert_pattern_in_file "${AGENT_SCRIPT}" "prevent_deadlocks()" "12"

# Test 13: Sources shared_functions.sh
assert_pattern_in_file "${AGENT_SCRIPT}" "shared_functions.sh" "13"

# Test 14: Has mkdir commands for directory creation
assert_pattern_in_file "${AGENT_SCRIPT}" "mkdir -p" "14"

# Test 15: Has find command for lock checking
assert_pattern_in_file "${AGENT_SCRIPT}" "find.*lock" "15"

# Test 16: Has stat command for file timestamps
assert_pattern_in_file "${AGENT_SCRIPT}" "stat" "16"

# Test 17: Has date command for current time
assert_pattern_in_file "${AGENT_SCRIPT}" "date +%s" "17"

# Test 18: Has sleep command in main loop
assert_pattern_in_file "${AGENT_SCRIPT}" "sleep" "18"

# Test 19: Has main function
assert_pattern_in_file "${AGENT_SCRIPT}" "main()" "19"

# Test 20: Has proper shebang
assert_pattern_in_file "${AGENT_SCRIPT}" "#!/bin/bash" "20"

echo "==========================================="
echo "Test Summary for monitor_lock_timeouts.sh:"
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
