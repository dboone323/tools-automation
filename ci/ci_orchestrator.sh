#!/bin/bash
# Comprehensive CI/CD Integration Script
# Orchestrates all CI components: testing, coverage, flaky detection, performance monitoring
# Called from GitHub Actions workflows for unified CI/CD execution

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"

# Load configuration
QUALITY_CONFIG="$WORKSPACE_ROOT/quality-config.yaml"

# Extract values from quality config (simplified parsing)
COVERAGE_MINIMUM=$(grep "minimum:" "$QUALITY_CONFIG" | grep -o "[0-9]*" | head -1 || echo "85")
COVERAGE_TARGET=$(grep "target:" "$QUALITY_CONFIG" | grep -o "[0-9]*" | head -1 || echo "90")
BUILD_TIMEOUT=$(grep "max_duration_seconds:" "$QUALITY_CONFIG" | grep -A1 "build_performance" | tail -1 | grep -o "[0-9]*" | head -1 || echo "120")
TEST_TIMEOUT=$(grep "max_duration_seconds:" "$QUALITY_CONFIG" | grep -A1 "test_performance" | tail -1 | grep -o "[0-9]*" | head -1 || echo "30")

# CI environment variables
COMMIT_SHA="${GITHUB_SHA:-$(git rev-parse HEAD)}"
CI_RUN_ID="${GITHUB_RUN_ID:-$(date +%s)}"
PROJECT_NAME="${1:-}"
OPERATION="${2:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging
log() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')] $1${NC}"
}

success() {
    echo -e "${GREEN}✅ $1${NC}"
}

warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

error() {
    echo -e "${RED}❌ $1${NC}"
}

# Validate project
validate_project() {
    local project="$1"

    if [[ ! -d "$WORKSPACE_ROOT/Projects/$project" ]]; then
        error "Project directory not found: $WORKSPACE_ROOT/Projects/$project"
        exit 1
    fi

    log "Validated project: $project"
}

# Run build with timeout protection
run_build() {
    local project="$1"
    local start_time
    start_time=$(date +%s.%3N)

    log "Starting build for $project (timeout: ${BUILD_TIMEOUT}s)"

    local timeout_wrapper="$SCRIPT_DIR/../Testing/test_timeout_wrapper.sh"
    local build_cmd

    # Check if this is a Swift Package project
    if [[ -f "Projects/$project/Package.swift" ]]; then
        build_cmd="cd $WORKSPACE_ROOT/Projects/$project && swift build --configuration release"
    else
        build_cmd="cd Projects/$project && xcodebuild build -project ${project}.xcodeproj -scheme $project -configuration Release -destination 'platform=macOS' -allowProvisioningUpdates"
    fi

    if [[ -x "$timeout_wrapper" ]]; then
        if "$timeout_wrapper" build "cd Projects/$project && $build_cmd"; then
            local end_time
            end_time=$(date +%s.%3N)
            local duration
            duration=$(echo "$end_time - $start_time" | bc)

            success "Build completed in ${duration}s"

            # Record performance metric
            "$SCRIPT_DIR/../performance_monitor_advanced.sh" record-build \
                "$project" "build" "$duration" "1" "$COMMIT_SHA" "$CI_RUN_ID"

            return 0
        else
            local end_time
            end_time=$(date +%s.%3N)
            local duration
            duration=$(echo "$end_time - $start_time" | bc)

            error "Build failed after ${duration}s"

            # Record failed build metric
            "$SCRIPT_DIR/../performance_monitor_advanced.sh" record-build \
                "$project" "build" "$duration" "0" "$COMMIT_SHA" "$CI_RUN_ID"

            return 1
        fi
    else
        warning "Timeout wrapper not found, running build without protection"
        cd "Projects/$project"
        if eval "$build_cmd"; then
            success "Build completed"
            return 0
        else
            error "Build failed"
            return 1
        fi
    fi
}

# Run tests with coverage
run_tests() {
    local project="$1"
    local test_type="${2:-unit}"
    local start_time
    start_time=$(date +%s.%3N)

    log "Starting $test_type tests for $project (timeout: ${TEST_TIMEOUT}s)"

    cd "Projects/$project"

    # Check if this is a Swift Package project
    if [[ -f "Package.swift" ]]; then
        log "Detected Swift Package project, using swift test"

        # Run tests with coverage
        if swift test --enable-code-coverage --parallel; then
            local end_time
            end_time=$(date +%s.%3N)
            local duration
            duration=$(echo "$end_time - $start_time" | bc)

            # Extract test results from output
            local test_output
            test_output=$(swift test --enable-code-coverage --parallel 2>&1)

            # Parse test counts (simplified)
            local test_count
            test_count=$(echo "$test_output" | grep -o "[0-9]* tests" | grep -o "[0-9]*" | tail -1 || echo "0")
            local failure_count
            failure_count=$(echo "$test_output" | grep -o "[0-9]* failed" | grep -o "[0-9]*" | tail -1 || echo "0")

            # Generate coverage report
            local coverage_percent="0.0"
            if xcrun llvm-cov export \
                -format="lcov" \
                .build/debug/*PackageTests.xctest/Contents/MacOS/*Tests \
                -instr-profile .build/debug/codecov/default.profdata \
                >coverage.lcov 2>/dev/null; then

                # Extract coverage percentage
                coverage_percent=$(grep -A 10 "SecurityFramework" coverage.lcov 2>/dev/null | grep -o "[0-9]*\.[0-9]*%" | tr -d '%' | head -1 || echo "0.0")
            fi

            success "Tests completed in ${duration}s (${test_count} tests, ${failure_count} failures, ${coverage_percent}% coverage)"

            # Record metrics
            "$SCRIPT_DIR/../performance_monitor_advanced.sh" record-test \
                "$project" "$test_type" "$duration" "$test_count" "$failure_count" "$coverage_percent" "$COMMIT_SHA" "$CI_RUN_ID"

            # Record coverage
            if [[ "$coverage_percent" != "0.0" ]]; then
                "$SCRIPT_DIR/../performance_monitor_advanced.sh" record-coverage \
                    "$project" "0" "0" "$coverage_percent" "$COMMIT_SHA" "$CI_RUN_ID"
            fi

            # Check coverage threshold
            if (($(echo "$coverage_percent < $COVERAGE_MINIMUM" | bc -l 2>/dev/null || echo "1"))); then
                error "Coverage ${coverage_percent}% below minimum ${COVERAGE_MINIMUM}%"

                # File coverage regression issue
                "$SCRIPT_DIR/create_issue.sh" coverage \
                    "$project" "$coverage_percent" "$COVERAGE_MINIMUM" "$COMMIT_SHA" "$CI_RUN_ID" || true

                return 1
            fi

            return 0
        else
            local end_time
            end_time=$(date +%s.%3N)
            local duration
            duration=$(echo "$end_time - $start_time" | bc)

            error "Tests failed after ${duration}s"

            # Record failed test metrics
            "$SCRIPT_DIR/../performance_monitor_advanced.sh" record-test \
                "$project" "$test_type" "$duration" "0" "1" "" "$COMMIT_SHA" "$CI_RUN_ID"

            return 1
        fi

    else
        log "Detected Xcode project, using xcodebuild test"

        # Run tests with Xcode
        local test_cmd="xcodebuild test -project ${project}.xcodeproj -scheme $project -destination 'platform=macOS' -enableCodeCoverage YES -parallel-testing-enabled YES"

        if eval "$test_cmd"; then
            local end_time
            end_time=$(date +%s.%3N)
            local duration
            duration=$(echo "$end_time - $start_time" | bc)

            success "Tests completed in ${duration}s"

            # Record basic metrics (would need more parsing for detailed counts)
            "$SCRIPT_DIR/../performance_monitor_advanced.sh" record-test \
                "$project" "$test_type" "$duration" "0" "0" "" "$COMMIT_SHA" "$CI_RUN_ID"

            return 0
        else
            local end_time
            end_time=$(date +%s.%3N)
            local duration
            duration=$(echo "$end_time - $start_time" | bc)

            error "Tests failed after ${duration}s"

            # Record failed test metrics
            "$SCRIPT_DIR/../performance_monitor_advanced.sh" record-test \
                "$project" "$test_type" "$duration" "0" "1" "" "$COMMIT_SHA" "$CI_RUN_ID"

            return 1
        fi
    fi
}

# Run flaky test detection
run_flaky_detection() {
    local project="$1"

    log "Running flaky test detection for $project"

    warning "Flaky test detection not implemented yet"
    return 0
}

# Run performance regression detection
run_performance_analysis() {
    local project="$1"

    log "Running performance regression analysis for $project"

    local perf_script="$SCRIPT_DIR/../performance_monitor_advanced.sh"

    if [[ -x "$perf_script" ]]; then
        # Analyze trends
        "$perf_script" analyze "$project" 7 || true

        # Detect regressions
        if "$perf_script" detect-regressions "$project"; then
            success "No performance regressions detected"
        else
            warning "Performance regressions detected"
            # Note: Regression alerts are already saved to file
        fi

        # Generate dashboard data
        "$perf_script" dashboard || true

        return 0
    else
        warning "Performance monitoring script not found"
        return 0
    fi
}

# Run security validation
run_security_check() {
    local project="$1"

    log "Running security validation for $project"

    # Check for security violations (simplified)
    if grep -r "API_KEY\|SECRET\|PASSWORD" "Projects/$project" --exclude-dir=".build" --exclude="*.xcresult" >/dev/null 2>&1; then
        error "Security violation: Potential sensitive data found"

        # File security issue
        "$SCRIPT_DIR/ci/create_issue.sh" security \
            "sensitive_data_exposure" "API keys or secrets found in source code" "$project" "$COMMIT_SHA" "$CI_RUN_ID" || true

        return 1
    else
        success "Security check passed"
        return 0
    fi
}

# Main CI orchestration
run_ci_pipeline() {
    local project="$1"
    local operation="$2"

    log "Starting CI pipeline for $project ($operation)"

    validate_project "$project"

    case "$operation" in
    build)
        run_build "$project"
        ;;
    test)
        run_tests "$project" "unit"
        ;;
    full)
        # Full CI pipeline: build -> test -> flaky detection -> performance -> security
        log "Running full CI pipeline"

        if ! run_build "$project"; then
            error "Build failed, stopping pipeline"
            exit 1
        fi

        if ! run_tests "$project" "unit"; then
            error "Tests failed, stopping pipeline"
            exit 1
        fi

        run_flaky_detection "$project" || true # Don't fail pipeline on flaky detection
        run_performance_analysis "$project" || true
        run_security_check "$project" || true

        success "Full CI pipeline completed successfully"
        ;;
    *)
        error "Unknown operation: $operation"
        echo "Usage: $0 <project> <operation>"
        echo "Operations: build, test, full"
        exit 1
        ;;
    esac
}

# Main entry point
main() {
    if [[ $# -lt 2 ]]; then
        error "Usage: $0 <project> <operation>"
        echo ""
        echo "Projects: CodingReviewer, AvoidObstaclesGame, PlannerApp, MomentumFinance, HabitQuest"
        echo "Operations: build, test, full"
        echo ""
        echo "Environment Variables:"
        echo "  GITHUB_SHA    - Commit SHA (auto-detected)"
        echo "  GITHUB_RUN_ID - CI Run ID (auto-detected)"
        exit 1
    fi

    local project="$1"
    local operation="$2"

    # Change to workspace root
    cd "$WORKSPACE_ROOT"

    run_ci_pipeline "$project" "$operation"
}

main "$@"
