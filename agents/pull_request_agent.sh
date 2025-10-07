#!/bin/bash
# Pull Request Agent: Creates, reviews, and auto-merges low-risk pull requests

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="PullRequestAgent"
LOG_FILE="$(dirname "$0")/pull_request_agent.log"
NOTIFICATION_FILE="$(dirname "$0")/communication/${AGENT_NAME}_notification.txt"
COMPLETED_FILE="$(dirname "$0")/communication/${AGENT_NAME}_completed.txt"
PR_QUEUE_FILE="$(dirname "$0")/pr_queue.json"
RISK_ASSESSMENT_FILE="$(dirname "$0")/risk_assessment.json"

# Risk assessment thresholds
LOW_RISK_THRESHOLD=20
MEDIUM_RISK_THRESHOLD=50
AUTO_MERGE_ENABLED=true

# Initialize files
mkdir -p "$(dirname "$0")/communication"
touch "${NOTIFICATION_FILE}"
touch "${COMPLETED_FILE}"

if [[ ! -f ${PR_QUEUE_FILE} ]]; then
  echo '{"prs": [], "completed": [], "rejected": []}' >"${PR_QUEUE_FILE}"
fi

if [[ ! -f ${RISK_ASSESSMENT_FILE} ]]; then
  echo '{"rules": {}}' >"${RISK_ASSESSMENT_FILE}"
fi

log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date)] [${level}] ${message}" >>"${LOG_FILE}"
}

# Notify orchestrator of task completion
notify_completion() {
  local task_id="$1"
  local success="$2"
  echo "$(date +%s)|${task_id}|${success}" >>"${COMPLETED_FILE}"
}

# Assess risk of a pull request
assess_risk() {
  local pr_title="$1"
  local pr_description="$2"
  local changed_files="$3"
  local risk_score=0

  log_message "INFO" "Assessing risk for PR: ${pr_title}"

  # Risk factors
  # Title contains critical keywords
  if echo "${pr_title}" | grep -qi "security\|critical\|breaking\|major"; then
    risk_score=$((risk_score + 30))
    log_message "INFO" "High-risk keywords detected in title"
  fi

  # Description contains risky terms
  if echo "${pr_description}" | grep -qi "security\|breaking\|migration\|database"; then
    risk_score=$((risk_score + 20))
    log_message "INFO" "Risky terms detected in description"
  fi

  # Check file types changed
  local critical_files
  critical_files=$(echo "${changed_files}" | grep -c "Podfile\|Package.swift\|.xcodeproj\|security\|config")
  risk_score=$((risk_score + (critical_files * 15)))

  # Check number of files changed
  local file_count
  file_count=$(echo "${changed_files}" | wc -l)
  if [[ ${file_count} -gt 10 ]]; then
    risk_score=$((risk_score + 20))
  elif [[ ${file_count} -gt 5 ]]; then
    risk_score=$((risk_score + 10))
  fi

  # Check for test files (lower risk if tests are included)
  local test_files
  test_files=$(echo "${changed_files}" | grep -c "Test\|test")
  if [[ ${test_files} -gt 0 ]]; then
    risk_score=$((risk_score - 10))
  fi

  # Ensure risk score is within bounds
  if [[ ${risk_score} -lt 0 ]]; then
    risk_score=0
  elif [[ ${risk_score} -gt 100 ]]; then
    risk_score=100
  fi

  log_message "INFO" "Risk assessment complete: ${risk_score}/100"
  echo "${risk_score}"
}

# Determine risk level
get_risk_level() {
  local risk_score="$1"

  if [[ ${risk_score} -le ${LOW_RISK_THRESHOLD} ]]; then
    echo "low"
  elif [[ ${risk_score} -le ${MEDIUM_RISK_THRESHOLD} ]]; then
    echo "medium"
  else
    echo "high"
  fi
}

# Create a pull request
create_pull_request() {
  local branch_name="$1"
  local title="$2"
  local description="$3"
  local base_branch="${4:-main}"
  local pr_id
  pr_id=$(date +%s%N | cut -b1-13)

  log_message "INFO" "Creating PR: ${title}"

  # Get changed files
  local changed_files
  changed_files=$(git diff --name-only "${base_branch}" "${branch_name}" 2>/dev/null || echo "")

  # Assess risk
  local risk_score
  risk_score=$(assess_risk "${title}" "${description}" "${changed_files}")
  local risk_level
  risk_level=$(get_risk_level "${risk_score}")

  local created_ts
  created_ts=$(date +%s)

  local pr_data
  if command -v jq &>/dev/null; then
    pr_data=$(jq -n \
      --arg id "${pr_id}" \
      --arg title "${title}" \
      --arg description "${description}" \
      --arg branch "${branch_name}" \
      --arg base "${base_branch}" \
      --arg risk_level "${risk_level}" \
      --arg changed_files "${changed_files}" \
      --arg status "created" \
      --argjson risk_score "${risk_score}" \
      --argjson created "${created_ts}" \
      '{id:$id,title:$title,description:$description,branch:$branch,base:$base,risk_score:$risk_score,risk_level:$risk_level,status:$status,created:$created,changed_files:$changed_files}')
  else
    pr_data=""
  fi

  # Add to queue
  if command -v jq &>/dev/null && [[ -n ${pr_data} ]]; then
    jq --argjson pr "${pr_data}" '.prs += [$pr]' "${PR_QUEUE_FILE}" >"${PR_QUEUE_FILE}.tmp" && mv "${PR_QUEUE_FILE}.tmp" "${PR_QUEUE_FILE}"
  fi

  log_message "INFO" "PR created: ${pr_id} (${risk_level} risk, score: ${risk_score})"

  # Auto-review if low risk
  if [[ ${risk_level} == "low" && ${AUTO_MERGE_ENABLED} == "true" ]]; then
    review_pull_request "${pr_id}"
  fi

  echo "${pr_id}"
}

# Review a pull request
review_pull_request() {
  local pr_id="$1"

  log_message "INFO" "Reviewing PR: ${pr_id}"

  # Get PR data
  local pr_data
  if command -v jq &>/dev/null; then
    pr_data=$(jq -r ".prs[] | select(.id == \"${pr_id}\")" "${PR_QUEUE_FILE}")
  fi

  if [[ -z ${pr_data} ]]; then
    log_message "ERROR" "PR not found: ${pr_id}"
    return 1
  fi

  local risk_level
  risk_level=$(echo "${pr_data}" | jq -r '.risk_level')
  local risk_score
  risk_score=$(echo "${pr_data}" | jq -r '.risk_score')
  local branch
  branch=$(echo "${pr_data}" | jq -r '.branch')
  local base
  base=$(echo "${pr_data}" | jq -r '.base')

  # Perform automated checks
  local checks_passed="true"
  local -a review_lines=()

  # Check 1: Build status
  if ! check_build_status "${branch}"; then
    checks_passed="false"
    review_lines+=("- [FAIL] Build failing")
  else
    review_lines+=("- [OK] Build passing")
  fi

  # Check 2: Tests
  if ! check_test_status "${branch}"; then
    checks_passed="false"
    review_lines+=("- [FAIL] Tests failing")
  else
    review_lines+=("- [OK] Tests passing")
  fi

  # Check 3: Code quality
  local quality_issues
  quality_issues=$(check_code_quality "${branch}")
  if [[ ${quality_issues} -gt 0 ]]; then
    review_lines+=("- [WARN] Code quality issues detected")
    if [[ ${quality_issues} -gt 5 ]]; then
      checks_passed="false"
    fi
  else
    review_lines+=("- [OK] Code quality checks passed")
  fi

  # Check 4: Security scan
  if ! check_security "${branch}"; then
    checks_passed="false"
    review_lines+=("- [FAIL] Security issues found")
  else
    review_lines+=("- [OK] Security scan passed")
  fi

  local review_comments=""
  if ((${#review_lines[@]} > 0)); then
    printf -v review_comments '%s\n' "${review_lines[@]}"
    review_comments=${review_comments%$'\n'}
  fi

  # Decision logic
  local decision="manual_review"
  if [[ ${checks_passed} == "true" && ${risk_level} == "low" ]]; then
    decision="auto_approve"
  elif [[ ${checks_passed} == "false" ]]; then
    decision="reject"
  fi

  # Update PR status
  update_pr_status "${pr_id}" "reviewed" "${decision}"

  # Generate review report
  generate_review_report "${pr_id}" "${decision}" "${review_comments}"

  log_message "INFO" "PR review complete: ${pr_id} -> ${decision}"

  # Auto-merge if approved
  if [[ ${decision} == "auto_approve" ]]; then
    merge_pull_request "${pr_id}"
  fi
}

# Check build status
check_build_status() {
  local branch="$1"

  log_message "INFO" "Checking build status for branch: ${branch}"

  # Switch to branch and attempt build
  git checkout "${branch}" 2>/dev/null

  # For Xcode projects
  local project_file
  project_file=$(find . -name "*.xcodeproj" | head -1)
  if [[ -n ${project_file} ]]; then
    local scheme
    scheme=$(xcodebuild -list -project "${project_file}" 2>/dev/null | grep "Schemes:" -A 5 | tail -5 | head -1 | xargs)

    if [[ -n ${scheme} ]]; then
      if xcodebuild -project "${project_file}" -scheme "${scheme}" -sdk iphonesimulator -configuration Debug build 2>/dev/null; then
        log_message "INFO" "Build successful for ${branch}"
        return 0
      fi
    fi
  fi

  # For Swift packages
  if [[ -f "Package.swift" ]]; then
    if swift build 2>/dev/null; then
      log_message "INFO" "Swift build successful for ${branch}"
      return 0
    fi
  fi

  log_message "WARNING" "Build failed for ${branch}"
  return 1
}

# Check test status
check_test_status() {
  local branch="$1"

  log_message "INFO" "Checking test status for branch: ${branch}"

  # For Swift packages
  if [[ -f "Package.swift" ]]; then
    if swift test 2>/dev/null; then
      log_message "INFO" "Tests passed for ${branch}"
      return 0
    fi
  fi

  # For Xcode projects
  local project_file
  project_file=$(find . -name "*.xcodeproj" | head -1)
  if [[ -n ${project_file} ]]; then
    local scheme
    scheme=$(xcodebuild -list -project "${project_file}" 2>/dev/null | grep "Schemes:" -A 5 | tail -5 | head -1 | xargs)

    if [[ -n ${scheme} ]]; then
      if xcodebuild -project "${project_file}" -scheme "${scheme}" -sdk iphonesimulator -configuration Debug test 2>/dev/null; then
        log_message "INFO" "Xcode tests passed for ${branch}"
        return 0
      fi
    fi
  fi

  log_message "WARNING" "Tests failed for ${branch}"
  return 1
}

# Check code quality
check_code_quality() {
  local branch="$1"
  local issues=0

  log_message "INFO" "Checking code quality for branch: ${branch}"

  # SwiftLint check
  if command -v swiftlint &>/dev/null; then
    local lint_output
    lint_output=$(swiftlint 2>&1)
    local lint_warnings
    lint_warnings=$(echo "${lint_output}" | grep -c "warning")
    local lint_errors
    lint_errors=$(echo "${lint_output}" | grep -c "error")
    issues=$((issues + lint_warnings + lint_errors))

    if [[ ${issues} -gt 0 ]]; then
      log_message "WARNING" "SwiftLint found ${issues} issues"
    fi
  fi

  # SwiftFormat check
  if command -v swiftformat &>/dev/null; then
    if ! swiftformat --dryrun . 2>/dev/null; then
      issues=$((issues + 1))
      log_message "WARNING" "Code formatting issues found"
    fi
  fi

  echo "${issues}"
}

# Check security
check_security() {
  local branch="$1"

  log_message "INFO" "Checking security for branch: ${branch}"

  # Basic security checks
  local security_issues=0

  # Check for hardcoded secrets
  if grep -r "password\|secret\|token\|api_key" --exclude-dir=".git" --exclude-dir="*.backup" . | grep -v "placeholder\|example\|test" | head -1 >/dev/null; then
    security_issues=$((security_issues + 1))
    log_message "WARNING" "Potential hardcoded secrets found"
  fi

  # Check for insecure file permissions
  local insecure_files
  insecure_files=$(find . -type f \( -name "*.pem" -o -name "*.key" -o -name "*.p12" \) -perm /0077 -print 2>/dev/null | wc -l | tr -d ' ')
  if [[ ${insecure_files} -gt 0 ]]; then
    security_issues=$((security_issues + 1))
    log_message "WARNING" "Insecure file permissions found"
  fi

  [[ ${security_issues} -eq 0 ]]
}

# Merge pull request
merge_pull_request() {
  local pr_id="$1"

  log_message "INFO" "Auto-merging PR: ${pr_id}"

  # Get PR data
  local pr_data=""
  local branch=""
  local base=""
  local pr_title=""
  if command -v jq &>/dev/null; then
    pr_data=$(jq -r --arg pr_id "${pr_id}" '.prs[] | select(.id == $pr_id)' "${PR_QUEUE_FILE}")
    branch=$(echo "${pr_data}" | jq -r '.branch // empty')
    base=$(echo "${pr_data}" | jq -r '.base // empty')
    pr_title=$(echo "${pr_data}" | jq -r '.title // ""')
  fi

  if [[ -z ${branch} || -z ${base} ]]; then
    log_message "ERROR" "Missing branch or base for PR ${pr_id}"
    update_pr_status "${pr_id}" "merge_failed" "missing_branch"
    return 1
  fi

  # Switch to base branch and merge
  git checkout "${base}" 2>/dev/null
  local merge_message
  merge_message=$(printf "Auto-merge: %s (PR #%s)" "${pr_title}" "${pr_id}")

  if git merge "${branch}" --no-ff -m "${merge_message}" 2>/dev/null; then
    log_message "INFO" "Successfully merged PR ${pr_id}"
    update_pr_status "${pr_id}" "merged" "success"

    # Clean up branch
    git branch -d "${branch}" 2>/dev/null
    git push origin --delete "${branch}" 2>/dev/null

    return 0
  else
    log_message "ERROR" "Failed to merge PR ${pr_id}"
    update_pr_status "${pr_id}" "merge_failed" "failed"
    return 1
  fi
}

# Update PR status
update_pr_status() {
  local pr_id="$1"
  local status="$2"
  local result="$3"

  if command -v jq &>/dev/null; then
    jq --arg pr_id "${pr_id}" --arg status "${status}" --arg result "${result}" \
      '(.prs[] | select(.id == $pr_id)) |= . + {"status": $status, "result": $result, "updated": now}' \
      "${PR_QUEUE_FILE}" >"${PR_QUEUE_FILE}.tmp" && mv "${PR_QUEUE_FILE}.tmp" "${PR_QUEUE_FILE}"
  fi
}

# Generate review report
generate_review_report() {
  local pr_id="$1"
  local decision="$2"
  local comments="$3"

  local report_dir
  report_dir="$(dirname "$0")/review_reports"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local report_file
  report_file="${report_dir}/pr_review_${pr_id}_${timestamp}.md"

  {
    echo "# Pull Request Review Report"
    echo "PR ID: ${pr_id}"
    echo "Review Date: $(date)"
    echo "Decision: ${decision}"
    echo ""
    echo "## Review Comments"
    echo "${comments}"
    echo ""
    echo "## Risk Assessment"

    # Get PR data for risk info
    if command -v jq &>/dev/null; then
      local pr_data
      pr_data=$(jq -r ".prs[] | select(.id == \"${pr_id}\")" "${PR_QUEUE_FILE}")
      local risk_score
      risk_score=$(echo "${pr_data}" | jq -r '.risk_score')
      local risk_level
      risk_level=$(echo "${pr_data}" | jq -r '.risk_level')
      local changed_files
      changed_files=$(echo "${pr_data}" | jq -r '.changed_files')

      echo "- Risk Score: ${risk_score}/100"
      echo "- Risk Level: ${risk_level}"
      echo "- Files Changed: ${changed_files}"
    fi

  } >"${report_file}"

  log_message "INFO" "Review report generated: ${report_file}"
}

# Process notifications from orchestrator
process_notifications() {
  if [[ -f ${NOTIFICATION_FILE} ]]; then
    while IFS='|' read -r _timestamp notification_type task_id; do
      case "${notification_type}" in
      "new_task")
        log_message "INFO" "Received new task: ${task_id}"
        # Process based on task type
        ;;
      "execute_task")
        log_message "INFO" "Executing task: ${task_id}"
        # Execute the specific task
        ;;
      esac
    done <"${NOTIFICATION_FILE}"

    # Clear processed notifications
    : >"${NOTIFICATION_FILE}"
  fi
}

# Main agent loop
log_message "INFO" "Pull Request Agent starting..."

while true; do
  # Process notifications from orchestrator
  process_notifications

  # Check for pending PRs to review
  if command -v jq &>/dev/null; then
    mapfile -t pending_prs < <(jq -r '.prs[] | select(.status == "created") | .id' "${PR_QUEUE_FILE}")

    for pr_id in "${pending_prs[@]}"; do
      review_pull_request "${pr_id}"
    done
  fi

  # Generate periodic status report (every 10 minutes)
  current_minute=$(date +%M)
  if [[ $((current_minute % 10)) -eq 0 ]]; then
    if declare -F generate_status_report >/dev/null 2>&1; then
      generate_status_report
    else
      # Fallback minimal status log
      pr_count=$(jq -r '.prs | length' "${PR_QUEUE_FILE}" 2>/dev/null || echo 0)
      log_message "INFO" "Status heartbeat: pending PRs=${pr_count}"
    fi
  fi

  sleep 60 # Check every minute
done
