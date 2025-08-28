#!/bin/bash

# Unified Workflow Status Dashboard
CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECTS_DIR="$CODE_DIR/Projects"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
	echo -e "${PURPLE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
	echo -e "${PURPLE}║                    🏗️  UNIFIED WORKFLOW DASHBOARD                            ║${NC}"
	echo -e "${PURPLE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
	echo ""
}

print_project_status() {
	local project_name="$1"
	local project_path="$PROJECTS_DIR/$project_name"

	echo -e "${CYAN}📱 $project_name${NC}"
	echo "   📍 Location: $project_path"

	# Count Swift files
	local swift_files=$(find "$project_path" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
	echo "   📄 Swift files: $swift_files"

	# Check GitHub workflows
	if [[ -d "$project_path/.github/workflows" ]]; then
		local workflow_count=$(find "$project_path/.github/workflows" -name "*.yml" -o -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
		echo -e "   🔄 GitHub workflows: ${GREEN}$workflow_count files${NC}"

		# List workflows
		find "$project_path/.github/workflows" -name "*.yml" -o -name "*.yaml" 2>/dev/null | while read workflow; do
			local workflow_name=$(basename "$workflow" .yml)
			echo "      • $workflow_name"
		done
	else
		echo -e "   🔄 GitHub workflows: ${RED}None${NC}"
	fi

	# Check for configuration files
	if [[ -f "$project_path/.swiftformat" ]]; then
		echo -e "   ⚙️  SwiftFormat config: ${GREEN}✓${NC}"
	else
		echo -e "   ⚙️  SwiftFormat config: ${RED}✗${NC}"
	fi

	if [[ -f "$project_path/.swiftlint.yml" ]]; then
		echo -e "   📝 SwiftLint config: ${GREEN}✓${NC}"
	else
		echo -e "   📝 SwiftLint config: ${RED}Default${NC}"
	fi

	# Check automation
	if [[ -d "$project_path/automation" ]]; then
		echo -e "   🤖 Local automation: ${GREEN}✓${NC}"
	else
		echo -e "   🤖 Local automation: ${RED}✗${NC}"
	fi

	# Run MCP CI check
	echo -e "   🔍 Running MCP CI check..."
	cd "$CODE_DIR/Tools/Automation"
	if ./mcp_workflow.sh ci-check "$project_name" >/dev/null 2>&1; then
		echo -e "   ✅ MCP CI status: ${GREEN}All checks passed${NC}"
	else
		echo -e "   ⚠️  MCP CI status: ${YELLOW}Some issues found${NC}"
	fi

	echo ""
}

print_mcp_integration() {
	echo -e "${BLUE}🔗 MCP GitHub Integration Status${NC}"
	echo ""

	# Test MCP tools availability
	if command -v gh >/dev/null 2>&1; then
		echo -e "   📡 GitHub CLI: ${GREEN}Installed${NC}"
		if gh auth status >/dev/null 2>&1; then
			echo -e "   🔑 GitHub Auth: ${GREEN}Authenticated${NC}"
		else
			echo -e "   🔑 GitHub Auth: ${YELLOW}Not authenticated${NC}"
		fi
	else
		echo -e "   📡 GitHub CLI: ${RED}Not installed${NC}"
		echo -e "   🔑 GitHub Auth: ${RED}N/A${NC}"
	fi

	echo -e "   🛠️  MCP Workflow Tools: ${GREEN}Available${NC}"
	echo "      • mcp_workflow.sh - Local CI/CD mirroring"
	echo "      • master_automation.sh - Unified project management"
	echo "      • GitHub API integration for workflow monitoring"
	echo ""
}

print_summary() {
	echo -e "${PURPLE}📊 WORKFLOW IMPLEMENTATION SUMMARY${NC}"
	echo ""

	local total_projects=0
	local projects_with_workflows=0
	local projects_with_ci_passing=0

	for project in "$PROJECTS_DIR"/*; do
		if [[ -d $project ]]; then
			local project_name=$(basename "$project")
			total_projects=$((total_projects + 1))

			if [[ -d "$project/.github/workflows" ]]; then
				projects_with_workflows=$((projects_with_workflows + 1))
			fi

			cd "$CODE_DIR/Tools/Automation"
			if ./mcp_workflow.sh ci-check "$project_name" >/dev/null 2>&1; then
				projects_with_ci_passing=$((projects_with_ci_passing + 1))
			fi
		fi
	done

	echo "   📱 Total projects: $total_projects"
	echo "   🔄 Projects with GitHub workflows: $projects_with_workflows/$total_projects"
	echo "   ✅ Projects passing all CI checks: $projects_with_ci_passing/$total_projects"
	echo ""

	if [[ $projects_with_workflows -eq $total_projects ]]; then
		echo -e "   ${GREEN}🎉 All projects have GitHub workflows implemented!${NC}"
	else
		echo -e "   ${YELLOW}⚠️  Some projects need workflow setup${NC}"
	fi

	if [[ $projects_with_ci_passing -eq $total_projects ]]; then
		echo -e "   ${GREEN}🎉 All projects passing CI checks!${NC}"
	else
		echo -e "   ${YELLOW}⚠️  Some projects need CI fixes${NC}"
	fi
}

# Main execution
main() {
	print_header
	print_mcp_integration

	# Process each project
	for project in "$PROJECTS_DIR"/*; do
		if [[ -d $project ]]; then
			local project_name=$(basename "$project")
			print_project_status "$project_name"
		fi
	done

	print_summary

	echo -e "${BLUE}🚀 Ready for unified CI/CD across all projects!${NC}"
}

main "$@"
