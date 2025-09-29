#!/bin/bash

# CI/CD Monitoring Dashboard
# Comprehensive monitoring system for GitHub Actions workflows

set -e

# Configuration
CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
MONITORING_DIR="${CODE_DIR}/Tools/Monitoring"
REPORTS_DIR="${MONITORING_DIR}/reports"
ALERTS_DIR="${MONITORING_DIR}/alerts"
DASHBOARD_FILE="${MONITORING_DIR}/dashboard.html"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Create monitoring directories
mkdir -p "${REPORTS_DIR}"
mkdir -p "${ALERTS_DIR}"

print_header() {
  echo -e "\n${BLUE}================================================${NC}"
  echo -e "${BLUE} 📊 CI/CD MONITORING DASHBOARD${NC}"
  echo -e "${BLUE}================================================${NC}\n"
}

print_status() {
  echo -e "${BLUE}[MONITOR]${NC} $1"
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

# Check GitHub CLI availability
check_github_cli() {
  if ! command -v gh >/dev/null 2>&1; then
    print_error "GitHub CLI (gh) not found. Please install it first."
    return 1
  fi

  if ! gh auth status >/dev/null 2>&1; then
    print_error "GitHub CLI not authenticated. Please run 'gh auth login' first."
    return 1
  fi

  return 0
}

# Get workflow status
get_workflow_status() {
  local report_file
  report_file="${REPORTS_DIR}/workflow_status_$(date +%Y%m%d_%H%M%S).json"

  print_status "Fetching workflow status..."

  # Get workflow list with status
  if gh workflow list --json name,state,id >"${report_file}"; then
    print_success "Workflow status retrieved successfully"
    echo "${report_file}"
  else
    print_error "Failed to retrieve workflow status"
    return 1
  fi
}

# Get recent workflow runs
get_recent_runs() {
  local limit
  limit="${1:-20}"
  local report_file
  report_file="${REPORTS_DIR}/recent_runs_$(date +%Y%m%d_%H%M%S).json"

  print_status "Fetching recent workflow runs (last ${limit})..."

  # Get recent runs with detailed information
  if gh run list --limit "${limit}" --json status,conclusion,workflowName,createdAt,updatedAt,headSha >"${report_file}"; then
    print_success "Recent runs retrieved successfully"
    echo "${report_file}"
  else
    print_error "Failed to retrieve recent runs"
    return 1
  fi
}

# Analyze workflow health
analyze_workflow_health() {
  local status_file
  status_file="$1"
  local runs_file
  runs_file="$2"
  local analysis_file
  analysis_file="${REPORTS_DIR}/health_analysis_$(date +%Y%m%d_%H%M%S).md"

  print_status "Analyzing workflow health..."

  {
    echo "# CI/CD Health Analysis Report"
    echo ""
    echo "Generated: $(date)"
    echo ""

    # Workflow Status Summary
    echo "## Workflow Status Summary"
    echo ""
    if [[ -f ${status_file} ]]; then
      local active_count=0
      local total_count=0

      # Simple parsing of JSON
      while IFS= read -r line; do
        if [[ ${line} == *"\"state\": \"active\""* ]]; then
          ((active_count++))
        fi
        if [[ ${line} == *"\"name\":"* ]]; then
          ((total_count++))
        fi
      done <"${status_file}"

      echo "- **Total Workflows**: ${total_count}"
      echo "- **Active Workflows**: ${active_count}"
      echo "- **Inactive Workflows**: $((total_count - active_count))"
      echo ""
    fi

    # Recent Runs Analysis
    echo "## Recent Runs Analysis"
    echo ""
    if [[ -f ${runs_file} ]]; then
      local success_count=0
      local failure_count=0
      local total_runs=0

      # Simple parsing of JSON
      while IFS= read -r line; do
        if [[ ${line} == *"\"conclusion\":"* ]]; then
          ((total_runs++))
          if [[ ${line} == *"\"success\""* ]]; then
            ((success_count++))
          elif [[ ${line} == *"\"failure\""* ]]; then
            ((failure_count++))
          fi
        fi
      done <"${runs_file}"

      echo "- **Total Recent Runs**: ${total_runs}"
      echo "- **Successful Runs**: ${success_count}"
      echo "- **Failed Runs**: ${failure_count}"
      echo ""

      if [[ ${total_runs} -gt 0 ]]; then
        local success_rate=$((success_count * 100 / total_runs))
        echo "- **Success Rate**: ${success_rate}%"
        echo ""

        # Success rate alerts
        if [[ ${success_rate} -lt 80 ]]; then
          echo "⚠️  **WARNING**: Low success rate (${success_rate}%)"
          echo ""
        fi
      fi
    fi

    # Recommendations
    echo "## Recommendations"
    echo ""
    echo "### Immediate Actions"
    echo ""
    echo "- 📊 **Monitor Success Rate**: Maintain >90% success rate for all workflows"
    echo "- ⚡ **Optimize Performance**: Keep average run times under 15 minutes"
    echo ""

    echo "### Maintenance Schedule"
    echo ""
    echo "- **Daily**: Check for failed workflows and resolve issues"
    echo "- **Weekly**: Review performance metrics and optimize slow workflows"
    echo "- **Monthly**: Audit workflow configurations and update dependencies"
    echo ""

  } >"${analysis_file}"

  print_success "Health analysis completed: ${analysis_file}"
  echo "${analysis_file}"
}

# Generate alerts
generate_alerts() {
  local status_file
  status_file="$1"
  local runs_file
  runs_file="$2"
  local alert_file
  alert_file="${ALERTS_DIR}/alerts_$(date +%Y%m%d_%H%M%S).md"

  print_status "Checking for alerts..."

  local alerts_found=0

  {
    echo "# CI/CD Alerts Report"
    echo ""
    echo "Generated: $(date)"
    echo ""

    # Check for inactive workflows
    if [[ -f ${status_file} ]]; then
      local inactive_found=false
      while IFS= read -r line; do
        if [[ ${line} == *"\"state\":"* ]] && [[ ${line} != *"\"active\""* ]]; then
          if [[ ${inactive_found} == false ]]; then
            echo "## 🚨 CRITICAL: Inactive Workflows"
            echo ""
            inactive_found=true
            alerts_found=$((alerts_found + 1))
          fi
          # Extract workflow name from previous lines
          echo "- Workflow is inactive"
        fi
      done <"${status_file}"
      if [[ ${inactive_found} == true ]]; then
        echo ""
      fi
    fi

    # Check for recent failures
    if [[ -f ${runs_file} ]]; then
      local failure_found=false
      while IFS= read -r line; do
        if [[ ${line} == *"\"conclusion\": \"failure\""* ]]; then
          if [[ ${failure_found} == false ]]; then
            echo "## ⚠️  WARNING: Recent Failures"
            echo ""
            failure_found=true
            alerts_found=$((alerts_found + 1))
          fi
          echo "- Workflow failed recently"
        fi
      done <"${runs_file}"
      if [[ ${failure_found} == true ]]; then
        echo ""
      fi
    fi

    if [[ ${alerts_found} -eq 0 ]]; then
      echo "## ✅ All Clear"
      echo ""
      echo "No critical alerts at this time."
      echo ""
    fi

  } >"${alert_file}"

  if [[ ${alerts_found} -gt 0 ]]; then
    print_warning "Found ${alerts_found} alerts - check ${alert_file}"
  else
    print_success "No alerts found"
  fi

  echo "${alert_file}"
}

# Generate HTML dashboard
generate_html_dashboard() {
  local status_file="$1"
  local runs_file="$2"
  local analysis_file="$3"
  local alerts_file="$4"

  print_status "Generating HTML dashboard..."

  # Simple metrics extraction
  local total_workflows=0
  local active_workflows=0
  local success_rate=0

  if [[ -f ${status_file} ]]; then
    while IFS= read -r line; do
      if [[ ${line} == *"\"name\":"* ]]; then
        ((total_workflows++))
      fi
      if [[ ${line} == *"\"state\": \"active\""* ]]; then
        ((active_workflows++))
      fi
    done <"${status_file}"
  fi

  if [[ -f ${runs_file} ]]; then
    local success_count=0
    local total_runs=0
    while IFS= read -r line; do
      if [[ ${line} == *"\"conclusion\":"* ]]; then
        ((total_runs++))
        if [[ ${line} == *"\"success\""* ]]; then
          ((success_count++))
        fi
      fi
    done <"${runs_file}"

    if [[ ${total_runs} -gt 0 ]]; then
      success_rate=$((success_count * 100 / total_runs))
    fi
  fi

  {
    echo "<!DOCTYPE html>"
    echo "<html lang='en'>"
    echo "<head>"
    echo "    <meta charset='UTF-8'>"
    echo "    <meta name='viewport' content='width=device-width, initial-scale=1.0'>"
    echo "    <title>CI/CD Monitoring Dashboard</title>"
    echo "    <style>"
    echo "        body { font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; margin: 0; padding: 20px; background: #f5f5f5; }"
    echo "        .container { max-width: 1200px; margin: 0 auto; background: white; border-radius: 8px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); overflow: hidden; }"
    echo "        .header { background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); color: white; padding: 30px; text-align: center; }"
    echo "        .header h1 { margin: 0; font-size: 2.5em; }"
    echo "        .header p { margin: 10px 0 0 0; opacity: 0.9; }"
    echo "        .content { padding: 30px; }"
    echo "        .metric-grid { display: grid; grid-template-columns: repeat(auto-fit, minmax(250px, 1fr)); gap: 20px; margin-bottom: 30px; }"
    echo "        .metric-card { background: #f8f9fa; border-radius: 8px; padding: 20px; border-left: 4px solid #667eea; }"
    echo "        .metric-card.success { border-left-color: #28a745; }"
    echo "        .metric-card.warning { border-left-color: #ffc107; }"
    echo "        .metric-card.error { border-left-color: #dc3545; }"
    echo "        .metric-card h3 { margin: 0 0 10px 0; color: #333; }"
    echo "        .metric-card .value { font-size: 2em; font-weight: bold; color: #667eea; }"
    echo "        .metric-card.success .value { color: #28a745; }"
    echo "        .metric-card.warning .value { color: #ffc107; }"
    echo "        .metric-card.error .value { color: #dc3545; }"
    echo "        .alerts { margin-top: 30px; }"
    echo "        .alert { padding: 15px; border-radius: 6px; margin-bottom: 10px; }"
    echo "        .alert.critical { background: #f8d7da; border-left: 4px solid #dc3545; color: #721c24; }"
    echo "        .alert.warning { background: #fff3cd; border-left: 4px solid #ffc107; color: #856404; }"
    echo "        .alert.info { background: #d1ecf1; border-left: 4px solid #17a2b8; color: #0c5460; }"
    echo "        .footer { background: #f8f9fa; padding: 20px; text-align: center; color: #666; border-top: 1px solid #dee2e6; }"
    echo "        .timestamp { color: #999; font-size: 0.9em; }"
    echo "    </style>"
    echo "</head>"
    echo "<body>"
    echo "    <div class='container'>"
    echo "        <div class='header'>"
    echo "            <h1>🚀 CI/CD Monitoring Dashboard</h1>"
    echo "            <p>Real-time workflow monitoring and health analysis</p>"
    echo "            <div class='timestamp'>Last updated: $(date)</div>"
    echo "        </div>"
    echo "        <div class='content'>"

    # Add metrics
    echo "            <div class='metric-grid'>"

    echo "                <div class='metric-card'>"
    echo "                    <h3>Total Workflows</h3>"
    echo "                    <div class='value'>${total_workflows}</div>"
    echo "                </div>"

    echo "                <div class='metric-card success'>"
    echo "                    <h3>Active Workflows</h3>"
    echo "                    <div class='value'>${active_workflows}</div>"
    echo "                </div>"

    local rate_class="success"
    if [[ ${success_rate} -lt 80 ]]; then
      rate_class="error"
    fi
    echo "                <div class='metric-card ${rate_class}'>"
    echo "                    <h3>Success Rate</h3>"
    echo "                    <div class='value'>${success_rate}%</div>"
    echo "                </div>"

    echo "            </div>"

    # Add alerts section
    if [[ -f ${alerts_file} ]]; then
      echo "            <div class='alerts'>"
      echo "                <h2>📢 System Status</h2>"

      # Check if there are any alerts
      if grep -q "CRITICAL\|WARNING" "${alerts_file}"; then
        echo "                <div class='alert warning'>"
        echo "                    <strong>⚠️  System Needs Attention:</strong> Check alerts file for details."
        echo "                </div>"
      else
        echo "                <div class='alert info'>"
        echo "                    <strong>✅ All Clear:</strong> No critical alerts at this time."
        echo "                </div>"
      fi

      echo "            </div>"
    fi

    echo "        </div>"
    echo "        <div class='footer'>"
    echo "            <p>Generated by CI/CD Monitoring System | <a href='${analysis_file}'>View Full Report</a></p>"
    echo "        </div>"
    echo "    </div>"
    echo "</body>"
    echo "</html>"
  } >"${DASHBOARD_FILE}"

  print_success "HTML dashboard generated: ${DASHBOARD_FILE}"
}

# Main monitoring function
run_monitoring() {
  print_header

  # Check prerequisites
  if ! check_github_cli; then
    return 1
  fi

  # Get workflow data
  local status_file
  status_file=$(get_workflow_status)
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  local runs_file
  runs_file=$(get_recent_runs 50)
  if [[ $? -ne 0 ]]; then
    return 1
  fi

  # Analyze health
  local analysis_file
  analysis_file=$(analyze_workflow_health "${status_file}" "${runs_file}")

  # Generate alerts
  local alerts_file
  alerts_file=$(generate_alerts "${status_file}" "${runs_file}")

  # Generate HTML dashboard
  generate_html_dashboard "${status_file}" "${runs_file}" "${analysis_file}" "${alerts_file}"

  print_success "Monitoring complete! 📊"
  echo ""
  echo "📁 Reports generated in: ${REPORTS_DIR}"
  echo "🚨 Alerts: ${alerts_file}"
  echo "📊 Dashboard: ${DASHBOARD_FILE}"
  echo ""
  echo "💡 Quick Actions:"
  echo "   • Open dashboard: open ${DASHBOARD_FILE}"
  echo "   • View alerts: cat ${alerts_file}"
  echo "   • Full analysis: cat ${analysis_file}"
}

# Show help
show_help() {
  echo "Usage: $0 [OPTIONS]"
  echo ""
  echo "CI/CD Monitoring Dashboard for GitHub Actions"
  echo ""
  echo "Options:"
  echo "  -h, --help     Show this help message"
  echo "  -w, --web      Generate and open HTML dashboard"
  echo "  -a, --alerts   Show current alerts only"
  echo "  -s, --status   Show workflow status only"
  echo ""
  echo "Examples:"
  echo "  $0                    # Run full monitoring suite"
  echo "  $0 --web             # Generate and open dashboard"
  echo "  $0 --alerts          # Show alerts only"
}

# Main script logic
main() {
  case "${1-}" in
  -h | --help)
    show_help
    exit 0
    ;;
  -w | --web)
    run_monitoring
    if [[ -f ${DASHBOARD_FILE} ]]; then
      open "${DASHBOARD_FILE}" 2>/dev/null || xdg-open "${DASHBOARD_FILE}" 2>/dev/null || echo "Please open: ${DASHBOARD_FILE}"
    fi
    ;;
  -a | --alerts)
    if check_github_cli; then
      local status_file
      status_file=$(get_workflow_status)
      local runs_file
      runs_file=$(get_recent_runs 20)
      generate_alerts "${status_file}" "${runs_file}" >/dev/null
    fi
    ;;
  -s | --status)
    if check_github_cli; then
      get_workflow_status >/dev/null
    fi
    ;;
  "")
    run_monitoring
    ;;
  *)
    print_error "Unknown option: $1"
    show_help
    exit 1
    ;;
  esac
}

# Run main function with all arguments
main "$@"
