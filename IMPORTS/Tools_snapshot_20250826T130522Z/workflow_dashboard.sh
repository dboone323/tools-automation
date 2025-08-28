#!/bin/bash

# Workflow Status Dashboard - Complete overview of development environment
CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
	echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
	echo -e "${CYAN}║${NC}              🚀 ENHANCED DEVELOPMENT WORKFLOWS DASHBOARD              ${CYAN}║${NC}"
	echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
	echo ""
}

print_section() {
	echo -e "${BLUE}📋 $1${NC}"
	echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

check_tool() {
	local tool_name="$1"
	local tool_command="$2"

	if command -v "$tool_command" &>/dev/null; then
		local version=$($tool_command --version 2>/dev/null | head -1 || echo "Unknown version")
		echo -e "  ✅ ${GREEN}$tool_name${NC} - $version"
		return 0
	else
		echo -e "  ❌ ${RED}$tool_name${NC} - Not installed"
		return 1
	fi
}

check_project_status() {
	local project_path="$1"
	local project_name=$(basename "$project_path")

	if [[ ! -d $project_path ]]; then
		return 1
	fi

	cd "$project_path"

	# Count files
	local swift_files=$(find . -name "*.swift" | wc -l | tr -d ' ')
	local test_files=$(find . -name "*Test*.swift" -o -name "*test*.swift" | wc -l | tr -d ' ')
	local total_lines=$(find . -name "*.swift" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")

	# Git status
	local git_status="❌ No Git"
	local git_branch=""
	if git rev-parse --git-dir >/dev/null 2>&1; then
		git_branch=$(git branch --show-current)
		local changes=$(git status --porcelain | wc -l | tr -d ' ')
		if [[ $changes -eq 0 ]]; then
			git_status="✅ Clean"
		else
			git_status="📝 $changes changes"
		fi
	fi

	# SwiftLint check
	local lint_status="❓ Unknown"
	if command -v swiftlint &>/dev/null; then
		if swiftlint --quiet &>/dev/null; then
			lint_status="✅ Clean"
		else
			local violations=$(swiftlint --reporter json 2>/dev/null | grep -o '"severity":"warning"' | wc -l | tr -d ' ')
			local errors=$(swiftlint --reporter json 2>/dev/null | grep -o '"severity":"error"' | wc -l | tr -d ' ')
			lint_status="⚠️  $violations warnings, $errors errors"
		fi
	fi

	echo -e "  ${PURPLE}📁 $project_name${NC}"
	echo "     📊 Files: $swift_files Swift, $test_files tests, $total_lines total lines"
	echo "     🌿 Git: $git_status$(if [[ -n $git_branch ]]; then echo " ($git_branch)"; fi)"
	echo "     🔍 Lint: $lint_status"
	echo ""
}

workflow_status_dashboard() {
	print_header

	# Tool Status
	print_section "Development Tools Status"
	check_tool "SwiftFormat" "swiftformat"
	check_tool "SwiftLint" "swiftlint"
	check_tool "Fastlane" "fastlane"
	check_tool "CocoaPods" "pod"
	check_tool "Xcode Build Tools" "xcodebuild"
	check_tool "Git" "git"
	check_tool "Swift" "swift"
	echo ""

	# Configuration Status
	print_section "Configuration Files"

	local swiftformat_config="$CODE_DIR/.swiftformat"
	if [[ -f $swiftformat_config ]]; then
		echo -e "  ✅ ${GREEN}.swiftformat${NC} - Configuration present"
	else
		echo -e "  ❌ ${RED}.swiftformat${NC} - Configuration missing"
	fi

	local automation_script="$CODE_DIR/Tools/Automation/master_automation.sh"
	if [[ -f $automation_script ]]; then
		echo -e "  ✅ ${GREEN}master_automation.sh${NC} - Available"
	else
		echo -e "  ❌ ${RED}master_automation.sh${NC} - Missing"
	fi

	local enhanced_workflow="$CODE_DIR/Tools/Automation/enhanced_workflow.sh"
	if [[ -f $enhanced_workflow ]]; then
		echo -e "  ✅ ${GREEN}enhanced_workflow.sh${NC} - Available"
	else
		echo -e "  ❌ ${RED}enhanced_workflow.sh${NC} - Missing"
	fi

	local git_workflow="$CODE_DIR/Tools/Automation/git_workflow.sh"
	if [[ -f $git_workflow ]]; then
		echo -e "  ✅ ${GREEN}git_workflow.sh${NC} - Available"
	else
		echo -e "  ❌ ${RED}git_workflow.sh${NC} - Missing"
	fi
	echo ""

	# Project Status
	print_section "Projects Overview"

	local projects_found=0
	for project_dir in "$CODE_DIR/Projects"/*; do
		if [[ -d $project_dir ]]; then
			check_project_status "$project_dir"
			((projects_found++))
		fi
	done

	if [[ $projects_found -eq 0 ]]; then
		echo "  ❌ No projects found in $CODE_DIR/Projects/"
		echo ""
	fi

	# Workflow Commands Summary
	print_section "Available Workflow Commands"
	echo "  🔧 ${BLUE}Master Automation:${NC}"
	echo "     ./Tools/Automation/master_automation.sh {list|run|all|status|format|lint|pods|fastlane|workflow}"
	echo ""
	echo "  ⚡ ${BLUE}Enhanced Workflows:${NC}"
	echo "     ./Tools/Automation/enhanced_workflow.sh {pre-commit|ios-setup|qa|deps} <project>"
	echo ""
	echo "  🌿 ${BLUE}Git Workflows:${NC}"
	echo "     ./Tools/Automation/git_workflow.sh {smart-commit|feature|release|status}"
	echo ""

	# Quick Actions
	print_section "Quick Actions"
	echo "  📝 Format all projects:     ${YELLOW}./Tools/Automation/master_automation.sh format${NC}"
	echo "  🔍 Lint all projects:       ${YELLOW}./Tools/Automation/master_automation.sh lint${NC}"
	echo "  📊 Architecture status:     ${YELLOW}./Tools/Automation/master_automation.sh status${NC}"
	echo "  🌿 Git status overview:     ${YELLOW}./Tools/Automation/git_workflow.sh status${NC}"
	echo ""

	# System Health
	print_section "System Health"
	local health_score=0
	local max_score=10

	# Check essential tools
	command -v swiftformat &>/dev/null && ((health_score++))
	command -v swiftlint &>/dev/null && ((health_score++))
	command -v fastlane &>/dev/null && ((health_score++))
	command -v pod &>/dev/null && ((health_score++))
	command -v xcodebuild &>/dev/null && ((health_score++))
	command -v git &>/dev/null && ((health_score++))

	# Check configuration files
	[[ -f $swiftformat_config ]] && ((health_score++))
	[[ -f $automation_script ]] && ((health_score++))
	[[ -f $enhanced_workflow ]] && ((health_score++))
	[[ -f $git_workflow ]] && ((health_score++))

	local health_percentage=$((health_score * 100 / max_score))

	if [[ $health_percentage -ge 90 ]]; then
		echo -e "  🟢 ${GREEN}EXCELLENT${NC} - $health_score/$max_score ($health_percentage%) - All systems operational"
	elif [[ $health_percentage -ge 70 ]]; then
		echo -e "  🟡 ${YELLOW}GOOD${NC} - $health_score/$max_score ($health_percentage%) - Minor issues detected"
	elif [[ $health_percentage -ge 50 ]]; then
		echo -e "  🟠 ${YELLOW}FAIR${NC} - $health_score/$max_score ($health_percentage%) - Some tools missing"
	else
		echo -e "  🔴 ${RED}POOR${NC} - $health_score/$max_score ($health_percentage%) - Significant issues detected"
	fi
	echo ""

	echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
	echo -e "${CYAN}📚 For detailed documentation: ./Documentation/Enhanced_Workflows.md${NC}"
	echo -e "${CYAN}🆘 For help: ./Tools/Automation/enhanced_workflow.sh help${NC}"
	echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Execute dashboard
workflow_status_dashboard
