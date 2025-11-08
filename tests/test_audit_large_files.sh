#!/bin/bash

# Test suite for audit_large_files.sh
# Comprehensive tests covering all functionality

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shell_test_framework.sh"

# Override PROJECT_ROOT for this test
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"

AUDIT_SCRIPT="$PROJECT_ROOT/audit_large_files.sh"

# Test: Basic audit with no large files
test_audit_no_large_files() {
    echo "Testing audit with no large files..."

    # Create a temporary directory for testing
    local test_dir="/tmp/audit_test_no_large"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Initialize git repo
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1

    # Create small files
    echo "small content" >small.txt
    echo "another small file" >another.txt
    git add . >/dev/null 2>&1
    git commit -m "Initial commit" >/dev/null 2>&1

    # Run audit with low threshold
    local output
    output=$("$AUDIT_SCRIPT" "1K" 2>/dev/null)

    # Should find no files > 1K in working tree, but Git history should show files
    if echo "$output" | grep -q "Scanning working tree" && echo "$output" | grep -q "Top 30 largest blobs"; then
        assert_success "Audit script ran successfully"
    else
        assert_failure "Audit script did not run"
    fi

    # Clean up
    cd "$PROJECT_ROOT"
    rm -rf "$test_dir"
}

# Test: Audit with large files
test_audit_with_large_files() {
    echo "Testing audit with large files..."

    # Create a temporary directory for testing
    local test_dir="/tmp/audit_test_large"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Initialize git repo
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1

    # Create a large file (> 1M)
    dd if=/dev/zero of=large_file.dat bs=1M count=2 2>/dev/null
    git add large_file.dat >/dev/null 2>&1
    git commit -m "Add large file" >/dev/null 2>&1

    # Create small files
    echo "small content" >small.txt

    # Run audit
    local output
    output=$("$AUDIT_SCRIPT" "1M" 2>/dev/null)

    # Should find the large file
    if echo "$output" | grep -q "large_file.dat"; then
        assert_success "Large file was detected"
    else
        assert_failure "Large file was not detected"
    fi

    # Clean up
    cd "$PROJECT_ROOT"
    rm -rf "$test_dir"
}

# Test: Audit with custom threshold
test_audit_custom_threshold() {
    echo "Testing audit with custom threshold..."

    # Create a temporary directory for testing
    local test_dir="/tmp/audit_test_threshold"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Initialize git repo
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1

    # Create files of different sizes
    dd if=/dev/zero of=medium.dat bs=500K count=1 2>/dev/null
    dd if=/dev/zero of=large.dat bs=2M count=1 2>/dev/null
    git add . >/dev/null 2>&1
    git commit -m "Add files" >/dev/null 2>&1

    # Run audit with 1M threshold
    local output
    output=$("$AUDIT_SCRIPT" "1M" 2>/dev/null)

    # Should find only large.dat in working tree (> 1M)
    # Extract just the working tree scan results (between "Scanning" and "Top 30")
    local working_tree_output
    working_tree_output=$(echo "$output" | sed -n '/Scanning working tree/,/Top 30/p' | sed '$d')

    if echo "$working_tree_output" | grep -q "large.dat" && ! echo "$working_tree_output" | grep -q "medium.dat"; then
        assert_success "Custom threshold worked correctly"
    else
        assert_failure "Custom threshold did not work"
    fi

    # Clean up
    cd "$PROJECT_ROOT"
    rm -rf "$test_dir"
}

# Test: Default threshold
test_audit_default_threshold() {
    echo "Testing audit with default threshold..."

    # Create a temporary directory for testing
    local test_dir="/tmp/audit_test_default"
    mkdir -p "$test_dir"
    cd "$test_dir"

    # Initialize git repo
    git init >/dev/null 2>&1
    git config user.name "Test User" >/dev/null 2>&1
    git config user.email "test@example.com" >/dev/null 2>&1

    # Create a small file
    echo "test" >test.txt
    git add . >/dev/null 2>&1
    git commit -m "Initial" >/dev/null 2>&1

    # Run audit with default threshold
    local output
    output=$("$AUDIT_SCRIPT" 2>/dev/null)

    # Should run without error
    if echo "$output" | grep -q "Scanning working tree"; then
        assert_success "Default threshold audit ran"
    else
        assert_failure "Default threshold audit failed"
    fi

    # Clean up
    cd "$PROJECT_ROOT"
    rm -rf "$test_dir"
}

# Test: Git history audit
test_audit_git_history() {
    echo "Testing Git history audit..."

    # Create a temporary git repo
    local test_dir="/tmp/audit_test_git"
    mkdir -p "$test_dir"
    cd "$test_dir"
    git init >/dev/null 2>&1
    git config user.name "Test User"
    git config user.email "test@example.com"

    # Create and commit a large file
    dd if=/dev/zero of=large_blob.dat bs=1M count=1 2>/dev/null
    git add large_blob.dat
    git commit -m "Add large file" >/dev/null 2>&1

    # Run audit
    local output
    output=$("$AUDIT_SCRIPT" "500K" 2>/dev/null)

    # Should show Git history analysis
    if echo "$output" | grep -q "Top 30 largest blobs"; then
        assert_success "Git history audit included"
    else
        assert_failure "Git history audit missing"
    fi

    # Clean up
    cd "$PROJECT_ROOT"
    rm -rf "$test_dir"
}
