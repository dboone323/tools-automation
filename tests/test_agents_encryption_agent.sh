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

AGENT_NAME="test_agents_encryption_agent.sh"
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

# Test script for encryption_agent.sh

set -e

# Get the absolute path to the test script directory
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "${TEST_DIR}/.." && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/encryption_agent.sh"

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

echo "Running tests for encryption_agent.sh..."
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

# Test 6: Defines BACKUP_DIR variable
assert_pattern_in_file "${AGENT_SCRIPT}" "BACKUP_DIR=" "6"

# Test 7: Defines ENCRYPTION_DIR variable
assert_pattern_in_file "${AGENT_SCRIPT}" "ENCRYPTION_DIR=" "7"

# Test 8: Defines CONFIG_DIR variable
assert_pattern_in_file "${AGENT_SCRIPT}" "CONFIG_DIR=" "8"

# Test 9: Defines LOG_FILE variable
assert_pattern_in_file "${AGENT_SCRIPT}" "LOG_FILE=" "9"

# Test 10: Defines STATUS_FILE variable
assert_pattern_in_file "${AGENT_SCRIPT}" "STATUS_FILE=" "10"

# Test 11: Defines CONFIG_FILE variable
assert_pattern_in_file "${AGENT_SCRIPT}" "CONFIG_FILE=" "11"

# Test 12: Defines KEYSTORE_FILE variable
assert_pattern_in_file "${AGENT_SCRIPT}" "KEYSTORE_FILE=" "12"

# Test 13: Has log function
assert_pattern_in_file "${AGENT_SCRIPT}" "log()" "13"

# Test 14: Has initialize_encryption_system function
assert_pattern_in_file "${AGENT_SCRIPT}" "initialize_encryption_system()" "14"

# Test 15: Has generate_master_key function
assert_pattern_in_file "${AGENT_SCRIPT}" "generate_master_key()" "15"

# Test 16: Has encrypt_data function
assert_pattern_in_file "${AGENT_SCRIPT}" "encrypt_data()" "16"

# Test 17: Has decrypt_data function
assert_pattern_in_file "${AGENT_SCRIPT}" "decrypt_data()" "17"

# Test 18: Has encrypt_file function
assert_pattern_in_file "${AGENT_SCRIPT}" "encrypt_file()" "18"

# Test 19: Has decrypt_file function
assert_pattern_in_file "${AGENT_SCRIPT}" "decrypt_file()" "19"

# Test 20: Has encrypt_directory function
assert_pattern_in_file "${AGENT_SCRIPT}" "encrypt_directory()" "20"

# Test 21: Has decrypt_directory function
assert_pattern_in_file "${AGENT_SCRIPT}" "decrypt_directory()" "21"

# Test 22: Has generate_key function
assert_pattern_in_file "${AGENT_SCRIPT}" "generate_key()" "22"

# Test 23: Has get_config_value function
assert_pattern_in_file "${AGENT_SCRIPT}" "get_config_value()" "23"

# Test 24: Has check_encryption_health function
assert_pattern_in_file "${AGENT_SCRIPT}" "check_encryption_health()" "24"

# Test 25: Has rotate_master_key function
assert_pattern_in_file "${AGENT_SCRIPT}" "rotate_master_key()" "25"

# Test 26: Has list_encrypted_files function
assert_pattern_in_file "${AGENT_SCRIPT}" "list_encrypted_files()" "26"

# Test 27: Has cleanup_old_backups function
assert_pattern_in_file "${AGENT_SCRIPT}" "cleanup_old_backups()" "27"

# Test 28: Has main function
assert_pattern_in_file "${AGENT_SCRIPT}" "main()" "28"

# Test 29: Has trap command for signal handling
assert_pattern_in_file "${AGENT_SCRIPT}" "trap" "29"

# Test 30: Has proper shebang
assert_pattern_in_file "${AGENT_SCRIPT}" "#!/bin/bash" "30"

# Test 31: Has case statement for command line arguments
assert_pattern_in_file "${AGENT_SCRIPT}" "case" "31"

# Test 32: Has mkdir commands for directory creation
assert_pattern_in_file "${AGENT_SCRIPT}" "mkdir -p" "32"

echo "==========================================="
echo "Test Summary for encryption_agent.sh:"
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
