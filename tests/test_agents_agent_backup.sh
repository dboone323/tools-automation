#!/bin/bash
# Test suite for agent_backup.sh

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/../agents/agent_backup.sh"

# Source shell test framework
source "${SCRIPT_DIR}/../shell_test_framework.sh"

# Test 1: Script should be executable
test_agent_backup_executable() {
    local test_name="test_agent_backup_executable"
    announce_test "$test_name"

    assert_file_executable "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 2: Should source shared_functions.sh
test_agent_backup_sources_shared_functions() {
    local test_name="test_agent_backup_sources_shared_functions"
    announce_test "$test_name"

    assert_pattern_in_file "source.*shared_functions.sh" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 3: Should have run_with_timeout function
test_agent_backup_timeout_function() {
    local test_name="test_agent_backup_timeout_function"
    announce_test "$test_name"

    assert_pattern_in_file "run_with_timeout\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 4: Should have initialize_manifest function
test_agent_backup_initialize_manifest() {
    local test_name="test_agent_backup_initialize_manifest"
    announce_test "$test_name"

    assert_pattern_in_file "initialize_manifest\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 5: Should have calculate_checksum function
test_agent_backup_calculate_checksum() {
    local test_name="test_agent_backup_calculate_checksum"
    announce_test "$test_name"

    assert_pattern_in_file "calculate_checksum\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 6: Should have create_backup function
test_agent_backup_create_backup() {
    local test_name="test_agent_backup_create_backup"
    announce_test "$test_name"

    assert_pattern_in_file "create_backup\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 7: Should have verify_backup function
test_agent_backup_verify_backup() {
    local test_name="test_agent_backup_verify_backup"
    announce_test "$test_name"

    assert_pattern_in_file "verify_backup\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 8: Should have list_backups function
test_agent_backup_list_backups() {
    local test_name="test_agent_backup_list_backups"
    announce_test "$test_name"

    assert_pattern_in_file "list_backups\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 9: Should have cleanup_old_backups function
test_agent_backup_cleanup_old() {
    local test_name="test_agent_backup_cleanup_old"
    announce_test "$test_name"

    assert_pattern_in_file "cleanup_old_backups\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 10: Should have restore_backup function
test_agent_backup_restore_backup() {
    local test_name="test_agent_backup_restore_backup"
    announce_test "$test_name"

    assert_pattern_in_file "restore_backup\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 11: Should have process_backup_task function
test_agent_backup_process_task() {
    local test_name="test_agent_backup_process_task"
    announce_test "$test_name"

    assert_pattern_in_file "process_backup_task\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 12: Should have main function
test_agent_backup_main() {
    local test_name="test_agent_backup_main"
    announce_test "$test_name"

    assert_pattern_in_file "main\(\)" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 13: Should have log_message function call
test_agent_backup_log_message() {
    local test_name="test_agent_backup_log_message"
    announce_test "$test_name"

    assert_pattern_in_file "log_message" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 14: Should have check_resource_limits function call
test_agent_backup_resource_limits() {
    local test_name="test_agent_backup_resource_limits"
    announce_test "$test_name"

    assert_pattern_in_file "check_resource_limits" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Test 15: Should have get_next_task function call
test_agent_backup_get_next_task() {
    local test_name="test_agent_backup_get_next_task"
    announce_test "$test_name"

    assert_pattern_in_file "get_next_task" "$AGENT_SCRIPT"

    test_passed "$test_name"
}

# Run all tests
run_tests() {
    echo "Running tests for agent_backup.sh..."
    echo "================================================================="

    # Run individual tests
    test_agent_backup_executable
    test_agent_backup_sources_shared_functions
    test_agent_backup_timeout_function
    test_agent_backup_initialize_manifest
    test_agent_backup_calculate_checksum
    test_agent_backup_create_backup
    test_agent_backup_verify_backup
    test_agent_backup_list_backups
    test_agent_backup_cleanup_old
    test_agent_backup_restore_backup
    test_agent_backup_process_task
    test_agent_backup_main
    test_agent_backup_log_message
    test_agent_backup_resource_limits
    test_agent_backup_get_next_task

    echo "================================================================="
    echo "Test Summary:"
    echo "Total tests: $(get_total_tests)"
    echo "Passed: $(get_passed_tests)"
    echo "Failed: $(get_failed_tests)"

    # Return success/failure
    if [[ $(get_failed_tests) -eq 0 ]]; then
        echo "✅ All tests passed!"
        return 0
    else
        echo "❌ Some tests failed!"
        return 1
    fi
}

# Execute tests if script is run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    run_tests
fi
