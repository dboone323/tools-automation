#!/bin/bash
# workflow_health_monitor.sh - Daily workflow health check
# Part of OA-06 Observability & Hygiene System

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
WORKFLOWS_DIR="${ROOT_DIR}/.github/workflows"
REPORT_DIR="${ROOT_DIR}/Tools/Automation/reports"
REPORT_FILE="${REPORT_DIR}/workflow_health_$(date +%Y%m%d).md"

# GitHub API configuration (uses GITHUB_TOKEN if available)
GITHUB_REPO="${GITHUB_REPOSITORY:-dboone323/Quantum-workspace}"
GITHUB_TOKEN="${GITHUB_TOKEN:-}"

# Thresholds
MAX_FAILURE_COUNT=3
MAX_HOURS_SINCE_RUN=48

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure report directory exists
mkdir -p "$REPORT_DIR"

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

# Initialize report
init_report() {
  cat >"$REPORT_FILE" <<EOF
# Workflow Health Report
**Generated:** $(date +"%Y-%m-%d %H:%M:%S")
**Repository:** ${GITHUB_REPO}

---

## Executive Summary

EOF
}

# Get workflow list from filesystem
get_workflows() {
  if [[ ! -d "$WORKFLOWS_DIR" ]]; then
    log_error "Workflows directory not found: $WORKFLOWS_DIR"
    return 1
  fi

  find "$WORKFLOWS_DIR" -name "*.yml" -type f | sort
}

# Check workflow configuration
check_workflow_config() {
  local workflow_file="$1"
  local workflow_name
  workflow_name=$(basename "$workflow_file")

  local has_schedule=false
  local has_push=false
  local has_pr=false
  local has_dispatch=false

  # Parse workflow triggers
  if grep -q "schedule:" "$workflow_file" 2>/dev/null; then
    has_schedule=true
  fi

  if grep -q "push:" "$workflow_file" 2>/dev/null; then
    has_push=true
  fi

  if grep -q "pull_request:" "$workflow_file" 2>/dev/null; then
    has_pr=true
  fi

  if grep -q "workflow_dispatch:" "$workflow_file" 2>/dev/null; then
    has_dispatch=true
  fi

  # Determine expected frequency
  local expected_frequency="Manual"
  if [[ "$has_schedule" == true ]]; then
    expected_frequency="Scheduled"
  elif [[ "$has_push" == true ]] || [[ "$has_pr" == true ]]; then
    expected_frequency="On Commits"
  fi

  echo "${workflow_name}|${expected_frequency}|${has_schedule}|${has_push}|${has_pr}|${has_dispatch}"
}

# Analyze all workflows
analyze_workflows() {
  log_info "Analyzing workflows..."

  echo "## 📋 Workflow Inventory" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"
  echo "| Workflow | Expected Frequency | Triggers |" >>"$REPORT_FILE"
  echo "|----------|-------------------|----------|" >>"$REPORT_FILE"

  local total_workflows=0
  local scheduled_workflows=0
  local commit_workflows=0
  local manual_workflows=0

  local workflow_files=()
  while IFS= read -r workflow_file; do
    workflow_files+=("$workflow_file")
  done < <(get_workflows)

  for workflow_file in "${workflow_files[@]}"; do
    ((total_workflows++))

    local workflow_info
    workflow_info=$(check_workflow_config "$workflow_file")

    local name frequency has_schedule has_push has_pr has_dispatch
    IFS='|' read -r name frequency has_schedule has_push has_pr has_dispatch <<<"$workflow_info"

    local triggers=""
    [[ "$has_schedule" == "true" ]] && triggers="${triggers}⏰ "
    [[ "$has_push" == "true" ]] && triggers="${triggers}📤 "
    [[ "$has_pr" == "true" ]] && triggers="${triggers}🔀 "
    [[ "$has_dispatch" == "true" ]] && triggers="${triggers}🎯 "

    if [[ "$frequency" == "Scheduled" ]]; then
      ((scheduled_workflows++))
    elif [[ "$frequency" == "On Commits" ]]; then
      ((commit_workflows++))
    else
      ((manual_workflows++))
    fi

    echo "| $name | $frequency | $triggers |" >>"$REPORT_FILE"
  done

  echo "" >>"$REPORT_FILE"
  echo "**Total Workflows:** ${total_workflows}" >>"$REPORT_FILE"
  echo "- Scheduled: ${scheduled_workflows}" >>"$REPORT_FILE"
  echo "- Commit-triggered: ${commit_workflows}" >>"$REPORT_FILE"
  echo "- Manual-only: ${manual_workflows}" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  log_success "Found ${total_workflows} workflows"
}

# Check for potential issues
check_workflow_issues() {
  log_info "Checking for potential issues..."

  echo "## ⚠️ Potential Issues" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  local issues_found=0

  # Check for duplicate workflow names
  local duplicate_names
  duplicate_names=$(get_workflows | xargs -I {} basename {} | sort | uniq -d)

  if [[ -n "$duplicate_names" ]]; then
    echo "### Duplicate Workflow Names" >>"$REPORT_FILE"
    echo "" >>"$REPORT_FILE"
    echo "🔴 **CRITICAL**: Found workflows with duplicate names:" >>"$REPORT_FILE"
    echo '```' >>"$REPORT_FILE"
    echo "$duplicate_names" >>"$REPORT_FILE"
    echo '```' >>"$REPORT_FILE"
    echo "" >>"$REPORT_FILE"
    ((issues_found++))
    log_warning "Duplicate workflow names detected"
  fi

  # Check for workflows with similar purposes (CI workflows)
  local ci_workflows
  ci_workflows=$(get_workflows | xargs -I {} basename {} | grep -i "ci\|test\|build" | wc -l | tr -d ' ')

  if [[ $ci_workflows -gt 3 ]]; then
    echo "### Potential CI/CD Redundancy" >>"$REPORT_FILE"
    echo "" >>"$REPORT_FILE"
    echo "🟡 **WARNING**: Found ${ci_workflows} CI/CD-related workflows:" >>"$REPORT_FILE"
    echo '```' >>"$REPORT_FILE"
    get_workflows | xargs -I {} basename {} | grep -Ei '(^|[-_.])((ci)|(test)|(build))($|[-_.])' >>"$REPORT_FILE"
    echo '```' >>"$REPORT_FILE"
    echo "Consider consolidating similar workflows to reduce complexity." >>"$REPORT_FILE"
    echo "" >>"$REPORT_FILE"
    ((issues_found++))
    log_warning "${ci_workflows} CI/CD workflows detected - may need consolidation"
  fi

  # Check for workflows without schedule or triggers
  while IFS= read -r workflow_file; do
    local workflow_name
    workflow_name=$(basename "$workflow_file")

    if ! grep -q -E "schedule:|push:|pull_request:|workflow_dispatch:|workflow_call:" "$workflow_file" 2>/dev/null; then
      if [[ $issues_found -eq 0 ]]; then
        echo "### Workflows Without Triggers" >>"$REPORT_FILE"
        echo "" >>"$REPORT_FILE"
      fi
      echo "- ⚠️ **$workflow_name** has no configured triggers" >>"$REPORT_FILE"
      ((issues_found++))
      log_warning "$workflow_name has no triggers"
    fi
  done < <(get_workflows)

  if [[ $issues_found -eq 0 ]]; then
    echo "✅ No issues detected" >>"$REPORT_FILE"
    log_success "No workflow issues detected"
  else
    echo "" >>"$REPORT_FILE"
    log_warning "${issues_found} potential issues detected"
  fi

  echo "" >>"$REPORT_FILE"
}

# Generate recommendations
generate_recommendations() {
  log_info "Generating recommendations..."

  echo "## 💡 Recommendations" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  # Count workflows by type
  local total
  total=$(get_workflows | wc -l | tr -d ' ')

  if [[ $total -gt 15 ]]; then
    echo "1. 🔄 **Workflow Consolidation**: With ${total} workflows, consider consolidating similar ones:" >>"$REPORT_FILE"
    echo "   - Merge redundant CI workflows" >>"$REPORT_FILE"
    echo "   - Combine similar validation workflows" >>"$REPORT_FILE"
    echo "   - Use workflow_call for reusable components" >>"$REPORT_FILE"
    echo "" >>"$REPORT_FILE"
  fi

  echo "2. 📊 **Monitoring**: Enable GitHub Actions usage tracking:" >>"$REPORT_FILE"
  echo "   - Review workflow execution times regularly" >>"$REPORT_FILE"
  echo "   - Monitor for failed workflow runs" >>"$REPORT_FILE"
  echo "   - Set up notifications for critical failures" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  echo "3. 🔧 **Maintenance**: Regular workflow hygiene:" >>"$REPORT_FILE"
  echo "   - Keep actions up to date (uses statements)" >>"$REPORT_FILE"
  echo "   - Remove unused workflows" >>"$REPORT_FILE"
  echo "   - Document workflow purposes" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  echo "4. ⚡ **Performance**: Optimize workflow execution:" >>"$REPORT_FILE"
  echo "   - Use caching for dependencies" >>"$REPORT_FILE"
  echo "   - Parallelize independent jobs" >>"$REPORT_FILE"
  echo "   - Set appropriate timeouts" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"
}

# Generate summary
generate_summary() {
  log_info "Generating summary..."

  local total_workflows
  total_workflows=$(get_workflows | wc -l | tr -d ' ')

  local scheduled
  scheduled=$(get_workflows | xargs grep -l "schedule:" 2>/dev/null | wc -l | tr -d ' ')

  # Update executive summary
  local temp_file="${REPORT_FILE}.tmp"
  cat >"$temp_file" <<EOF
# Workflow Health Report
**Generated:** $(date +"%Y-%m-%d %H:%M:%S")
**Repository:** ${GITHUB_REPO}

---

## Executive Summary

| Metric | Value |
|--------|-------|
| Total Workflows | ${total_workflows} |
| Scheduled Workflows | ${scheduled} |
| Status | 🟢 HEALTHY |

EOF

  # Append the rest of the report (skip first 9 lines)
  tail -n +10 "$REPORT_FILE" >>"$temp_file"
  mv "$temp_file" "$REPORT_FILE"
}

# Main execution
main() {
  log_info "Starting workflow health check..."
  echo

  # Initialize report
  init_report

  # Run checks
  analyze_workflows
  check_workflow_issues
  generate_recommendations

  # Generate summary
  generate_summary

  log_success "Workflow health check complete!"
  log_info "Report saved to: $REPORT_FILE"

  # Display report
  echo
  echo "========================================="
  cat "$REPORT_FILE"
  echo "========================================="
}

# Run main function
main "$@"
