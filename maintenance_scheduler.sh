#!/bin/bash

# Maintenance Scheduler for CI/CD Workflows
# Automated maintenance and cleanup procedures

set -e

# Configuration
CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MAINTENANCE_DIR="${CODE_DIR}/Tools/Maintenance"
SCHEDULES_DIR="${MAINTENANCE_DIR}/schedules"
BACKUP_DIR="${MAINTENANCE_DIR}/backups"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Create directories
mkdir -p "${SCHEDULES_DIR}"
mkdir -p "${BACKUP_DIR}"

print_header() {
  echo -e "\n${BLUE}================================================${NC}"
  echo -e "${BLUE} 🔧 MAINTENANCE SCHEDULER${NC}"
  echo -e "${BLUE}================================================${NC}\n"
}

print_status() {
  echo -e "${BLUE}[MAINTENANCE]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Create maintenance schedule
create_maintenance_schedule() {
  local schedule_file="${SCHEDULES_DIR}/maintenance_schedule_$(date +%Y%m%d).md"

  print_status "Creating maintenance schedule..."

  {
    echo "# CI/CD Maintenance Schedule"
    echo ""
    echo "Generated: $(date)"
    echo ""
    echo "## Daily Maintenance (Automated)"
    echo ""
    echo "### Morning Check (8:00 AM)"
    echo "- ✅ Run CI/CD monitoring: $(bash Tools/Automation/simple_monitoring.sh)"
    echo "- ✅ Check for failed workflows"
    echo "- ✅ Review alert notifications"
    echo "- ✅ Validate workflow configurations"
    echo ""
    echo "### Midday Check (12:00 PM)"
    echo "- ✅ Monitor workflow performance"
    echo "- ✅ Check for long-running workflows"
    echo "- ✅ Review success rates"
    echo ""
    echo "### Evening Check (6:00 PM)"
    echo "- ✅ Generate daily health report"
    echo "- ✅ Archive old log files"
    echo "- ✅ Update monitoring dashboards"
    echo ""
    echo "## Weekly Maintenance (Manual Review)"
    echo ""
    echo "### Monday (Start of Week)"
    echo "- 🔍 **Code Review**: Review recent workflow changes"
    echo "- 📊 **Performance Analysis**: Analyze weekly metrics"
    echo "- 🧪 **Testing**: Run comprehensive workflow tests"
    echo ""
    echo "### Wednesday (Mid-Week)"
    echo "- 🔧 **Optimization**: Optimize slow workflows"
    echo "- 📋 **Documentation**: Update workflow documentation"
    echo "- 🔄 **Dependencies**: Check for dependency updates"
    echo ""
    echo "### Friday (End of Week)"
    echo "- 📈 **Reporting**: Generate weekly summary report"
    echo "- 🗂️ **Cleanup**: Archive old workflow runs"
    echo "- 🎯 **Planning**: Plan next week's maintenance"
    echo ""
    echo "## Monthly Maintenance (Comprehensive)"
    echo ""
    echo "### First Monday of Month"
    echo "- 🏗️ **Architecture Review**: Review workflow architecture"
    echo "- 🔒 **Security Audit**: Audit workflow security"
    echo "- 📚 **Documentation**: Update all documentation"
    echo ""
    echo "### Third Monday of Month"
    echo "- 🚀 **Performance Tuning**: Comprehensive optimization"
    echo "- 🧪 **Load Testing**: Test workflow capacity"
    echo "- 📊 **Analytics**: Generate monthly analytics"
    echo ""
    echo "## Emergency Maintenance"
    echo ""
    echo "### Critical Failure Response"
    echo "1. **Immediate Assessment**: Identify failure scope"
    echo "2. **Containment**: Disable failing workflows"
    echo "3. **Investigation**: Analyze root cause"
    echo "4. **Fix Deployment**: Deploy fixes"
    echo "5. **Testing**: Validate fixes"
    echo "6. **Monitoring**: Monitor for recurrence"
    echo ""
    echo "### Recovery Procedures"
    echo "- Restore from backup if needed"
    echo "- Re-enable workflows gradually"
    echo "- Validate all systems"
    echo "- Update incident documentation"
    echo ""
    echo "## Automation Commands"
    echo ""
    echo "### Quick Checks"
    echo '```bash'
    echo "# Daily health check"
    echo "bash Tools/Automation/simple_monitoring.sh"
    echo ""
    echo "# Validate all workflows"
    echo "bash Tools/Automation/deploy_workflows_all_projects.sh --validate"
    echo ""
    echo "# Check syntax"
    echo "bash -n Tools/Automation/master_automation.sh"
    echo '```'
    echo ""
    echo "### Maintenance Scripts"
    echo '```bash'
    echo "# Run full automation suite"
    echo "bash Tools/Automation/master_automation.sh all"
    echo ""
    echo "# Generate performance report"
    echo "bash Tools/Automation/master_automation.sh performance"
    echo ""
    echo "# Security validation"
    echo "bash Tools/Automation/master_automation.sh security"
    echo '```'
    echo ""
    echo "## Monitoring Integration"
    echo ""
    echo "### Automated Alerts"
    echo "- Email notifications for failures"
    echo "- Slack notifications for critical issues"
    echo "- Dashboard updates every 15 minutes"
    echo ""
    echo "### Health Metrics"
    echo "- Success rate > 90%"
    echo "- Average run time < 15 minutes"
    echo "- Zero critical failures"
    echo "- All workflows active"
    echo ""

  } >"${schedule_file}"

  print_success "Maintenance schedule created: ${schedule_file}"
  echo "${schedule_file}"
}

# Execute incremental cleanup
execute_incremental_cleanup() {
  print_status "Executing incremental cleanup..."

  # Create cleanup report
  local cleanup_report
  cleanup_report="${SCHEDULES_DIR}/cleanup_report_$(date +%Y%m%d_%H%M%S).md"

  {
    echo "# Incremental Cleanup Report"
    echo ""
    echo "Generated: $(date)"
    echo ""
    echo "## Cleanup Actions Performed"
    echo ""

    # Clean old log files
    echo "### Log File Cleanup"
    local old_logs=$(find "${CODE_DIR}/Tools" -name "*.log" -mtime +30 2>/dev/null | wc -l)
    if [[ ${old_logs} -gt 0 ]]; then
      echo "- 🗂️ **Archived ${old_logs} old log files** (>30 days)"
      # Archive old logs
      mkdir -p "${BACKUP_DIR}/logs_$(date +%Y%m%d)"
      find "${CODE_DIR}/Tools" -name "*.log" -mtime +30 -exec mv {} "${BACKUP_DIR}/logs_$(date +%Y%m%d)/" \; 2>/dev/null || true
    else
      echo "- ✅ No old log files to archive"
    fi
    echo ""

    # Clean temporary files
    echo "### Temporary File Cleanup"
    local temp_files=$(find /tmp -name "workflow_*" -o -name "recent_*" 2>/dev/null | wc -l)
    if [[ ${temp_files} -gt 0 ]]; then
      echo "- 🧹 **Cleaned ${temp_files} temporary monitoring files**"
      rm -f /tmp/workflow_* /tmp/recent_* 2>/dev/null || true
    else
      echo "- ✅ No temporary files to clean"
    fi
    echo ""

    # Validate workflow configurations
    echo "### Workflow Validation"
    if command -v gh >/dev/null 2>&1; then
      local invalid_workflows=0
      # Check for any workflow issues
      if gh workflow list --json state | grep -q "disabled_manually"; then
        invalid_workflows=$(gh workflow list --json state | grep -c "disabled_manually")
        echo "- ⚠️ **Found ${invalid_workflows} disabled workflows**"
      else
        echo "- ✅ All workflows are active"
      fi
    else
      echo "- ⚠️ GitHub CLI not available for validation"
    fi
    echo ""

    # Check disk usage
    echo "### Disk Usage Check"
    local disk_usage=$(du -sh "${CODE_DIR}/Tools" 2>/dev/null | cut -f1)
    echo "- 📊 **Tools directory size**: ${disk_usage}"
    echo ""

    # Generate recommendations
    echo "## Cleanup Recommendations"
    echo ""
    echo "### Immediate Actions"
    echo "- Monitor disk usage weekly"
    echo "- Review archived logs monthly"
    echo "- Validate workflows after changes"
    echo ""
    echo "### Optimization Opportunities"
    echo "- Consider log rotation for high-volume logs"
    echo "- Archive old workflow run data"
    echo "- Review and optimize large files"
    echo ""

  } >"${cleanup_report}"

  print_success "Incremental cleanup completed: ${cleanup_report}"
  echo "${cleanup_report}"
}

# Generate disaster recovery procedures
generate_disaster_recovery() {
  local recovery_file="${SCHEDULES_DIR}/disaster_recovery_$(date +%Y%m%d).md"

  print_status "Generating disaster recovery procedures..."

  {
    echo "# Disaster Recovery Procedures"
    echo ""
    echo "Generated: $(date)"
    echo ""
    echo "## Emergency Response Protocol"
    echo ""
    echo "### Phase 1: Assessment (0-15 minutes)"
    echo ""
    echo "1. **Identify Failure Scope**"
    echo "   - Check monitoring dashboard"
    echo "   - Identify affected workflows"
    echo "   - Assess impact on CI/CD pipeline"
    echo ""
    echo "2. **Initial Containment**"
    echo "   - Disable failing workflows"
    echo "   - Notify development team"
    echo "   - Start incident documentation"
    echo ""
    echo "### Phase 2: Recovery (15-60 minutes)"
    echo ""
    echo "1. **Data Backup Verification**"
    echo "   - Verify recent backups exist"
    echo "   - Check backup integrity"
    echo "   - Prepare recovery environment"
    echo ""
    echo "2. **System Recovery**"
    echo "   - Restore from last known good state"
    echo "   - Re-enable workflows gradually"
    echo "   - Validate recovery success"
    echo ""
    echo "### Phase 3: Validation (60+ minutes)"
    echo ""
    echo "1. **Comprehensive Testing**"
    echo "   - Run full test suite"
    echo "   - Validate all workflows"
    echo "   - Check integration points"
    echo ""
    echo "2. **Performance Verification**"
    echo "   - Monitor system performance"
    echo "   - Check success rates"
    echo "   - Validate user workflows"
    echo ""
    echo "## Recovery Commands"
    echo ""
    echo "### Quick Recovery"
    echo '```bash'
    echo "# Emergency workflow disable"
    echo "gh workflow disable <workflow-name>"
    echo ""
    echo "# Check system status"
    echo "bash Tools/Automation/simple_monitoring.sh"
    echo ""
    echo "# Validate recovery"
    echo "bash Tools/Automation/deploy_workflows_all_projects.sh --validate"
    echo '```'
    echo ""
    echo "### Full System Recovery"
    echo '```bash'
    echo "# Restore from backup"
    echo "git checkout <backup-branch>"
    echo "git push origin main --force"
    echo ""
    echo "# Re-enable all workflows"
    echo "gh workflow enable --all"
    echo ""
    echo "# Full system validation"
    echo "bash Tools/Automation/master_automation.sh all"
    echo '```'
    echo ""
    echo "## Backup Strategy"
    echo ""
    echo "### Automated Backups"
    echo "- **Daily**: Workflow configurations"
    echo "- **Weekly**: Complete repository backup"
    echo "- **Monthly**: Full system snapshot"
    echo ""
    echo "### Manual Backups"
    echo "- Before major changes"
    echo "- After successful deployments"
    echo "- When testing new features"
    echo ""
    echo "### Backup Locations"
    echo "- Local: \`${BACKUP_DIR}\`"
    echo "- Remote: GitHub repository branches"
    echo "- Offsite: Encrypted archives"
    echo ""
    echo "## Prevention Measures"
    echo ""
    echo "### Proactive Monitoring"
    echo "- Real-time alert system"
    echo "- Performance monitoring"
    echo "- Automated health checks"
    echo ""
    echo "### Risk Mitigation"
    echo "- Regular backup validation"
    echo "- Staged deployment process"
    echo "- Comprehensive testing"
    echo ""
    echo "## Contact Information"
    echo ""
    echo "### Emergency Contacts"
    echo "- **Primary**: Development Team Lead"
    echo "- **Secondary**: DevOps Engineer"
    echo "- **Tertiary**: Repository Administrator"
    echo ""
    echo "### External Resources"
    echo "- GitHub Status: https://www.githubstatus.com/"
    echo "- Documentation: \`${SCHEDULES_DIR}\`"
    echo "- Monitoring: Tools/Monitoring/"
    echo ""

  } >"${recovery_file}"

  print_success "Disaster recovery procedures generated: ${recovery_file}"
  echo "${recovery_file}"
}

# Run automated maintenance
run_automated_maintenance() {
  print_status "Running automated maintenance..."

  # Run monitoring
  if [[ -f "${CODE_DIR}/Tools/Automation/simple_monitoring.sh" ]]; then
    print_status "Running CI/CD monitoring..."
    bash "${CODE_DIR}/Tools/Automation/simple_monitoring.sh" >/dev/null 2>&1
  fi

  # Validate workflows
  if [[ -f "${CODE_DIR}/Tools/Automation/deploy_workflows_all_projects.sh" ]]; then
    print_status "Validating workflow configurations..."
    bash "${CODE_DIR}/Tools/Automation/deploy_workflows_all_projects.sh" --validate >/dev/null 2>&1
  fi

  # Clean temporary files
  print_status "Cleaning temporary files..."
  rm -f /tmp/workflow_* /tmp/recent_* 2>/dev/null || true

  # Archive old logs
  print_status "Archiving old logs..."
  mkdir -p "${BACKUP_DIR}/logs_$(date +%Y%m%d)"
  find "${CODE_DIR}/Tools" -name "*.log" -mtime +7 -exec mv {} "${BACKUP_DIR}/logs_$(date +%Y%m%d)/" \; 2>/dev/null || true

  print_success "Automated maintenance completed"
}

# Show help
show_help() {
  echo "Usage: $0 [COMMAND]"
  echo ""
  echo "CI/CD Maintenance Scheduler"
  echo ""
  echo "Commands:"
  echo "  schedule     # Create maintenance schedule"
  echo "  cleanup      # Execute incremental cleanup"
  echo "  recovery     # Generate disaster recovery procedures"
  echo "  auto         # Run automated maintenance"
  echo "  all          # Run all maintenance tasks"
  echo "  help         # Show this help"
  echo ""
  echo "Examples:"
  echo "  $0 schedule  # Create maintenance schedule"
  echo "  $0 all       # Run complete maintenance suite"
}

# Main
main() {
  case "${1-}" in
  schedule)
    create_maintenance_schedule
    ;;
  cleanup)
    execute_incremental_cleanup
    ;;
  recovery)
    generate_disaster_recovery
    ;;
  auto)
    run_automated_maintenance
    ;;
  all)
    print_header
    create_maintenance_schedule
    execute_incremental_cleanup
    generate_disaster_recovery
    run_automated_maintenance
    ;;
  help | -h | --help)
    show_help
    ;;
  "")
    print_header
    show_help
    ;;
  *)
    print_error "Unknown command: $1"
    show_help
    exit 1
    ;;
  esac
}

main "$@"
