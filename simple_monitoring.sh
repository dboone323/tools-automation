#!/bin/bash

# CI/CD Monitoring System
# Simple monitoring for GitHub Actions workflows

set -e

# Configuration
CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
REPORTS_DIR="${CODE_DIR}/Tools/Monitoring/reports"
ALERTS_DIR="${CODE_DIR}/Tools/Monitoring/alerts"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

# Create directories
mkdir -p "${REPORTS_DIR}"
mkdir -p "${ALERTS_DIR}"

print_header() {
	echo -e "\n${BLUE}================================================${NC}"
	echo -e "${BLUE} 📊 CI/CD MONITORING SYSTEM${NC}"
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

# Check GitHub CLI
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
	print_status "Fetching workflow status..." >&2

	local temp_file
	temp_file=$(mktemp)

	if gh workflow list --json name,state --repo dboone323/Quantum-workspace >"${temp_file}"; then
		print_success "Workflow status retrieved" >&2
		echo "${temp_file}"
		return 0
	else
		print_error "Failed to retrieve workflow status" >&2
		rm -f "${temp_file}"
		return 1
	fi
}

# Get recent runs
get_recent_runs() {
	local limit="${1:-20}"
	print_status "Fetching recent workflow runs (last ${limit})..." >&2

	local temp_file
	temp_file=$(mktemp)

	if gh run list --limit "${limit}" --json conclusion --repo dboone323/Quantum-workspace >"${temp_file}"; then
		print_success "Recent runs retrieved" >&2
		echo "${temp_file}"
		return 0
	else
		print_error "Failed to retrieve recent runs" >&2
		rm -f "${temp_file}"
		return 1
	fi
}

# Analyze health
analyze_health() {
	local status_file="$1"
	local runs_file="$2"
	local report_file="${REPORTS_DIR}/health_report_$(date +%Y%m%d_%H%M%S).md"

	print_status "Analyzing workflow health..."

	# Check if files exist
	if [[ ! -f ${status_file} ]]; then
		print_error "Status file not found: ${status_file}"
		return 1
	fi

	if [[ ! -f ${runs_file} ]]; then
		print_error "Runs file not found: ${runs_file}"
		return 1
	fi

	# Parse the JSON data with fallback methods
	local total_workflows=0
	local active_workflows=0
	local success_runs=0
	local failure_runs=0
	local action_required=0

	# Try jq first, fallback to grep
	if command -v jq >/dev/null 2>&1; then
		total_workflows=$(jq '. | length' "${status_file}" 2>/dev/null || echo "0")
		active_workflows=$(jq '[.[] | select(.state == "active")] | length' "${status_file}" 2>/dev/null || echo "0")
		success_runs=$(jq '[.[] | select(.conclusion == "success")] | length' "${runs_file}" 2>/dev/null || echo "0")
		failure_runs=$(jq '[.[] | select(.conclusion == "failure")] | length' "${runs_file}" 2>/dev/null || echo "0")
		action_required=$(jq '[.[] | select(.conclusion == "action_required")] | length' "${runs_file}" 2>/dev/null || echo "0")
	else
		# Fallback to grep-based parsing
		total_workflows=$(grep -c '"name"' "${status_file}" 2>/dev/null || echo "0")
		active_workflows=$(grep -c '"state":"active"' "${status_file}" 2>/dev/null || echo "0")
		success_runs=$(grep -c '"conclusion":"success"' "${runs_file}" 2>/dev/null || echo "0")
		failure_runs=$(grep -c '"conclusion":"failure"' "${runs_file}" 2>/dev/null || echo "0")
		action_required=$(grep -c '"conclusion":"action_required"' "${runs_file}" 2>/dev/null || echo "0")
	fi

	local total_runs=$((success_runs + failure_runs + action_required))

	local success_rate=0
	if [[ ${total_runs} -gt 0 ]]; then
		success_rate=$((success_runs * 100 / total_runs))
	fi

	{
		echo "# CI/CD Health Report"
		echo ""
		echo "Generated: $(date)"
		echo ""
		echo "## Summary"
		echo ""
		echo "- **Total Workflows**: ${total_workflows}"
		echo "- **Active Workflows**: ${active_workflows}"
		echo "- **Recent Runs Analyzed**: ${total_runs}"
		echo "- **Successful Runs**: ${success_runs}"
		echo "- **Failed Runs**: ${failure_runs}"
		echo "- **Action Required**: ${action_required}"
		echo "- **Success Rate**: ${success_rate}%"
		echo ""

		if [[ ${success_rate} -lt 90 ]]; then
			echo "⚠️  **WARNING**: Success rate below 90%"
			echo ""
		fi

		if [[ ${failure_runs} -gt 0 ]]; then
			echo "🚨 **ALERT**: ${failure_runs} recent workflow failures detected"
			echo ""
		fi

		if [[ ${action_required} -gt 0 ]]; then
			echo "⚠️  **NOTICE**: ${action_required} runs require manual action"
			echo ""
		fi

		echo "## Recommendations"
		echo ""
		if [[ ${failure_runs} -gt 0 ]]; then
			echo "- 🔧 **Investigate Failures**: Check the ${failure_runs} failed workflow runs"
		fi
		if [[ ${action_required} -gt 0 ]]; then
			echo "- 📋 **Review Actions**: Address ${action_required} runs requiring manual action"
		fi
		echo "- 📊 **Monitor Daily**: Check workflow status regularly"
		echo "- 🎯 **Maintain Quality**: Keep success rate above 90%"
		echo ""

	} >"${report_file}"

	print_success "Health analysis complete: ${report_file}"
	echo "${report_file}"
}

# Generate alerts
generate_alerts() {
	local status_file="$1"
	local runs_file="$2"
	local alert_file="${ALERTS_DIR}/alerts_$(date +%Y%m%d_%H%M%S).md"

	print_status "Checking for alerts..."

	# Check if files exist
	if [[ ! -f ${status_file} ]]; then
		print_error "Status file not found: ${status_file}"
		return 1
	fi

	if [[ ! -f ${runs_file} ]]; then
		print_error "Runs file not found: ${runs_file}"
		return 1
	fi

	local alerts_found=0

	# Parse alert conditions with fallback methods
	local failure_count=0
	local action_required=0
	local inactive_count=0

	# Try jq first, fallback to grep
	if command -v jq >/dev/null 2>&1; then
		failure_count=$(jq '[.[] | select(.conclusion == "failure")] | length' "${runs_file}" 2>/dev/null || echo "0")
		action_required=$(jq '[.[] | select(.conclusion == "action_required")] | length' "${runs_file}" 2>/dev/null || echo "0")
		inactive_count=$(jq '[.[] | select(.state == "disabled_manually")] | length' "${status_file}" 2>/dev/null || echo "0")
	else
		# Fallback to grep-based parsing
		failure_count=$(grep -c '"conclusion":"failure"' "${runs_file}" 2>/dev/null || echo "0")
		action_required=$(grep -c '"conclusion":"action_required"' "${runs_file}" 2>/dev/null || echo "0")
		inactive_count=$(grep -c '"state":"disabled_manually"' "${status_file}" 2>/dev/null || echo "0")
	fi

	{
		echo "# CI/CD Alerts"
		echo ""
		echo "Generated: $(date)"
		echo ""

		# Check for failures
		if [[ ${failure_count} -gt 0 ]]; then
			echo "## 🚨 CRITICAL: Workflow Failures"
			echo ""
			echo "- **${failure_count}** workflow runs failed recently"
			echo "- **Impact**: CI/CD pipeline reliability compromised"
			echo "- **Action Required**: Investigate and fix failing workflows"
			echo ""
			alerts_found=$((alerts_found + 1))
		fi

		# Check for action required
		if [[ ${action_required} -gt 0 ]]; then
			echo "## ⚠️  WARNING: Manual Action Required"
			echo ""
			echo "- **${action_required}** workflow runs require manual intervention"
			echo "- **Action Required**: Review and approve pending workflows"
			echo ""
			alerts_found=$((alerts_found + 1))
		fi

		# Check for inactive workflows
		if [[ ${inactive_count} -gt 0 ]]; then
			echo "## ℹ️  NOTICE: Inactive Workflows"
			echo ""
			echo "- **${inactive_count}** workflows are currently inactive"
			echo "- **Action Required**: Review and reactivate if needed"
			echo ""
			alerts_found=$((alerts_found + 1))
		fi

		if [[ ${alerts_found} -eq 0 ]]; then
			echo "## ✅ All Clear"
			echo ""
			echo "No alerts at this time. All systems operational."
			echo ""
		fi

		echo "## Next Steps"
		echo ""
		if [[ ${failure_count} -gt 0 ]]; then
			echo '- Run: `gh run list --limit 10` to see recent failures'
			echo "- Check workflow logs for error details"
		fi
		if [[ ${action_required} -gt 0 ]]; then
			echo '- Run: `gh run list --limit 10` to see pending runs'
			echo "- Review and take necessary actions"
		fi
		echo '- Monitor daily with: `bash simple_monitoring.sh`'
		echo ""

	} >"${alert_file}"

	if [[ ${alerts_found} -gt 0 ]]; then
		print_warning "Found ${alerts_found} alerts - check ${alert_file}"
	else
		print_success "No alerts found - all systems operational"
	fi

	echo "${alert_file}"
}

# Main monitoring
run_monitoring() {
	print_header

	if ! check_github_cli; then
		return 1
	fi

	local status_file
	status_file=$(get_workflow_status)
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	local runs_file
	runs_file=$(get_recent_runs 30)
	if [[ $? -ne 0 ]]; then
		return 1
	fi

	local report_file
	report_file=$(analyze_health "${status_file}" "${runs_file}")

	local alert_file
	alert_file=$(generate_alerts "${status_file}" "${runs_file}")

	print_success "Monitoring complete!"
	echo ""
	echo "📊 Report: ${report_file}"
	echo "🚨 Alerts: ${alert_file}"
	echo ""
	echo "💡 Quick view:"
	echo "   cat ${report_file}"
	echo "   cat ${alert_file}"

	# Cleanup temporary files
	rm -f "${status_file}" "${runs_file}"
}

# Show help
show_help() {
	echo "Usage: $0 [OPTIONS]"
	echo ""
	echo "CI/CD Monitoring System"
	echo ""
	echo "Options:"
	echo "  -h, --help    Show this help"
	echo "  -s, --status  Show workflow status"
	echo "  -a, --alerts  Show alerts only"
	echo ""
	echo "Examples:"
	echo "  $0           # Run full monitoring"
	echo "  $0 --status  # Show status only"
}

# Main
main() {
	case "${1-}" in
	-h | --help)
		show_help
		exit 0
		;;
	-s | --status)
		if check_github_cli; then
			local status_file
			status_file=$(get_workflow_status)
			if [[ -n ${status_file} ]]; then
				echo "Workflow status retrieved: ${status_file}"
				# Cleanup temporary file
				rm -f "${status_file}"
			fi
		fi
		;;
	-a | --alerts)
		if check_github_cli; then
			local status_file
			status_file=$(get_workflow_status)
			local runs_file
			runs_file=$(get_recent_runs 20)
			local alert_file
			alert_file=$(generate_alerts "${status_file}" "${runs_file}")
			if [[ -n ${alert_file} ]]; then
				echo "Alerts generated: ${alert_file}"
				# Cleanup temporary files
				rm -f "${status_file}" "${runs_file}"
			fi
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

main "$@"
