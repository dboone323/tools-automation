#!/usr/bin/env bash
set -euo pipefail

# Unified test runner for shell, Python, Swift (SwiftPM) tests.
# Flags:
#   RUN_INTEGRATION=1 to include integration tests
#   TEST_MODE=1 to enable AI stubbing
#   CI_FULL=1 to enable parallel pytest (-n auto)
#   FAST_MODE=1 run smoke subset only (future extension)
#   COVERAGE=1 gather coverage artifacts
#   RETRY_FLAKY=1 enable retry logic for flaky tests
#   QUARANTINE_MODE=1 run only quarantined tests
#   UPDATE_QUARANTINE=1 auto-update quarantine based on failures

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
cd "$ROOT_DIR"

export PATH="$ROOT_DIR/tools/test_shims:$PATH"

# Prefer project virtual environment Python if present
if [[ -x "$ROOT_DIR/.venv/bin/python" ]]; then
    export PATH="$ROOT_DIR/.venv/bin:$PATH"
fi

if [[ "${TEST_MODE:-0}" == "1" ]]; then
    echo "[info] TEST_MODE enabled: AI calls stubbed"
fi

CONFIG_FILE="$ROOT_DIR/tests/config/test_settings.json"
if [[ -f "$CONFIG_FILE" ]]; then
    # Use jq to read config only if available; avoid failing the runner if jq is not installed.
    if command -v jq >/dev/null 2>&1; then
        RUN_INTEGRATION=${RUN_INTEGRATION:-$(jq -r '.run_integration' "$CONFIG_FILE")}
        DEFAULT_TIMEOUT=$(jq -r '.timeout_default_sec' "$CONFIG_FILE")
    else
        echo "[warning] 'jq' not found: using environment/default test settings"
        RUN_INTEGRATION=${RUN_INTEGRATION:-0}
        DEFAULT_TIMEOUT=60
    fi
else
    RUN_INTEGRATION=${RUN_INTEGRATION:-0}
    DEFAULT_TIMEOUT=60
fi

export TIMEOUT_SEC=${TIMEOUT_SEC:-$DEFAULT_TIMEOUT}

# Load quarantine system
QUARANTINE_FILE="$ROOT_DIR/tests/quarantine.txt"
QUARANTINE_TESTS=()
if [[ -f "$QUARANTINE_FILE" ]]; then
    while IFS= read -r line; do
        [[ -n "$line" && ! "$line" =~ ^[[:space:]]*# ]] && QUARANTINE_TESTS+=("$line")
    done <"$QUARANTINE_FILE"
fi

# Load retry helper if available
RETRY_HELPER="$ROOT_DIR/scripts/test_retry_helper.sh"
if [[ -f "$RETRY_HELPER" ]]; then
    source "$RETRY_HELPER"
fi

# Test result tracking
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0
SKIPPED_TESTS=0
FLAKY_TESTS=0
QUARANTINED_TESTS=0

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log_info() { echo -e "${BLUE}[INFO]${NC} $1"; }
log_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
log_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1"; }

# Check if test should be quarantined
is_quarantined() {
    local test_name
    test_name="$1"
    for quarantined in "${QUARANTINE_TESTS[@]}"; do
        if [[ "$test_name" == "$quarantined" ]]; then
            return 0
        fi
    done
    return 1
}

# Record test result
record_test_result() {
    local test_name
    test_name="$1"
    local result
    result="$2" # passed|failed|skipped|flaky|quarantined

    ((TOTAL_TESTS++))

    case "$result" in
    passed) ((PASSED_TESTS++)) ;;
    failed) ((FAILED_TESTS++)) ;;
    skipped) ((SKIPPED_TESTS++)) ;;
    flaky) ((FLAKY_TESTS++)) ;;
    quarantined) ((QUARANTINED_TESTS++)) ;;
    esac

    # Log to test results file
    local results_file
    results_file="$ROOT_DIR/reports/test_results_$(date +%Y%m%d_%H%M%S).jsonl"
    mkdir -p "$ROOT_DIR/reports"
    echo "{\"timestamp\":\"$(date -u +%Y-%m-%dT%H:%M:%SZ)\",\"test\":\"$test_name\",\"result\":\"$result\"}" >>"$results_file"
}

# Run test with retry logic if enabled
run_test_with_retry() {
    local test_name
    test_name="$1"
    shift

    if [[ "${RETRY_FLAKY:-0}" == "1" ]] && command -v retry_with_backoff >/dev/null 2>&1; then
        if retry_with_backoff "$@"; then
            record_test_result "$test_name" "passed"
            return 0
        else
            local exit_code
            exit_code=$?
            # Check if this is a known flaky test
            if is_quarantined "$test_name"; then
                record_test_result "$test_name" "flaky"
                log_warning "Flaky test quarantined: $test_name"
                return 0 # Don't fail on quarantined tests
            else
                record_test_result "$test_name" "failed"
                return $exit_code
            fi
        fi
    else
        if "$@"; then
            record_test_result "$test_name" "passed"
            return 0
        else
            local exit_code
            exit_code=$?
            record_test_result "$test_name" "failed"
            return $exit_code
        fi
    fi
}

shell_tests() {
    echo "[phase] Shell tests"
    local pattern
    pattern="tests/test_*.sh"
    local failed_tests
    failed_tests=()

    for f in $pattern; do
        if [[ -f "$f" ]]; then
            local test_name
            test_name=$(basename "$f" .sh)

            # Check quarantine mode
            if [[ "${QUARANTINE_MODE:-0}" == "1" ]] && ! is_quarantined "$test_name"; then
                log_info "Skipping non-quarantined test: $test_name"
                record_test_result "$test_name" "skipped"
                continue
            fi

            echo "[run] $f"
            if ! run_test_with_retry "$test_name" bash "$f"; then
                failed_tests+=("$test_name")
            fi
        fi
    done

    # Auto-update quarantine if enabled
    if [[ "${UPDATE_QUARANTINE:-0}" == "1" ]] && [[ ${#failed_tests[@]} -gt 0 ]]; then
        log_warning "Auto-quarantining failed tests..."
        for test in "${failed_tests[@]}"; do
            python3 "$ROOT_DIR/scripts/update_quarantine.py" add "$test" 2>/dev/null || true
        done
    fi
}

python_tests() {
    echo "[phase] Python tests"
    if [[ -d tests ]]; then
        local PY
        PY=python
        # Prefer venv python explicitly if available
        if [[ -x "$ROOT_DIR/.venv/bin/python" ]]; then
            PY="$ROOT_DIR/.venv/bin/python"
        fi
        if ! command -v "$PY" >/dev/null 2>&1; then
            PY=python3
        fi
        if ! command -v "$PY" >/dev/null 2>&1; then
            echo "[skip] No python interpreter found; skipping Python tests"
            return 0
        fi
        if ! "$PY" -c "import pytest" >/dev/null 2>&1; then
            echo "[skip] pytest module not available; skipping Python tests"
            return 0
        fi

        # Build pytest command
        local cmd
        cmd=("$PY" -m pytest)
        if [[ "${COVERAGE:-0}" == "1" ]] && "$PY" -c "import coverage" >/dev/null 2>&1; then
            cmd=("$PY" -m coverage run -m pytest)
        fi

        # Add parallel execution in CI
        if [[ "${CI_FULL:-0}" == "1" ]]; then
            cmd+=(-n auto)
        fi

        # Add quiet mode unless verbose requested
        if [[ "${VERBOSE:-0}" != "1" ]]; then
            cmd+=(-q)
        fi

        # Handle integration tests
        if [[ "${RUN_INTEGRATION}" == "1" ]]; then
            cmd+=(-m "not skip")
        else
            # Exclude integration tests by marker and by path to avoid
            # executing long-running integration suites in this pass.
            cmd+=(-m "not integration")
            cmd+=(--ignore=tests/integration)
        fi

        # Add quarantine filtering
        if [[ "${QUARANTINE_MODE:-0}" == "1" ]]; then
            cmd+=(--ignore-glob="**/test_*.py" -k "quarantine")
        fi

        echo "[cmd] ${cmd[*]}"
        if "${cmd[@]}"; then
            log_success "Python tests passed"
        else
            log_error "Python tests failed"
            return 1
        fi

        # Generate coverage report
        if [[ "${COVERAGE:-0}" == "1" ]] && "$PY" -c "import coverage" >/dev/null 2>&1; then
            "$PY" -m coverage json -o reports/python-coverage.json || true
            "$PY" -m coverage html -d reports/python-coverage-html || true
        fi
    fi
}

swift_packages=(MomentumFinance shared-kit)
swift_tests() {
    echo "[phase] Swift tests"
    if ! command -v swift >/dev/null 2>&1; then
        echo "[skip] swift not installed; skipping Swift tests"
        return 0
    fi

    # Optional exclusions via env: comma-separated list
    IFS=',' read -r -a EXCLUDES <<<"${SWIFT_PACKAGE_EXCLUDES:-}"

    for pkg in "${swift_packages[@]}"; do
        if [[ -f "$pkg/Package.swift" ]]; then
            skip_pkg=0
            for ex in "${EXCLUDES[@]}"; do
                [[ "$ex" == "$pkg" ]] && skip_pkg=1 && break
            done
            if [[ $skip_pkg -eq 1 ]]; then
                echo "[skip] Excluding Swift package $pkg"
                continue
            fi

            echo "[run] swift test ($pkg)"
            pushd "$pkg" >/dev/null

            local swift_cmd

            swift_cmd=(swift test)
            if [[ "${COVERAGE:-0}" == "1" ]]; then
                swift_cmd+=(--enable-code-coverage)
            fi

            if "${swift_cmd[@]}"; then
                log_success "Swift tests passed for $pkg"
            else
                log_error "Swift tests failed for $pkg"
                popd >/dev/null
                return 1
            fi

            # Extract coverage if enabled
            if [[ "${COVERAGE:-0}" == "1" ]]; then
                # Export coverage data for merging
                if command -v llvm-cov >/dev/null 2>&1; then
                    llvm-cov export \
                        -format="lcov" \
                        .build/debug/${pkg}PackageTests.xctest/Contents/MacOS/${pkg}PackageTests \
                        -instr-profile .build/debug/codecov/default.profdata \
                        >"$ROOT_DIR/reports/swift-coverage-${pkg}.json" 2>/dev/null || true
                fi
            fi

            popd >/dev/null
        fi
    done
}

# Merge coverage reports if available
merge_coverage_reports() {
    if [[ "${COVERAGE:-0}" == "1" ]] && [[ -f "$ROOT_DIR/scripts/merge_coverage.sh" ]]; then
        echo "[phase] Merging coverage reports"
        bash "$ROOT_DIR/scripts/merge_coverage.sh"
    fi
}

# Generate test summary report
generate_test_summary() {
    local summary_file
    summary_file="$ROOT_DIR/reports/test_summary_$(date +%Y%m%d_%H%M%S).json"
    mkdir -p "$ROOT_DIR/reports"

    cat >"$summary_file" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "total_tests": $TOTAL_TESTS,
  "passed_tests": $PASSED_TESTS,
  "failed_tests": $FAILED_TESTS,
  "skipped_tests": $SKIPPED_TESTS,
  "flaky_tests": $FLAKY_TESTS,
  "quarantined_tests": $QUARANTINED_TESTS,
  "success_rate": $(echo "scale=2; ($PASSED_TESTS * 100) / $TOTAL_TESTS" | bc 2>/dev/null || echo "0"),
  "config": {
    "test_mode": ${TEST_MODE:-0},
    "run_integration": ${RUN_INTEGRATION:-0},
    "coverage": ${COVERAGE:-0},
    "retry_flaky": ${RETRY_FLAKY:-0},
    "quarantine_mode": ${QUARANTINE_MODE:-0}
  }
}
EOF

    log_info "Test summary written to: $summary_file"
}

main() {
    log_info "Starting unified test runner"
    log_info "Configuration: TEST_MODE=${TEST_MODE:-0}, COVERAGE=${COVERAGE:-0}, RETRY_FLAKY=${RETRY_FLAKY:-0}"

    # Run test phases
    shell_tests
    python_tests
    swift_tests

    # Merge coverage if enabled
    merge_coverage_reports

    # Generate summary
    generate_test_summary

    # Print final results
    echo ""
    echo "═══════════════════════════════════════════════════════════════"
    echo "                        TEST RESULTS"
    echo "═══════════════════════════════════════════════════════════════"
    echo "Total Tests:    $TOTAL_TESTS"
    echo "Passed:         $PASSED_TESTS"
    echo "Failed:         $FAILED_TESTS"
    echo "Skipped:        $SKIPPED_TESTS"
    echo "Flaky:          $FLAKY_TESTS"
    echo "Quarantined:    $QUARANTINED_TESTS"
    echo ""

    if [[ $FAILED_TESTS -eq 0 ]]; then
        log_success "All tests completed successfully!"
        exit 0
    else
        log_error "Some tests failed. Check quarantine and retry settings."
        exit 1
    fi
}

main "$@"
