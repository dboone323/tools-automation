#!/bin/bash
# Merge Guard Script
# Part of OA-05: AI Review & Guarded Merge
# Enforces validation safeguards before allowing code merges

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
VALIDATION_REPORTS_DIR="${VALIDATION_REPORTS_DIR:-./validation_reports}"
MCP_SERVER="${MCP_SERVER:-http://localhost:5005}"
AI_REVIEWS_DIR="${AI_REVIEWS_DIR:-./ai_reviews}"
MAX_VALIDATION_AGE=3600 # 1 hour in seconds
STRICT_MODE="${STRICT_MODE:-false}"

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Check if validation reports exist and are recent
check_validation_reports() {
  local project="${1:-all}"

  log_info "Checking validation reports for project: ${project}"

  if [ ! -d "$VALIDATION_REPORTS_DIR" ]; then
    log_error "Validation reports directory not found: ${VALIDATION_REPORTS_DIR}"
    return 1
  fi

  local report_count=0
  local passing_count=0
  local failing_count=0
  local current_time=$(date +%s)

  # Find recent validation reports
  for report in "${VALIDATION_REPORTS_DIR}"/*.json; do
    if [ ! -f "$report" ]; then
      continue
    fi

    # Check if report matches project filter
    if [ "$project" != "all" ]; then
      if ! echo "$report" | grep -q "${project}_validation"; then
        continue
      fi
    fi

    report_count=$((report_count + 1))

    # Check report age
    local report_time=$(stat -f %m "$report" 2>/dev/null || stat -c %Y "$report" 2>/dev/null)
    local age=$((current_time - report_time))

    if [ $age -gt $MAX_VALIDATION_AGE ]; then
      log_warning "Validation report too old (${age}s): $(basename "$report")"
      if [ "$STRICT_MODE" = "true" ]; then
        return 1
      fi
      continue
    fi

    # Check overall status
    local overall_status=$(jq -r '.overall_status // "unknown"' "$report")

    if [ "$overall_status" = "passed" ]; then
      passing_count=$((passing_count + 1))
      log_success "✓ $(basename "$report"): PASSED"
    else
      failing_count=$((failing_count + 1))

      # Extract specific failures
      local lint_status=$(jq -r '.lint.status // "unknown"' "$report")
      local format_status=$(jq -r '.format.status // "unknown"' "$report")
      local build_status=$(jq -r '.build.status // "unknown"' "$report")

      log_error "✗ $(basename "$report"): FAILED"
      log_error "  - Lint: ${lint_status}"
      log_error "  - Format: ${format_status}"
      log_error "  - Build: ${build_status}"

      # Show error counts
      if [ "$lint_status" = "failed" ]; then
        local lint_errors=$(jq -r '.lint.errors // 0' "$report")
        local lint_warnings=$(jq -r '.lint.warnings // 0' "$report")
        log_error "  - Lint Errors: ${lint_errors}, Warnings: ${lint_warnings}"
      fi
    fi
  done

  if [ $report_count -eq 0 ]; then
    log_error "No validation reports found"
    return 1
  fi

  log_info "Validation Summary: ${passing_count} passed, ${failing_count} failed out of ${report_count} reports"

  if [ $failing_count -gt 0 ]; then
    log_error "Validation checks FAILED"
    return 1
  fi

  log_success "All validation checks PASSED"
  return 0
}

# Check MCP server for recent failures
check_mcp_alerts() {
  log_info "Checking MCP server for recent alerts..."

  # Check if MCP server is accessible
  if ! curl -sf "${MCP_SERVER}/status" >/dev/null 2>&1; then
    log_warning "MCP server not accessible at ${MCP_SERVER}"
    if [ "$STRICT_MODE" = "true" ]; then
      return 1
    fi
    return 0
  fi

  # Get alerts from MCP
  local alerts_json
  alerts_json=$(curl -sf "${MCP_SERVER}/status" 2>/dev/null)

  if [ $? -ne 0 ]; then
    log_warning "Failed to get MCP status"
    return 0
  fi

  # Check for critical or error level alerts in last hour
  local alert_count=$(echo "$alerts_json" | jq '.alerts | length')
  local critical_count=0
  local error_count=0
  local current_time=$(date +%s)
  local one_hour_ago=$((current_time - 3600))

  if [ "$alert_count" = "null" ] || [ "$alert_count" = "0" ]; then
    log_success "No recent MCP alerts"
    return 0
  fi

  # Parse alerts
  while IFS= read -r alert; do
    local level=$(echo "$alert" | jq -r '.level')
    local message=$(echo "$alert" | jq -r '.message')
    local timestamp=$(echo "$alert" | jq -r '.timestamp')

    # Convert timestamp to seconds (if it's ISO format)
    local alert_time=$(date -j -f "%Y-%m-%dT%H:%M:%S" "${timestamp%.*}" +%s 2>/dev/null || echo "$current_time")

    # Only consider recent alerts
    if [ $alert_time -lt $one_hour_ago ]; then
      continue
    fi

    case "$level" in
    critical)
      critical_count=$((critical_count + 1))
      log_error "Critical alert: ${message}"
      ;;
    error)
      error_count=$((error_count + 1))
      log_warning "Error alert: ${message}"
      ;;
    esac
  done < <(echo "$alerts_json" | jq -c '.alerts[]?' 2>/dev/null || echo "")

  if [ $critical_count -gt 0 ]; then
    log_error "${critical_count} critical alerts found in last hour"
    return 1
  fi

  if [ $error_count -gt 0 ]; then
    log_warning "${error_count} error alerts found in last hour"
    if [ "$STRICT_MODE" = "true" ]; then
      return 1
    fi
  fi

  log_success "MCP alerts check passed"
  return 0
}

# Check AI review status
check_ai_review() {
  log_info "Checking AI code review status..."

  if [ ! -d "$AI_REVIEWS_DIR" ]; then
    log_warning "AI reviews directory not found: ${AI_REVIEWS_DIR}"
    if [ "$STRICT_MODE" = "true" ]; then
      return 1
    fi
    return 0
  fi

  # Find most recent review
  local latest_review=$(ls -t "${AI_REVIEWS_DIR}"/review_*.md 2>/dev/null | head -1)

  if [ -z "$latest_review" ] || [ ! -f "$latest_review" ]; then
    log_warning "No AI code review found"
    if [ "$STRICT_MODE" = "true" ]; then
      return 1
    fi
    return 0
  fi

  # Check review age
  local current_time=$(date +%s)
  local review_time=$(stat -f %m "$latest_review" 2>/dev/null || stat -c %Y "$latest_review" 2>/dev/null)
  local age=$((current_time - review_time))

  if [ $age -gt $MAX_VALIDATION_AGE ]; then
    log_warning "AI review too old (${age}s): $(basename "$latest_review")"
    if [ "$STRICT_MODE" = "true" ]; then
      return 1
    fi
  fi

  log_info "Latest AI review: $(basename "$latest_review") (${age}s old)"

  # Extract approval status
  local approval_status="UNKNOWN"
  if grep -q "BLOCKED" "$latest_review"; then
    approval_status="BLOCKED"
  elif grep -q "NEEDS_CHANGES" "$latest_review"; then
    approval_status="NEEDS_CHANGES"
  elif grep -q "APPROVED" "$latest_review"; then
    approval_status="APPROVED"
  fi

  log_info "AI Review Status: ${approval_status}"

  # Extract issue counts
  local critical=$(grep -i "Critical Issues:" "$latest_review" | grep -oE '[0-9]+' | head -1 || echo "0")
  local major=$(grep -i "Major Issues:" "$latest_review" | grep -oE '[0-9]+' | head -1 || echo "0")
  local minor=$(grep -i "Minor Issues:" "$latest_review" | grep -oE '[0-9]+' | head -1 || echo "0")

  log_info "Issues - Critical: ${critical}, Major: ${major}, Minor: ${minor}"

  # Check approval status
  case "$approval_status" in
  BLOCKED)
    log_error "AI review is BLOCKED - merge not allowed"
    return 1
    ;;
  NEEDS_CHANGES)
    log_warning "AI review suggests changes"
    if [ "$STRICT_MODE" = "true" ] && [ "$critical" -gt 0 ]; then
      log_error "Critical issues found in strict mode"
      return 1
    fi
    if [ "$critical" -gt 0 ]; then
      log_error "${critical} critical issues found"
      return 1
    fi
    ;;
  APPROVED)
    log_success "AI review APPROVED"
    return 0
    ;;
  *)
    log_warning "AI review status unclear"
    if [ "$STRICT_MODE" = "true" ]; then
      return 1
    fi
    ;;
  esac

  return 0
}

# Main guard function
guard_merge() {
  local project="${1:-all}"

  log_info "======================================"
  log_info "MERGE GUARD: Starting checks"
  log_info "Project: ${project}"
  log_info "Strict Mode: ${STRICT_MODE}"
  log_info "======================================"
  echo ""

  local checks_passed=0
  local checks_failed=0

  # Check 1: Validation Reports
  echo "Check 1: Validation Reports"
  if check_validation_reports "$project"; then
    checks_passed=$((checks_passed + 1))
  else
    checks_failed=$((checks_failed + 1))
  fi
  echo ""

  # Check 2: MCP Alerts
  echo "Check 2: MCP Alert Status"
  if check_mcp_alerts; then
    checks_passed=$((checks_passed + 1))
  else
    checks_failed=$((checks_failed + 1))
  fi
  echo ""

  # Check 3: AI Review
  echo "Check 3: AI Code Review"
  if check_ai_review; then
    checks_passed=$((checks_passed + 1))
  else
    checks_failed=$((checks_failed + 1))
  fi
  echo ""

  # Summary
  log_info "======================================"
  log_info "MERGE GUARD SUMMARY"
  log_info "======================================"
  log_info "Checks Passed: ${checks_passed}/3"
  log_info "Checks Failed: ${checks_failed}/3"
  log_info "======================================"
  echo ""

  if [ $checks_failed -gt 0 ]; then
    log_error "MERGE BLOCKED: ${checks_failed} check(s) failed"
    echo ""
    echo "To proceed with merge:"
    echo "  1. Fix validation failures and re-run validation"
    echo "  2. Address critical issues from AI review"
    echo "  3. Resolve any MCP alerts"
    echo "  4. Re-run this guard: $0"
    echo ""
    return 1
  fi

  log_success "MERGE APPROVED: All checks passed"
  echo ""
  echo "✓ Validation reports: PASSED"
  echo "✓ MCP alerts: CLEAN"
  echo "✓ AI review: APPROVED"
  echo ""
  log_success "Safe to proceed with merge"
  return 0
}

# Usage information
usage() {
  cat <<EOF
Usage: $0 [OPTIONS] [PROJECT]

Merge guard: Enforces validation safeguards before allowing merges

OPTIONS:
    -h, --help          Show this help message
    -s, --strict        Enable strict mode (more rigorous checks)
    -m, --mcp URL       MCP server URL (default: http://localhost:5005)
    -v, --validation DIR  Validation reports directory (default: ./validation_reports)
    -r, --reviews DIR   AI reviews directory (default: ./ai_reviews)
    -a, --age SECONDS   Max validation age in seconds (default: 3600)

ARGUMENTS:
    PROJECT             Project name to check (default: all)

EXAMPLES:
    # Check all projects
    $0

    # Check specific project
    $0 CodingReviewer

    # Strict mode
    $0 --strict

    # Custom directories
    $0 --validation /path/to/reports --reviews /path/to/reviews

ENVIRONMENT VARIABLES:
    VALIDATION_REPORTS_DIR  Path to validation reports
    MCP_SERVER              MCP server URL
    AI_REVIEWS_DIR          Path to AI reviews
    STRICT_MODE             Enable strict mode (true/false)
    MAX_VALIDATION_AGE      Max age in seconds

EXIT CODES:
    0 - All checks passed, safe to merge
    1 - One or more checks failed, merge blocked
EOF
}

# Parse command line arguments
PROJECT="all"

while [[ $# -gt 0 ]]; do
  case "$1" in
  -h | --help)
    usage
    exit 0
    ;;
  -s | --strict)
    STRICT_MODE="true"
    shift
    ;;
  -m | --mcp)
    MCP_SERVER="$2"
    shift 2
    ;;
  -v | --validation)
    VALIDATION_REPORTS_DIR="$2"
    shift 2
    ;;
  -r | --reviews)
    AI_REVIEWS_DIR="$2"
    shift 2
    ;;
  -a | --age)
    MAX_VALIDATION_AGE="$2"
    shift 2
    ;;
  -*)
    log_error "Unknown option: $1"
    usage
    exit 1
    ;;
  *)
    PROJECT="$1"
    shift
    ;;
  esac
done

# Run merge guard
guard_merge "$PROJECT"
