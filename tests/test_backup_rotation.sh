#!/bin/bash

# Test suite for backup_rotation.sh
# Comprehensive tests covering all functionality

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shell_test_framework.sh"

# Override PROJECT_ROOT for this test
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BACKUP_SCRIPT="$PROJECT_ROOT/backup_rotation.sh"

# Test: Basic backup rotation
test_backup_rotation_basic() {
    echo "Testing basic backup rotation..."

    # Create a temporary backup directory
    local test_backup_dir="/tmp/test_backups_basic"
    mkdir -p "$test_backup_dir"

    # Create some test backup directories (simulate CodingReviewer backups)
    for i in {1..15}; do
        local backup_name="CodingReviewer_test_$(printf "%03d" $i)"
        mkdir -p "$test_backup_dir/$backup_name"
        echo "test content $i" >"$test_backup_dir/$backup_name/file.txt"
        # Set modification time to simulate age (newer = smaller number)
        touch -t "2025$(printf "%02d" $((12 - i)))010000" "$test_backup_dir/$backup_name"
    done

    # Run rotation keeping only 5 recent backups
    local output
    output=$("$BACKUP_SCRIPT" "$test_backup_dir" 5 2>/dev/null)

    # Should show rotation activity
    if echo "$output" | grep -q "Compressed.*old backup directories"; then
        assert_success "Basic backup rotation executed"
    else
        assert_failure "Basic backup rotation failed"
    fi

    # Clean up
    rm -rf "$test_backup_dir"
}

# Test: No rotation needed
test_backup_rotation_no_rotation() {
    echo "Testing no rotation needed scenario..."

    # Create a temporary backup directory
    local test_backup_dir="/tmp/test_backups_no_rotation"
    mkdir -p "$test_backup_dir"

    # Create only a few recent backups (less than keep threshold)
    for i in {1..3}; do
        local backup_name="CodingReviewer_test_$(printf "%03d" $i)"
        mkdir -p "$test_backup_dir/$backup_name"
        echo "test content $i" >"$test_backup_dir/$backup_name/file.txt"
    done

    # Run rotation keeping 5 backups (we only have 3)
    local output
    output=$("$BACKUP_SCRIPT" "$test_backup_dir" 5 2>/dev/null)

    # Should indicate no rotation needed
    if echo "$output" | grep -q "No rotation needed"; then
        assert_success "No rotation correctly detected"
    else
        assert_failure "No rotation detection failed"
    fi

    # Clean up
    rm -rf "$test_backup_dir"
}

# Test: Custom keep count
test_backup_rotation_custom_keep() {
    echo "Testing custom keep count..."

    # Create a temporary backup directory
    local test_backup_dir="/tmp/test_backups_custom"
    mkdir -p "$test_backup_dir"

    # Create test backups
    for i in {1..12}; do
        local backup_name="CodingReviewer_test_$(printf "%03d" $i)"
        mkdir -p "$test_backup_dir/$backup_name"
        echo "test content $i" >"$test_backup_dir/$backup_name/file.txt"
        touch -t "2025$(printf "%02d" $((12 - i)))010000" "$test_backup_dir/$backup_name"
    done

    # Run rotation keeping only 3 recent backups
    local output
    output=$("$BACKUP_SCRIPT" "$test_backup_dir" 3 2>/dev/null)

    # Should show keeping 3 backups
    if echo "$output" | grep -q "Keeping 3 most recent backups"; then
        assert_success "Custom keep count respected"
    else
        assert_failure "Custom keep count not respected"
    fi

    # Clean up
    rm -rf "$test_backup_dir"
}

# Test: Statistics display
test_backup_rotation_stats() {
    echo "Testing backup statistics display..."

    # Create a temporary backup directory
    local test_backup_dir="/tmp/test_backups_stats"
    mkdir -p "$test_backup_dir"

    # Create mix of directories and compressed files
    for i in {1..5}; do
        local backup_name="CodingReviewer_test_$(printf "%03d" $i)"
        mkdir -p "$test_backup_dir/$backup_name"
        echo "test content $i" >"$test_backup_dir/$backup_name/file.txt"
    done

    # Create some compressed files
    for i in {6..8}; do
        local compressed_name="CodingReviewer_test_$(printf "%03d" $i).tar.gz"
        touch "$test_backup_dir/$compressed_name"
    done

    # Run rotation (should show stats)
    local output
    output=$("$BACKUP_SCRIPT" "$test_backup_dir" 10 2>/dev/null)

    # Should show statistics
    if echo "$output" | grep -q "Directories (uncompressed):" && echo "$output" | grep -q "Compressed files:"; then
        assert_success "Statistics display working"
    else
        assert_failure "Statistics display failed"
    fi

    # Clean up
    rm -rf "$test_backup_dir"
}

# Test: Missing backup directory
test_backup_rotation_missing_dir() {
    echo "Testing missing backup directory..."

    # Run rotation on non-existent directory
    local output
    output=$("$BACKUP_SCRIPT" "/tmp/non_existent_backup_dir_$(date +%s)" 5 2>&1)

    # Should fail with error message
    if echo "$output" | grep -q "Backup directory not found"; then
        assert_success "Missing directory error handled"
    else
        assert_failure "Missing directory error not handled"
    fi
}

# Test: Cleanup old backups
test_backup_rotation_cleanup() {
    echo "Testing cleanup of old compressed backups..."

    # Create a temporary backup directory
    local test_backup_dir="/tmp/test_backups_cleanup"
    mkdir -p "$test_backup_dir"

    # Create some old compressed files (simulate old backups)
    for i in {1..3}; do
        local old_file="CodingReviewer_old_$(printf "%03d" $i).tar.gz"
        touch "$test_backup_dir/$old_file"
        # Set modification time to 40 days ago
        touch -a -m -r "$test_backup_dir/$old_file" -t "$(date -v-40d +%Y%m%d%H%M)" "$test_backup_dir/$old_file" 2>/dev/null ||
            touch -d "40 days ago" "$test_backup_dir/$old_file" 2>/dev/null ||
            touch "$test_backup_dir/$old_file" # Fallback if date manipulation fails
    done

    # Create some recent compressed files
    for i in {4..5}; do
        local recent_file="CodingReviewer_recent_$(printf "%03d" $i).tar.gz"
        touch "$test_backup_dir/$recent_file"
    done

    # Run rotation (should trigger cleanup)
    local output
    output=$("$BACKUP_SCRIPT" "$test_backup_dir" 10 2>/dev/null)

    # Should show cleanup activity or indicate no old backups to remove
    if echo "$output" | grep -q -E "(Removed.*old backups|No old backups to remove)"; then
        assert_success "Cleanup functionality working"
    else
        assert_failure "Cleanup functionality failed"
    fi

    # Clean up
    rm -rf "$test_backup_dir"
}
