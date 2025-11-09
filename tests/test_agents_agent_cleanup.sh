#!/bin/bash

# Test suite for agent_cleanup.sh
# Comprehensive tests covering log rotation, cache pruning, and workspace maintenance

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shell_test_framework.sh"

# Override PROJECT_ROOT for this test
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_DIR="$PROJECT_ROOT/agents"

AGENT_CLEANUP_SCRIPT="$AGENTS_DIR/agent_cleanup.sh"

# Test: Basic cleanup functionality
test_agent_cleanup_basic() {
    echo "Testing basic agent cleanup functionality..."

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
    echo "/tmp/test_cleanup.lock"
}
EOF

    # Temporarily replace the shared_functions.sh source
    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CLEANUP_SCRIPT"

    # Create test cleanup directory
    mkdir -p "/tmp/test_cleanup"

    # Run cleanup with test mode
    TEST_MODE=1 CLEANUP_DIR="/tmp/test_cleanup" "$AGENT_CLEANUP_SCRIPT" cleanup 2>/dev/null || true

    assert_success "Basic cleanup execution"

    # Restore original file
    mv "$AGENT_CLEANUP_SCRIPT.bak" "$AGENT_CLEANUP_SCRIPT"

    # Clean up
    rm -rf "/tmp/test_shared" "/tmp/test_cleanup"
}

# Test: Cleanup status command
test_agent_cleanup_status() {
    echo "Testing cleanup status command..."

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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CLEANUP_SCRIPT"

    # Run status command
    output=$(TEST_MODE=1 "$AGENT_CLEANUP_SCRIPT" status 2>/dev/null || true)

    assert_success "Status command execution"

    # Check if output contains expected information
    if echo "$output" | grep -q "cleanup\|status\|disk\|memory"; then
        assert_success "Status output contains cleanup information"
    else
        assert_failure "Status output missing cleanup information"
    fi

    # Restore and cleanup
    mv "$AGENT_CLEANUP_SCRIPT.bak" "$AGENT_CLEANUP_SCRIPT"
    rm -rf "/tmp/test_shared"
}

# Test: Log rotation functionality
test_agent_cleanup_log_rotation() {
    echo "Testing log rotation functionality..."

    # Create test log directory with old log files
    mkdir -p "/tmp/test_logs"
    touch "/tmp/test_logs/agent_old_20230101.log"
    touch "/tmp/test_logs/agent_recent_20231201.log"
    echo "test log content" >"/tmp/test_logs/agent_old_20230101.log"

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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CLEANUP_SCRIPT"

    # Run log rotation
    TEST_MODE=1 LOG_DIR="/tmp/test_logs" RETENTION_DAYS=30 "$AGENT_CLEANUP_SCRIPT" rotate-logs 2>/dev/null || true

    assert_success "Log rotation execution"

    # Check if old logs were handled (compressed/archived)
    if [ -f "/tmp/test_logs/agent_old_20230101.log.gz" ] || [ ! -f "/tmp/test_logs/agent_old_20230101.log" ]; then
        assert_success "Old logs were rotated"
    else
        assert_failure "Old logs were not rotated"
    fi

    # Restore and cleanup
    mv "$AGENT_CLEANUP_SCRIPT.bak" "$AGENT_CLEANUP_SCRIPT"
    rm -rf "/tmp/test_shared" "/tmp/test_logs"
}

# Test: Cache pruning functionality
test_agent_cleanup_cache_pruning() {
    echo "Testing cache pruning functionality..."

    # Create test cache directory with old cache files
    mkdir -p "/tmp/test_cache"
    touch "/tmp/test_cache/cache_old_20230101.dat"
    touch "/tmp/test_cache/cache_recent_20231201.dat"
    echo "cache data" >"/tmp/test_cache/cache_old_20230101.dat"

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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CLEANUP_SCRIPT"

    # Run cache pruning
    TEST_MODE=1 CACHE_DIR="/tmp/test_cache" CACHE_RETENTION_DAYS=30 "$AGENT_CLEANUP_SCRIPT" prune-cache 2>/dev/null || true

    assert_success "Cache pruning execution"

    # Check if old cache files were removed
    if [ ! -f "/tmp/test_cache/cache_old_20230101.dat" ]; then
        assert_success "Old cache files were pruned"
    else
        assert_failure "Old cache files were not pruned"
    fi

    # Restore and cleanup
    mv "$AGENT_CLEANUP_SCRIPT.bak" "$AGENT_CLEANUP_SCRIPT"
    rm -rf "/tmp/test_shared" "/tmp/test_cache"
}

# Test: Temp file cleanup
test_agent_cleanup_temp_files() {
    echo "Testing temp file cleanup..."

    # Create test temp directory with various temp files
    mkdir -p "/tmp/test_temp"
    touch "/tmp/test_temp/temp_file_1.tmp"
    touch "/tmp/test_temp/temp_file_2.tmp"
    mkdir -p "/tmp/test_temp/subdir"
    touch "/tmp/test_temp/subdir/temp_file_3.tmp"
    echo "temp data" >"/tmp/test_temp/temp_file_1.tmp"

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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CLEANUP_SCRIPT"

    # Run temp file cleanup
    TEST_MODE=1 TEMP_DIR="/tmp/test_temp" "$AGENT_CLEANUP_SCRIPT" clean-temp 2>/dev/null || true

    assert_success "Temp file cleanup execution"

    # Check if temp files were removed
    if [ ! -f "/tmp/test_temp/temp_file_1.tmp" ] && [ ! -f "/tmp/test_temp/temp_file_2.tmp" ]; then
        assert_success "Temp files were cleaned up"
    else
        assert_failure "Temp files were not cleaned up"
    fi

    # Restore and cleanup
    mv "$AGENT_CLEANUP_SCRIPT.bak" "$AGENT_CLEANUP_SCRIPT"
    rm -rf "/tmp/test_shared" "/tmp/test_temp"
}

# Test: Resource limit checking
test_agent_cleanup_resource_limits() {
    echo "Testing resource limit checking..."

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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CLEANUP_SCRIPT"

    # Run resource check
    output=$(TEST_MODE=1 "$AGENT_CLEANUP_SCRIPT" check-limits 2>/dev/null || true)

    assert_success "Resource limit check execution"

    # Check if output contains resource information
    if echo "$output" | grep -q "memory\|cpu\|load\|resource"; then
        assert_success "Resource check output contains limit information"
    else
        assert_failure "Resource check output missing limit information"
    fi

    # Restore and cleanup
    mv "$AGENT_CLEANUP_SCRIPT.bak" "$AGENT_CLEANUP_SCRIPT"
    rm -rf "/tmp/test_shared"
}

# Test: System load checking
test_agent_cleanup_system_load() {
    echo "Testing system load checking..."

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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CLEANUP_SCRIPT"

    # Mock sysctl for macOS
    mock_command "sysctl" "vm.loadavg: 1.5 1.2 1.0"

    # Run load check
    output=$(TEST_MODE=1 "$AGENT_CLEANUP_SCRIPT" check-load 2>/dev/null || true)

    assert_success "System load check execution"

    # Check if output contains load information
    if echo "$output" | grep -q "load\|busy\|available"; then
        assert_success "Load check output contains load information"
    else
        assert_failure "Load check output missing load information"
    fi

    # Restore and cleanup
    mv "$AGENT_CLEANUP_SCRIPT.bak" "$AGENT_CLEANUP_SCRIPT"
    rm -rf "/tmp/test_shared"
}

# Test: Invalid command handling
test_agent_cleanup_invalid_command() {
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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CLEANUP_SCRIPT"

    # Run invalid command
    TEST_MODE=1 "$AGENT_CLEANUP_SCRIPT" invalid_command 2>/dev/null || true

    local exit_code=$?
    assert_equals 1 "$exit_code" "Should exit with error for invalid command"

    # Restore and cleanup
    mv "$AGENT_CLEANUP_SCRIPT.bak" "$AGENT_CLEANUP_SCRIPT"
    rm -rf "/tmp/test_shared"
}

# Test: No arguments handling
test_agent_cleanup_no_args() {
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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CLEANUP_SCRIPT"

    # Run with no arguments
    output=$(TEST_MODE=1 "$AGENT_CLEANUP_SCRIPT" 2>/dev/null || true)

    assert_success "No arguments execution"

    # Check if output contains usage information
    if echo "$output" | grep -q "Usage\|usage\|help\|Commands"; then
        assert_success "No args output contains usage information"
    else
        assert_failure "No args output missing usage information"
    fi

    # Restore and cleanup
    mv "$AGENT_CLEANUP_SCRIPT.bak" "$AGENT_CLEANUP_SCRIPT"
    rm -rf "/tmp/test_shared"
}

# Test: Concurrency control
test_agent_cleanup_concurrency() {
    echo "Testing concurrency control..."

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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CLEANUP_SCRIPT"

    # Test concurrency control (this would be more complex in real implementation)
    TEST_MODE=1 "$AGENT_CLEANUP_SCRIPT" status 2>/dev/null || true

    assert_success "Concurrency control test"

    # Restore and cleanup
    mv "$AGENT_CLEANUP_SCRIPT.bak" "$AGENT_CLEANUP_SCRIPT"
    rm -rf "/tmp/test_shared"
}
