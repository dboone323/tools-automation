#!/bin/bash

# Multi-Project Unified Dashboard Configuration
# Monitors CodingReviewer, HabitQuest, and MomentumFinance

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Project Paths
PROJECTS_ROOT="/Users/danielstevens/Desktop/Code/Projects"
CODINGREVIEWER_PATH="$PROJECTS_ROOT/CodingReviewer"
HABITQUEST_PATH="$PROJECTS_ROOT/HabitQuest"
MOMENTUMFINANCE_PATH="$PROJECTS_ROOT/MomentumFinance"

# Project Names Array
PROJECTS=("CodingReviewer" "HabitQuest" "MomentumFinance")

print_header() {
	echo -e "${CYAN}=================================================================================${NC}"
	echo -e "${CYAN}🚀 MULTI-PROJECT AUTOMATION DASHBOARD${NC}"
	echo -e "${CYAN}     CodingReviewer | HabitQuest | MomentumFinance${NC}"
	echo -e "${CYAN}=================================================================================${NC}"
	echo ""
}

print_project_status() {
	local project_name=$1
	local project_path=$2

	echo -e "${BLUE}📱 $project_name Status${NC}"
	echo "   📁 Path: $project_path"

	if [[ -d "$project_path/Tools/Automation" ]]; then
		echo -e "   ✅ Automation: ${GREEN}Deployed${NC}"

		# Check if project config exists
		if [[ -f "$project_path/Tools/Automation/project_config.sh" ]]; then
			echo -e "   ⚙️  Config: ${GREEN}Available${NC}"
		else
			echo -e "   ⚙️  Config: ${YELLOW}Missing${NC}"
		fi

		# Check MCP integration
		if [[ -f "$project_path/Tools/Automation/mcp_workflow.sh" ]]; then
			echo -e "   🔗 MCP: ${GREEN}Integrated${NC}"
		else
			echo -e "   🔗 MCP: ${YELLOW}Not Found${NC}"
		fi

		# Check AI enhancements
		if [[ -f "$project_path/Tools/Automation/ai_enhancement_system.sh" ]]; then
			echo -e "   🤖 AI Tools: ${GREEN}Available${NC}"
		else
			echo -e "   🤖 AI Tools: ${YELLOW}Not Found${NC}"
		fi

	else
		echo -e "   ❌ Automation: ${RED}Not Deployed${NC}"
	fi
	echo ""
}

run_project_automation() {
	local project_name=$1
	local project_path=$2

	echo -e "${PURPLE}🔧 Running automation for $project_name...${NC}"

	if [[ -f "$project_path/Tools/Automation/master_automation.sh" ]]; then
		cd "$project_path"
		./Tools/Automation/master_automation.sh status
		echo ""
	else
		echo -e "   ${RED}❌ Master automation script not found${NC}"
		echo ""
	fi
}

test_mcp_integration() {
	local project_name=$1
	local project_path=$2

	echo -e "${CYAN}🔗 Testing MCP integration for $project_name...${NC}"

	if [[ -f "$project_path/Tools/Automation/project_config.sh" ]]; then
		cd "$project_path"
		/Users/danielstevens/Desktop/Code/Tools/Automation/simple_mcp_check.sh "$project_name"
		echo ""
	else
		echo -e "   ${RED}❌ Project automation not found${NC}"
		echo ""
	fi
}

show_unified_status() {
	print_header

	echo -e "${YELLOW}📊 Overall Project Status${NC}"
	echo ""

	for project in "${PROJECTS[@]}"; do
		case $project in
		"CodingReviewer")
			print_project_status "$project" "$CODINGREVIEWER_PATH"
			;;
		"HabitQuest")
			print_project_status "$project" "$HABITQUEST_PATH"
			;;
		"MomentumFinance")
			print_project_status "$project" "$MOMENTUMFINANCE_PATH"
			;;
		esac
	done
}

run_all_automation() {
	echo -e "${GREEN}🚀 Running automation on all projects...${NC}"
	echo ""

	run_project_automation "CodingReviewer" "$CODINGREVIEWER_PATH"
	run_project_automation "HabitQuest" "$HABITQUEST_PATH"
	run_project_automation "MomentumFinance" "$MOMENTUMFINANCE_PATH"
}

test_all_mcp() {
	echo -e "${CYAN}🔗 Testing MCP integration on all projects...${NC}"
	echo ""

	test_mcp_integration "CodingReviewer" "$CODINGREVIEWER_PATH"
	test_mcp_integration "HabitQuest" "$HABITQUEST_PATH"
	test_mcp_integration "MomentumFinance" "$MOMENTUMFINANCE_PATH"
}

show_help() {
	echo "Multi-Project Dashboard Usage:"
	echo "  $0 status           # Show status of all projects"
	echo "  $0 run-all          # Run automation on all projects"
	echo "  $0 test-mcp         # Test MCP integration on all projects"
	echo "  $0 project <name>   # Focus on specific project"
	echo ""
	echo "Available projects: CodingReviewer, HabitQuest, MomentumFinance"
}

# Main execution
case "${1:-status}" in
"status")
	show_unified_status
	;;
"run-all")
	run_all_automation
	;;
"test-mcp")
	test_all_mcp
	;;
"project")
	if [[ -n $2 ]]; then
		case "$2" in
		"CodingReviewer")
			print_project_status "$2" "$CODINGREVIEWER_PATH"
			run_project_automation "$2" "$CODINGREVIEWER_PATH"
			;;
		"HabitQuest")
			print_project_status "$2" "$HABITQUEST_PATH"
			run_project_automation "$2" "$HABITQUEST_PATH"
			;;
		"MomentumFinance")
			print_project_status "$2" "$MOMENTUMFINANCE_PATH"
			run_project_automation "$2" "$MOMENTUMFINANCE_PATH"
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
"help" | "--help" | "-h")
	show_help
	;;
*)
	echo "Unknown command: $1"
	show_help
	;;
esac
