#!/bin/bash
# Automated Issue Filing System for CI/CD Failures
# Creates GitHub issues for test failures, coverage regressions, and build timeouts
# Integrates with quantum-agent-self-heal.yml for automated remediation

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "$SCRIPT_DIR/../.." && pwd)"

# Configuration
GITHUB_TOKEN=${GITHUB_TOKEN:-""}
REPO_OWNER="dboone323"
REPO_NAME="Quantum-workspace"
MAX_ISSUES_PER_HOUR=10
ISSUE_TRACKING_FILE="$WORKSPACE_ROOT/.issue_tracking.json"

# Quality thresholds from config
COVERAGE_MINIMUM=85
BUILD_TIMEOUT_SECONDS=120
TEST_TIMEOUT_SECONDS=30

# Initialize issue tracking
init_issue_tracking() {
    if [[ ! -f "$ISSUE_TRACKING_FILE" ]]; then
        echo '{
  "issues_created": [],
  "last_hour_count": 0,
  "last_hour_reset": "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"
}' >"$ISSUE_TRACKING_FILE"
    fi
}

# Check rate limiting
check_rate_limit() {
    local current_time=$(date +%s)
    local last_reset=$(jq -r '.last_hour_reset' "$ISSUE_TRACKING_FILE" 2>/dev/null || echo "")
    local last_reset_epoch=$(date -d "$last_reset" +%s 2>/dev/null || echo "0")
    local hours_since_reset=$(( (current_time - last_reset_epoch) / 3600 ))

    if [[ $hours_since_reset -ge 1 ]]; then
        # Reset counter
        local reset_time
        reset_time=$(date -u +%Y-%m-%dT%H:%M:%SZ)
        jq ".last_hour_count = 0 | .last_hour_reset = \"$reset_time\"" "$ISSUE_TRACKING_FILE" >"${ISSUE_TRACKING_FILE}.tmp"
        mv "${ISSUE_TRACKING_FILE}.tmp" "$ISSUE_TRACKING_FILE"
    fi

    local current_count=$(jq -r '.last_hour_count' "$ISSUE_TRACKING_FILE" 2>/dev/null || echo "0")

    if [[ $current_count -ge $MAX_ISSUES_PER_HOUR ]]; then
        echo "Rate limit exceeded: $current_count issues in last hour (max: $MAX_ISSUES_PER_HOUR)"
        return 1
    fi

    return 0
}

# Increment issue counter
increment_counter() {
    jq '.last_hour_count += 1' "$ISSUE_TRACKING_FILE" >"${ISSUE_TRACKING_FILE}.tmp"
    mv "${ISSUE_TRACKING_FILE}.tmp" "$ISSUE_TRACKING_FILE"
}

# Create GitHub issue via API
create_github_issue() {
    local title="$1"
    local body="$2"
    local labels="$3"
    local assignees="$4"

    if [[ -z "$GITHUB_TOKEN" ]]; then
        echo "Warning: GITHUB_TOKEN not set, cannot create GitHub issue"
        echo "Issue would be: $title"
        return 1
    fi

    local api_url="https://api.github.com/repos/$REPO_OWNER/$REPO_NAME/issues"
    local data=$(jq -n \
        --arg title "$title" \
        --arg body "$body" \
        --arg labels "$labels" \
        --arg assignees "$assignees" \
        '{
          title: $title,
          body: $body,
          labels: ($labels | split(",") | map(select(. != ""))),
          assignees: ($assignees | split(",") | map(select(. != "")))
        }')

    local response
    response=$(curl -s -X POST \
        -H "Authorization: token $GITHUB_TOKEN" \
        -H "Accept: application/vnd.github.v3+json" \
        -d "$data" \
        "$api_url")

    local issue_number=$(echo "$response" | jq -r '.number' 2>/dev/null || echo "")

    if [[ -n "$issue_number" && "$issue_number" != "null" ]]; then
        echo "Created issue #$issue_number: $title"
        return 0
    else
        echo "Failed to create issue. Response: $response"
        return 1
    fi
}

# File issue for coverage regression
file_coverage_issue() {
    local project="$1"
    local actual_coverage="$2"
    local expected_minimum="$3"
    local commit_sha="$4"
    local run_id="$5"

    local title="Coverage Regression: $project (${actual_coverage}% < ${expected_minimum}%)"
    local body=$(cat <<EOF
## Coverage Regression Detected

**Project:** $project
**Actual Coverage:** ${actual_coverage}%
**Minimum Required:** ${expected_minimum}%
**Deficit:** $(echo "$expected_minimum - $actual_coverage" | bc)%

**Details:**
- Commit: $commit_sha
- CI Run: $run_id
- Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)

**Impact:** This blocks the current PR from merging.

**Required Action:**
1. Add additional test coverage to reach ${expected_minimum}% minimum
2. Focus on uncovered code paths in the coverage report
3. Consider adding integration tests for complex logic

**Files to Review:**
- Test coverage report in CI artifacts
- Uncovered source files in $project

**Priority:** High - Blocks deployment
EOF
)

    local labels="coverage-regression,ci-failure,high-priority,needs-tests"
    local assignees=""

    create_github_issue "$title" "$body" "$labels" "$assignees"
}

# File issue for build timeout
file_timeout_issue() {
    local operation="$1"
    local duration="$2"
    local timeout_limit="$3"
    local project="$4"
    local commit_sha="$5"
    local run_id="$6"

    local title="Build Timeout: $operation exceeded ${timeout_limit}s limit"
    local body=$(cat <<EOF
## Build Timeout Detected

**Operation:** $operation
**Actual Duration:** ${duration}s
**Timeout Limit:** ${timeout_limit}s
**Project:** $project

**Details:**
- Commit: $commit_sha
- CI Run: $run_id
- Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)

**Impact:** Build process is hanging or running too slowly.

**Possible Causes:**
- Infinite loops in code
- Deadlocks in concurrent operations
- Large test data sets
- Network timeouts
- Resource exhaustion

**Required Action:**
1. Investigate the hanging operation
2. Add timeout guards to long-running processes
3. Optimize performance bottlenecks
4. Consider breaking down large operations

**Debug Steps:**
1. Run locally with verbose logging
2. Check for infinite loops or deadlocks
3. Profile performance with Instruments
4. Review recent code changes for performance impacts

**Priority:** Critical - Blocks CI/CD pipeline
EOF
)

    local labels="build-timeout,ci-failure,critical,performance"
    local assignees=""

    create_github_issue "$title" "$body" "$labels" "$assignees"
}

# File issue for flaky test
file_flaky_test_issue() {
    local test_name="$1"
    local failure_rate="$2"
    local consecutive_failures="$3"
    local project="$4"
    local commit_sha="$5"
    local run_id="$6"

    local title="Flaky Test: $test_name (${failure_rate}% failure rate)"
    local body=$(cat <<EOF
## Flaky Test Detected

**Test:** $test_name
**Failure Rate:** ${failure_rate}%
**Consecutive Failures:** $consecutive_failures
**Project:** $project

**Details:**
- Commit: $commit_sha
- CI Run: $run_id
- Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)

**Impact:** Test is unreliable and may cause false CI failures.

**Flaky Test Criteria Met:**
- ${consecutive_failures} consecutive failures (threshold: 5 = blocked)
- ${failure_rate}% failure rate over multiple runs

**Required Action:**
1. Investigate root cause of flakiness
2. Fix race conditions, timing issues, or external dependencies
3. Add proper test isolation and cleanup
4. Consider converting to integration test if external dependencies required

**Common Flaky Test Causes:**
- Race conditions in async code
- External API dependencies
- Shared state between tests
- Timing-sensitive assertions
- Resource cleanup issues

**Priority:** High - Affects CI reliability
EOF
)

    local labels="flaky-test,ci-unreliable,high-priority,test-quality"
    local assignees=""

    create_github_issue "$title" "$body" "$labels" "$assignees"
}

# File issue for security violation
file_security_issue() {
    local violation_type="$1"
    local details="$2"
    local project="$3"
    local commit_sha="$4"
    local run_id="$5"

    local title="Security Violation: $violation_type in $project"
    local body=$(cat <<EOF
## Security Violation Detected

**Violation Type:** $violation_type
**Project:** $project
**Details:** $details

**Security Scan Results:**
- Commit: $commit_sha
- CI Run: $run_id
- Timestamp: $(date -u +%Y-%m-%dT%H:%M:%SZ)

**Impact:** Potential security vulnerability detected.

**Required Action:**
1. Review the security violation details
2. Fix the security issue immediately
3. Consider security review for related code
4. Update security scanning rules if false positive

**Security Categories:**
- API Key exposure
- Hardcoded credentials
- Insecure data handling
- Privacy compliance violations
- Encryption validation failures

**Priority:** Critical - Security vulnerability
EOF
)

    local labels="security-violation,critical,security-review"
    local assignees=""

    create_github_issue "$title" "$body" "$labels" "$assignees"
}

# Main issue filing function
file_issue() {
    local issue_type="$1"
    shift

    init_issue_tracking

    if ! check_rate_limit; then
        echo "Rate limit exceeded, skipping issue creation"
        return 1
    fi

    case "$issue_type" in
    coverage)
        file_coverage_issue "$@"
        ;;
    timeout)
        file_timeout_issue "$@"
        ;;
    flaky)
        file_flaky_test_issue "$@"
        ;;
    security)
        file_security_issue "$@"
        ;;
    *)
        echo "Unknown issue type: $issue_type"
        return 1
        ;;
    esac

    if [[ $? -eq 0 ]]; then
        increment_counter
    fi
}

# CLI interface
main() {
    if [[ $# -lt 1 ]]; then
        cat <<EOF
Usage: $0 <issue_type> [args...]

Issue Types:
  coverage <project> <actual%> <minimum%> <commit> <run_id>
  timeout <operation> <duration> <limit> <project> <commit> <run_id>
  flaky <test_name> <failure_rate%> <consecutive> <project> <commit> <run_id>
  security <violation_type> <details> <project> <commit> <run_id>

Examples:
  $0 coverage CodingReviewer 75.2 85 abc123 12345
  $0 timeout "Unit Tests" 65 60 CodingReviewer def456 12346
  $0 flaky "testEncryption" 60.0 3 CodingReviewer ghi789 12347

Environment Variables:
  GITHUB_TOKEN    - GitHub API token for issue creation
  MAX_ISSUES_PER_HOUR - Rate limit (default: 10)

EOF
        exit 1
    fi

    file_issue "$@"
}

main "$@"