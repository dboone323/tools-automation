#!/bin/bash

# Flaky Test Detection System for Quantum-workspace
# Runs tests multiple times to identify intermittent failures

set -euo pipefail

# Configuration
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RUNS_PER_TEST=5
FLAKY_THRESHOLD=0.3 # 30% failure rate considered flaky
TIMEOUT_SECONDS=120

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

# Data structures
test_runs=""
test_failures=""
flaky_tests=""

# Function to run a single test project multiple times
detect_flaky_tests() {
    local project="$1"
    local project_path="$WORKSPACE_ROOT/Projects/$project"

    log_info "Running flaky detection for $project ($RUNS_PER_TEST runs)..."

    cd "$project_path"

    local failures=0

    for run in $(seq 1 $RUNS_PER_TEST); do
        log_info "Run $run/$RUNS_PER_TEST for $project..."

        local start_time=$(date +%s)

        # Run tests based on project type
        if [[ "$project" == "CodingReviewer" ]]; then
            if swift test --parallel >/dev/null 2>&1; then
                echo "PASS" >"/tmp/${project}_run_${run}"
            else
                echo "FAIL" >"/tmp/${project}_run_${run}"
                ((failures++))
            fi
        else
            local scheme="$project"
            if xcodebuild test \
                -scheme "$scheme" \
                -destination 'platform=macOS' \
                -parallel-testing-enabled YES \
                -test-timeouts-enabled YES \
                -maximum-test-execution-time-allowance "$TIMEOUT_SECONDS" \
                >/dev/null 2>&1; then
                echo "PASS" >"/tmp/${project}_run_${run}"
            else
                echo "FAIL" >"/tmp/${project}_run_${run}"
                ((failures++))
            fi
        fi

        local end_time=$(date +%s)
        local duration=$((end_time - start_time))

        local result=$(cat "/tmp/${project}_run_${run}")
        log_info "Run $run completed in ${duration}s: $result"
    done

    # Calculate flaky metrics
    local total_runs=$RUNS_PER_TEST
    local failure_rate=$(echo "scale=2; $failures / $total_runs" | bc -l 2>/dev/null || echo "0")

    # Store results in files
    echo "$failures" >"/tmp/${project}_failures"
    echo "$failure_rate" >"/tmp/${project}_failure_rate"

    if (($(echo "$failure_rate > $FLAKY_THRESHOLD" | bc -l 2>/dev/null || echo "0"))); then
        echo "FLAKY ($failure_rate failure rate)" >"/tmp/${project}_status"
        log_warning "$project is FLAKY: $failures/$total_runs failures ($failure_rate)"
    elif [[ $failures -gt 0 ]]; then
        echo "UNSTABLE ($failure_rate failure rate)" >"/tmp/${project}_status"
        log_warning "$project is UNSTABLE: $failures/$total_runs failures ($failure_rate)"
    else
        echo "STABLE (0 failures)" >"/tmp/${project}_status"
        log_success "$project is STABLE: $total_runs/$total_runs passes"
    fi
}

# Function to generate flaky test report
generate_flaky_report() {
    echo
    echo "========================================"
    echo "      FLAKY TEST DETECTION REPORT"
    echo "========================================"
    echo

    local total_projects=0
    local stable_projects=0
    local unstable_projects=0
    local flaky_projects=0

    for project in "${projects[@]}"; do
        ((total_projects++))
        local status_file="/tmp/${project}_status"
        local status="UNKNOWN"

        if [[ -f "$status_file" ]]; then
            status=$(cat "$status_file")
        fi

        if [[ "$status" == *"STABLE"* ]]; then
            ((stable_projects++))
            echo -e "${GREEN}✓ $project${NC} - $status"
        elif [[ "$status" == *"FLAKY"* ]]; then
            ((flaky_projects++))
            echo -e "${RED}✗ $project${NC} - $status"
        elif [[ "$status" == *"UNSTABLE"* ]]; then
            ((unstable_projects++))
            echo -e "${YELLOW}⚠ $project${NC} - $status"
        fi

        # Show detailed run results
        echo "  Run results:"
        for run in $(seq 1 $RUNS_PER_TEST); do
            local result_file="/tmp/${project}_run_${run}"
            local result="UNKNOWN"
            if [[ -f "$result_file" ]]; then
                result=$(cat "$result_file")
            fi

            if [[ "$result" == "PASS" ]]; then
                echo -e "    Run $run: ${GREEN}PASS${NC}"
            else
                echo -e "    Run $run: ${RED}FAIL${NC}"
            fi
        done
        echo
    done

    echo "Summary:"
    echo "- Total projects: $total_projects"
    echo "- Stable: $stable_projects"
    echo "- Unstable: $unstable_projects"
    echo "- Flaky: $flaky_projects"

    if [[ $flaky_projects -gt 0 ]]; then
        echo
        log_error "FLAKY TESTS DETECTED! Projects with >${FLAKY_THRESHOLD} failure rate need investigation."
        return 1
    elif [[ $unstable_projects -gt 0 ]]; then
        echo
        log_warning "UNSTABLE TESTS DETECTED. Projects with intermittent failures should be monitored."
        return 0
    else
        echo
        log_success "All tests are stable!"
        return 0
    fi
}

# Function to save flaky test results to file
save_flaky_results() {
    local output_file="$WORKSPACE_ROOT/flaky_test_results_$(date +%Y%m%d_%H%M%S).json"

    # Create JSON output
    echo "{" >"$output_file"
    echo "  \"timestamp\": \"$(date -Iseconds)\"," >>"$output_file"
    echo "  \"runs_per_test\": $RUNS_PER_TEST," >>"$output_file"
    echo "  \"flaky_threshold\": $FLAKY_THRESHOLD," >>"$output_file"
    echo "  \"results\": {" >>"$output_file"

    local first=true
    for project in "${projects[@]}"; do
        if [[ $first == false ]]; then
            echo "," >>"$output_file"
        fi
        first=false

        local failures_file="/tmp/${project}_failures"
        local failure_rate_file="/tmp/${project}_failure_rate"
        local status_file="/tmp/${project}_status"

        local failures=0
        local failure_rate="0"
        local status="UNKNOWN"

        if [[ -f "$failures_file" ]]; then
            failures=$(cat "$failures_file")
        fi
        if [[ -f "$failure_rate_file" ]]; then
            failure_rate=$(cat "$failure_rate_file")
        fi
        if [[ -f "$status_file" ]]; then
            status=$(cat "$status_file")
        fi

        echo "    \"$project\": {" >>"$output_file"
        echo "      \"status\": \"$status\"," >>"$output_file"
        echo "      \"failures\": $failures," >>"$output_file"
        echo "      \"total_runs\": $RUNS_PER_TEST," >>"$output_file"
        echo "      \"failure_rate\": $failure_rate," >>"$output_file"
        echo "      \"runs\": [" >>"$output_file"

        local run_first=true
        for run in $(seq 1 $RUNS_PER_TEST); do
            if [[ $run_first == false ]]; then
                echo "," >>"$output_file"
            fi
            run_first=false

            local result_file="/tmp/${project}_run_${run}"
            local result="UNKNOWN"
            if [[ -f "$result_file" ]]; then
                result=$(cat "$result_file")
            fi
            echo "        \"$result\"" >>"$output_file"
        done
        echo "      ]" >>"$output_file"
        echo "    }" >>"$output_file"
    done

    echo "  }" >>"$output_file"
    echo "}" >>"$output_file"

    log_info "Flaky test results saved to: $output_file"
}

# Main execution
main() {
    local projects=("$@")

    if [[ ${#projects[@]} -eq 0 ]]; then
        # Default to all projects
        projects=("AvoidObstaclesGame" "CodingReviewer" "PlannerApp" "MomentumFinance" "HabitQuest")
    fi

    log_info "Starting flaky test detection across ${#projects[@]} projects..."
    log_info "Configuration: Runs per test=$RUNS_PER_TEST, Flaky threshold=${FLAKY_THRESHOLD}"

    local start_time=$(date +%s)

    # Run flaky detection for each project
    for project in "${projects[@]}"; do
        detect_flaky_tests "$project"
    done

    local end_time=$(date +%s)
    local total_duration=$((end_time - start_time))

    # Generate and save report
    generate_flaky_report
    local report_exit=$?

    save_flaky_results

    echo
    log_info "Total execution time: ${total_duration}s"

    exit $report_exit
}

# Run main function with all arguments
main "$@"
