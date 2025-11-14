#!/bin/bash

# Test script for serve_dashboard.sh

set -e

# Get the absolute path to the test script directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/serve_dashboard.sh"

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

echo "Running tests for serve_dashboard.sh..."
echo "==========================================="

# Test 1: Script exists
assert_file_exists "${AGENT_SCRIPT}" "1"

# Test 2: Script is executable
assert_file_executable "${AGENT_SCRIPT}" "2"

# Test 3: Defines SCRIPT_DIR variable
assert_pattern_in_file "${AGENT_SCRIPT}" "SCRIPT_DIR=" "3"

# Test 4: Defines DASHBOARD_DIR variable
assert_pattern_in_file "${AGENT_SCRIPT}" "DASHBOARD_DIR=" "4"

# Test 5: Defines LOG_FILE variable
assert_pattern_in_file "${AGENT_SCRIPT}" "LOG_FILE=" "5"

# Test 6: Defines STATUS_FILE variable
assert_pattern_in_file "${AGENT_SCRIPT}" "STATUS_FILE=" "6"

# Test 7: Defines PORT variable
assert_pattern_in_file "${AGENT_SCRIPT}" "PORT=" "7"

# Test 8: Defines HOST variable
assert_pattern_in_file "${AGENT_SCRIPT}" "HOST=" "8"

# Test 9: Has log function
assert_pattern_in_file "${AGENT_SCRIPT}" "log()" "9"

# Test 10: Has update_status function
assert_pattern_in_file "${AGENT_SCRIPT}" "update_status()" "10"

# Test 11: Has check_dependencies function
assert_pattern_in_file "${AGENT_SCRIPT}" "check_dependencies()" "11"

# Test 12: Has create_sample_dashboard function
assert_pattern_in_file "${AGENT_SCRIPT}" "create_sample_dashboard()" "12"

# Test 13: Has start_server function
assert_pattern_in_file "${AGENT_SCRIPT}" "start_server()" "13"

# Test 14: Has stop_server function
assert_pattern_in_file "${AGENT_SCRIPT}" "stop_server()" "14"

# Test 15: Has check_server_health function
assert_pattern_in_file "${AGENT_SCRIPT}" "check_server_health()" "15"

# Test 16: Sources shared_functions.sh
assert_pattern_in_file "${AGENT_SCRIPT}" "shared_functions.sh" "16"

# Test 17: Has mkdir commands for directory creation
assert_pattern_in_file "${AGENT_SCRIPT}" "mkdir -p" "17"

# Test 18: Has python command for server
assert_pattern_in_file "${AGENT_SCRIPT}" "python" "18"

# Test 19: Has main function
assert_pattern_in_file "${AGENT_SCRIPT}" "main()" "19"

# Test 20: Has proper shebang
assert_pattern_in_file "${AGENT_SCRIPT}" "#!/bin/bash" "20"

echo "==========================================="
echo "Test Summary for serve_dashboard.sh:"
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
