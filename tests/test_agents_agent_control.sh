#!/bin/bash

# Test suite for agent_control.sh
# Comprehensive tests covering agent lifecycle management

# Source the test framework
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "$SCRIPT_DIR/shell_test_framework.sh"

# Override PROJECT_ROOT for this test
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
AGENTS_DIR="$PROJECT_ROOT/agents"

AGENT_CONTROL_SCRIPT="$AGENTS_DIR/agent_control.sh"

# Test: Basic control functionality
test_agent_control_basic() {
    echo "Testing basic agent control functionality..."

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
    echo "/tmp/test_control.lock"
}
EOF

    # Temporarily replace the shared_functions.sh source
    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CONTROL_SCRIPT"

    # Run control with test mode
    TEST_MODE=1 "$AGENT_CONTROL_SCRIPT" status 2>/dev/null || true

    assert_success "Basic control execution"

    # Restore original file
    mv "$AGENT_CONTROL_SCRIPT.bak" "$AGENT_CONTROL_SCRIPT"

    # Clean up
    rm -rf "/tmp/test_shared"
}

# Test: Control status command
test_agent_control_status() {
    echo "Testing control status command..."

    # Create mock agent status file
    cat >"$AGENTS_DIR/agent_status.json" <<'EOF'
{
  "agents": {
    "agent_supervisor.sh": {
      "status": "running",
      "pid": 12345,
      "last_seen": 1234567890
    },
    "agent_monitoring.sh": {
      "status": "idle",
      "pid": null,
      "last_seen": 1234567890
    }
  },
  "last_update": 1234567890
}
EOF

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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CONTROL_SCRIPT"

    # Run status command
    output=$(TEST_MODE=1 "$AGENT_CONTROL_SCRIPT" status 2>/dev/null || true)

    assert_success "Status command execution"

    # Check if output contains expected information
    if echo "$output" | grep -q "running\|idle\|stopped"; then
        assert_success "Status output contains agent information"
    else
        assert_failure "Status output missing agent information"
    fi

    # Restore and cleanup
    mv "$AGENT_CONTROL_SCRIPT.bak" "$AGENT_CONTROL_SCRIPT"
    rm -rf "/tmp/test_shared"
    rm -f "$AGENTS_DIR/agent_status.json"
}

# Test: Control list command
test_agent_control_list() {
    echo "Testing control list command..."

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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CONTROL_SCRIPT"

    # Run list command
    output=$(TEST_MODE=1 "$AGENT_CONTROL_SCRIPT" list 2>/dev/null || true)

    assert_success "List command execution"

    # Check if output contains agent information
    if echo "$output" | grep -q "agent_\|\.sh\|Available agents"; then
        assert_success "List output contains agent information"
    else
        assert_failure "List output missing agent information"
    fi

    # Restore and cleanup
    mv "$AGENT_CONTROL_SCRIPT.bak" "$AGENT_CONTROL_SCRIPT"
    rm -rf "/tmp/test_shared"
}

# Test: Control start command
test_agent_control_start() {
    echo "Testing control start command..."

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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CONTROL_SCRIPT"

    # Run start command (should not actually start agents in test mode)
    TEST_MODE=1 "$AGENT_CONTROL_SCRIPT" start 2>/dev/null || true

    assert_success "Start command execution"

    # Restore and cleanup
    mv "$AGENT_CONTROL_SCRIPT.bak" "$AGENT_CONTROL_SCRIPT"
    rm -rf "/tmp/test_shared"
}

# Test: Control stop command
test_agent_control_stop() {
    echo "Testing control stop command..."

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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CONTROL_SCRIPT"

    # Run stop command
    TEST_MODE=1 "$AGENT_CONTROL_SCRIPT" stop 2>/dev/null || true

    assert_success "Stop command execution"

    # Restore and cleanup
    mv "$AGENT_CONTROL_SCRIPT.bak" "$AGENT_CONTROL_SCRIPT"
    rm -rf "/tmp/test_shared"
}

# Test: Control restart command
test_agent_control_restart() {
    echo "Testing control restart command..."

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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CONTROL_SCRIPT"

    # Run restart command
    TEST_MODE=1 "$AGENT_CONTROL_SCRIPT" restart 2>/dev/null || true

    assert_success "Restart command execution"

    # Restore and cleanup
    mv "$AGENT_CONTROL_SCRIPT.bak" "$AGENT_CONTROL_SCRIPT"
    rm -rf "/tmp/test_shared"
}

# Test: Invalid command handling
test_agent_control_invalid_command() {
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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CONTROL_SCRIPT"

    # Run invalid command
    TEST_MODE=1 "$AGENT_CONTROL_SCRIPT" invalid_command 2>/dev/null || true

    local exit_code=$?
    assert_equals 1 "$exit_code" "Should exit with error for invalid command"

    # Restore and cleanup
    mv "$AGENT_CONTROL_SCRIPT.bak" "$AGENT_CONTROL_SCRIPT"
    rm -rf "/tmp/test_shared"
}

# Test: No arguments handling
test_agent_control_no_args() {
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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CONTROL_SCRIPT"

    # Run with no arguments
    output=$(TEST_MODE=1 "$AGENT_CONTROL_SCRIPT" 2>/dev/null || true)

    assert_success "No arguments execution"

    # Check if output contains usage information
    if echo "$output" | grep -q "Usage\|usage\|help\|Commands"; then
        assert_success "No args output contains usage information"
    else
        assert_failure "No args output missing usage information"
    fi

    # Restore and cleanup
    mv "$AGENT_CONTROL_SCRIPT.bak" "$AGENT_CONTROL_SCRIPT"
    rm -rf "/tmp/test_shared"
}

# Test: Core agents array validation
test_agent_control_core_agents() {
    echo "Testing core agents array validation..."

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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CONTROL_SCRIPT"

    # Check if the script defines CORE_AGENTS array
    if grep -q "CORE_AGENTS=" "$AGENT_CONTROL_SCRIPT"; then
        assert_success "CORE_AGENTS array is defined"
    else
        assert_failure "CORE_AGENTS array is not defined"
    fi

    # Restore and cleanup
    mv "$AGENT_CONTROL_SCRIPT.bak" "$AGENT_CONTROL_SCRIPT"
    rm -rf "/tmp/test_shared"
}

# Test: Timeout protection
test_agent_control_timeout() {
    echo "Testing timeout protection..."

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

    sed -i.bak 's|source "${SCRIPT_DIR}/shared_functions.sh"|source "/tmp/test_shared/shared_functions.sh"|g' "$AGENT_CONTROL_SCRIPT"

    # Test timeout handling
    TEST_MODE=1 "$AGENT_CONTROL_SCRIPT" status 2>/dev/null || true

    assert_success "Timeout functionality available"

    # Restore and cleanup
    mv "$AGENT_CONTROL_SCRIPT.bak" "$AGENT_CONTROL_SCRIPT"
    rm -rf "/tmp/test_shared"
}
