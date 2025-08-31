#!/bin/bash
#!/usr/bin/env bash

# Master Automation Controller for Unified Code Architecture
set -euo pipefail

CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECTS_DIR="${CODE_DIR}/Projects"
DRY_RUN=0

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_status() { echo -e "${BLUE}[AUTOMATION]${NC} $1"; }
print_success() { echo -e "${GREEN}[SUCCESS]${NC} $1"; }
print_warning() { echo -e "${YELLOW}[WARNING]${NC} $1"; }
print_error() { echo -e "[ERROR] $1"; }

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

# List available projects
list_projects() {
	print_status "Available projects in unified Code architecture:"
	for project in "${PROJECTS_DIR}"/*; do
		if [[ -d ${project} ]]; then
			local project_name
			project_name=$(basename "${project}")
			local swift_files
			swift_files=$(find "${project}" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
			local has_automation
			if [[ -d "${project}/automation" ]]; then
				has_automation=" (✅ automation)"
			else
				has_automation=" (❌ no automation)"
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
		print_error "Project ${project_name} not found"
		return 1
	fi

	print_status "Running automation for ${project_name}..."

	if [[ -f "${project_path}/automation/run_automation.sh" ]]; then
		mkdir -p "${project_path}/automation/logs" 2>/dev/null || true
		(cd "${project_path}" && bash automation/run_automation.sh) || {
			print_error "${project_name}: automation script failed"
			return 1
		}
		print_success "${project_name} automation completed"
	else
		print_warning "No automation script found for ${project_name}"
		return 1
	fi
}

# Format code using SwiftFormat
format_code() {
	local project_name="${1-}"

	if [[ -n ${project_name} ]]; then
		local project_path
		project_path="${PROJECTS_DIR}/${project_name}"
		if [[ ! -d ${project_path} ]]; then
			print_error "Project ${project_name} not found"
			return 1
		fi
		print_status "Formatting Swift code in ${project_name}..."
		swiftformat "${project_path}" --exclude "*.backup" 2>/dev/null || print_warning "swiftformat not available or failed"
		print_success "Code formatting completed for ${project_name}"
	else
		print_status "Formatting Swift code in all projects..."
		for project in "${PROJECTS_DIR}"/*; do
			if [[ -d ${project} ]]; then
				local project_name
				project_name=$(basename "${project}")
				print_status "Formatting ${project_name}..."
				swiftformat "${project}" --exclude "*.backup" 2>/dev/null || print_warning "swiftformat not available or failed for ${project_name}"
			fi
		done
		print_success "Code formatting completed for all projects"
	fi
}

# Lint code using SwiftLint
lint_code() {
	local project_name="${1-}"

	if [[ -n ${project_name} ]]; then
		local project_path
		project_path="${PROJECTS_DIR}/${project_name}"
		if [[ ! -d ${project_path} ]]; then
			print_error "Project ${project_name} not found"
			return 1
		fi
		print_status "Linting Swift code in ${project_name}..."
		(cd "${project_path}" && swiftlint) || print_warning "swiftlint not available or failed for ${project_name}"
		print_success "Code linting completed for ${project_name}"
	else
		print_status "Linting Swift code in all projects..."
		for project in "${PROJECTS_DIR}"/*; do
			if [[ -d ${project} ]]; then
				local project_name
				project_name=$(basename "${project}")
				print_status "Linting ${project_name}..."
				(cd "${project}" && swiftlint) || print_warning "Lint not available or failed for ${project_name}"
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
		print_error "Project ${project_name} not found"
		return 1
	fi

	print_status "Initializing CocoaPods for ${project_name}..."
	# Run CocoaPods commands explicitly so set -e remains effective
	(cd "${project_path}" && [[ ! -f "Podfile" ]])
	if [[ $? -eq 0 ]]; then
		(cd "${project_path}" && pod init) || {
			print_error "CocoaPods init failed for ${project_name}"
			return 1
		}
	else
		(cd "${project_path}" && pod install) || {
			print_error "CocoaPods install failed for ${project_name}"
			return 1
		}
	fi
	print_success "CocoaPods setup completed for ${project_name}"
}

# Setup Fastlane for iOS deployment
init_fastlane() {
	local project_name="$1"
	local project_path="${PROJECTS_DIR}/${project_name}"

	if [[ ! -d ${project_path} ]]; then
		print_error "Project ${project_name} not found"
		return 1
	fi

	print_status "Setting up Fastlane for ${project_name}..."
	# Run fastlane init explicitly to avoid masking errors
	if [[ ! -d "${project_path}/fastlane" ]]; then
		(cd "${project_path}" && fastlane init) || {
			print_error "Fastlane init failed for ${project_name}"
			return 1
		}
	else
		print_status "Fastlane already configured for ${project_name}"
	fi
	print_success "Fastlane setup checked for ${project_name}"
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
			local project_name
			project_name=$(basename "${project}")
			print_status "Attempting automation for ${project_name}"

			if [[ -f "${project}/automation/run_automation.sh" ]]; then
				mkdir -p "${project}/automation/logs" 2>/dev/null || true

				if [[ ${DRY_RUN} -eq 1 ]]; then
					print_status "Dry-run: would run automation for ${project_name} (skipping actual execution)"
					continue
				fi

				if (cd "${project}" && bash automation/run_automation.sh); then
					print_success "${project_name} automation completed"
				else
					print_warning "Automation failed for ${project_name}"
				fi
			else
				print_warning "No automation script for ${project_name} — running lint as lightweight verification"
				if command -v swiftlint >/dev/null 2>&1; then
					(cd "${project}" && swiftlint) || print_warning "Lint not available or failed for ${project_name}"
				else
					print_warning "swiftlint not installed for ${project_name}"
				fi
			fi
		fi
	done
	print_success "All project automations attempted"
}

# Delegate to other automation helpers (keeps behavior similar to previous master script)
# Note: these helper scripts are expected to exist under Tools/Automation/

main() {
	case "${1-}" in
	list) list_projects ;;
	run) if [[ -n ${2-} ]]; then run_project_automation "$2"; else
		echo "Usage: $0 run <project_name>"
		list_projects
		exit 1
	fi ;;
	all) run_all_automation ;;
	status) show_status ;;
	format) format_code "$2" ;;
	lint) lint_code "$2" ;;
	pods) if [[ -n ${2-} ]]; then init_pods "$2"; else
		echo "Usage: $0 pods <project_name>"
		list_projects
		exit 1
	fi ;;
	fastlane) if [[ -n ${2-} ]]; then init_fastlane "$2"; else
		echo "Usage: $0 fastlane <project_name>"
		list_projects
		exit 1
	fi ;;
	workflow) if [[ -n ${2-} ]] && [[ -n ${3-} ]]; then "${CODE_DIR}/Tools/Automation/enhanced_workflow.sh" "$2" "$3"; else
		echo "Usage: $0 workflow <command> <project_name>"
		exit 1
	fi ;;
	dashboard) "${CODE_DIR}/Tools/Automation/workflow_dashboard.sh" ;;
	unified) "${CODE_DIR}/Tools/Automation/unified_dashboard.sh" ;;
	mcp) if [[ -n ${2-} ]]; then "${CODE_DIR}/Tools/Automation/mcp_workflow.sh" "$2" "${3-}"; else
		echo "Usage: $0 mcp <command> [project_name]"
		exit 1
	fi ;;
	autofix) if [[ -n ${2-} ]]; then "${CODE_DIR}/Tools/Automation/intelligent_autofix.sh" fix "$2"; else "${CODE_DIR}/Tools/Automation/intelligent_autofix.sh" fix-all; fi ;;
	validate) if [[ -n ${2-} ]]; then "${CODE_DIR}/Tools/Automation/intelligent_autofix.sh" validate "$2"; else
		echo "Usage: $0 validate <project_name>"
		exit 1
	fi ;;
	rollback) if [[ -n ${2-} ]]; then "${CODE_DIR}/Tools/Automation/intelligent_autofix.sh" rollback "$2"; else
		echo "Usage: $0 rollback <project_name>"
		exit 1
	fi ;;
	enhance) if [[ -n ${2-} ]]; then "${CODE_DIR}/Tools/Automation/ai_enhancement_system.sh" "$2" "${3-}"; else
		echo "Usage: $0 enhance <command> [project]"
		exit 1
	fi ;;
	*)
		echo "🏗️  Unified Code Architecture - Master Automation Controller"
		echo ""
		echo "Usage: $0 {list|run <project>|all|status|format [project]|lint [project]|pods <project>|fastlane <project>|workflow <command> <project>|mcp <command> <project>|autofix [project]|validate <project>|rollback <project>|enhance <command> [project]|dashboard|unified}"
		echo ""
		exit 1
		;;
	esac
}

main "$@"
