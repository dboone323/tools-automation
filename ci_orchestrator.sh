#!/bin/bash

# CI Orchestrator for Quantum-workspace
# Handles PR validation vs release builds with circuit breakers and performance monitoring

set -euo pipefail

# Configuration
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
COVERAGE_THRESHOLD=85
PERFORMANCE_TIMEOUT=120 # seconds
CIRCUIT_BREAKER_FAILURES=3
MAX_RETRIES=2

# Execution modes
MODE="${1:-pr-validation}"
shift || true

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

# Circuit breaker state
declare -A circuit_breaker_state
declare -A consecutive_failures

# Performance tracking
declare -A performance_metrics
declare -A start_times
declare -A end_times

# Function to initialize circuit breaker
init_circuit_breaker() {
    local projects=("AvoidObstaclesGame" "CodingReviewer" "PlannerApp" "MomentumFinance" "HabitQuest")

    for project in "${projects[@]}"; do
        circuit_breaker_state["$project"]="CLOSED"
        consecutive_failures["$project"]=0
    done
}

# Function to check circuit breaker state
check_circuit_breaker() {
    local project="$1"

    if [[ "${circuit_breaker_state[$project]}" == "OPEN" ]]; then
        log_warning "Circuit breaker OPEN for $project - skipping"
        return 1
    fi

    return 0
}

# Function to update circuit breaker
update_circuit_breaker() {
    local project="$1"
    local success="$2"

    if [[ "$success" == "true" ]]; then
        circuit_breaker_state["$project"]="CLOSED"
        consecutive_failures["$project"]=0
    else
        ((consecutive_failures["$project"]++))
        if [[ ${consecutive_failures["$project"]} -ge $CIRCUIT_BREAKER_FAILURES ]]; then
            circuit_breaker_state["$project"]="OPEN"
            log_error "Circuit breaker OPENED for $project after ${consecutive_failures["$project"]} failures"
        fi
    fi
}

# Function to run PR validation (fast feedback)
run_pr_validation() {
    log_info "Running PR validation mode (fast feedback)..."

    # Run parallel tests with reduced scope
    if "$WORKSPACE_ROOT/Tools/Automation/run_parallel_tests.sh"; then
        log_success "PR validation passed"
        return 0
    else
        log_error "PR validation failed"
        return 1
    fi
}

# Function to run release build (comprehensive)
run_release_build() {
    log_info "Running release build mode (comprehensive validation)..."

    local success=true

    # Step 1: Run comprehensive tests
    log_info "Step 1: Running comprehensive test suite..."
    if ! "$WORKSPACE_ROOT/Tools/Automation/run_parallel_tests.sh"; then
        log_error "Comprehensive tests failed"
        success=false
    fi

    # Step 2: Run flaky test detection
    log_info "Step 2: Running flaky test detection..."
    if ! "$WORKSPACE_ROOT/Tools/Automation/detect_flaky_tests.sh"; then
        log_warning "Flaky tests detected - not blocking release but should be investigated"
        # Don't set success=false for flaky tests in release mode
    fi

    # Step 3: Performance validation
    log_info "Step 3: Running performance validation..."
    if ! run_performance_validation; then
        log_error "Performance validation failed"
        success=false
    fi

    # Step 4: Quality gate validation
    log_info "Step 4: Running quality gate validation..."
    if ! run_quality_gate_validation; then
        log_error "Quality gate validation failed"
        success=false
    fi

    if [[ "$success" == "true" ]]; then
        log_success "Release build validation passed"
        return 0
    else
        log_error "Release build validation failed"
        return 1
    fi
}

# Function to run performance validation
run_performance_validation() {
    local projects=("AvoidObstaclesGame" "CodingReviewer" "PlannerApp" "MomentumFinance" "HabitQuest")
    local success=true

    for project in "${projects[@]}"; do
        if ! check_circuit_breaker "$project"; then
            continue
        fi

        log_info "Running performance validation for $project..."

        local start_time=$(date +%s)
        start_times["$project:perf"]=$start_time

        # Run performance tests with timeout
        if timeout "$PERFORMANCE_TIMEOUT" "$WORKSPACE_ROOT/Tools/Automation/run_performance_tests.sh" "$project" 2>/dev/null; then
            local end_time=$(date +%s)
            end_times["$project:perf"]=$end_time
            local duration=$((end_time - start_time))
            performance_metrics["$project:duration"]=$duration

            if [[ $duration -gt $PERFORMANCE_TIMEOUT ]]; then
                log_error "Performance test for $project timed out after ${PERFORMANCE_TIMEOUT}s"
                update_circuit_breaker "$project" "false"
                success=false
            else
                log_success "Performance test for $project completed in ${duration}s"
                update_circuit_breaker "$project" "true"
            fi
        else
            log_error "Performance test failed for $project"
            update_circuit_breaker "$project" "false"
            success=false
        fi
    done

    return $success
}

# Function to run quality gate validation
run_quality_gate_validation() {
    log_info "Running quality gate validation..."

    # Check coverage thresholds
    local coverage_file="$WORKSPACE_ROOT/coverage_report.json"
    if [[ -f "$coverage_file" ]]; then
        local overall_coverage=$(jq -r '.overall_coverage // 0' "$coverage_file" 2>/dev/null || echo "0")

        if (($(echo "$overall_coverage < $COVERAGE_THRESHOLD" | bc -l 2>/dev/null || echo "1"))); then
            log_error "Coverage gate failed: ${overall_coverage}% < ${COVERAGE_THRESHOLD}%"
            return 1
        else
            log_success "Coverage gate passed: ${overall_coverage}% >= ${COVERAGE_THRESHOLD}%"
        fi
    else
        log_warning "No coverage report found - skipping coverage validation"
    fi

    # Check for linting issues
    if command -v swiftlint >/dev/null 2>&1; then
        log_info "Running SwiftLint validation..."
        if ! swiftlint --strict; then
            log_error "SwiftLint validation failed"
            return 1
        else
            log_success "SwiftLint validation passed"
        fi
    else
        log_warning "SwiftLint not available - skipping lint validation"
    fi

    return 0
}

# Function to run with retry logic
run_with_retry() {
    local command="$1"
    local max_retries="$2"
    local attempt=1

    while [[ $attempt -le $max_retries ]]; do
        log_info "Attempt $attempt/$max_retries: $command"

        if eval "$command"; then
            return 0
        fi

        ((attempt++))
        if [[ $attempt -le $max_retries ]]; then
            log_warning "Attempt failed, retrying in 5 seconds..."
            sleep 5
        fi
    done

    log_error "All $max_retries attempts failed"
    return 1
}

# Function to generate CI report
generate_ci_report() {
    local mode="$1"
    local success="$2"
    local output_file="$WORKSPACE_ROOT/ci_report_$(date +%Y%m%d_%H%M%S).json"

    echo "{" >"$output_file"
    echo "  \"timestamp\": \"$(date -Iseconds)\"," >>"$output_file"
    echo "  \"mode\": \"$mode\"," >>"$output_file"
    echo "  \"success\": $success," >>"$output_file"
    echo "  \"circuit_breaker_state\": {" >>"$output_file"

    local first=true
    for project in "${!circuit_breaker_state[@]}"; do
        if [[ $first == false ]]; then
            echo "," >>"$output_file"
        fi
        first=false
        echo "    \"$project\": {" >>"$output_file"
        echo "      \"state\": \"${circuit_breaker_state[$project]}\"," >>"$output_file"
        echo "      \"consecutive_failures\": ${consecutive_failures[$project]}" >>"$output_file"
        echo "    }" >>"$output_file"
    done

    echo "  }," >>"$output_file"
    echo "  \"performance_metrics\": {" >>"$output_file"

    first=true
    for metric in "${!performance_metrics[@]}"; do
        if [[ $first == false ]]; then
            echo "," >>"$output_file"
        fi
        first=false
        echo "    \"$metric\": ${performance_metrics[$metric]}" >>"$output_file"
    done

    echo "  }" >>"$output_file"
    echo "}" >>"$output_file"

    log_info "CI report saved to: $output_file"
}

# Main execution
main() {
    log_info "Starting CI orchestrator in $MODE mode..."

    # Initialize circuit breaker
    init_circuit_breaker

    local start_time=$(date +%s)
    local success=false

    case "$MODE" in
    "pr-validation")
        if run_pr_validation; then
            success=true
        fi
        ;;
    "release-build")
        if run_release_build; then
            success=true
        fi
        ;;
    *)
        log_error "Unknown mode: $MODE. Use 'pr-validation' or 'release-build'"
        exit 1
        ;;
    esac

    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    # Generate report
    generate_ci_report "$MODE" "$success"

    echo
    log_info "CI execution completed in ${total_duration}s"

    if [[ "$success" == "true" ]]; then
        log_success "CI pipeline succeeded!"
        exit 0
    else
        log_error "CI pipeline failed!"
        exit 1
    fi
}

# Run main function
main "$@"
