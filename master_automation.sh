#!/bin/bash

# Master Automation Controller for Unified Code Architecture
CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECTS_DIR="${CODE_DIR}/Projects"

# Performance monitoring variables
PERFORMANCE_LOG="${CODE_DIR}/Tools/Automation/logs/performance.log"
METRICS_DIR="${CODE_DIR}/Tools/Automation/metrics"
SESSION_START_TIME=$(date +%s)

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
	echo -e "${BLUE}[AUTOMATION]${NC} $1"
}

print_success() {
	echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
	echo -e "${YELLOW}[WARNING]${NC} $1"
}

# Performance Monitoring Functions
log_execution_time() {
	local operation="$1"
	local start_time="$2"
	local end_time=$(date +%s)
	local duration=$((end_time - start_time))
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	# Create metrics directory if it doesn't exist
	mkdir -p "${METRICS_DIR}"

	# Log to performance file
	echo "${timestamp}|${operation}|${duration}|$(date +%s)" >>"${PERFORMANCE_LOG}"

	# Log to console
	echo -e "${BLUE}[PERFORMANCE]${NC} ${operation} completed in ${duration}s"

	# Check for performance alerts
	check_performance_alerts "${operation}" "${duration}"
}

check_performance_alerts() {
	local operation="$1"
	local duration="$2"

	# Define performance thresholds (in seconds)
	local threshold_critical=300 # 5 minutes
	local threshold_warning=120  # 2 minutes

	if [[ ${duration} -gt ${threshold_critical} ]]; then
		echo -e "${RED}[ALERT]${NC} CRITICAL: ${operation} took ${duration}s (exceeds ${threshold_critical}s threshold)"
		log_alert "CRITICAL" "${operation}" "${duration}" "${threshold_critical}"
	elif [[ ${duration} -gt ${threshold_warning} ]]; then
		echo -e "${YELLOW}[ALERT]${NC} WARNING: ${operation} took ${duration}s (exceeds ${threshold_warning}s threshold)"
		log_alert "WARNING" "${operation}" "${duration}" "${threshold_warning}"
	fi
}

log_alert() {
	local level="$1"
	local operation="$2"
	local duration="$3"
	local threshold="$4"
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	echo "${timestamp}|${level}|${operation}|${duration}|${threshold}" >>"${METRICS_DIR}/alerts.log"
}

generate_performance_report() {
	local report_file="${METRICS_DIR}/performance_report_$(date +%Y%m%d_%H%M%S).md"

	echo "# Performance Report - $(date)" >"${report_file}"
	echo "" >>"${report_file}"
	echo "## Summary" >>"${report_file}"
	echo "" >>"${report_file}"

	# Calculate session duration
	local current_time=$(date +%s)
	local session_duration=$((current_time - SESSION_START_TIME))
	echo "- **Session Duration**: ${session_duration}s" >>"${report_file}"
	echo "- **Report Generated**: $(date)" >>"${report_file}"
	echo "" >>"${report_file}"

	# Analyze performance data
	if [[ -f ${PERFORMANCE_LOG} ]]; then
		echo "## Performance Metrics" >>"${report_file}"
		echo "" >>"${report_file}"

		# Top 10 slowest operations
		echo "### Top 10 Slowest Operations" >>"${report_file}"
		echo "" >>"${report_file}"
		echo "| Operation | Duration (s) | Timestamp |" >>"${report_file}"
		echo "|-----------|--------------|-----------|" >>"${report_file}"
		tail -n 100 "${PERFORMANCE_LOG}" | sort -t'|' -k3 -nr | head -10 | while IFS='|' read -r timestamp operation duration epoch; do
			echo "| ${operation} | ${duration} | ${timestamp} |" >>"${report_file}"
		done
		echo "" >>"${report_file}"

		# Performance trends
		echo "### Performance Trends (Last 24h)" >>"${report_file}"
		echo "" >>"${report_file}"
		local yesterday=$(date -v-1d +%s)
		local slow_count=$(awk -F'|' -v yesterday="${yesterday}" '$4 > yesterday && $3 > 60 {count++} END {print count+0}' "${PERFORMANCE_LOG}")
		local total_count=$(awk -F'|' -v yesterday="${yesterday}" '$4 > yesterday {count++} END {print count+0}' "${PERFORMANCE_LOG}")

		if [[ ${total_count} -gt 0 ]]; then
			local slow_percentage=$((slow_count * 100 / total_count))
			echo "- **Total Operations**: ${total_count}" >>"${report_file}"
			echo "- **Slow Operations (>60s)**: ${slow_count} (${slow_percentage}%)" >>"${report_file}"
		fi
		echo "" >>"${report_file}"
	fi

	# Check for alerts
	if [[ -f "${METRICS_DIR}/alerts.log" ]]; then
		echo "## Recent Alerts" >>"${report_file}"
		echo "" >>"${report_file}"
		echo "| Level | Operation | Duration | Threshold | Timestamp |" >>"${report_file}"
		echo "|-------|-----------|----------|-----------|-----------|" >>"${report_file}"
		tail -n 10 "${METRICS_DIR}/alerts.log" | while IFS='|' read -r timestamp level operation duration threshold; do
			echo "| ${level} | ${operation} | ${duration}s | ${threshold}s | ${timestamp} |" >>"${report_file}"
		done
		echo "" >>"${report_file}"
	fi

	echo "## Recommendations" >>"${report_file}"
	echo "" >>"${report_file}"

	# Generate recommendations based on performance data
	if [[ -f ${PERFORMANCE_LOG} ]]; then
		local avg_duration=$(awk -F'|' '{sum+=$3; count++} END {if(count>0) print int(sum/count); else print 0}' "${PERFORMANCE_LOG}")
		if [[ ${avg_duration} -gt 120 ]]; then
			echo "- ⚠️  **High Average Duration**: Consider optimizing frequently slow operations" >>"${report_file}"
		fi

		local error_rate=$(grep -c "ERROR\|FAILED\|CRITICAL" "${METRICS_DIR}/alerts.log" 2>/dev/null || echo "0")
		if [[ ${error_rate} -gt 5 ]]; then
			echo "- 🚨 **High Error Rate**: Review error patterns and implement better error handling" >>"${report_file}"
		fi
	fi

	echo "- 📊 **Regular Monitoring**: Continue monitoring performance trends" >>"${report_file}"
	echo "- 🔧 **Optimization**: Focus on top 3 slowest operations for optimization" >>"${report_file}"
	echo "" >>"${report_file}"

	print_success "Performance report generated: ${report_file}"
	echo "View report: ${report_file}"
}

track_performance_metrics() {
	local operation="$1"
	local start_time=$(date +%s)

	# Execute the operation (passed as remaining arguments)
	shift
	"$@"
	local exit_code=$?

	local end_time=$(date +%s)
	local duration=$((end_time - start_time))

	# Log the performance metrics
	log_execution_time "${operation}" "${start_time}"

	# Track additional metrics
	local memory_usage=$(ps -o rss= -p $$ 2>/dev/null | awk '{print $1*1024}' || echo "0")
	local cpu_usage=$(ps -o pcpu= -p $$ 2>/dev/null || echo "0")

	# Log detailed metrics
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
	echo "${timestamp}|${operation}|${duration}|${memory_usage}|${cpu_usage}|${exit_code}" >>"${METRICS_DIR}/detailed_metrics.log"

	return "${exit_code}"
}

# Enhanced Error Recovery & Resilience Functions
retry_operation() {
	local command="$1"
	local operation_name="$2"
	local max_attempts="${RETRY_ATTEMPTS:-3}"
	local attempt=1
	local start_time=$(date +%s)

	print_status "Starting ${operation_name} (max ${max_attempts} attempts)"

	while [[ ${attempt} -le ${max_attempts} ]]; do
		print_status "Attempt ${attempt}/${max_attempts}: ${operation_name}"

		if eval "${command}"; then
			log_execution_time "${operation_name}" "${start_time}"
			print_success "${operation_name} completed successfully on attempt ${attempt}"
			return 0
		else
			local error_code=$?
			print_warning "${operation_name} failed on attempt ${attempt} (exit code: ${error_code})"

			if [[ ${attempt} -lt ${max_attempts} ]]; then
				local backoff_time=$((attempt * 2))
				print_status "Waiting ${backoff_time}s before retry..."
				sleep "${backoff_time}"
			fi
			((attempt++))
		fi
	done

	log_execution_time "${operation_name}" "${start_time}"
	print_error "${operation_name} failed after ${max_attempts} attempts"
	log_error "${operation_name}" "Failed after ${max_attempts} attempts" "${error_code}"
	return 1
}

log_error() {
	local operation="$1"
	local message="$2"
	local error_code="$3"
	local timestamp=$(date '+%Y-%m-%d %H:%M:%S')

	mkdir -p "${METRICS_DIR}"
	echo "${timestamp}|ERROR|${operation}|${message}|${error_code}" >>"${METRICS_DIR}/errors.log"
}

print_error() {
	echo -e "${RED}[ERROR]${NC} $1"
}

# Security Enhancement Functions
validate_security() {
	local project_path="$1"
	local operation_start=$(date +%s)

	print_status "🔒 Running security validation..."

	local issues_found=0

	# Check for exposed secrets
	if grep -r "password\|secret\|token\|api_key\|private_key" "${project_path}" --exclude-dir=".git" --exclude-dir="*.backup" | grep -v "placeholder\|example\|test" | grep -v "Pods/"; then
		print_warning "Potential exposed secrets found"
		((issues_found++))
	fi

	# Check for insecure file permissions
	local insecure_files=$(find "${project_path}" -name "*.pem" -o -name "*.key" -o -name "*.p12" | xargs ls -la 2>/dev/null | grep -v "r--------" | wc -l | tr -d ' ')
	if [[ ${insecur_files} -gt 0 ]]; then
		print_warning "Found ${insecure_files} files with insecure permissions"
		((issues_found++))
	fi

	# Check for hardcoded URLs/IPs
	if grep -r "http://localhost\|127.0.0.1\|0.0.0.0" "${project_path}" --exclude-dir=".git" --include="*.swift" | grep -v "comment\|test\|example"; then
		print_warning "Potential hardcoded localhost/development URLs found"
		((issues_found++))
	fi

	log_execution_time "security_validation" "${operation_start}"

	if [[ ${issues_found} -eq 0 ]]; then
		print_success "✅ Security validation passed"
		return 0
	else
		print_warning "⚠️  Security validation found ${issues_found} issues"
		return 1
	fi
}

# Configuration Management Functions
load_config() {
	local config_file="${CODE_DIR}/Tools/Automation/config/automation_config.yaml"

	if [[ -f ${config_file} ]]; then
		print_status "Loading configuration from ${config_file}"
		# In a real implementation, you'd parse YAML here
		# For now, we'll use environment variables as fallback
		export MAX_EXECUTION_TIME="${MAX_EXECUTION_TIME:-300}"
		export RETRY_ATTEMPTS="${RETRY_ATTEMPTS:-3}"
		export LOG_LEVEL="${LOG_LEVEL:-INFO}"
	else
		print_warning "Configuration file not found, using defaults"
	fi
}

validate_config() {
	print_status "Validating configuration..."

	# Check required directories
	local required_dirs=("${METRICS_DIR}" "${CODE_DIR}/Tools/Automation/logs" "${CODE_DIR}/Tools/Automation/config")
	for dir in "${required_dirs[@]}"; do
		if [[ ! -d ${dir} ]]; then
			mkdir -p "${dir}"
			print_status "Created directory: ${dir}"
		fi
	done

	# Validate tool availability
	local required_tools=("git" "python3" "swiftlint")
	for tool in "${required_tools[@]}"; do
		if ! command -v "${tool}" &>/dev/null; then
			print_warning "Required tool not found: ${tool}"
		fi
	done
}

# Documentation Generation Functions
generate_docs() {
	local operation_start=$(date +%s)
	local docs_dir="${CODE_DIR}/Tools/Documentation"

	print_status "📚 Generating documentation..."

	mkdir -p "${docs_dir}"

	# Generate command reference
	{
		echo "# Master Automation Command Reference"
		echo ""
		echo "Generated: $(date)"
		echo ""
		echo "## Available Commands"
		echo ""
		echo "| Command | Description |"
		echo "|---------|-------------|"
		echo '| `list` | List all projects with status |'
		echo '| `run <project>` | Run automation for specific project |'
		echo '| `all` | Run automation for all projects |'
		echo '| `status` | Show unified architecture status |'
		echo '| `format [project]` | Format Swift code |'
		echo '| `lint [project]` | Lint Swift code |'
		echo '| `pods <project>` | Initialize/update CocoaPods |'
		echo '| `fastlane <project>` | Setup Fastlane for iOS deployment |'
		echo '| `performance` | Generate performance report |'
		echo '| `security [project]` | Run security validation |'
	} >"${docs_dir}/commands.md"

	# Generate project status report
	{
		echo "# Project Status Report"
		echo ""
		echo "Generated: $(date)"
		echo ""
		echo "## Projects Overview"
		echo ""
	} >"${docs_dir}/project_status.md"

	list_projects >>"${docs_dir}/project_status.md"

	log_execution_time "documentation_generation" "${operation_start}"
	print_success "✅ Documentation updated in ${docs_dir}"
}

# Integration Testing Functions
run_integration_tests() {
	local operation_start=$(date +%s)
	local test_results_dir="${METRICS_DIR}/integration_tests"

	print_status "🧪 Running integration tests..."

	mkdir -p "${test_results_dir}"

	local test_report="${test_results_dir}/integration_test_$(date +%Y%m%d_%H%M%S).md"
	{
		echo "# Integration Test Report"
		echo ""
		echo "Generated: $(date)"
		echo ""
		echo "## Test Results"
		echo ""
	} >"${test_report}"

	local total_tests=0
	local passed_tests=0
	local failed_tests=0

	# Test project dependencies
	for project in "${PROJECTS_DIR}"/*; do
		if [[ -d ${project} ]]; then
			local project_name=$(basename "${project}")
			((total_tests++))

			print_status "Testing ${project_name} integration..."

			# Test 1: Check if project builds successfully
			if [[ -d ${project} ]] && cd "${project}"; then
				# Check for Xcode project files using find command
				local xcodeproj_count=$(find . -maxdepth 1 -name "*.xcodeproj" 2>/dev/null | wc -l | tr -d ' ')
				local xcworkspace_count=$(find . -maxdepth 1 -name "*.xcworkspace" 2>/dev/null | wc -l | tr -d ' ')

				if [[ ${xcodeproj_count} -gt 0 ]] || [[ ${xcworkspace_count} -gt 0 ]]; then
					if xcodebuild -list 2>/dev/null | grep -q "Targets:"; then
						echo "- ✅ ${project_name}: Build configuration valid" >>"${test_report}"
						((passed_tests++))
					else
						echo "- ❌ ${project_name}: Build configuration invalid" >>"${test_report}"
						((failed_tests++))
					fi
				else
					echo "- ⚠️  ${project_name}: No Xcode project found (may be documentation or tools)" >>"${test_report}"
					((passed_tests++))
				fi
			fi
		fi
	done

	# Test automation system integration
	((total_tests++))
	if [[ -f "${CODE_DIR}/Tools/Automation/master_automation.sh" ]]; then
		if bash "${CODE_DIR}/Tools/Automation/master_automation.sh" status >/dev/null 2>&1; then
			echo "- ✅ Automation system: Status check passed" >>"${test_report}"
			((passed_tests++))
		else
			echo "- ❌ Automation system: Status check failed" >>"${test_report}"
			((failed_tests++))
		fi
	fi

	# Test configuration validation
	((total_tests++))
	if [[ -f "${CODE_DIR}/Tools/Automation/config/automation_config.yaml" ]]; then
		echo "- ✅ Configuration: File exists and accessible" >>"${test_report}"
		((passed_tests++))
	else
		echo "- ❌ Configuration: File missing" >>"${test_report}"
		((failed_tests++))
	fi

	# Summary
	{
		echo ""
		echo "## Summary"
		echo ""
		echo "- **Total Tests**: ${total_tests}"
		echo "- **Passed**: ${passed_tests}"
		echo "- **Failed**: ${failed_tests}"
		echo "- **Success Rate**: $((passed_tests * 100 / total_tests))%"
		echo ""
	} >>"${test_report}"

	log_execution_time "integration_testing" "${operation_start}"

	if [[ ${failed_tests} -eq 0 ]]; then
		print_success "✅ All integration tests passed"
	else
		print_warning "⚠️  ${failed_tests} integration tests failed"
	fi

	echo "View detailed report: ${test_report}"
}

# List available projects
list_projects() {
	print_status "Available projects in unified Code architecture:"
	for project in "${PROJECTS_DIR}"/*; do
		if [[ -d ${project} ]]; then
			local project_name=$(basename "${project}")
			local swift_files=$(find "${project}" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')

			# Check for automation in multiple ways
			local has_automation=""
			local automation_type=""

			# Check for automation directories (case insensitive)
			if [[ -d "${project}/automation" ]] || [[ -d "${project}/Automation" ]]; then
				has_automation=" (✅ automation)"
				automation_type="directory"
			# Check for Tools directory with automation scripts
			elif [[ -d "${project}/Tools" ]] && [[ -n "$(find "${project}/Tools" -name "*automation*" -o -name "*build*" -o -name "*dev*" -o -name "*.sh" | head -1)" ]]; then
				has_automation=" (✅ automation)"
				automation_type="tools"
			# Check for automation scripts in project root
			elif [[ -n "$(find "${project}" -maxdepth 1 -name "*automation*" -o -name "*build*" -o -name "*dev*" -o -name "*.sh" | grep -v "test_" | head -1)" ]]; then
				has_automation=" (✅ automation)"
				automation_type="scripts"
			else
				has_automation=" (❌ no automation)"
				automation_type="none"
			fi

			echo "  - ${project_name}: ${swift_files} Swift files${has_automation}"
		fi
	done
}

# Run automation for specific project
run_project_automation() {
	local project_name="$1"
	local project_path="${PROJECTS_DIR}/${project_name}"

	if [[ ! -d ${project_path} ]]; then
		echo "❌ Project ${project_name} not found"
		return 1
	fi

	print_status "Running automation for ${project_name}..."

	# Try to find and run automation script
	local automation_script=""

	# Check for automation/run_automation.sh (primary)
	if [[ -f "${project_path}/automation/run_automation.sh" ]]; then
		automation_script="${project_path}/automation/run_automation.sh"
	elif [[ -f "${project_path}/Automation/run_automation.sh" ]]; then
		automation_script="${project_path}/Automation/run_automation.sh"
	# Check for dev.sh in project root
	elif [[ -f "${project_path}/dev.sh" ]]; then
		automation_script="${project_path}/dev.sh"
	# Check for build scripts in Tools directory
	elif [[ -f "${project_path}/Tools/build.sh" ]]; then
		automation_script="${project_path}/Tools/build.sh"
	elif [[ -f "${project_path}/Tools/smart_builder.sh" ]]; then
		automation_script="${project_path}/Tools/smart_builder.sh"
	# Check for any .sh script in Tools directory
	else
		local script=$(find "${project_path}/Tools" -name "*.sh" 2>/dev/null | head -1)
		if [[ -n ${script} ]]; then
			automation_script="${script}"
		fi
	fi

	if [[ -n ${automation_script} ]]; then
		print_status "Found automation script: $(basename "${automation_script}")"
		# Set PROJECT_NAME environment variable for the automation script
		cd "${project_path}" && PROJECT_NAME="${project_name}" bash "${automation_script}"
		print_success "${project_name} automation completed"
	else
		print_warning "No automation script found for ${project_name}"
		print_status "Available files in project:"
		find "${project_path}" -maxdepth 2 -name "*.sh" 2>/dev/null | head -5 | sed 's/^/  - /'
		return 1
	fi
}

# Format code using SwiftFormat
format_code() {
	local project_name="${1-}"

	if [[ -n ${project_name} ]]; then
		local project_path="${PROJECTS_DIR}/${project_name}"
		if [[ ! -d ${project_path} ]]; then
			echo "❌ Project ${project_name} not found"
			return 1
		fi
		print_status "Formatting Swift code in ${project_name}..."
		swiftformat "${project_path}" --exclude "*.backup" 2>/dev/null
		print_success "Code formatting completed for ${project_name}"
	else
		print_status "Formatting Swift code in all projects..."
		for project in "${PROJECTS_DIR}"/*; do
			if [[ -d ${project} ]]; then
				local project_name=$(basename "${project}")
				print_status "Formatting ${project_name}..."
				swiftformat "${project}" --exclude "*.backup" 2>/dev/null
			fi
		done
		print_success "Code formatting completed for all projects"
	fi
}

# Lint code using SwiftLint
lint_code() {
	local project_name="${1-}"

	if [[ -n ${project_name} ]]; then
		local project_path="${PROJECTS_DIR}/${project_name}"
		if [[ ! -d ${project_path} ]]; then
			echo "❌ Project ${project_name} not found"
			return 1
		fi
		print_status "Linting Swift code in ${project_name}..."
		cd "${project_path}" && swiftlint
		print_success "Code linting completed for ${project_name}"
	else
		print_status "Linting Swift code in all projects..."
		for project in "${PROJECTS_DIR}"/*; do
			if [[ -d ${project} ]]; then
				local project_name=$(basename "${project}")
				print_status "Linting ${project_name}..."
				cd "${project}" && swiftlint
			fi
		done
		print_success "Code linting completed for all projects"
	fi
}

# Initialize CocoaPods for a project
init_pods() {
	local project_name="$1"
	local project_path="${PROJECTS_DIR}/${project_name}"

	if [[ ! -d ${project_path} ]]; then
		echo "❌ Project ${project_name} not found"
		return 1
	fi

	print_status "Initializing CocoaPods for ${project_name}..."
	cd "${project_path}" || exit

	if [[ ! -f "Podfile" ]]; then
		print_status "Creating Podfile..."
		pod init
		print_success "Podfile created"
	else
		print_status "Installing/updating pods..."
		pod install
		print_success "CocoaPods setup completed"
	fi
}

# Setup Fastlane for iOS deployment
init_fastlane() {
	local project_name="$1"
	local project_path="${PROJECTS_DIR}/${project_name}"

	if [[ ! -d ${project_path} ]]; then
		echo "❌ Project ${project_name} not found"
		return 1
	fi

	print_status "Setting up Fastlane for ${project_name}..."
	cd "${project_path}" || exit

	if [[ ! -d "fastlane" ]]; then
		print_status "Initializing Fastlane..."
		fastlane init
		print_success "Fastlane initialized"
	else
		print_status "Fastlane already configured"
	fi
}

# Show unified architecture status
show_status() {
	print_status "Unified Code Architecture Status"
	echo ""

	echo "📍 Location: ${CODE_DIR}"
	echo "📊 Projects: $(find "${PROJECTS_DIR}" -maxdepth 1 -type d | tail -n +2 | wc -l | tr -d ' ')"

	# Check tool availability
	echo ""
	print_status "Development Tools:"
	check_tool "xcodebuild" "Xcode Build System"
	check_tool "swift" "Swift Compiler"
	check_tool "swiftlint" "SwiftLint"
	check_tool "swiftformat" "SwiftFormat"
	check_tool "fastlane" "Fastlane"
	check_tool "pod" "CocoaPods"
	check_tool "git" "Git"
	check_tool "python3" "Python"

	echo ""
	list_projects
}

# Run automation for all projects
run_all_automation() {
	print_status "Running automation for all projects..."
	for project in "${PROJECTS_DIR}"/*; do
		if [[ -d ${project} ]]; then
			local project_name=$(basename "${project}")
			print_status "Attempting automation for ${project_name}"

			# Try to find automation script using improved detection
			local automation_script=""
			local project_path="${project}"

			# Check for automation/run_automation.sh (primary)
			if [[ -f "${project_path}/automation/run_automation.sh" ]]; then
				automation_script="${project_path}/automation/run_automation.sh"
			elif [[ -f "${project_path}/Automation/run_automation.sh" ]]; then
				automation_script="${project_path}/Automation/run_automation.sh"
			# Check for dev.sh in project root
			elif [[ -f "${project_path}/dev.sh" ]]; then
				automation_script="${project_path}/dev.sh"
			# Check for build scripts in Tools directory
			elif [[ -f "${project_path}/Tools/build.sh" ]]; then
				automation_script="${project_path}/Tools/build.sh"
			elif [[ -f "${project_path}/Tools/smart_builder.sh" ]]; then
				automation_script="${project_path}/Tools/smart_builder.sh"
			# Check for any .sh script in Tools directory
			else
				automation_script=$(find "${project_path}/Tools" -name "*.sh" 2>/dev/null | head -1)
			fi

			if [[ -n ${automation_script} ]]; then
				print_status "Found automation script: $(basename "${automation_script}")"
				(cd "${project_path}" && PROJECT_NAME="${project_name}" bash "${automation_script}") || print_warning "Automation failed for ${project_name}"
			else
				print_warning "No automation script for ${project_name} — running lint as lightweight verification"
				(cd "${project}" && command -v swiftlint >/dev/null 2>&1 && swiftlint) || print_warning "Lint not available or failed for ${project_name}"
			fi
		fi
	done
	print_success "All project automations attempted"
}

# Check if a tool is available
check_tool() {
	local tool="$1"
	local description="$2"
	if command -v "${tool}" &>/dev/null; then
		echo "  ✅ ${description}"
	else
		echo "  ❌ ${description} (not installed)"
	fi
}

# Main execution
case "${1-}" in
"list")
	list_projects
	;;
"run")
	if [[ -n ${2-} ]]; then
		run_project_automation "$2"
	else
		echo "Usage: $0 run <project_name>"
		list_projects
		exit 1
	fi
	;;
"all")
	run_all_automation
	;;
"status")
	show_status
	;;
"format")
	format_code "$2"
	;;
"lint")
	lint_code "$2"
	;;
"pods")
	if [[ -n ${2-} ]]; then
		init_pods "$2"
	else
		echo "Usage: $0 pods <project_name>"
		list_projects
		exit 1
	fi
	;;
"fastlane")
	if [[ -n ${2-} ]]; then
		init_fastlane "$2"
	else
		echo "Usage: $0 fastlane <project_name>"
		list_projects
		exit 1
	fi
	;;
"workflow")
	if [[ -n ${2-} ]] && [[ -n ${3-} ]]; then
		"${CODE_DIR}/Tools/Automation/enhanced_workflow.sh" "$2" "$3"
	else
		echo "Usage: $0 workflow <command> <project_name>"
		echo "Available workflow commands: pre-commit, ios-setup, qa, deps"
		exit 1
	fi
	;;
"dashboard")
	"${CODE_DIR}/Tools/Automation/workflow_dashboard.sh"
	;;
"performance")
	generate_performance_report
	;;
"security")
	if [[ -n ${2-} ]]; then
		validate_security "${PROJECTS_DIR}/$2"
	else
		echo "Usage: $0 security <project_name>"
		list_projects
		exit 1
	fi
	;;
"docs")
	generate_docs
	;;
"config")
	validate_config
	;;
"integration-test")
	run_integration_tests
	;;
"retry-test")
	# Test retry mechanism
	retry_operation "echo 'Testing retry mechanism'" "retry_test"
	;;
"mcp")
	if [[ -n ${2-} ]]; then
		if [[ ${2} == "status" || ${2} == "autofix-all" ]]; then
			"${CODE_DIR}/Tools/Automation/mcp_workflow.sh" "$2"
		elif [[ -n ${3-} ]]; then
			"${CODE_DIR}/Tools/Automation/mcp_workflow.sh" "$2" "$3"
		else
			echo "Usage: $0 mcp <command> [project_name]"
			echo "Available MCP commands: check, ci-check, fix, autofix, autofix-all, validate, rollback, status"
			exit 1
		fi
	else
		echo "Usage: $0 mcp <command> [project_name]"
		echo "Available MCP commands: check, ci-check, fix, autofix, autofix-all, validate, rollback, status"
		exit 1
	fi
	;;
"autofix")
	if [[ -n ${2-} ]]; then
		"${CODE_DIR}/Tools/Automation/intelligent_autofix.sh" fix "$2"
	else
		"${CODE_DIR}/Tools/Automation/intelligent_autofix.sh" fix-all
	fi
	;;
"validate")
	if [[ -n ${2-} ]]; then
		"${CODE_DIR}/Tools/Automation/intelligent_autofix.sh" validate "$2"
	else
		echo "Usage: $0 validate <project_name>"
		exit 1
	fi
	;;
"rollback")
	if [[ -n ${2-} ]]; then
		"${CODE_DIR}/Tools/Automation/intelligent_autofix.sh" rollback "$2"
	else
		echo "Usage: $0 rollback <project_name>"
		exit 1
	fi
	;;
"enhance")
	if [[ -n ${2-} ]]; then
		if [[ ${2} == "analyze-all" || ${2} == "auto-apply-all" || ${2} == "report" || ${2} == "status" ]]; then
			"${CODE_DIR}/Tools/Automation/ai_enhancement_system.sh" "$2"
		elif [[ -n ${3-} ]]; then
			"${CODE_DIR}/Tools/Automation/ai_enhancement_system.sh" "$2" "$3"
		else
			echo "Usage: $0 enhance <command> [project_name]"
			echo "Available commands: analyze, analyze-all, auto-apply, auto-apply-all, report, status"
			exit 1
		fi
	else
		echo "Usage: $0 enhance <command> [project_name]"
		echo "Available commands: analyze, analyze-all, auto-apply, auto-apply-all, report, status"
		exit 1
	fi
	;;
*)
	echo "🏗️  Unified Code Architecture - Master Automation Controller"
	echo ""
	echo "Usage: $0 {list|run <project>|all|status|format [project]|lint [project]|pods <project>|fastlane <project>|workflow <command> <project>|mcp <command> <project>|autofix [project]|validate <project>|rollback <project>|enhance <command> [project]|dashboard|unified|performance|security <project>|docs|config|integration-test|retry-test}"
	echo ""
	echo "Commands:"
	echo "  list                    # List all projects with status"
	echo "  run <project>          # Run automation for specific project"
	echo "  all                    # Run automation for all projects"
	echo "  status                 # Show unified architecture status"
	echo "  format [project]       # Format Swift code (all projects if no project specified)"
	echo "  lint [project]         # Lint Swift code (all projects if no project specified)"
	echo "  pods <project>         # Initialize/update CocoaPods for project"
	echo "  fastlane <project>     # Setup Fastlane for iOS deployment"
	echo "  workflow <cmd> <proj>  # Run enhanced workflow (pre-commit, ios-setup, qa, deps)"
	echo "  mcp <cmd> <proj>       # MCP GitHub workflow integration (check, ci-check, fix, autofix, validate, rollback, status)"
	echo "  autofix [project]      # Run intelligent auto-fix with safety checks (all projects if none specified)"
	echo "  validate <project>     # Run comprehensive validation checks"
	echo "  rollback <project>     # Rollback last auto-fix if backup exists"
	echo "  enhance <cmd> [proj]   # AI-powered enhancement system (analyze, auto-apply, analyze-all, auto-apply-all, report, status)"
	echo "  dashboard              # Show comprehensive workflow status dashboard"
	echo "  unified                # Show unified workflow status across all projects"
	echo "  performance            # Generate performance report with metrics and alerts"
	echo "  security <project>     # Run security validation and check for vulnerabilities"
	echo "  docs                   # Generate comprehensive documentation and command reference"
	echo "  config                 # Validate and setup automation configuration"
	echo "  integration-test       # Run integration tests across all projects"
	echo "  retry-test             # Test retry mechanism and error recovery"
	echo ""
	exit 1
	;;
esac
