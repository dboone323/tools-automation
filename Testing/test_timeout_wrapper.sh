#!/bin/bash

# Test Timeout Wrapper with Retry Logic and Circuit Breaker
# Prevents stuck builds/tests and implements intelligent fallback strategies

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Timeout defaults (can be overridden)
BUILD_TIMEOUT=${BUILD_TIMEOUT:-180}
UNIT_TEST_TIMEOUT=${UNIT_TEST_TIMEOUT:-60}
INTEGRATION_TEST_TIMEOUT=${INTEGRATION_TEST_TIMEOUT:-120}
UI_TEST_TIMEOUT=${UI_TEST_TIMEOUT:-180}

# Retry configuration
MAX_RETRIES=${MAX_RETRIES:-3}
RETRY_BACKOFF=(1 2 4) # Exponential backoff in seconds

# Circuit breaker state file
CIRCUIT_BREAKER_STATE="$WORKSPACE_ROOT/.circuit_breaker_state"
CIRCUIT_BREAKER_THRESHOLD=3
CIRCUIT_BREAKER_RESET_MINUTES=5

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Initialize circuit breaker state
init_circuit_breaker() {
    if [[ ! -f "$CIRCUIT_BREAKER_STATE" ]]; then
        echo '{"failures": 0, "state": "closed", "last_failure": 0}' >"$CIRCUIT_BREAKER_STATE"
    fi
}

# Check circuit breaker state
check_circuit_breaker() {
    local state
    state=$(jq -r '.state' "$CIRCUIT_BREAKER_STATE" 2>/dev/null || echo "closed")
    local last_failure
    last_failure=$(jq -r '.last_failure' "$CIRCUIT_BREAKER_STATE" 2>/dev/null || echo "0")
    local current_time
    current_time=$(date +%s)
    local time_since_failure=$((current_time - last_failure))

    if [[ "$state" == "open" ]]; then
        # Check if enough time has passed to try half-open
        if [[ $time_since_failure -gt $((CIRCUIT_BREAKER_RESET_MINUTES * 60)) ]]; then
            echo -e "${YELLOW}⚡ Circuit breaker entering half-open state${NC}"
            echo '{"failures": 0, "state": "half-open", "last_failure": '"$last_failure"'}' >"$CIRCUIT_BREAKER_STATE"
            return 0
        else
            echo -e "${RED}🚫 Circuit breaker is OPEN - refusing to execute${NC}"
            echo -e "${YELLOW}   Will retry in $(((CIRCUIT_BREAKER_RESET_MINUTES * 60) - time_since_failure)) seconds${NC}"
            return 1
        fi
    fi

    return 0
}

# Record circuit breaker failure
record_failure() {
    local failures
    failures=$(jq -r '.failures' "$CIRCUIT_BREAKER_STATE" 2>/dev/null || echo "0")
    failures=$((failures + 1))
    local current_time
    current_time=$(date +%s)

    if [[ $failures -ge $CIRCUIT_BREAKER_THRESHOLD ]]; then
        echo -e "${RED}🚨 Circuit breaker TRIPPED after $failures consecutive failures${NC}"
        echo '{"failures": '"$failures"', "state": "open", "last_failure": '"$current_time"'}' >"$CIRCUIT_BREAKER_STATE"
    else
        echo '{"failures": '"$failures"', "state": "closed", "last_failure": '"$current_time"'}' >"$CIRCUIT_BREAKER_STATE"
    fi
}

# Record circuit breaker success
record_success() {
    echo -e "${GREEN}✅ Circuit breaker reset after successful execution${NC}"
    echo '{"failures": 0, "state": "closed", "last_failure": 0}' >"$CIRCUIT_BREAKER_STATE"
}

# Execute command with timeout
execute_with_timeout() {
    local timeout=$1
    local command_type=$2
    shift 2
    local command="$*"

    echo -e "${BLUE}⏱️  Executing with ${timeout}s timeout: $command_type${NC}"

    # Use timeout command (GNU coreutils or macOS timeout via gtimeout)
    local timeout_cmd="timeout"
    if command -v gtimeout >/dev/null 2>&1; then
        timeout_cmd="gtimeout"
    fi

    local exit_code=0
    if $timeout_cmd "$timeout" bash -c "$command"; then
        echo -e "${GREEN}✅ Command completed successfully${NC}"
        return 0
    else
        exit_code=$?
        if [[ $exit_code -eq 124 ]]; then
            echo -e "${RED}⏰ Command timed out after ${timeout}s${NC}"
            return 124
        else
            echo -e "${RED}❌ Command failed with exit code $exit_code${NC}"
            return $exit_code
        fi
    fi
}

# Execute with retry logic
execute_with_retry() {
    local timeout=$1
    local command_type=$2
    shift 2
    local command="$*"

    local attempt=1
    local exit_code=0

    while [[ $attempt -le $MAX_RETRIES ]]; do
        echo -e "${BLUE}🔄 Attempt $attempt/$MAX_RETRIES${NC}"

        if execute_with_timeout "$timeout" "$command_type" "$command"; then
            return 0
        else
            exit_code=$?

            # Check if it's a transient failure worth retrying
            if [[ $exit_code -eq 124 ]]; then
                # Timeout - don't retry, this is a real issue
                echo -e "${RED}⏰ Timeout is not transient - skipping retry${NC}"
                return $exit_code
            fi

            if [[ $attempt -lt $MAX_RETRIES ]]; then
                local backoff_index=$((attempt - 1))
                local backoff_time=${RETRY_BACKOFF[$backoff_index]}
                echo -e "${YELLOW}⏳ Waiting ${backoff_time}s before retry...${NC}"
                sleep "$backoff_time"
            fi

            attempt=$((attempt + 1))
        fi
    done

    echo -e "${RED}❌ All $MAX_RETRIES attempts failed${NC}"
    return $exit_code
}

# Main execution function
run_with_protection() {
    local operation_type=$1
    local timeout=$2
    shift 2
    local command="$*"

    init_circuit_breaker

    # Check circuit breaker
    if ! check_circuit_breaker; then
        return 1
    fi

    echo -e "${BLUE}╔════════════════════════════════════════════════╗${NC}"
    echo -e "${BLUE}║  Running: $operation_type${NC}"
    echo -e "${BLUE}║  Timeout: ${timeout}s | Retries: $MAX_RETRIES${NC}"
    echo -e "${BLUE}╚════════════════════════════════════════════════╝${NC}\n"

    local start_time
    start_time=$(date +%s)

    if execute_with_retry "$timeout" "$operation_type" "$command"; then
        local end_time
        end_time=$(date +%s)
        local duration
        duration=$((end_time - start_time))

        echo -e "${GREEN}✅ Success in ${duration}s${NC}"
        record_success
        return 0
    else
        local exit_code=$?
        local end_time
        end_time=$(date +%s)
        local duration
        duration=$((end_time - start_time))

        echo -e "${RED}❌ Failed after ${duration}s${NC}"
        record_failure
        return $exit_code
    fi
}

# Usage function
usage() {
    cat <<EOF
Usage: $0 <operation> <command>

Operations:
  build           - Run build with 180s timeout
  unit-test       - Run unit tests with 60s timeout
  integration     - Run integration tests with 120s timeout
  ui-test         - Run UI tests with 180s timeout
  custom <timeout> - Run with custom timeout

Examples:
  $0 build "xcodebuild -project MyApp.xcodeproj -scheme MyApp build"
  $0 unit-test "xcodebuild test -scheme MyAppTests"
  $0 custom 300 "long-running-command"

Environment Variables:
  BUILD_TIMEOUT           - Override build timeout (default: 180)
  UNIT_TEST_TIMEOUT       - Override unit test timeout (default: 60)
  INTEGRATION_TEST_TIMEOUT - Override integration timeout (default: 120)
  UI_TEST_TIMEOUT         - Override UI test timeout (default: 180)
  MAX_RETRIES             - Maximum retry attempts (default: 3)

EOF
    exit 1
}

# Main script
main() {
    if [[ $# -lt 2 ]]; then
        usage
    fi

    local operation=$1
    shift

    case "$operation" in
    build)
        run_with_protection "Build" "$BUILD_TIMEOUT" "$@"
        ;;
    unit-test)
        run_with_protection "Unit Tests" "$UNIT_TEST_TIMEOUT" "$@"
        ;;
    integration)
        run_with_protection "Integration Tests" "$INTEGRATION_TEST_TIMEOUT" "$@"
        ;;
    ui-test)
        run_with_protection "UI Tests" "$UI_TEST_TIMEOUT" "$@"
        ;;
    custom)
        if [[ $# -lt 2 ]]; then
            echo -e "${RED}Error: custom requires timeout value${NC}"
            usage
        fi
        local custom_timeout=$1
        shift
        run_with_protection "Custom ($custom_timeout s)" "$custom_timeout" "$@"
        ;;
    *)
        echo -e "${RED}Error: Unknown operation: $operation${NC}"
        usage
        ;;
    esac
}

# Check for required commands
if ! command -v timeout >/dev/null 2>&1 && ! command -v gtimeout >/dev/null 2>&1; then
    echo -e "${RED}Error: timeout command not found${NC}"
    echo -e "${YELLOW}Install coreutils: brew install coreutils${NC}"
    exit 1
fi

if ! command -v jq >/dev/null 2>&1; then
    echo -e "${RED}Error: jq command not found${NC}"
    echo -e "${YELLOW}Install jq: brew install jq${NC}"
    exit 1
fi

main "$@"
