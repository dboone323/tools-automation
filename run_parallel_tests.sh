#!/bin/bash

# Parallel Test Execution Framework for Quantum-workspace
# Runs tests across all 5 projects with coverage, performance monitoring, and parallel execution

set -euo pipefail

# Configuration
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECTS=("AvoidObstaclesGame" "CodingReviewer" "PlannerApp" "MomentumFinance" "HabitQuest")
COVERAGE_THRESHOLD=85
TIMEOUT_SECONDS=120
MAX_PARALLEL_JOBS=3

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

# Performance tracking
declare -A start_times
declare -A end_times
declare -A test_results
declare -A coverage_results

# Function to run tests for a single project
run_project_tests() {
    local project="$1"
    local project_path="$WORKSPACE_ROOT/Projects/$project"
    local start_time=$(date +%s)

    log_info "Starting tests for $project..."

    # Store start time
    echo "$start_time" >"/tmp/${project}_start_time"

    # Change to project directory
    cd "$project_path"

    # Determine test command based on project type
    if [[ "$project" == "CodingReviewer" ]]; then
        # SPM-based project
        if ! swift test --enable-code-coverage --parallel; then
            log_error "Tests failed for $project"
            echo "FAILED" >"/tmp/${project}_test_result"
            return 1
        fi
    else
        # Xcode-based projects
        local scheme="$project"
        if xcodebuild test \
            -scheme "$scheme" \
            -destination 'platform=macOS' \
            -enableCodeCoverage YES \
            -parallel-testing-enabled YES \
            -test-timeouts-enabled YES \
            -maximum-test-execution-time-allowance "$TIMEOUT_SECONDS"; then
            log_error "Tests failed for $project"
            echo "FAILED" >"/tmp/${project}_test_result"
            return 1
        fi
    fi

    local end_time=$(date +%s)
    echo "$end_time" >"/tmp/${project}_end_time"
    echo "PASSED" >"/tmp/${project}_test_result"
    log_success "Tests passed for $project"

    # Collect coverage data
    collect_coverage "$project"

    return 0
}

# Function to collect coverage data
collect_coverage() {
    local project="$1"
    local project_path="$WORKSPACE_ROOT/Projects/$project"

    log_info "Collecting coverage for $project..."

    if [[ "$project" == "CodingReviewer" ]]; then
        # SPM coverage collection
        if command -v llvm-cov >/dev/null 2>&1; then
            # Find coverage files
            local profraw_files=$(find "$project_path" -name "*.profraw" 2>/dev/null || true)
            if [[ -n "$profraw_files" ]]; then
                # Convert profraw to profdata
                xcrun llvm-profdata merge -sparse "$profraw_files" -o "$project_path/coverage.profdata" 2>/dev/null || true

                # Generate coverage report
                local coverage_report=$(xcrun llvm-cov report \
                    "$(swift build --show-bin-path)/$project" \
                    -instr-profile="$project_path/coverage.profdata" \
                    -ignore-filename-regex="\.build|Tests" 2>/dev/null || echo "0.00")

                # Extract percentage
                local coverage_pct=$(echo "$coverage_report" | grep -oP '\d+\.\d+(?=%)' | head -1 || echo "0.00")
                coverage_results["$project"]="$coverage_pct"
                echo "$coverage_pct" >"/tmp/${project}_coverage"
                log_info "Coverage for $project: ${coverage_pct}%"
            else
                coverage_results["$project"]="0.00"
                log_warning "No coverage data found for $project"
            fi
        else
            coverage_results["$project"]="N/A"
            log_warning "llvm-cov not available for $project coverage"
        fi
    else
        # Xcode coverage collection
        local derived_data=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "*$project*" -type d -maxdepth 1 | head -1)
        if [[ -d "$derived_data" ]]; then
            local coverage_dir="$derived_data/Logs/Test/*.xcresult"
            if [[ -d "$coverage_dir" ]]; then
                # Use xccov to get coverage
                local coverage_pct=$(xcrun xccov view --report --json "$coverage_dir" 2>/dev/null |
                    jq -r '.targets[0].lineCoverage * 100' 2>/dev/null || echo "0.00")
                coverage_results["$project"]="$coverage_pct"
                echo "$coverage_pct" >"/tmp/${project}_coverage"
                log_info "Coverage for $project: ${coverage_pct}%"
            else
                coverage_results["$project"]="0.00"
                log_warning "No Xcode coverage data found for $project"
            fi
        else
            coverage_results["$project"]="0.00"
            log_warning "No derived data found for $project"
        fi
    fi
}

# Function to run tests in parallel with job control
run_parallel_tests() {
    local pids=()
    local running=0

    for project in "${PROJECTS[@]}"; do
        # Wait for a slot if max parallel jobs reached
        while [[ $running -ge $MAX_PARALLEL_JOBS ]]; do
            sleep 1
            # Clean up finished jobs
            for i in "${!pids[@]}"; do
                if ! kill -0 "${pids[$i]}" 2>/dev/null; then
                    unset 'pids[$i]'
                    ((running--))
                fi
            done
        done

        # Start test job
        run_project_tests "$project" &
        pids+=($!)
        ((running++))

        log_info "Started parallel test job for $project (running: $running/$MAX_PARALLEL_JOBS)"
    done

    # Wait for all remaining jobs to complete
    for pid in "${pids[@]}"; do
        wait "$pid"
    done
}

# Function to generate test report
generate_report() {
    local total_projects=${#PROJECTS[@]}
    local passed_count=0
    local failed_projects=()
    local coverage_warnings=()

    echo
    echo "========================================"
    echo "   PARALLEL TEST EXECUTION REPORT"
    echo "========================================"
    echo

    for project in "${PROJECTS[@]}"; do
        local status_file="/tmp/${project}_test_result"
        local coverage_file="/tmp/${project}_coverage"
        local start_file="/tmp/${project}_start_time"
        local end_file="/tmp/${project}_end_time"

        local status="UNKNOWN"
        local coverage="N/A"
        local duration="N/A"

        if [[ -f "$status_file" ]]; then
            status=$(cat "$status_file")
        fi

        if [[ -f "$coverage_file" ]]; then
            coverage=$(cat "$coverage_file")
        fi

        if [[ -f "$start_file" && -f "$end_file" ]]; then
            local start_time=$(cat "$start_file")
            local end_time=$(cat "$end_file")
            duration=$((end_time - start_time))
        fi

        if [[ "$status" == "PASSED" ]]; then
            ((passed_count++))
            echo -e "${GREEN}✓ $project${NC} - PASSED (${duration}s) - Coverage: ${coverage}%"
        else
            failed_projects+=("$project")
            echo -e "${RED}✗ $project${NC} - FAILED (${duration}s) - Coverage: ${coverage}%"
        fi

        # Check coverage threshold
        if [[ "$coverage" =~ ^[0-9]+(\.[0-9]+)?$ && $(echo "$coverage < $COVERAGE_THRESHOLD" | bc -l 2>/dev/null || echo "1") == "1" ]]; then
            coverage_warnings+=("$project (${coverage}%)")
        fi
    done

    echo
    echo "Summary:"
    echo "- Projects tested: $total_projects"
    echo "- Passed: $passed_count"
    echo "- Failed: $((total_projects - passed_count))"
    echo "- Success rate: $((passed_count * 100 / total_projects))%"

    if [[ ${#coverage_warnings[@]} -gt 0 ]]; then
        echo
        log_warning "Coverage below ${COVERAGE_THRESHOLD}% threshold:"
        for warning in "${coverage_warnings[@]}"; do
            echo "  - $warning"
        done
    fi

    if [[ ${#failed_projects[@]} -gt 0 ]]; then
        echo
        log_error "Failed projects:"
        for failed in "${failed_projects[@]}"; do
            echo "  - $failed"
        done
        return 1
    fi

    return 0
}

# Main execution
main() {
    log_info "Starting parallel test execution across ${#PROJECTS[@]} projects..."
    log_info "Configuration: Max parallel jobs=$MAX_PARALLEL_JOBS, Timeout=${TIMEOUT_SECONDS}s, Coverage threshold=${COVERAGE_THRESHOLD}%"

    local start_time=$(date +%s)

    # Run tests in parallel
    run_parallel_tests

    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    # Generate report
    generate_report
    local report_exit=$?

    echo
    log_info "Total execution time: ${total_duration}s"

    if [[ $report_exit -eq 0 ]]; then
        log_success "All tests passed!"
    else
        log_error "Some tests failed!"
        exit 1
    fi
}

# Run main function
main "$@"
