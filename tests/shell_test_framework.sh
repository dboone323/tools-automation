#!/bin/bash

# Simplified Shell Script Agent Test Framework

# Test framework setup
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Calculate PROJECT_ROOT relative to TEST_DIR
if [[ "$TEST_DIR" == */tests ]]; then
    PROJECT_ROOT="$(dirname "$TEST_DIR")"
else
    # Fallback: assume we're in the project root
    PROJECT_ROOT="$(pwd)"
fi
AGENTS_DIR="$PROJECT_ROOT/agents"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Logging
log_test() {
    local level="$1"
    local message="$2"
    local timestamp
    timestamp=$(date +'%Y-%m-%d %H:%M:%S')

    case "$level" in
    "PASS") echo -e "${GREEN}[$timestamp] ✅ PASS: $message${NC}" ;;
    "FAIL") echo -e "${RED}[$timestamp] ❌ FAIL: $message${NC}" ;;
    "SKIP") echo -e "${YELLOW}[$timestamp] ⚠️  SKIP: $message${NC}" ;;
    "INFO") echo -e "${BLUE}[$timestamp] ℹ️  INFO: $message${NC}" ;;
    *) echo "[$timestamp] $message" ;;
    esac
}

# Assertion functions
assert_not_contains() {
    local haystack="$1"
    local needle="$2"
    local message="$3"
    ((TESTS_RUN++))
    if ! echo "$haystack" | grep -q "$needle"; then
        ((TESTS_PASSED++))
        log_test "PASS" "$message"
        return 0
    else
        ((TESTS_FAILED++))
        log_test "FAIL" "$message (unexpected match: '$needle')"
        return 1
    fi
}
assert_success() {
    local message="$1"
    local exit_code=$?
    ((TESTS_RUN++))
    if [[ $exit_code -eq 0 ]]; then
        ((TESTS_PASSED++))
        log_test "PASS" "$message"
        return 0
    else
        ((TESTS_FAILED++))
        log_test "FAIL" "$message"
        return 1
    fi
}

assert_failure() {
    local message="$1"
    local exit_code=$?
    ((TESTS_RUN++))
    if [[ $exit_code -ne 0 ]]; then
        ((TESTS_PASSED++))
        log_test "PASS" "$message"
        return 0
    else
        ((TESTS_FAILED++))
        log_test "FAIL" "$message"
        return 1
    fi
}

assert_equals() {
    local expected="$1"
    local actual="$2"
    local message="$3"
    ((TESTS_RUN++))
    if [[ "$expected" == "$actual" ]]; then
        ((TESTS_PASSED++))
        log_test "PASS" "$message"
        return 0
    else
        ((TESTS_FAILED++))
        log_test "FAIL" "$message (expected: '$expected', actual: '$actual')"
        return 1
    fi
}

assert_file_exists() {
    local file="$1"
    local message="$2"
    ((TESTS_RUN++))
    if [[ -f "$file" ]]; then
        ((TESTS_PASSED++))
        log_test "PASS" "$message"
        return 0
    else
        ((TESTS_FAILED++))
        log_test "FAIL" "$message (file not found: $file)"
        return 1
    fi
}

assert_file_contains() {
    local file="$1"
    local pattern="$2"
    local message="$3"
    ((TESTS_RUN++))
    if [[ -f "$file" ]] && grep -q "$pattern" "$file"; then
        ((TESTS_PASSED++))
        log_test "PASS" "$message"
        return 0
    else
        ((TESTS_FAILED++))
        log_test "FAIL" "$message (pattern '$pattern' not found in $file)"
        return 1
    fi
}

# Mock functions
mock_command() {
    local cmd="$1"
    local mock_output="$2"
    local mock_exit_code="${3:-0}"

    # Create a mock script
    local mock_script="/tmp/mock_$cmd"
    cat >"$mock_script" <<EOF
#!/bin/bash
echo "$mock_output"
exit $mock_exit_code
EOF
    chmod +x "$mock_script"

    # Add to PATH
    export PATH="/tmp:$PATH"
    ln -sf "$mock_script" "/tmp/$cmd"
}

cleanup_mocks() {
    # Remove mock scripts
    rm -f /tmp/mock_*
}

# Setup and teardown
setup_test_env() {
    export TEST_MODE=true
    export SINGLE_RUN=true
    export LOG_FILE="/tmp/test_agent.log"
    export STATUS_FILE="/tmp/test_agent_status.json"
    export TASK_QUEUE="/tmp/test_task_queue.json"

    # Clean up any existing test files
    rm -f "$LOG_FILE" "$STATUS_FILE" "$TASK_QUEUE"

    # Create basic status file
    cat >"$STATUS_FILE" <<'EOF'
{
  "agents": {
    "test_agent": {
      "status": "idle",
      "pid": 12345,
      "last_seen": 1234567890
    }
  },
  "last_update": 1234567890
}
EOF

    # Create basic task queue
    cat >"$TASK_QUEUE" <<'EOF'
[
  {
    "id": "test_task_001",
    "type": "monitoring",
    "description": "Test monitoring task",
    "status": "pending",
    "assigned_to": null,
    "created_at": 1234567890
  }
]
EOF
}

teardown_test_env() {
    # Clean up test files
    rm -f "$LOG_FILE" "$STATUS_FILE" "$TASK_QUEUE"
    cleanup_mocks
    unset TEST_MODE SINGLE_RUN LOG_FILE STATUS_FILE TASK_QUEUE
}

# Simple test runner
run_test_suite() {
    local test_file="$1"
    local test_function_prefix="${2:-test_}"

    echo "=========================================="
    echo "Running test suite: $test_file"
    echo "=========================================="

    # Source the test file
    source "$test_file"

    # Find and run all test functions
    local test_functions
    test_functions=$(declare -F | grep "^declare -f $test_function_prefix" | sed "s/declare -f //")

    for test_func in $test_functions; do
        echo ""
        echo "Running test: $test_func"
        echo "----------------------------------------"

        # Setup
        setup_test_env

        # Apply per-test timeout override if declared (TIMEOUT_SEC inside test function)
        local per_test_timeout="${TIMEOUT_SEC:-}"
        if declare -f "${test_func}_timeout" >/dev/null 2>&1; then
            per_test_timeout=$("${test_func}_timeout")
        fi

        if [[ -n "$per_test_timeout" ]]; then
            export TIMEOUT_SEC="$per_test_timeout"
        fi

        # Run test
        if "$test_func"; then
            log_test "PASS" "Test $test_func completed successfully"
        else
            log_test "FAIL" "Test $test_func failed"
        fi

        # Teardown
        teardown_test_env
    done

    echo ""
    echo "=========================================="
    echo "Test Results for $test_file:"
    echo "Total: $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    echo "=========================================="
}
