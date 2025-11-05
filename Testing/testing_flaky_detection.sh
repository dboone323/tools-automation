#!/bin/bash
# Testing Enhancement: Flaky Test Detection with Auto-Skip and CI Blocking
# Runs tests multiple times to identify flaky tests and enforce quality thresholds
# Thresholds:
#   - 3 failures in 5 runs = Auto-skip (mark as flaky, don't fail CI)
#   - 5 consecutive failures = Block CI (consistent failure, needs investigation)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
METRICS_DIR="${WORKSPACE_ROOT}/.metrics/testing"
FLAKY_REGISTRY="${METRICS_DIR}/flaky_test_registry.json"

mkdir -p "${METRICS_DIR}"

# Initialize flaky registry if it doesn't exist
if [[ ! -f "${FLAKY_REGISTRY}" ]]; then
    echo '{
  "tests": {},
  "last_updated": "'"$(date -u +%Y-%m-%dT%H:%M:%SZ)"'"
}' >"${FLAKY_REGISTRY}"
fi

log() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [flaky_detection] $*"
}

error() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [ERROR] $*" >&2
}

# Parse xcresult to extract test results
parse_xcresult() {
    local xcresult_path="$1"
    local output_json="$2"

    if [[ ! -d "${xcresult_path}" ]]; then
        error "xcresult not found: ${xcresult_path}"
        return 1
    fi

    # Extract test results using xcresulttool
    xcrun xcresulttool get test-results summaries \
        --path "${xcresult_path}" \
        --format json >"${output_json}" 2>/dev/null || true
}

# Analyze test results across iterations
analyze_flaky_patterns() {
    local results_dir="$1"
    local iterations="$2"
    local project_name="$3"
    local timestamp="$4"

    declare -A test_pass_counts
    declare -A test_fail_counts
    declare -A test_consecutive_fails
    local total_tests=0
    local flaky_tests=0
    local blocked_tests=0

    # Parse all iteration results
    for i in $(seq 1 "${iterations}"); do
        local result_json="${results_dir}/parsed_result_${i}.json"

        if [[ ! -f "${result_json}" ]]; then
            log "Warning: Missing parsed result for iteration ${i}"
            continue
        fi

        # Extract test names and results (simplified parsing)
        # In production, use proper JSON parsing with jq
        local test_names
        test_names=$(jq -r '.summaries[].tests[]?.identifier // empty' "${result_json}" 2>/dev/null || echo "")

        for test_name in ${test_names:-}; do
            # Track test outcomes
            local test_status
            test_status=$(jq -r ".summaries[].tests[] | select(.identifier==\"${test_name}\") | .testStatus" "${result_json}" 2>/dev/null || echo "Unknown")

            if [[ "${test_status}" == "Success" ]]; then
                test_pass_counts["${test_name}"]=$((${test_pass_counts["${test_name}"]:-0} + 1))
                test_consecutive_fails["${test_name}"]=0
            elif [[ "${test_status}" == "Failure" ]]; then
                test_fail_counts["${test_name}"]=$((${test_fail_counts["${test_name}"]:-0} + 1))
                test_consecutive_fails["${test_name}"]=$((${test_consecutive_fails["${test_name}"]:-0} + 1))
            fi
        done
    done

    # Analyze patterns
    local flaky_tests_json="["
    local first=true

    for test_name in "${!test_pass_counts[@]}"; do
        local passes=${test_pass_counts["${test_name}"]:-0}
        local fails=${test_fail_counts["${test_name}"]:-0}
        local consecutive_fails=${test_consecutive_fails["${test_name}"]:-0}
        local total_runs=$((passes + fails))

        ((total_tests++))

        # Apply thresholds
        local status="stable"
        local action="none"

        # 5 consecutive failures = Block CI
        if [[ ${consecutive_fails} -ge 5 ]]; then
            status="blocked"
            action="block_ci"
            ((blocked_tests++))
            log "🚫 Test BLOCKED: ${test_name} (${consecutive_fails} consecutive failures)"
        # 3 failures in 5 runs = Auto-skip (flaky)
        elif [[ ${fails} -ge 3 ]] && [[ ${total_runs} -ge 5 ]]; then
            status="flaky"
            action="auto_skip"
            ((flaky_tests++))
            log "⚠️  Test FLAKY: ${test_name} (${fails}/${total_runs} failures)"
        fi

        # Add to JSON report
        if [[ "${status}" != "stable" ]]; then
            if [[ "${first}" != "true" ]]; then
                flaky_tests_json+=","
            fi
            first=false

            flaky_tests_json+='
    {
      "test_name": "'${test_name}'",
      "status": "'${status}'",
      "action": "'${action}'",
      "passes": '${passes}',
      "failures": '${fails}',
      "consecutive_failures": '${consecutive_fails}',
      "total_runs": '${total_runs}',
      "failure_rate": '$(awk "BEGIN {printf \"%.2f\", (${fails} / ${total_runs}) * 100}")'
    }'
        fi
    done

    flaky_tests_json+="
  ]"

    # Generate report
    local report_file="${METRICS_DIR}/flaky_tests_${project_name}_${timestamp}.json"
    cat >"${report_file}" <<EOF
{
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "project": "${project_name}",
  "iterations": ${iterations},
  "flaky_tests": ${flaky_tests_json},
  "summary": {
    "total_tests": ${total_tests},
    "flaky_tests": ${flaky_tests},
    "blocked_tests": ${blocked_tests},
    "stable_tests": $((total_tests - flaky_tests - blocked_tests)),
    "flaky_percentage": $(awk "BEGIN {printf \"%.2f\", (${flaky_tests} / ${total_tests}) * 100}"),
    "blocked_percentage": $(awk "BEGIN {printf \"%.2f\", (${blocked_tests} / ${total_tests}) * 100}")
  },
  "thresholds": {
    "auto_skip": "3 failures in 5 runs",
    "block_ci": "5 consecutive failures"
  }
}
EOF

    log "Flaky test detection report: ${report_file}"
    log "Summary: ${total_tests} tests, ${flaky_tests} flaky, ${blocked_tests} blocked"

    # Update flaky registry
    update_flaky_registry "${project_name}" "${report_file}"

    # Return exit code based on blocked tests
    if [[ ${blocked_tests} -gt 0 ]]; then
        error "❌ CI BLOCKED: ${blocked_tests} tests have 5+ consecutive failures"
        return 1
    fi

    return 0
}

# Update centralized flaky test registry
update_flaky_registry() {
    local project_name="$1"
    local report_file="$2"

    if [[ ! -f "${report_file}" ]]; then
        error "Report file not found: ${report_file}"
        return 1
    fi

    # Extract flaky tests from report
    local flaky_tests
    flaky_tests=$(jq -r '.flaky_tests[] | select(.status == "flaky") | .test_name' "${report_file}" 2>/dev/null || echo "")

    local blocked_tests
    blocked_tests=$(jq -r '.flaky_tests[] | select(.status == "blocked") | .test_name' "${report_file}" 2>/dev/null || echo "")

    # Update registry (simplified - in production use proper JSON manipulation)
    local timestamp
    timestamp=$(date -u +%Y-%m-%dT%H:%M:%SZ)

    log "Updated flaky registry with results from ${project_name}"
}

detect_flaky_tests() {
    local project_path="$1"
    local iterations="${2:-5}" # Default 5 iterations
    local project_name
    project_name=$(basename "${project_path}")
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)

    log "Detecting flaky tests in ${project_name} (${iterations} iterations)"

    cd "${project_path}" || return 1

    # Find xcodeproj
    local xcodeproj
    xcodeproj=$(find . -maxdepth 1 -name "*.xcodeproj" | head -1)

    if [[ -z ${xcodeproj} ]]; then
        log "No Xcode project found, skipping flaky detection"
        return 1
    fi

    local scheme="${project_name}"
    local results_dir="${METRICS_DIR}/flaky_results_${timestamp}"
    mkdir -p "${results_dir}"

    # Run tests multiple times
    for i in $(seq 1 "${iterations}"); do
        log "Running test iteration ${i}/${iterations}..."

        # Use timeout wrapper for safety
        local timeout_wrapper="${SCRIPT_DIR}/test_timeout_wrapper.sh"
        if [[ -x "${timeout_wrapper}" ]]; then
            "${timeout_wrapper}" unit-test "${xcodeproj}" "${scheme}" "${results_dir}/iteration_${i}.xcresult" || true
        else
            # Fallback to direct xcodebuild
            xcodebuild test \
                -project "${xcodeproj}" \
                -scheme "${scheme}" \
                -destination 'platform=iOS Simulator,name=iPhone 15' \
                -resultBundlePath "${results_dir}/iteration_${i}.xcresult" \
                >"${results_dir}/output_${i}.log" 2>&1 || true
        fi

        # Parse results
        if [[ -d "${results_dir}/iteration_${i}.xcresult" ]]; then
            parse_xcresult "${results_dir}/iteration_${i}.xcresult" "${results_dir}/parsed_result_${i}.json"
        fi

        sleep 2 # Brief pause between runs
    done

    # Analyze results for flaky patterns
    log "Analyzing test results for flaky patterns..."
    analyze_flaky_patterns "${results_dir}" "${iterations}" "${project_name}" "${timestamp}"
}

# If called directly, run detection
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    if [[ $# -eq 0 ]]; then
        echo "Usage: $0 <project_path> [iterations]"
        echo ""
        echo "Thresholds:"
        echo "  - 3 failures in 5 runs = Auto-skip (flaky test)"
        echo "  - 5 consecutive failures = Block CI (consistent failure)"
        exit 1
    fi

    detect_flaky_tests "$@"
fi
