#!/bin/bash

# Automated Issue Detection and Triage System
# Analyzes test results, coverage, and performance to identify issues

set -euo pipefail

# Configuration
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
RESULTS_DIR="$WORKSPACE_ROOT/test_results"
ISSUES_DIR="$RESULTS_DIR/issues"
CONFIG_FILE="$WORKSPACE_ROOT/quality-config.yaml"

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

# Load configuration
load_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        log_error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi

    # Extract values using grep and sed, removing comments
    FLAKY_THRESHOLD=$(grep "flaky_test_threshold:" "$CONFIG_FILE" | sed 's/.*: *\([0-9]*\).*/\1/')
    COVERAGE_MINIMUM=$(grep "minimum: [0-9]" "$CONFIG_FILE" | head -1 | sed 's/.*: *\([0-9]*\).*/\1/')
    PERFORMANCE_THRESHOLD=$(grep "alert_threshold_percent:" "$CONFIG_FILE" | sed 's/.*: *\([0-9]*\).*/\1/')

    log_info "Loaded configuration: flaky_threshold=$FLAKY_THRESHOLD, coverage_minimum=$COVERAGE_MINIMUM, performance_threshold=$PERFORMANCE_THRESHOLD"
}

# Function to detect test failures
detect_test_failures() {
    local project="$1"
    local test_results_file="$RESULTS_DIR/${project}_test_results.json"

    log_info "🔍 Analyzing test failures for $project..."

    if [[ ! -f "$test_results_file" ]]; then
        log_warning "No test results file found for $project: $test_results_file"
        return 0
    fi

    # Parse test results and look for failures
    local failed_tests
    failed_tests=$(jq -r '.tests[] | select(.status == "failed") | .name' "$test_results_file" 2>/dev/null || echo "")

    if [[ -n "$failed_tests" ]]; then
        local issue_file
        issue_file="$ISSUES_DIR/${project}_test_failures_$(date +%Y%m%d_%H%M%S).json"

        jq -n --arg project "$project" --argjson failed_tests "$(echo "$failed_tests" | jq -R -s 'split("\n") | map(select(. != ""))')" '{
            type: "test_failures",
            severity: "high",
            project: $project,
            timestamp: now | strftime("%Y-%m-%dT%H:%M:%SZ"),
            details: {
                failed_tests: $failed_tests,
                count: ($failed_tests | length)
            },
            recommendations: [
                "Review test failure details",
                "Check for recent code changes",
                "Run tests locally to reproduce",
                "Update test expectations if needed"
            ]
        }' >"$issue_file"

        log_warning "❌ Found $(echo "$failed_tests" | wc -l) test failures for $project"
        return 1
    else
        log_success "✅ No test failures found for $project"
        return 0
    fi
}

# Function to detect coverage regressions
detect_coverage_regressions() {
    local project="$1"
    local coverage_file="$RESULTS_DIR/${project}_coverage.json"

    log_info "📊 Analyzing coverage for $project..."

    if [[ ! -f "$coverage_file" ]]; then
        log_warning "No coverage file found for $project: $coverage_file"
        return 0
    fi

    # Get current coverage
    local current_coverage
    current_coverage=$(jq -r '.coverage_percent // 0' "$coverage_file" 2>/dev/null || echo "0")

    # Get minimum required coverage
    local min_coverage="$COVERAGE_MINIMUM"
    if [[ "$project" == "CodingReviewer" ]]; then
        local temp_min_coverage
        temp_min_coverage=$(grep "test_coverage_minimum:" "$CONFIG_FILE" | grep -A 5 "CodingReviewer" | grep "test_coverage_minimum:" | sed 's/.*: *//')
        if [[ -n "$temp_min_coverage" ]]; then
            min_coverage="$temp_min_coverage"
        fi
    fi

    if (($(echo "$current_coverage < $min_coverage" | bc -l 2>/dev/null || echo "1"))); then
        local issue_file
        issue_file="$ISSUES_DIR/${project}_coverage_regression_$(date +%Y%m%d_%H%M%S).json"

        jq -n --arg project "$project" --arg current "$current_coverage" --arg minimum "$min_coverage" '{
            type: "coverage_regression",
            severity: "medium",
            project: $project,
            timestamp: now | strftime("%Y-%m-%dT%H:%M:%SZ"),
            details: {
                current_coverage: ($current | tonumber),
                minimum_required: ($minimum | tonumber),
                deficit: (($minimum | tonumber) - ($current | tonumber))
            },
            recommendations: [
                "Add unit tests for uncovered code",
                "Review test exclusions",
                "Consider refactoring complex functions",
                "Run coverage analysis locally"
            ]
        }' >"$issue_file"

        log_warning "📉 Coverage regression: $current_coverage% < $min_coverage% for $project"
        return 1
    else
        log_success "✅ Coverage acceptable: $current_coverage% >= $min_coverage% for $project"
        return 0
    fi
}

# Function to detect flaky tests
detect_flaky_tests() {
    local project="$1"
    local flaky_file="$RESULTS_DIR/${project}_flaky_tests.json"

    log_info "🎲 Analyzing flaky tests for $project..."

    if [[ ! -f "$flaky_file" ]]; then
        log_warning "No flaky test file found for $project: $flaky_file"
        return 0
    fi

    # Count flaky tests
    local flaky_count
    flaky_count=$(jq -r '.flaky_tests | length' "$flaky_file" 2>/dev/null || echo "0")

    if [[ "$flaky_count" -gt "$FLAKY_THRESHOLD" ]]; then
        local issue_file
        issue_file="$ISSUES_DIR/${project}_flaky_tests_$(date +%Y%m%d_%H%M%S).json"

        jq -n --arg project "$project" --arg count "$flaky_count" --arg threshold "$FLAKY_THRESHOLD" '{
            type: "flaky_tests",
            severity: "medium",
            project: $project,
            timestamp: now | strftime("%Y-%m-%dT%H:%M:%SZ"),
            details: {
                flaky_test_count: ($count | tonumber),
                threshold: ($threshold | tonumber),
                excess: (($count | tonumber) - ($threshold | tonumber))
            },
            recommendations: [
                "Review flaky test patterns",
                "Check for race conditions",
                "Add test isolation",
                "Consider skipping unreliable tests temporarily"
            ]
        }' >"$issue_file"

        log_warning "🎲 Excessive flaky tests: $flaky_count > $FLAKY_THRESHOLD for $project"
        return 1
    else
        log_success "✅ Flaky test count acceptable: $flaky_count <= $FLAKY_THRESHOLD for $project"
        return 0
    fi
}

# Function to detect performance regressions
detect_performance_regressions() {
    local project="$1"
    local perf_file="$RESULTS_DIR/${project}_performance.json"

    log_info "⚡ Analyzing performance for $project..."

    if [[ ! -f "$perf_file" ]]; then
        log_warning "No performance file found for $project: $perf_file"
        return 0
    fi

    # Get current performance metrics
    local current_time
    local max_allowed
    current_time=$(jq -r '.total_duration_seconds // 0' "$perf_file" 2>/dev/null || echo "0")
    max_allowed=$(grep "max_duration_seconds:" "$CONFIG_FILE" | head -1 | sed 's/.*: *//')

    if (($(echo "$current_time > $max_allowed" | bc -l 2>/dev/null || echo "0"))); then
        local issue_file
        issue_file="$ISSUES_DIR/${project}_performance_regression_$(date +%Y%m%d_%H%M%S).json"

        jq -n --arg project "$project" --arg current "$current_time" --arg max "$max_allowed" '{
            type: "performance_regression",
            severity: "high",
            project: $project,
            timestamp: now | strftime("%Y-%m-%dT%H:%M:%SZ"),
            details: {
                current_duration_seconds: ($current | tonumber),
                max_allowed_seconds: ($max | tonumber),
                excess_seconds: (($current | tonumber) - ($max | tonumber))
            },
            recommendations: [
                "Profile test execution",
                "Optimize slow tests",
                "Consider parallel execution",
                "Review test setup/teardown"
            ]
        }' >"$issue_file"

        log_warning "🐌 Performance regression: ${current_time}s > ${max_allowed}s for $project"
        return 1
    else
        log_success "✅ Performance acceptable: ${current_time}s <= ${max_allowed}s for $project"
        return 0
    fi
}

# Function to generate issue summary
generate_issue_summary() {
    log_info "📋 Generating issue summary..."

    local summary_file
    local issue_files
    summary_file="$ISSUES_DIR/issue_summary_$(date +%Y%m%d_%H%M%S).json"
    issue_files=$(find "$ISSUES_DIR" -name "*.json" -type f ! -name "issue_summary_*.json" 2>/dev/null || echo "")

    # Count issues by type and severity
    local high_severity=0
    local medium_severity=0
    local low_severity=0
    local test_failures=0
    local coverage_regressions=0
    local flaky_tests=0
    local performance_regressions=0

    for issue_file in $issue_files; do
        if [[ "$issue_file" == *"_test_failures_"* ]]; then
            ((test_failures++))
        elif [[ "$issue_file" == *"_coverage_regression_"* ]]; then
            ((coverage_regressions++))
        elif [[ "$issue_file" == *"_flaky_tests_"* ]]; then
            ((flaky_tests++))
        elif [[ "$issue_file" == *"_performance_regression_"* ]]; then
            ((performance_regressions++))
        fi

        local severity
        severity=$(jq -r '.severity' "$issue_file" 2>/dev/null || echo "unknown")
        case "$severity" in
        "high") ((high_severity++)) ;;
        "medium") ((medium_severity++)) ;;
        "low") ((low_severity++)) ;;
        esac
    done

    # Generate summary
    jq -n \
        --arg high "$high_severity" \
        --arg medium "$medium_severity" \
        --arg low "$low_severity" \
        --arg test_failures "$test_failures" \
        --arg coverage_regressions "$coverage_regressions" \
        --arg flaky_tests "$flaky_tests" \
        --arg performance_regressions "$performance_regressions" \
        --arg timestamp "$(date -Iseconds)" \
        '{
            timestamp: $timestamp,
            summary: {
                total_issues: (($high | tonumber) + ($medium | tonumber) + ($low | tonumber)),
                by_severity: {
                    high: ($high | tonumber),
                    medium: ($medium | tonumber),
                    low: ($low | tonumber)
                },
                by_type: {
                    test_failures: ($test_failures | tonumber),
                    coverage_regressions: ($coverage_regressions | tonumber),
                    flaky_tests: ($flaky_tests | tonumber),
                    performance_regressions: ($performance_regressions | tonumber)
                }
            },
            recommendations: [
                "Review high-severity issues first",
                "Address test failures immediately",
                "Monitor flaky tests for patterns",
                "Optimize performance regressions",
                "Ensure coverage meets minimum requirements"
            ]
        }' >"$summary_file"

    log_info "📊 Issue summary saved to: $summary_file"

    # Print summary to console
    echo
    echo "=========================================="
    echo "        ISSUE DETECTION SUMMARY"
    echo "=========================================="
    echo "High Severity Issues: $high_severity"
    echo "Medium Severity Issues: $medium_severity"
    echo "Low Severity Issues: $low_severity"
    echo
    echo "By Type:"
    echo "- Test Failures: $test_failures"
    echo "- Coverage Regressions: $coverage_regressions"
    echo "- Flaky Tests: $flaky_tests"
    echo "- Performance Regressions: $performance_regressions"
    echo

    if [[ $high_severity -gt 0 ]]; then
        log_error "🚨 HIGH SEVERITY ISSUES DETECTED - REQUIRES IMMEDIATE ATTENTION"
        return 1
    elif [[ $medium_severity -gt 0 ]] || [[ $test_failures -gt 0 ]]; then
        log_warning "⚠️  ISSUES DETECTED - REVIEW RECOMMENDED"
        return 0
    else
        log_success "✅ NO SIGNIFICANT ISSUES DETECTED"
        return 0
    fi
}

# Main execution
main() {
    local projects=("$@")

    if [[ ${#projects[@]} -eq 0 ]]; then
        # Default to all projects
        projects=("AvoidObstaclesGame" "CodingReviewer" "PlannerApp" "MomentumFinance" "HabitQuest")
    fi

    log_info "Starting automated issue detection for ${#projects[@]} projects..."

    # Load configuration
    load_config

    # Create issues directory
    mkdir -p "$ISSUES_DIR"

    local total_issues=0

    # Analyze each project
    for project in "${projects[@]}"; do
        log_info "🔍 Analyzing $project..."

        local project_issues=0

        # Run all detection functions
        if ! detect_test_failures "$project"; then
            ((project_issues++))
        fi

        if ! detect_coverage_regressions "$project"; then
            ((project_issues++))
        fi

        if ! detect_flaky_tests "$project"; then
            ((project_issues++))
        fi

        if ! detect_performance_regressions "$project"; then
            ((project_issues++))
        fi

        total_issues=$((total_issues + project_issues))

        if [[ $project_issues -gt 0 ]]; then
            log_warning "⚠️  Found $project_issues issues for $project"
        else
            log_success "✅ No issues found for $project"
        fi
    done

    # Generate summary
    generate_issue_summary
    local summary_exit=$?

    log_info "Issue detection completed. Total issues found: $total_issues"

    exit $summary_exit
}

# Run main function with all arguments
main "$@"
