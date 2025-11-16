#!/bin/bash
# Shell Test Framework for Agent Testing
# Provides assertion functions and test management for shell script testing

# Global test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Announce test start
announce_test() {
    local test_name="$1"
    echo "Running test: $test_name"
    ((TOTAL_TESTS++))
}

# Mark test as passed
test_passed() {
    local test_name="$1"
    echo -e "${GREEN}✅ PASS${NC}: $test_name"
    ((PASSED_TESTS++))
}

# Mark test as failed
test_failed() {
    local test_name="$1"
    local message="${2:-}"
    echo -e "${RED}❌ FAIL${NC}: $test_name - $message"
    ((FAILED_TESTS++))
}

# Get total tests run
get_total_tests() {
    echo "$TOTAL_TESTS"
}

# Get passed tests count
get_passed_tests() {
    echo "$PASSED_TESTS"
}

# Get failed tests count
get_failed_tests() {
    echo "$FAILED_TESTS"
}

# Assertion: assert true
assert_true() {
    local condition="$1"
    local message="${2:-}"
    if [[ "$condition" == "true" ]]; then
        return 0
    else
        test_failed "assertion" "$message"
        return 1
    fi
}

# Assertion: assert equals
assert_equals() {
    local expected="$1"
    local actual="${2:-}"
    local message="${3:-}"
    if [[ "$expected" == "$actual" ]]; then
        return 0
    else
        test_failed "assertion" "$message (expected: '$expected', actual: '$actual')"
        return 1
    fi
}

# Assertion: assert not empty
assert_not_empty() {
    local value="$1"
    local message="${2:-}"
    if [[ -n "$value" ]]; then
        return 0
    else
        test_failed "assertion" "$message"
        return 1
    fi
}

# Assertion: assert file exists
assert_file_exists() {
    local file_path="$1"
    local message="${2:-}"
    # Normalize file path (strip accidental newlines introduced by callers)
    file_path="${file_path//$'\n'/}"
    # If the resulting path doesn't exist but contains '/agents/',
    # try to map to the repo's agents directory (helps when REPO_ROOT
    # was accidentally duplicated in the test harness).
    if [[ ! -e "$file_path" && "$file_path" == *"/agents/"* ]]; then
        local suffix
        suffix="agents/${file_path##*agents/}"
        local candidate
        candidate="$PWD/${suffix}"
        if [[ -e "$candidate" || -x "$candidate" ]]; then
            file_path="$candidate"
        fi
    fi
    if [[ -f "$file_path" ]]; then
        return 0
    else
        test_failed "assertion" "$message (file not found: $file_path)"
        return 1
    fi
}

# Assertion: assert file does not exist
assert_file_not_exists() {
    local file_path="$1"
    local message="${2:-}"
    # Normalize file path (strip accidental newlines introduced by callers)
    file_path="${file_path//$'\n'/}"
    if [[ ! -f "$file_path" ]]; then
        return 0
    else
        test_failed "assertion" "$message (file exists: $file_path)"
        return 1
    fi
}

# Assertion: assert contains
assert_contains() {
    local haystack="$1"
    local needle="${2:-}"
    local message="${3:-}"
    if [[ "$haystack" == *"$needle"* ]]; then
        return 0
    else
        test_failed "assertion" "$message"
        return 1
    fi
}

# Assertion: assert regex match
assert_regex() {
    local text="$1"
    local pattern="${2:-}"
    local message="${3:-}"
    if [[ "$text" =~ $pattern ]]; then
        return 0
    else
        test_failed "assertion" "$message"
        return 1
    fi
}

# Assertion: assert file is executable
assert_file_executable() {
    local file_path="$1"
    local message="${2:-}"
    # Normalize file path (strip accidental newlines introduced by callers)
    file_path="${file_path//$'\n'/}"
    if [[ -x "$file_path" ]]; then
        return 0
    else
        test_failed "assertion" "$message (file not executable: $file_path)"
        return 1
    fi
}

# Assertion: assert pattern in file
assert_pattern_in_file() {
    local pattern="$1"
    local file_path="${2:-}"
    # Normalize file path (strip accidental newlines introduced by callers)
    file_path="${file_path//$'\n'/}"
    local message="${3:-}"
    if grep -q "$pattern" "$file_path" 2>/dev/null; then
        return 0
    else
        test_failed "assertion" "$message (pattern '$pattern' not found in $file_path)"
        return 1
    fi
}
