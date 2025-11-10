#!/bin/bash

# Test script for simple_dashboard.sh

set -e

# Get the absolute path to the test script directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/simple_dashboard.sh"

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

echo "Running tests for simple_dashboard.sh..."
echo "==========================================="

# Test 1: Script exists
assert_file_exists "${AGENT_SCRIPT}" "1"

# Test 2: Script is executable
assert_file_executable "${AGENT_SCRIPT}" "2"

# Test 3: Defines SCRIPT_DIR variable
assert_pattern_in_file "${AGENT_SCRIPT}" "SCRIPT_DIR=" "3"

# Test 4: Defines STATUS_DIR variable
assert_pattern_in_file "${AGENT_SCRIPT}" "STATUS_DIR=" "4"

# Test 5: Defines LOG_FILE variable
assert_pattern_in_file "${AGENT_SCRIPT}" "LOG_FILE=" "5"

# Test 6: Defines REFRESH_INTERVAL variable
assert_pattern_in_file "${AGENT_SCRIPT}" "REFRESH_INTERVAL=" "6"

# Test 7: Has log function
assert_pattern_in_file "${AGENT_SCRIPT}" "log()" "7"

# Test 8: Has clear_screen function
assert_pattern_in_file "${AGENT_SCRIPT}" "clear_screen()" "8"

# Test 9: Has print_header function
assert_pattern_in_file "${AGENT_SCRIPT}" "print_header()" "9"

# Test 10: Has print_agent_status function
assert_pattern_in_file "${AGENT_SCRIPT}" "print_agent_status()" "10"

# Test 11: Has print_system_info function
assert_pattern_in_file "${AGENT_SCRIPT}" "print_system_info()" "11"

# Test 12: Has print_recent_logs function
assert_pattern_in_file "${AGENT_SCRIPT}" "print_recent_logs()" "12"

# Test 13: Has display_dashboard function
assert_pattern_in_file "${AGENT_SCRIPT}" "display_dashboard()" "13"

# Test 14: Sources shared_functions.sh
assert_pattern_in_file "${AGENT_SCRIPT}" "shared_functions.sh" "14"

# Test 15: Has mkdir commands for directory creation
assert_pattern_in_file "${AGENT_SCRIPT}" "mkdir -p" "15"

# Test 16: Has sleep command in main loop
assert_pattern_in_file "${AGENT_SCRIPT}" "sleep" "16"

# Test 17: Has trap command for signal handling
assert_pattern_in_file "${AGENT_SCRIPT}" "trap" "17"

# Test 18: Has main function
assert_pattern_in_file "${AGENT_SCRIPT}" "main()" "18"

# Test 19: Has proper shebang
assert_pattern_in_file "${AGENT_SCRIPT}" "#!/bin/bash" "19"

# Test 20: Has echo -e for colored output
assert_pattern_in_file "${AGENT_SCRIPT}" "echo -e" "20"

echo "==========================================="
echo "Test Summary for simple_dashboard.sh:"
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
