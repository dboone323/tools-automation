#!/bin/bash
# Test suite for backup_manager.sh
# Tests backup/restore functionality with rotation

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="${SCRIPT_DIR}/../agents"
TEST_RESULTS_DIR="${SCRIPT_DIR}/test_results"
mkdir -p "${TEST_RESULTS_DIR}"

# Source the shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

AGENT_SCRIPT="${AGENTS_DIR}/backup_manager.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

echo "Testing backup_manager.sh..."

# Test 1: Script should be executable
test_script_executable() {
    assert_file_executable "${AGENT_SCRIPT}"
}

# Test 2: Script should define SCRIPT_DIR variable
test_defines_script_dir() {
    assert_pattern_in_file "SCRIPT_DIR=" "${AGENT_SCRIPT}"
}

# Test 3: Script should source shared_functions.sh
test_sources_shared_functions() {
    assert_pattern_in_file "source.*shared_functions.sh" "${AGENT_SCRIPT}"
}

# Test 4: Script should define BACKUP_DIR variable
test_defines_backup_dir() {
    assert_pattern_in_file "BACKUP_DIR=" "${AGENT_SCRIPT}"
}

# Test 5: Script should define PROJECTS_DIR variable
test_defines_projects_dir() {
    assert_pattern_in_file "PROJECTS_DIR=" "${AGENT_SCRIPT}"
}

# Test 6: Script should define AUDIT_LOG variable
test_defines_audit_log() {
    assert_pattern_in_file "AUDIT_LOG=" "${AGENT_SCRIPT}"
}

# Test 7: Script should define MAX_BACKUPS_PER_PROJECT variable
test_defines_max_backups() {
    assert_pattern_in_file "MAX_BACKUPS_PER_PROJECT=" "${AGENT_SCRIPT}"
}

# Test 8: Script should have rotate_backups function
test_has_rotate_backups_function() {
    assert_pattern_in_file "rotate_backups\(\)" "${AGENT_SCRIPT}"
}

# Test 9: Script should have backup_if_needed function
test_has_backup_if_needed_function() {
    assert_pattern_in_file "backup_if_needed\(\)" "${AGENT_SCRIPT}"
}

# Test 10: Script should handle backup case
test_handles_backup_case() {
    assert_pattern_in_file "backup)" "${AGENT_SCRIPT}"
}

# Test 11: Script should handle backup_if_needed case
test_handles_backup_if_needed_case() {
    assert_pattern_in_file "backup_if_needed)" "${AGENT_SCRIPT}"
}

# Test 12: Script should handle rotate case
test_handles_rotate_case() {
    assert_pattern_in_file "rotate)" "${AGENT_SCRIPT}"
}

# Test 13: Script should handle restore case
test_handles_restore_case() {
    assert_pattern_in_file "restore)" "${AGENT_SCRIPT}"
}

# Test 14: Script should handle list case
test_handles_list_case() {
    assert_pattern_in_file "list)" "${AGENT_SCRIPT}"
}

# Test 15: Script should create backup directory
test_creates_backup_dir() {
    assert_pattern_in_file "mkdir -p.*BACKUP_DIR" "${AGENT_SCRIPT}"
}

# Test 16: Script should use find command for backups
test_uses_find_for_backups() {
    assert_pattern_in_file "find.*BACKUP_DIR" "${AGENT_SCRIPT}"
}

# Test 17: Script should use cp -r for copying
test_uses_cp_r_for_copying() {
    assert_pattern_in_file "cp -r" "${AGENT_SCRIPT}"
}

# Test 18: Script should use rm -rf for removal
test_uses_rm_rf_for_removal() {
    assert_pattern_in_file "rm -rf" "${AGENT_SCRIPT}"
}

# Test 19: Script should use date for timestamps
test_uses_date_for_timestamps() {
    assert_pattern_in_file "date +" "${AGENT_SCRIPT}"
}

# Test 20: Script should provide usage information
test_provides_usage_info() {
    assert_pattern_in_file "Usage:" "${AGENT_SCRIPT}"
}

# Run all tests
tests=(
    test_script_executable
    test_defines_script_dir
    test_sources_shared_functions
    test_defines_backup_dir
    test_defines_projects_dir
    test_defines_audit_log
    test_defines_max_backups
    test_has_rotate_backups_function
    test_has_backup_if_needed_function
    test_handles_backup_case
    test_handles_backup_if_needed_case
    test_handles_rotate_case
    test_handles_restore_case
    test_handles_list_case
    test_creates_backup_dir
    test_uses_find_for_backups
    test_uses_cp_r_for_copying
    test_uses_rm_rf_for_removal
    test_uses_date_for_timestamps
    test_provides_usage_info
)

echo "Running ${#tests[@]} tests for backup_manager.sh..."

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
echo "backup_manager.sh Test Results"
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
RESULTS_FILE="${TEST_RESULTS_DIR}/test_backup_manager_results.txt"
{
    echo "backup_manager.sh Test Results"
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
