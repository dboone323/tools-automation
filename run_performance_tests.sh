#!/bin/bash

# Performance Test Runner for Quantum-workspace
# Measures test execution time and resource usage

set -euo pipefail

# Configuration
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PERFORMANCE_TIMEOUT=120
MEMORY_THRESHOLD_MB=1024

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() { echo -e "${BLUE}[INFO]${NC} $1" >&2; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1" >&2; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1" >&2; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Function to measure memory usage
measure_memory() {
    local pid="$1"
    local max_memory=0

    while kill -0 "$pid" 2>/dev/null; do
        local current_memory=$(ps -o rss= -p "$pid" 2>/dev/null | awk '{print $1}' || echo "0")
        if [[ $current_memory -gt $max_memory ]]; then
            max_memory=$current_memory
        fi
        sleep 0.1
    done

    echo $((max_memory / 1024)) # Convert to MB
}

# Function to run performance tests for a project
run_performance_test() {
    local project="$1"
    local project_path="$WORKSPACE_ROOT/Projects/$project"

    log_info "Running performance test for $project..."

    cd "$project_path"

    local start_time=$(date +%s.%3N)

    # Run tests in background to measure resources
    if [[ "$project" == "CodingReviewer" ]]; then
        swift test --parallel &
    else
        local scheme="$project"
        xcodebuild test \
            -scheme "$scheme" \
            -destination 'platform=macOS' \
            -parallel-testing-enabled YES \
            -test-timeouts-enabled YES \
            -maximum-test-execution-time-allowance "$PERFORMANCE_TIMEOUT" &
    fi

    local test_pid=$!

    # Measure memory usage
    local max_memory=$(measure_memory "$test_pid")

    # Wait for test completion
    local exit_code=0
    if ! wait "$test_pid"; then
        exit_code=1
    fi

    local end_time=$(date +%s.%3N)
    local duration=$(echo "$end_time - $start_time" | bc -l 2>/dev/null || echo "0")

    # Check performance thresholds
    local success=true

    if (($(echo "$duration > $PERFORMANCE_TIMEOUT" | bc -l 2>/dev/null || echo "0"))); then
        log_error "Performance test timed out: ${duration}s > ${PERFORMANCE_TIMEOUT}s"
        success=false
    else
        log_success "Performance test completed in ${duration}s"
    fi

    if [[ $max_memory -gt $MEMORY_THRESHOLD_MB ]]; then
        log_error "Memory usage exceeded threshold: ${max_memory}MB > ${MEMORY_THRESHOLD_MB}MB"
        success=false
    else
        log_info "Peak memory usage: ${max_memory}MB"
    fi

    # Output performance metrics in JSON format for CI orchestrator
    echo "{"
    echo "  \"project\": \"$project\","
    echo "  \"duration_seconds\": $duration,"
    echo "  \"peak_memory_mb\": $max_memory,"
    echo "  \"success\": $success,"
    echo "  \"timeout_threshold\": $PERFORMANCE_TIMEOUT,"
    echo "  \"memory_threshold_mb\": $MEMORY_THRESHOLD_MB"
    echo "}"

    return $exit_code
}

# Main execution
main() {
    local project="${1:-}"

    if [[ -z "$project" ]]; then
        log_error "Usage: $0 <project_name>"
        log_error "Available projects: AvoidObstaclesGame, CodingReviewer, PlannerApp, MomentumFinance, HabitQuest"
        exit 1
    fi

    # Validate project exists
    local project_path="$WORKSPACE_ROOT/Projects/$project"
    if [[ ! -d "$project_path" ]]; then
        log_error "Project not found: $project"
        exit 1
    fi

    run_performance_test "$project"
}

# Run main function
main "$@"
