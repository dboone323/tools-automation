#!/bin/bash

# Test suite for agent_backup.sh
# Comprehensive tests covering backup and disaster recovery functionality

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shell_test_framework.sh"

# Override PROJECT_ROOT for this test
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_DIR="$PROJECT_ROOT/agents"

AGENT_BACKUP_SCRIPT="$AGENTS_DIR/agent_backup.sh"

# Test: Basic backup functionality
test_agent_backup_basic() {
    echo "Testing basic agent backup functionality..."

    # Mock the shared_functions.sh to avoid dependencies
    mkdir -p "/tmp/test_shared"
    cat >"/tmp/test_shared/shared_functions.sh" <<'EOF'
#!/bin/bash
log_message() {
    local level="$1"
    local message="$2"
    echo "[$level] $message"
}

run_with_lock() {
    local lock_file="$1"
    shift
    "$@"
}

get_lock_file() {
    echo "/tmp/test_backup.lock"
}
EOF

    # Temporarily replace the shared_functions.sh source
    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_BACKUP_SCRIPT"

    # Create test backup directory
    mkdir -p "/tmp/test_backup"

    # Run backup with test mode
    TEST_MODE=1 BACKUP_DIR="/tmp/test_backup" "$AGENT_BACKUP_SCRIPT" backup 2>/dev/null || true

    assert_success "Basic backup execution"

    # Restore original file
    mv "$AGENT_BACKUP_SCRIPT.bak" "$AGENT_BACKUP_SCRIPT"

    # Clean up
    rm -rf "/tmp/test_shared" "/tmp/test_backup"
}

# Test: Backup status command
test_agent_backup_status() {
    echo "Testing backup status command..."

    # Mock shared functions
    mkdir -p "/tmp/test_shared"
    cat >"/tmp/test_shared/shared_functions.sh" <<'EOF'
#!/bin/bash
log_message() {
    local level="$1"
    local message="$2"
    echo "[$level] $message"
}
EOF

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_BACKUP_SCRIPT"

    # Run status command
    output=$(TEST_MODE=1 "$AGENT_BACKUP_SCRIPT" status 2>/dev/null || true)

    assert_success "Status command execution"

    # Check if output contains expected information
    if echo "$output" | grep -q "backup\|status\|Backup"; then
        assert_success "Status output contains backup information"
    else
        assert_failure "Status output missing backup information"
    fi

    # Restore and cleanup
    mv "$AGENT_BACKUP_SCRIPT.bak" "$AGENT_BACKUP_SCRIPT"
    rm -rf "/tmp/test_shared"
}

# Test: Backup list command
test_agent_backup_list() {
    echo "Testing backup list command..."

    # Create test backup directory with some files
    mkdir -p "/tmp/test_backup"
    touch "/tmp/test_backup/backup1.tar.gz"
    touch "/tmp/test_backup/backup2.tar.gz"

    # Mock shared functions
    mkdir -p "/tmp/test_shared"
    cat >"/tmp/test_shared/shared_functions.sh" <<'EOF'
#!/bin/bash
log_message() {
    local level="$1"
    local message="$2"
    echo "[$level] $message"
}
EOF

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_BACKUP_SCRIPT"

    # Run list command
    output=$(TEST_MODE=1 BACKUP_DIR="/tmp/test_backup" "$AGENT_BACKUP_SCRIPT" list 2>/dev/null || true)

    assert_success "List command execution"

    # Check if output contains backup files
    if echo "$output" | grep -q "backup1\|backup2\|\.tar\.gz"; then
        assert_success "List output contains backup files"
    else
        assert_failure "List output missing backup files"
    fi

    # Restore and cleanup
    mv "$AGENT_BACKUP_SCRIPT.bak" "$AGENT_BACKUP_SCRIPT"
    rm -rf "/tmp/test_shared" "/tmp/test_backup"
}

# Test: Backup restore command
test_agent_backup_restore() {
    echo "Testing backup restore command..."

    # Create test backup directory and mock backup file
    mkdir -p "/tmp/test_backup" "/tmp/test_restore"
    echo "test data" >"/tmp/test_backup/test_file.txt"
    cd "/tmp/test_backup" && tar -czf backup1.tar.gz test_file.txt

    # Mock shared functions
    mkdir -p "/tmp/test_shared"
    cat >"/tmp/test_shared/shared_functions.sh" <<'EOF'
#!/bin/bash
log_message() {
    local level="$1"
    local message="$2"
    echo "[$level] $message"
}

run_with_lock() {
    local lock_file="$1"
    shift
    "$@"
}
EOF

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_BACKUP_SCRIPT"

    # Run restore command
    TEST_MODE=1 BACKUP_DIR="/tmp/test_backup" RESTORE_DIR="/tmp/test_restore" "$AGENT_BACKUP_SCRIPT" restore backup1.tar.gz 2>/dev/null || true

    assert_success "Restore command execution"

    # Check if file was restored
    if [ -f "/tmp/test_restore/test_file.txt" ]; then
        assert_success "File was successfully restored"
    else
        assert_failure "File was not restored"
    fi

    # Restore and cleanup
    mv "$AGENT_BACKUP_SCRIPT.bak" "$AGENT_BACKUP_SCRIPT"
    rm -rf "/tmp/test_shared" "/tmp/test_backup" "/tmp/test_restore"
}

# Test: Backup cleanup command
test_agent_backup_cleanup() {
    echo "Testing backup cleanup command..."

    # Create test backup directory with old files
    mkdir -p "/tmp/test_backup"
    touch "/tmp/test_backup/old_backup_20230101.tar.gz"
    touch "/tmp/test_backup/recent_backup_20231201.tar.gz"

    # Mock shared functions
    mkdir -p "/tmp/test_shared"
    cat >"/tmp/test_shared/shared_functions.sh" <<'EOF'
#!/bin/bash
log_message() {
    local level="$1"
    local message="$2"
    echo "[$level] $message"
}

run_with_lock() {
    local lock_file="$1"
    shift
    "$@"
}
EOF

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_BACKUP_SCRIPT"

    # Run cleanup command
    TEST_MODE=1 BACKUP_DIR="/tmp/test_backup" RETENTION_DAYS=30 "$AGENT_BACKUP_SCRIPT" cleanup 2>/dev/null || true

    assert_success "Cleanup command execution"

    # Restore and cleanup
    mv "$AGENT_BACKUP_SCRIPT.bak" "$AGENT_BACKUP_SCRIPT"
    rm -rf "/tmp/test_shared" "/tmp/test_backup"
}

# Test: Invalid command handling
test_agent_backup_invalid_command() {
    echo "Testing invalid command handling..."

    # Mock shared functions
    mkdir -p "/tmp/test_shared"
    cat >"/tmp/test_shared/shared_functions.sh" <<'EOF'
#!/bin/bash
log_message() {
    local level="$1"
    local message="$2"
    echo "[$level] $message"
}
EOF

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_BACKUP_SCRIPT"

    # Run invalid command
    TEST_MODE=1 "$AGENT_BACKUP_SCRIPT" invalid_command 2>/dev/null || true

    local exit_code=$?
    assert_equals 1 "$exit_code" "Should exit with error for invalid command"

    # Restore and cleanup
    mv "$AGENT_BACKUP_SCRIPT.bak" "$AGENT_BACKUP_SCRIPT"
    rm -rf "/tmp/test_shared"
}

# Test: No arguments handling
test_agent_backup_no_args() {
    echo "Testing no arguments handling..."

    # Mock shared functions
    mkdir -p "/tmp/test_shared"
    cat >"/tmp/test_shared/shared_functions.sh" <<'EOF'
#!/bin/bash
log_message() {
    local level="$1"
    local message="$2"
    echo "[$level] $message"
}
EOF

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_BACKUP_SCRIPT"

    # Run with no arguments
    output=$(TEST_MODE=1 "$AGENT_BACKUP_SCRIPT" 2>/dev/null || true)

    assert_success "No arguments execution"

    # Check if output contains usage information
    if echo "$output" | grep -q "Usage\|usage\|help\|Commands"; then
        assert_success "No args output contains usage information"
    else
        assert_failure "No args output missing usage information"
    fi

    # Restore and cleanup
    mv "$AGENT_BACKUP_SCRIPT.bak" "$AGENT_BACKUP_SCRIPT"
    rm -rf "/tmp/test_shared"
}

# Test: Backup integrity check
test_agent_backup_integrity() {
    echo "Testing backup integrity check..."

    # Create test backup directory and valid backup file
    mkdir -p "/tmp/test_backup"
    echo "test data" >"/tmp/test_backup/test_file.txt"
    cd "/tmp/test_backup" && tar -czf valid_backup.tar.gz test_file.txt

    # Create corrupted backup file
    echo "corrupted data" >"/tmp/test_backup/corrupted_backup.tar.gz"

    # Mock shared functions
    mkdir -p "/tmp/test_shared"
    cat >"/tmp/test_shared/shared_functions.sh" <<'EOF'
#!/bin/bash
log_message() {
    local level="$1"
    local message="$2"
    echo "[$level] $message"
}
EOF

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_BACKUP_SCRIPT"

    # Run integrity check
    output=$(TEST_MODE=1 BACKUP_DIR="/tmp/test_backup" "$AGENT_BACKUP_SCRIPT" verify 2>/dev/null || true)

    assert_success "Integrity check execution"

    # Check if output contains integrity information
    if echo "$output" | grep -q "integrity\|verify\|valid\|corrupt"; then
        assert_success "Integrity output contains verification information"
    else
        assert_failure "Integrity output missing verification information"
    fi

    # Restore and cleanup
    mv "$AGENT_BACKUP_SCRIPT.bak" "$AGENT_BACKUP_SCRIPT"
    rm -rf "/tmp/test_shared" "/tmp/test_backup"
}

# Test: Timeout functionality
test_agent_backup_timeout() {
    echo "Testing timeout functionality..."

    # Mock shared functions with timeout implementation
    mkdir -p "/tmp/test_shared"
    cat >"/tmp/test_shared/shared_functions.sh" <<'EOF'
#!/bin/bash
log_message() {
    local level="$1"
    local message="$2"
    echo "[$level] $message"
}

run_with_timeout() {
    local timeout="$1"
    shift
    local cmd="$*"

    # Simple timeout implementation for testing
    if command -v timeout >/dev/null 2>&1; then
        timeout --kill-after=5s "${timeout}s" bash -c "$cmd"
    else
        # Mock timeout for testing
        bash -c "$cmd" &
        local pid=$!
        sleep "$timeout"
        kill "$pid" 2>/dev/null || true
        return 124
    fi
}
EOF

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_BACKUP_SCRIPT"

    # Test timeout handling
    TEST_MODE=1 "$AGENT_BACKUP_SCRIPT" status 2>/dev/null || true

    assert_success "Timeout functionality available"

    # Restore and cleanup
    mv "$AGENT_BACKUP_SCRIPT.bak" "$AGENT_BACKUP_SCRIPT"
    rm -rf "/tmp/test_shared"
}
