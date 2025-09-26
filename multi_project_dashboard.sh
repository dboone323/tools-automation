#!/bin/bash

# Multi-Project Unified Dashboard Configuration
# Monitors CodingReviewer, HabitQuest, and MomentumFinance

set -euo pipefail

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

readonly ROOT_DIR="${ROOT_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
readonly PROJECTS_ROOT="${PROJECTS_ROOT:-${ROOT_DIR}/Projects}"
readonly SIMPLE_MCP_CHECK="${ROOT_DIR}/Tools/Automation/simple_mcp_check.sh"
readonly MASTER_AUTOMATION_PATH="Tools/Automation/master_automation.sh"

readonly PROJECTS=("CodingReviewer" "HabitQuest" "MomentumFinance")

print_header() {
	echo -e "${CYAN}=================================================================================${NC}"
	echo -e "${CYAN}🚀 MULTI-PROJECT AUTOMATION DASHBOARD${NC}"
	echo -e "${CYAN}     CodingReviewer | HabitQuest | MomentumFinance${NC}"
	echo -e "${CYAN}=================================================================================${NC}"
	echo ""
}

print_project_status() {
	local project_name="$1"
	local project_path="${PROJECTS_ROOT}/${project_name}"

	echo -e "${BLUE}${project_name} Status${NC}"
	echo "   📁 Path: ${project_path}"

	if [[ ! -d ${project_path} ]]; then
		echo -e "   ${RED}❌ Project directory not found${NC}"
		echo ""
		return
	fi

	local automation_dir="${project_path}/Tools/Automation"
	if [[ -d ${automation_dir} ]]; then
		echo -e "   ✅ Automation: ${GREEN}Deployed${NC}"

		if [[ -f "${automation_dir}/project_config.sh" ]]; then
			echo -e "   ⚙️  Config: ${GREEN}Available${NC}"
		else
			echo -e "   ⚙️  Config: ${YELLOW}Missing${NC}"
		fi

		if [[ -f "${automation_dir}/mcp_workflow.sh" ]]; then
			echo -e "   🔗 MCP: ${GREEN}Integrated${NC}"
		else
			echo -e "   🔗 MCP: ${YELLOW}Not Found${NC}"
		fi

		if compgen -G "${automation_dir}/ai_enhancement*_system.sh" >/dev/null; then
			echo -e "   🤖 AI Tools: ${GREEN}Available${NC}"
		else
			echo -e "   🤖 AI Tools: ${YELLOW}Not Found${NC}"
		fi
	else
		echo -e "   ❌ Automation: ${RED}Not Deployed${NC}"
	fi

	local swift_files
	swift_files=$(find "${project_path}" -type f -name "*.swift" -print 2>/dev/null | wc -l | tr -d ' ')
	local workflow_count=0
	if [[ -d "${project_path}/.github/workflows" ]]; then
		workflow_count=$(find "${project_path}/.github/workflows" -type f \( -name '*.yml' -o -name '*.yaml' \) -print | wc -l | tr -d ' ')
	fi

	echo "   📊 Swift files: ${swift_files:-0}"
	echo "   🔄 Workflows: ${workflow_count}"
	echo ""
}

run_project_automation() {
	local project_name="$1"
	local project_path="${PROJECTS_ROOT}/${project_name}"

	echo -e "${PURPLE}🔧 Running automation for ${project_name}...${NC}"

	if [[ -f "${project_path}/${MASTER_AUTOMATION_PATH}" ]]; then
		(
			cd "${project_path}" || exit 1
			./${MASTER_AUTOMATION_PATH} status || true
		)
	else
		echo -e "   ${RED}❌ Master automation script not found${NC}"
	fi

	echo ""
}

test_mcp_integration() {
	local project_name="$1"
	local project_path="${PROJECTS_ROOT}/${project_name}"

	echo -e "${CYAN}🔗 Testing MCP integration for ${project_name}...${NC}"

	if [[ ! -f ${SIMPLE_MCP_CHECK} ]]; then
		echo -e "   ${RED}❌ simple_mcp_check.sh not available${NC}"
		echo ""
		return
	fi

	if [[ -d ${project_path} ]]; then
		(
			cd "${project_path}" || exit 1
			bash "${SIMPLE_MCP_CHECK}" "${project_name}" || true
		)
	else
		echo -e "   ${RED}❌ Project directory not found${NC}"
	fi

	echo ""
}

show_unified_status() {
	print_header

	echo -e "${YELLOW}📊 Overall Project Status${NC}"
	echo ""

	for project in "${PROJECTS[@]}"; do
		print_project_status "${project}"
	done
}

run_all_automation() {
	echo -e "${GREEN}🚀 Running automation on all projects...${NC}"
	echo ""

	for project in "${PROJECTS[@]}"; do
		run_project_automation "${project}"
	done
}

test_all_mcp() {
	echo -e "${CYAN}🔗 Testing MCP integration on all projects...${NC}"
	echo ""

	for project in "${PROJECTS[@]}"; do
		test_mcp_integration "${project}"
	done
}

show_help() {
	echo "Multi-Project Dashboard Usage:"
	echo "  $0 status           # Show status of all projects"
	echo "  $0 run-all          # Run automation on all projects"
	echo "  $0 test-mcp         # Test MCP integration on all projects"
	echo "  $0 project <name>   # Focus on specific project"
	echo ""
	echo "Available projects: ${PROJECTS[*]}"
}

case "${1:-status}" in
status)
	show_unified_status
	;;
run-all)
	run_all_automation
	;;
test-mcp)
	test_all_mcp
	;;
project)
	if [[ -n ${2-} ]]; then
		case "$2" in
		CodingReviewer | HabitQuest | MomentumFinance)
			print_project_status "$2"
			run_project_automation "$2"
			;;
		*)
			echo "Unknown project: $2"
			show_help
			;;
		esac
	else
		echo "Please specify a project name"
		show_help
	fi
	;;
help | --help | -h)
	show_help
	;;
*)
	echo "Unknown command: $1"
	show_help
	;;
esac
