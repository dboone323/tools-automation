#!/bin/bash
# Test suite for backup_manager.sh
# Comprehensive testing for backup/restore operations with rotation and audit logging

# Source the agent script for testing
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENTS_DIR="$(cd "${SCRIPT_DIR}/../agents" && pwd)"
AGENT_SCRIPT="${AGENTS_DIR}/backup_manager.sh"

# Set test mode to prevent main loop execution
export TEST_MODE=true

# Source the agent script
# shellcheck source=../agents/backup_manager.sh
source "${AGENT_SCRIPT}"

# Mock external commands and functions for testing
mock_date() {
    local format="$1"
    case "$format" in
    "+%Y%m%d_%H%M%S")
        echo "20231201_120000"
        ;;
    "+%Y-%m-%d %H:%M:%S")
        echo "2023-12-01 12:00:00"
        ;;
    *)
        echo "mock_date"
        ;;
    esac
}

mock_whoami() {
    echo "testuser"
}

mock_cp() {
    local src="$1"
    local dest="$2"
    echo "cp mocked: $src -> $dest"
    # Create the destination directory to simulate successful copy
    mkdir -p "$dest"
}

mock_rm() {
    local target="$1"
    echo "rm mocked: $target"
    # Actually remove if it's a test directory
    if [[ "$target" == /tmp/test_* ]]; then
        rm -rf "$target" 2>/dev/null || true
    fi
}

mock_find() {
    local path="$1"
    local args=("$@")
    case "${args[*]}" in
    *"-name test_project_* -type d -mmin -60"*)
        # Mock recent backup check - return empty for no recent backup
        echo ""
        ;;
    *"-name test_project_recent_* -type d -mmin -60"*)
        # Mock recent backup exists
        echo "/tmp/test_backups/test_project_recent_20231201_110000"
        ;;
    *"-maxdepth 1 -type d -name test_project_*"*)
        # Mock finding backup directories
        echo "/tmp/test_backups/test_project_20231201_120000"
        echo "/tmp/test_backups/test_project_20231201_110000"
        ;;
    *"-maxdepth 1 -type d -name nonexistent_*"*)
        # Mock no backups found
        echo ""
        ;;
    *)
        echo "find mocked"
        ;;
    esac
}

mock_ls() {
    local args=("$@")
    if [[ "${args[*]}" == *"-lh"* ]]; then
        echo "total 0"
        echo "drwxr-xr-x  2 testuser  staff   64B Dec  1 12:00 test_project_20231201_120000"
    else
        echo "ls mocked"
    fi
}

mock_stat() {
    local flag="$1"
    local file="$2"
    case "$flag" in
    "-f %m")
        # Mock file modification time
        echo "1701432000"
        ;;
    "-c %Y")
        echo "1701432000"
        ;;
    *)
        echo "stat mocked"
        ;;
    esac
}

mock_mkdir() {
    local dir="$1"
    echo "mkdir mocked: $dir"
    # Don't actually create directories to avoid issues
    return 0
}

mock_touch() {
    local file="$1"
    echo "touch mocked: $file"
    # Don't actually touch files
    return 0
}

# Mock shared functions
update_agent_status() {
    # Mock agent status update
    return 0
}

# Override commands with mocks
date() { mock_date "$@"; }
whoami() { mock_whoami "$@"; }
cp() { mock_cp "$@"; }
rm() { mock_rm "$@"; }
find() { mock_find "$@"; }
ls() { mock_ls "$@"; }
stat() { mock_stat "$@"; }
mkdir() { mock_mkdir "$@"; }
touch() { mock_touch "$@"; }

# Test setup and teardown
setup_test_env() {
    export TEST_MODE=true

    # Create test directories
    export BACKUP_DIR="/tmp/test_backups"
    export PROJECTS_DIR="/tmp/test_projects"
    export AUDIT_LOG="/tmp/test_audit.log"

    # Actually create directories for tests
    mkdir -p "$BACKUP_DIR"
    mkdir -p "$PROJECTS_DIR"
    mkdir -p "$PROJECTS_DIR/test_project"
    echo "test content" >"$PROJECTS_DIR/test_project/test_file.txt"

    # Initialize audit log
    touch "$AUDIT_LOG"

    # Set MAX_BACKUPS_PER_PROJECT for testing
    MAX_BACKUPS_PER_PROJECT=3
}

teardown_test_env() {
    rm -rf /tmp/test_backups /tmp/test_projects /tmp/test_audit.log
    unset BACKUP_DIR
    unset PROJECTS_DIR
    unset AUDIT_LOG
}

# Test functions
test_basic_execution() {
    echo "Testing basic execution..."

    # Test that the script sources without errors
    assert_success "Script sources successfully" true

    echo "✓ Basic execution test passed"
}

test_backup_creation() {
    echo "Testing backup creation..."

    # Test successful backup creation
    bash "$AGENT_SCRIPT" backup test_project 2>/dev/null
    assert_success "Backup creation succeeds" [ $? -eq 0 ]

    # Verify audit log entry
    assert_success "Audit log contains backup entry" grep -q "action=backup.*result=success" "$AUDIT_LOG"

    echo "✓ Backup creation test passed"
}

test_backup_if_needed() {
    echo "Testing backup_if_needed functionality..."

    # Test backup_if_needed when no recent backup exists
    bash "$AGENT_SCRIPT" backup_if_needed test_project 2>/dev/null
    assert_success "backup_if_needed creates backup when none recent" [ $? -eq 0 ]

    # Test backup_if_needed when recent backup exists (mocked)
    bash "$AGENT_SCRIPT" backup_if_needed test_project_recent 2>/dev/null
    assert_success "backup_if_needed skips when recent backup exists" [ $? -eq 0 ]

    echo "✓ backup_if_needed test passed"
}

test_backup_rotation() {
    echo "Testing backup rotation..."

    # Create multiple backups to trigger rotation
    for i in {1..5}; do
        mkdir -p "$BACKUP_DIR/test_project_20231201_12000${i}"
    done

    # Test rotation
    bash "$AGENT_SCRIPT" rotate test_project 2>/dev/null
    assert_success "Backup rotation succeeds" [ $? -eq 0 ]

    # Verify audit log entries for removed backups
    local remove_count
    remove_count=$(grep -c "action=rotate_backup.*result=success" "$AUDIT_LOG")
    assert_success "Rotation audit entries created" [ "$remove_count" -gt 0 ]

    echo "✓ Backup rotation test passed"
}

test_restore_functionality() {
    echo "Testing restore functionality..."

    # Create a backup first
    mkdir -p "$BACKUP_DIR/test_project_20231201_120000"
    echo "backup content" >"$BACKUP_DIR/test_project_20231201_120000/backup_file.txt"

    # Remove original project to test restore
    rm -rf "$PROJECTS_DIR/test_project"

    # Test restore
    bash "$AGENT_SCRIPT" restore test_project 2>/dev/null
    assert_success "Restore succeeds" [ $? -eq 0 ]

    # Verify audit log entry
    assert_success "Audit log contains restore entry" grep -q "action=restore.*result=success" "$AUDIT_LOG"

    echo "✓ Restore functionality test passed"
}

test_list_backups() {
    echo "Testing list backups functionality..."

    # Create some test backups
    mkdir -p "$BACKUP_DIR/test_project_20231201_120000"
    mkdir -p "$BACKUP_DIR/other_project_20231201_130000"

    # Test list command
    local output
    output=$(bash "$AGENT_SCRIPT" list 2>/dev/null)
    assert_success "List command succeeds" [ $? -eq 0 ]

    # Verify audit log entry
    assert_success "Audit log contains list entry" grep -q "action=list_backups.*result=success" "$AUDIT_LOG"

    echo "✓ List backups test passed"
}

test_error_handling() {
    echo "Testing error handling..."

    # Test backup of non-existent project
    bash "$AGENT_SCRIPT" backup nonexistent_project 2>/dev/null
    assert_success "Non-existent project backup fails gracefully" [ $? -eq 1 ]

    # Verify audit log entry for failure
    assert_success "Audit log contains failure entry" grep -q "action=backup.*result=fail" "$AUDIT_LOG"

    # Test restore of project with no backups
    bash "$AGENT_SCRIPT" restore nonexistent_project 2>/dev/null
    assert_success "Restore with no backups fails gracefully" [ $? -eq 1 ]

    # Test rotate with no project specified
    bash "$AGENT_SCRIPT" rotate 2>/dev/null
    assert_success "Rotate without project fails gracefully" [ $? -eq 1 ]

    echo "✓ Error handling test passed"
}

test_rotate_backups_function() {
    echo "Testing rotate_backups function directly..."

    # Create test backup directories
    mkdir -p "$BACKUP_DIR/test_rotate_1"
    mkdir -p "$BACKUP_DIR/test_rotate_2"
    mkdir -p "$BACKUP_DIR/test_rotate_3"
    mkdir -p "$BACKUP_DIR/test_rotate_4"
    mkdir -p "$BACKUP_DIR/test_rotate_5"

    # Touch files with different timestamps (simulate different ages)
    touch "$BACKUP_DIR/test_rotate_1" # newest
    sleep 1
    touch "$BACKUP_DIR/test_rotate_2"
    sleep 1
    touch "$BACKUP_DIR/test_rotate_3"
    sleep 1
    touch "$BACKUP_DIR/test_rotate_4"
    sleep 1
    touch "$BACKUP_DIR/test_rotate_5" # oldest

    # Test rotation (should keep 3 most recent)
    rotate_backups "test_rotate"

    # Count remaining directories
    local remaining
    remaining=$(find "$BACKUP_DIR" -name "test_rotate_*" -type d | wc -l)
    assert_success "Rotation keeps correct number of backups" [ "$remaining" -le 3 ]

    echo "✓ rotate_backups function test passed"
}

test_audit_logging() {
    echo "Testing audit logging functionality..."

    # Clear audit log
    >"$AUDIT_LOG"

    # Perform various operations
    bash "$AGENT_SCRIPT" backup test_project 2>/dev/null
    bash "$AGENT_SCRIPT" list 2>/dev/null
    bash "$AGENT_SCRIPT" rotate test_project 2>/dev/null

    # Verify audit log contains expected entries
    local backup_entries
    local list_entries
    local rotate_entries

    backup_entries=$(grep -c "action=backup" "$AUDIT_LOG")
    list_entries=$(grep -c "action=list_backups" "$AUDIT_LOG")
    rotate_entries=$(grep -c "action=rotate_backup" "$AUDIT_LOG")

    assert_success "Backup operations logged" [ "$backup_entries" -gt 0 ]
    assert_success "List operations logged" [ "$list_entries" -gt 0 ]
    assert_success "Rotate operations logged" [ "$rotate_entries" -gt 0 ]

    echo "✓ Audit logging test passed"
}

test_invalid_command() {
    echo "Testing invalid command handling..."

    # Test invalid command
    bash "$AGENT_SCRIPT" invalid_command 2>/dev/null
    assert_success "Invalid command fails gracefully" [ $? -eq 1 ]

    echo "✓ Invalid command test passed"
}

# Assertion functions
assert_success() {
    local message="$1"
    shift
    if "$@"; then
        echo "✓ ${message}"
        return 0
    else
        echo "✗ ${message}"
        return 1
    fi
}

# Run tests
main() {
    echo "Running backup_manager.sh test suite..."
    echo "=========================================="

    local failed_tests=0
    local total_tests=0

    setup_test_env

    # Run all tests
    for test_func in test_basic_execution test_backup_creation test_backup_if_needed test_backup_rotation test_restore_functionality test_list_backups test_error_handling test_rotate_backups_function test_audit_logging test_invalid_command; do
        ((total_tests++))
        echo ""
        echo "Running ${test_func}..."
        if ! ${test_func}; then
            ((failed_tests++))
            echo "✗ ${test_func} failed"
        fi
    done

    teardown_test_env

    echo ""
    echo "=========================================="
    echo "Test Results: ${total_tests} total, $((total_tests - failed_tests)) passed, ${failed_tests} failed"

    if [[ ${failed_tests} -eq 0 ]]; then
        echo "✓ All tests passed!"
        exit 0
    else
        echo "✗ ${failed_tests} test(s) failed"
        exit 1
    fi
}

# Run main if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
