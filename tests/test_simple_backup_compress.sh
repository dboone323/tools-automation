#!/bin/bash

# Test suite for simple_backup_compress.sh
# Comprehensive tests covering all functionality

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shell_test_framework.sh"

# Override PROJECT_ROOT for this test
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

BACKUP_COMPRESS_SCRIPT="$PROJECT_ROOT/simple_backup_compress.sh"

# Test: Basic backup compression
test_backup_compress_basic() {
    echo "Testing basic backup compression..."

    # Create test backup directory
    local real_backup_dir="/Users/danielstevens/Desktop/Tools/Automation/agents/backups"
    mkdir -p "$real_backup_dir"

    # Create a test backup directory
    local test_backup="$real_backup_dir/CodingReviewer_test_001"
    mkdir -p "$test_backup"
    echo "test content" >"$test_backup/test.txt"

    # Run the compression script
    "$BACKUP_COMPRESS_SCRIPT"

    assert_success "Backup compression execution"

    # Check that the backup was compressed
    local compressed_file="$real_backup_dir/CodingReviewer_test_001.tar.gz"
    assert_file_exists "$compressed_file" "Compressed backup file should exist"

    # Check that the original directory was removed
    [[ ! -d "$real_backup_dir/CodingReviewer_test_001" ]]
    assert_success "Original backup directory should be removed"

    # Clean up
    rm -rf "$real_backup_dir"
}

# Test: No backups to compress
test_backup_compress_no_backups() {
    echo "Testing no backups to compress..."

    # Create empty backup directory
    local real_backup_dir="/Users/danielstevens/Desktop/Tools/Automation/agents/backups"
    mkdir -p "$real_backup_dir"

    # Run the compression script
    "$BACKUP_COMPRESS_SCRIPT"

    assert_success "No backups compression"

    # Clean up
    rm -rf "$real_backup_dir"
}

# Test: Already compressed backup
test_backup_compress_already_compressed() {
    echo "Testing already compressed backup..."

    # Create test backup directory
    local real_backup_dir="/Users/danielstevens/Desktop/Tools/Automation/agents/backups"
    mkdir -p "$real_backup_dir"

    # Create a compressed file
    touch "$real_backup_dir/CodingReviewer_test_002.tar.gz"

    # Run the compression script
    "$BACKUP_COMPRESS_SCRIPT"

    assert_success "Already compressed backup handling"

    # Clean up
    rm -rf "$real_backup_dir"
}

# Test: Missing backup directory
test_backup_compress_missing_dir() {
    echo "Testing missing backup directory..."

    # Ensure backup directory doesn't exist
    local real_backup_dir="/Users/danielstevens/Desktop/Tools/Automation/agents/backups"
    rm -rf "$real_backup_dir"

    # Run the compression script
    "$BACKUP_COMPRESS_SCRIPT"

    local exit_code=$?
    assert_equals 1 "$exit_code" "Should fail when backup directory doesn't exist"
}
