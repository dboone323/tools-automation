#!/bin/bash

# Parallel Test Execution Framework for Quantum-workspace
# Runs tests across all 5 projects with coverage, performance monitoring, and parallel execution

set -euo pipefail

# Configuration
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# Projects will be determined dynamically unless TEST_PROJECTS env var is provided
PROJECTS=()
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

# Performance tracking (aggregated via temp files per project; variables removed to reduce lint noise)

# Resolve on-disk path for a logical project name
resolve_project_path() {
    local project="$1"

    # 1) Legacy layout: Projects/<Name>
    if [[ -d "$WORKSPACE_ROOT/Projects/$project" ]]; then
        echo "$WORKSPACE_ROOT/Projects/$project"
        return 0
    fi

    # 2) Top-level folder with same name (e.g., Shared)
    if [[ -d "$WORKSPACE_ROOT/$project" ]]; then
        echo "$WORKSPACE_ROOT/$project"
        return 0
    fi

    # 3) Special-case Shared package location
    if [[ "$project" == "Shared" && -d "$WORKSPACE_ROOT/Shared" ]]; then
        echo "$WORKSPACE_ROOT/Shared"
        return 0
    fi

    # 4) Fallback: try to locate a folder by Package.swift parent name
    local pkg
    while IFS= read -r pkg; do
        local dir
        dir="$(dirname "$pkg")"
        if [[ "$(basename "$dir")" == "$project" ]]; then
            echo "$dir"
            return 0
        fi
    done < <(find "$WORKSPACE_ROOT" -maxdepth 3 -name Package.swift 2>/dev/null)

    # Not found
    echo ""; return 1
}

# Discover available testable units if PROJECTS not provided
discover_projects() {
    local discovered=()

    # If TEST_PROJECTS env is set, honor it
    if [[ -n "${TEST_PROJECTS:-}" ]]; then
        # Split by space
        for p in ${TEST_PROJECTS}; do
            discovered+=("$p")
        done
    else
        # Prefer known top-level packages (Shared) and any Package.swift within first 3 levels excluding Tools/WebInterface
        if [[ -f "$WORKSPACE_ROOT/Shared/Package.swift" ]]; then
            discovered+=("Shared")
        fi
        # Discover other packages (exclude Tools/WebInterface which is not part of core testing)
        while IFS= read -r pkg; do
            local dir
            dir="$(dirname "$pkg")"
            local name
            name="$(basename "$dir")"
            # Skip Shared (already added) and Tools subpackages unless explicitly requested
            if [[ "$name" != "Shared" && "$dir" != "$WORKSPACE_ROOT/Tools/WebInterface"* ]]; then
                discovered+=("$name")
            fi
        done < <(find "$WORKSPACE_ROOT" -maxdepth 3 -name Package.swift 2>/dev/null)
    fi

    # If nothing found, fall back to legacy list (will be skipped if paths missing)
    if [[ ${#discovered[@]} -eq 0 ]]; then
        discovered=("AvoidObstaclesGame" "CodingReviewer" "PlannerApp" "MomentumFinance" "HabitQuest")
    fi

    PROJECTS=("${discovered[@]}")
}

# Function to run tests for a single project
run_project_tests() {
    local project="$1"
    local project_path
    project_path="$(resolve_project_path "$project")"
    local start_time
    start_time=$(date +%s)

    log_info "Starting tests for $project..."

    # Store start time
    echo "$start_time" >"/tmp/${project}_start_time"

    # Validate and change to project directory
    if [[ -z "$project_path" || ! -d "$project_path" ]]; then
        log_error "Project path not found for $project"
        echo "FAILED" >"/tmp/${project}_test_result"
        # Record times to avoid negative durations
        echo "$start_time" >"/tmp/${project}_end_time"
        # Create empty artifacts
        : >"/tmp/${project}_test_output"
        echo "0.00" >"/tmp/${project}_coverage"
        return 1
    fi

    cd "$project_path"

    local test_output_file="/tmp/${project}_test_output"

    # Determine test command based on project type
    # Determine test strategy by presence of SwiftPM or Xcode project files
    if [[ -f "Package.swift" ]]; then
        # Swift Package
        if swift test --enable-code-coverage --parallel >"$test_output_file" 2>&1; then
            log_success "Tests passed for $project"
            echo "PASSED" >"/tmp/${project}_test_result"
        else
            # Handle SwiftPM packages with no tests
            if grep -q "no tests found" "$test_output_file" 2>/dev/null; then
                log_warning "No tests found for $project - marking as PASSED (build-only)"
                echo "PASSED" >"/tmp/${project}_test_result"
            else
                log_error "Tests failed for $project"
                echo "FAILED" >"/tmp/${project}_test_result"
                return 1
            fi
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
            -maximum-test-execution-time-allowance "$TIMEOUT_SECONDS" >"$test_output_file" 2>&1; then
            log_success "Tests passed for $project"
            echo "PASSED" >"/tmp/${project}_test_result"
        else
            log_error "Tests failed for $project"
            echo "FAILED" >"/tmp/${project}_test_result"
            return 1
        fi
    fi

    local end_time
    end_time=$(date +%s)
    echo "$end_time" >"/tmp/${project}_end_time"

    # Collect coverage data
    collect_coverage "$project"

    return 0
}

# Function to collect coverage data
collect_coverage() {
    local project="$1"
    local project_path="$WORKSPACE_ROOT/Projects/$project"

    log_info "Collecting coverage for $project..."

    local coverage_pct="0.00"

    if [[ -f "$project_path/Package.swift" ]]; then
        # Swift Package coverage collection
        if command -v llvm-cov >/dev/null 2>&1; then
            # Find coverage files
            local profraw_files
            profraw_files=$(find "$project_path" -name "*.profraw" 2>/dev/null || true)
            if [[ -n "$profraw_files" ]]; then
                # Convert profraw to profdata
                xcrun llvm-profdata merge -sparse "$profraw_files" -o "$project_path/coverage.profdata" 2>/dev/null || true

                # Generate coverage report
                local coverage_report
                # Attempt to infer binary from .build debug products
                local bin
                bin="$(swift build --show-bin-path 2>/dev/null)/$project"
                coverage_report=$(xcrun llvm-cov report \
                    "$bin" \
                    -instr-profile="$project_path/coverage.profdata" \
                    -ignore-filename-regex="\.build|Tests" 2>/dev/null || echo "0.00")

                # Extract percentage
                coverage_pct=$(echo "$coverage_report" | grep -oP '\d+\.\d+(?=%)' | head -1 || echo "0.00")
                log_info "Coverage for $project: ${coverage_pct}%"
            else
                log_warning "No coverage data found for $project"
            fi
        else
            log_warning "llvm-cov not available for $project coverage"
        fi
    else
        # Xcode coverage collection
        local derived_data
        derived_data=$(find "$HOME/Library/Developer/Xcode/DerivedData" -name "*$project*" -type d -maxdepth 1 | head -1)
        if [[ -d "$derived_data" ]]; then
            local coverage_dir="$derived_data/Logs/Test/*.xcresult"
            if [[ -d "$coverage_dir" ]]; then
                # Use xccov to get coverage
                coverage_pct=$(xcrun xccov view --report --json "$coverage_dir" 2>/dev/null |
                    jq -r '.targets[0].lineCoverage * 100' 2>/dev/null || echo "0.00")
                log_info "Coverage for $project: ${coverage_pct}%"
            else
                log_warning "No Xcode coverage data found for $project"
            fi
        else
            log_warning "No derived data found for $project"
        fi
    fi

    # Save coverage to temporary file for report generation
    echo "$coverage_pct" >"/tmp/${project}_coverage"

    # Save coverage data to JSON file for other scripts
    local coverage_file="$WORKSPACE_ROOT/test_results/${project}_coverage.json"
    cat >"$coverage_file" <<EOF
{
  "project": "$project",
  "coverage_percentage": "$coverage_pct",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
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

# Function to parse test output and extract individual test results
parse_test_output() {
    local output_file="$1"
    local test_results="[]"

    if [[ ! -f "$output_file" ]]; then
        echo "$test_results"
        return
    fi

    # Parse test results from xcodebuild output
    # Look for lines like "Test Case '-[TestClass testMethod]' passed/failed"
    local parsed_tests
    parsed_tests=$(grep -E "Test Case.*(passed|failed)" "$output_file" 2>/dev/null |
        sed "s/.*Test Case '-\[\([^]]*\)\]' \([a-z]*\).*/\1 \2/" |
        awk '{
            test_name = $1
            for(i=2; i<NF; i++) test_name = test_name " " $i
            status = $NF
            printf "{\"name\":\"%s\",\"status\":\"%s\"},", test_name, status
        }' | sed 's/,$//')

    if [[ -n "$parsed_tests" ]]; then
        test_results="[$parsed_tests]"
    fi

    echo "$test_results"
}

# Function to generate test report
generate_report() {
    local total_projects=${#PROJECTS[@]}
    local passed_count=0
    local failed_projects=()
    local coverage_warnings=()

    # Create test_results directory if it doesn't exist
    mkdir -p "$WORKSPACE_ROOT/test_results"

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
        local output_file="/tmp/${project}_test_output"

        local status="UNKNOWN"
        local coverage="N/A"
        local duration="N/A"
        local test_results="[]"

        if [[ -f "$status_file" ]]; then
            status=$(cat "$status_file")
        fi

        if [[ -f "$coverage_file" ]]; then
            coverage=$(cat "$coverage_file")
        fi

        if [[ -f "$start_file" && -f "$end_file" ]]; then
            local start_time
            local end_time
            start_time=$(cat "$start_file")
            end_time=$(cat "$end_file")
            duration=$((end_time - start_time))
        fi

        # Parse individual test results from output
        if [[ -f "$output_file" ]]; then
            test_results=$(parse_test_output "$output_file")
        fi

        # Save detailed results to JSON file for other scripts to use
        local result_file="$WORKSPACE_ROOT/test_results/${project}_test_results.json"
        cat >"$result_file" <<EOF
{
  "project": "$project",
  "status": "$status",
  "coverage": "$coverage",
  "duration": "$duration",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "tests": $test_results
}
EOF

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
    # Discover projects before running
    discover_projects

    log_info "Starting parallel test execution across ${#PROJECTS[@]} projects..."
    log_info "Configuration: Max parallel jobs=$MAX_PARALLEL_JOBS, Timeout=${TIMEOUT_SECONDS}s, Coverage threshold=${COVERAGE_THRESHOLD}%"

    local start_time
    start_time=$(date +%s)

    # Run tests in parallel (don't exit on failures)
    run_parallel_tests || true

    local end_time
    end_time=$(date +%s)
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
