#!/bin/bash
# Test Retry Helper - Exponential backoff retry logic for flaky tests
# Source this file in test runners to add retry capabilities

# Configuration
export RETRY_MAX_ATTEMPTS="${RETRY_MAX_ATTEMPTS:-3}"
export RETRY_INITIAL_DELAY="${RETRY_INITIAL_DELAY:-2}"
export RETRY_MAX_DELAY="${RETRY_MAX_DELAY:-30}"
export RETRY_BACKOFF_MULTIPLIER="${RETRY_BACKOFF_MULTIPLIER:-2}"

# Colors for output
RETRY_RED='\033[0;31m'
RETRY_GREEN='\033[0;32m'
RETRY_YELLOW='\033[1;33m'
RETRY_BLUE='\033[0;34m'
RETRY_NC='\033[0m'

# Logging
retry_log_info() { echo -e "${RETRY_BLUE}[RETRY]${RETRY_NC} $1" >&2; }
retry_log_success() { echo -e "${RETRY_GREEN}[RETRY]${RETRY_NC} $1" >&2; }
retry_log_warning() { echo -e "${RETRY_YELLOW}[RETRY]${RETRY_NC} $1" >&2; }
retry_log_error() { echo -e "${RETRY_RED}[RETRY]${RETRY_NC} $1" >&2; }

# Execute command with exponential backoff retry
# Usage: retry_with_backoff <command> [args...]
retry_with_backoff() {
    local attempt=1
    local delay="$RETRY_INITIAL_DELAY"
    local exit_code=0

    while [[ $attempt -le $RETRY_MAX_ATTEMPTS ]]; do
        retry_log_info "Attempt $attempt/$RETRY_MAX_ATTEMPTS: $*"

        # Execute the command
        if "$@"; then
            if [[ $attempt -gt 1 ]]; then
                retry_log_success "Command succeeded on attempt $attempt"
            fi
            return 0
        fi

        exit_code=$?

        # Last attempt failed
        if [[ $attempt -eq $RETRY_MAX_ATTEMPTS ]]; then
            retry_log_error "Command failed after $RETRY_MAX_ATTEMPTS attempts"
            return $exit_code
        fi

        # Calculate next delay with exponential backoff
        retry_log_warning "Attempt $attempt failed (exit code: $exit_code), retrying in ${delay}s..."
        sleep "$delay"

        delay=$((delay * RETRY_BACKOFF_MULTIPLIER))
        if [[ $delay -gt $RETRY_MAX_DELAY ]]; then
            delay=$RETRY_MAX_DELAY
        fi

        attempt=$((attempt + 1))
    done

    return $exit_code
}

# Execute test with retry on specific failure patterns
# Usage: retry_test_on_pattern <pattern> <command> [args...]
retry_test_on_pattern() {
    local pattern="$1"
    shift

    local attempt=1
    local delay="$RETRY_INITIAL_DELAY"
    local temp_output
    temp_output=$(mktemp)

    while [[ $attempt -le $RETRY_MAX_ATTEMPTS ]]; do
        retry_log_info "Test attempt $attempt/$RETRY_MAX_ATTEMPTS: $*"

        # Execute command and capture output
        if "$@" 2>&1 | tee "$temp_output"; then
            rm -f "$temp_output"
            if [[ $attempt -gt 1 ]]; then
                retry_log_success "Test passed on attempt $attempt"
            fi
            return 0
        fi

        local exit_code=$?

        # Check if failure matches retry pattern
        if grep -q "$pattern" "$temp_output"; then
            retry_log_warning "Detected flaky test pattern: '$pattern'"

            if [[ $attempt -lt $RETRY_MAX_ATTEMPTS ]]; then
                retry_log_warning "Retrying in ${delay}s..."
                sleep "$delay"

                delay=$((delay * RETRY_BACKOFF_MULTIPLIER))
                if [[ $delay -gt $RETRY_MAX_DELAY ]]; then
                    delay=$RETRY_MAX_DELAY
                fi

                attempt=$((attempt + 1))
                continue
            fi
        fi

        # Non-retryable failure or max attempts reached
        rm -f "$temp_output"
        retry_log_error "Test failed (exit code: $exit_code)"
        return $exit_code
    done

    rm -f "$temp_output"
    return 1
}

# Common flaky test patterns for Swift/iOS
FLAKY_PATTERNS=(
    "Failed to create destination device"
    "Unable to boot device"
    "Connection to device lost"
    "Test runner crashed"
    "Timed out waiting"
    "Network connection lost"
    "Simulator is not available"
    "xcodebuild was interrupted"
)

# Retry Swift test with common flaky patterns
# Usage: retry_swift_test <xcodebuild command and args>
retry_swift_test() {
    local combined_pattern
    combined_pattern=$(
        IFS='|'
        echo "${FLAKY_PATTERNS[*]}"
    )

    retry_test_on_pattern "$combined_pattern" "$@"
}

# Record retry statistics for monitoring
record_retry_stats() {
    local test_name="$1"
    local attempt_count="$2"
    local success="$3" # true/false

    local stats_file="${RETRY_STATS_FILE:-metrics/test_retry_stats.jsonl}"
    local stats_dir
    stats_dir="$(dirname "$stats_file")"

    mkdir -p "$stats_dir"

    local timestamp
    timestamp=$(date -u +"%Y-%m-%dT%H:%M:%SZ")

    cat >>"$stats_file" <<EOF
{"timestamp":"$timestamp","test":"$test_name","attempts":$attempt_count,"success":$success}
EOF

    retry_log_info "Retry stats recorded: $test_name (attempts: $attempt_count, success: $success)"
}

# Check retry budget (similar to error budget)
check_retry_budget() {
    local test_name="$1"
    local stats_file="${RETRY_STATS_FILE:-metrics/test_retry_stats.jsonl}"

    if [[ ! -f "$stats_file" ]]; then
        return 0 # No stats yet, allow retry
    fi

    # Count recent retries for this test (last 24 hours)
    local cutoff_time
    cutoff_time=$(date -u -v-24H +"%Y-%m-%dT%H:%M:%SZ" 2>/dev/null || date -u -d '24 hours ago' +"%Y-%m-%dT%H:%M:%SZ")

    local retry_count
    retry_count=$(grep "\"test\":\"$test_name\"" "$stats_file" |
        awk -v cutoff="$cutoff_time" -F'"' '{if ($4 >= cutoff && $10 == "true") print}' |
        wc -l | tr -d ' ')

    local total_count
    total_count=$(grep "\"test\":\"$test_name\"" "$stats_file" |
        awk -v cutoff="$cutoff_time" -F'"' '{if ($4 >= cutoff) print}' |
        wc -l | tr -d ' ')

    if [[ $total_count -eq 0 ]]; then
        return 0
    fi

    # Calculate retry rate
    local retry_rate
    retry_rate=$(echo "scale=2; ($retry_count * 100) / $total_count" | bc)

    # Allow up to 50% retry rate
    if (($(echo "$retry_rate > 50" | bc -l))); then
        retry_log_error "Retry budget exhausted for $test_name (rate: ${retry_rate}%)"
        return 1
    fi

    retry_log_info "Retry budget OK for $test_name (rate: ${retry_rate}%)"
    return 0
}

# Export functions for use in subshells
export -f retry_with_backoff
export -f retry_test_on_pattern
export -f retry_swift_test
export -f record_retry_stats
export -f check_retry_budget
export -f retry_log_info
export -f retry_log_success
export -f retry_log_warning
export -f retry_log_error
