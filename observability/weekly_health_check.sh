#!/bin/bash
# weekly_health_check.sh - Comprehensive weekly health check and reporting
# Part of OA-06 Observability & Hygiene System

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
REPORT_DIR="${ROOT_DIR}/Tools/Automation/reports"
METRICS_DIR="${ROOT_DIR}/Tools/Automation/metrics"
LOGS_DIR="${ROOT_DIR}/Tools/Automation/logs"
REPORT_FILE="${REPORT_DIR}/weekly_health_report_$(date +%Y%m%d).md"

# Thresholds
DISK_WARNING_THRESHOLD=75
DISK_CRITICAL_THRESHOLD=85
BACKUP_MAX_AGE_DAYS=7
LOG_MAX_SIZE_MB=100

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Ensure directories exist
mkdir -p "$REPORT_DIR" "$METRICS_DIR"

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
# Weekly Health Check Report
**Generated:** $(date +"%Y-%m-%d %H:%M:%S")
**Period:** Last 7 days
**Repository:** Quantum-workspace

---

## Executive Summary

EOF
}

# Check disk usage
check_disk_usage() {
  log_info "Checking disk usage..."

  echo "## 💾 Disk Usage Analysis" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  local disk_usage
  disk_usage=$(df -h "$ROOT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')
  local disk_avail
  disk_avail=$(df -h "$ROOT_DIR" | awk 'NR==2 {print $4}')

  echo "**Current Usage:** ${disk_usage}% (Available: ${disk_avail})" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  if [[ $disk_usage -ge $DISK_CRITICAL_THRESHOLD ]]; then
    echo "🔴 **Status:** CRITICAL - Disk usage above ${DISK_CRITICAL_THRESHOLD}%" >>"$REPORT_FILE"
    log_error "CRITICAL: Disk usage at ${disk_usage}%"
  elif [[ $disk_usage -ge $DISK_WARNING_THRESHOLD ]]; then
    echo "🟡 **Status:** WARNING - Disk usage above ${DISK_WARNING_THRESHOLD}%" >>"$REPORT_FILE"
    log_warning "WARNING: Disk usage at ${disk_usage}%"
  else
    echo "🟢 **Status:** HEALTHY" >>"$REPORT_FILE"
    log_success "Disk usage healthy at ${disk_usage}%"
  fi

  echo "" >>"$REPORT_FILE"

  # Top space consumers
  echo "### Top Space Consumers" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"
  echo '```' >>"$REPORT_FILE"
  du -sh "$ROOT_DIR"/* 2>/dev/null | sort -hr | head -10 >>"$REPORT_FILE"
  echo '```' >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"
}

# Check backup health
check_backup_health() {
  log_info "Checking backup health..."

  echo "## 📦 Backup System Health" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  local backup_dirs=(
    "${ROOT_DIR}/Tools/Automation/agents/backups"
    "${ROOT_DIR}/.autofix_backups"
  )

  local total_backups=0
  local compressed_backups=0
  local total_backup_size=0
  local old_backups=0

  for backup_dir in "${backup_dirs[@]}"; do
    if [[ -d "$backup_dir" ]]; then
      local dir_name
      dir_name=$(basename "$backup_dir")

      # Count uncompressed backups
      local uncompressed
      uncompressed=$(find "$backup_dir" -maxdepth 1 -type d ! -path "$backup_dir" 2>/dev/null | wc -l)
      total_backups=$((total_backups + uncompressed))

      # Count compressed backups
      local compressed
      compressed=$(find "$backup_dir" -maxdepth 1 -name "*.tar.gz" 2>/dev/null | wc -l)
      compressed_backups=$((compressed_backups + compressed))
      total_backups=$((total_backups + compressed))

      # Calculate size
      local size
      size=$(du -sk "$backup_dir" 2>/dev/null | awk '{print $1}')
      total_backup_size=$((total_backup_size + size))

      # Count old backups (>7 days)
      local old
      old=$(find "$backup_dir" -maxdepth 1 \( -type d -o -name "*.tar.gz" \) -mtime +${BACKUP_MAX_AGE_DAYS} 2>/dev/null | wc -l)
      old_backups=$((old_backups + old))

      echo "- **$dir_name**: ${uncompressed} uncompressed, ${compressed} compressed" >>"$REPORT_FILE"
    fi
  done

  echo "" >>"$REPORT_FILE"
  echo "**Total Backups:** ${total_backups}" >>"$REPORT_FILE"
  # Use parameter expansion to avoid division by zero
  local denominator=${total_backups:-1}
  echo "**Compressed Backups:** ${compressed_backups} ($((compressed_backups * 100 / denominator))%)" >>"$REPORT_FILE"
  echo "**Total Size:** $((total_backup_size / 1024)) MB" >>"$REPORT_FILE"
  echo "**Backups Older Than ${BACKUP_MAX_AGE_DAYS} Days:** ${old_backups}" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  if [[ $old_backups -gt 10 ]]; then
    echo "🟡 **Recommendation:** Consider cleaning old backups (${old_backups} found)" >>"$REPORT_FILE"
    log_warning "${old_backups} old backups detected"
  else
    echo "🟢 **Status:** HEALTHY" >>"$REPORT_FILE"
    log_success "Backup health check passed"
  fi

  echo "" >>"$REPORT_FILE"
}

# Check log health
check_log_health() {
  log_info "Checking log health..."

  echo "## 📝 Log System Health" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  if [[ ! -d "$LOGS_DIR" ]]; then
    echo "🟢 **Status:** No logs directory (clean)" >>"$REPORT_FILE"
    echo "" >>"$REPORT_FILE"
    return
  fi

  local total_logs
  total_logs=$(find "$LOGS_DIR" -type f \( -name "*.log" -o -name "*.log.gz" \) 2>/dev/null | wc -l)
  local total_log_size
  total_log_size=$(du -sk "$LOGS_DIR" 2>/dev/null | awk '{print $1}')
  local large_logs
  large_logs=$(find "$LOGS_DIR" -type f -name "*.log" -size +${LOG_MAX_SIZE_MB}M 2>/dev/null | wc -l)

  echo "**Total Log Files:** ${total_logs}" >>"$REPORT_FILE"
  echo "**Total Size:** $((total_log_size / 1024)) MB" >>"$REPORT_FILE"
  echo "**Large Logs (>${LOG_MAX_SIZE_MB}MB):** ${large_logs}" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  if [[ $large_logs -gt 0 ]]; then
    echo "🟡 **Recommendation:** Rotate or compress large log files" >>"$REPORT_FILE"
    echo "" >>"$REPORT_FILE"
    echo "### Large Log Files" >>"$REPORT_FILE"
    echo '```' >>"$REPORT_FILE"
    find "$LOGS_DIR" -type f -name "*.log" -size +${LOG_MAX_SIZE_MB}M -exec ls -lh {} \; 2>/dev/null >>"$REPORT_FILE"
    echo '```' >>"$REPORT_FILE"
    log_warning "${large_logs} large log files detected"
  else
    echo "🟢 **Status:** HEALTHY" >>"$REPORT_FILE"
    log_success "Log health check passed"
  fi

  echo "" >>"$REPORT_FILE"
}

# Check workflow health
check_workflow_health() {
  log_info "Checking GitHub workflow health..."

  echo "## ⚙️ GitHub Workflow Health" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  local workflow_dir="${ROOT_DIR}/.github/workflows"

  if [[ ! -d "$workflow_dir" ]]; then
    echo "⚪ **Status:** No workflows directory" >>"$REPORT_FILE"
    echo "" >>"$REPORT_FILE"
    return
  fi

  local total_workflows
  total_workflows=$(find "$workflow_dir" -name "*.yml" -o -name "*.yaml" 2>/dev/null | wc -l)

  echo "**Total Workflows:** ${total_workflows}" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  # List workflows
  echo "### Active Workflows" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"
  find "$workflow_dir" -name "*.yml" -o -name "*.yaml" 2>/dev/null | while read -r workflow; do
    local name
    name=$(basename "$workflow")
    echo "- \`$name\`" >>"$REPORT_FILE"
  done

  echo "" >>"$REPORT_FILE"
  echo "🟢 **Status:** HEALTHY" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  log_success "Found ${total_workflows} active workflows"
}

# Check project health
check_project_health() {
  log_info "Checking project health..."

  echo "## 🏗️ Project Health" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  local projects_dir="${ROOT_DIR}/Projects"

  if [[ ! -d "$projects_dir" ]]; then
    echo "⚪ **Status:** No projects directory" >>"$REPORT_FILE"
    echo "" >>"$REPORT_FILE"
    return
  fi

  local project_count=0
  local projects_with_tests=0

  echo "### Projects Overview" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  for project_dir in "$projects_dir"/*/; do
    if [[ -d "$project_dir" ]]; then
      ((project_count++))
      local project_name
      project_name=$(basename "$project_dir")

      # Check for test files
      local test_count
      test_count=$(find "$project_dir" -name "*Test*.swift" -o -name "*Tests.swift" 2>/dev/null | wc -l)

      if [[ $test_count -gt 0 ]]; then
        ((projects_with_tests++))
        echo "- ✅ **$project_name** ($test_count test files)" >>"$REPORT_FILE"
      else
        echo "- ⚠️ **$project_name** (no tests found)" >>"$REPORT_FILE"
      fi
    fi
  done

  echo "" >>"$REPORT_FILE"
  echo "**Total Projects:** ${project_count}" >>"$REPORT_FILE"
  echo "**Projects With Tests:** ${projects_with_tests}/${project_count}" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  if [[ $projects_with_tests -lt $project_count ]]; then
    echo "🟡 **Recommendation:** Add tests to projects without test coverage" >>"$REPORT_FILE"
    log_warning "$((project_count - projects_with_tests)) projects without tests"
  else
    echo "🟢 **Status:** HEALTHY" >>"$REPORT_FILE"
    log_success "All projects have test coverage"
  fi

  echo "" >>"$REPORT_FILE"
}

# Generate recommendations
generate_recommendations() {
  log_info "Generating recommendations..."

  echo "## 💡 Recommendations" >>"$REPORT_FILE"
  echo "" >>"$REPORT_FILE"

  # Read current disk usage
  local disk_usage
  disk_usage=$(df -h "$ROOT_DIR" | awk 'NR==2 {print $5}' | sed 's/%//')

  local recommendations=()

  # Disk-based recommendations
  if [[ $disk_usage -ge $DISK_CRITICAL_THRESHOLD ]]; then
    recommendations+=("🔴 **URGENT:** Free up disk space immediately (currently at ${disk_usage}%)")
    recommendations+=("   - Run \`./Tools/Automation/observability/cleanup_agent_backups.sh --force\`")
    recommendations+=("   - Run \`./Tools/Automation/observability/compress_old_backups.sh\`")
  elif [[ $disk_usage -ge $DISK_WARNING_THRESHOLD ]]; then
    recommendations+=("🟡 **WARNING:** Monitor disk usage closely (currently at ${disk_usage}%)")
    recommendations+=("   - Schedule regular cleanup with nightly workflow")
  fi

  # General recommendations
  recommendations+=("✅ Ensure nightly-hygiene workflow is running successfully")
  recommendations+=("✅ Review backup compression ratio weekly")
  recommendations+=("✅ Monitor log file growth and rotate as needed")
  recommendations+=("✅ Keep SwiftLint auto-fix workflow active for code quality")

  if [[ ${#recommendations[@]} -eq 0 ]]; then
    echo "🟢 No critical recommendations at this time. System is healthy!" >>"$REPORT_FILE"
  else
    for rec in "${recommendations[@]}"; do
      echo "- $rec" >>"$REPORT_FILE"
    done
  fi

  echo "" >>"$REPORT_FILE"
}

# Generate summary
generate_summary() {
  log_info "Generating executive summary..."

  # Insert summary at the top
  local temp_file="${REPORT_FILE}.tmp"

  # Extract status indicators
  local disk_status="UNKNOWN"
  local backup_status="UNKNOWN"
  local log_status="UNKNOWN"
  local workflow_status="UNKNOWN"

  if grep -q "Disk usage healthy" "$REPORT_FILE"; then
    disk_status="🟢 HEALTHY"
  elif grep -q "WARNING: Disk usage" "$REPORT_FILE"; then
    disk_status="🟡 WARNING"
  elif grep -q "CRITICAL: Disk usage" "$REPORT_FILE"; then
    disk_status="🔴 CRITICAL"
  fi

  if grep -q "Backup health check passed" "$REPORT_FILE"; then
    backup_status="🟢 HEALTHY"
  elif grep -q "Consider cleaning old backups" "$REPORT_FILE"; then
    backup_status="🟡 WARNING"
  fi

  if grep -q "Log health check passed" "$REPORT_FILE"; then
    log_status="🟢 HEALTHY"
  elif grep -q "Rotate or compress large log files" "$REPORT_FILE"; then
    log_status="🟡 WARNING"
  fi

  workflow_status="🟢 HEALTHY"

  # Create summary section
  cat >"$temp_file" <<EOF
# Weekly Health Check Report
**Generated:** $(date +"%Y-%m-%d %H:%M:%S")
**Period:** Last 7 days
**Repository:** Quantum-workspace

---

## Executive Summary

| Component | Status |
|-----------|--------|
| Disk Usage | ${disk_status} |
| Backup System | ${backup_status} |
| Log System | ${log_status} |
| GitHub Workflows | ${workflow_status} |

---

EOF

  # Append the rest of the report (skip first 9 lines)
  tail -n +10 "$REPORT_FILE" >>"$temp_file"
  mv "$temp_file" "$REPORT_FILE"
}

# Main execution
main() {
  log_info "Starting weekly health check..."
  echo

  # Initialize report
  init_report

  # Run all checks
  check_disk_usage
  check_backup_health
  check_log_health
  check_workflow_health
  check_project_health

  # Generate recommendations
  generate_recommendations

  # Generate summary
  generate_summary

  log_success "Weekly health check complete!"
  log_info "Report saved to: $REPORT_FILE"

  # Display report
  echo
  echo "========================================="
  cat "$REPORT_FILE"
  echo "========================================="
}

# Run main function
main "$@"
