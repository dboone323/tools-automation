#!/bin/bash

# Unified Quantum Dashboard for Quantum-workspace
# Consolidates workflow_dashboard.sh and unified_dashboard.sh functionality

set -euo pipefail

# Workspace directories
WORKSPACE_ROOT="/Users/danielstevens/Desktop/Quantum-workspace"
PROJECTS_DIR="${WORKSPACE_ROOT}/Projects"
TOOLS_DIR="${WORKSPACE_ROOT}/Tools"
DOCS_DIR="${WORKSPACE_ROOT}/Documentation"

# Colors for consistent output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Output functions
print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              🚀 QUANTUM WORKSPACE DASHBOARD                           ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "${BLUE}📋 $1${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

print_status() {
    echo -e "${BLUE}[DASHBOARD]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
    echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
    echo -e "${RED}❌ $1${NC}"
}

# Check if a tool is available
check_tool() {
    local tool_name="$1"
    local tool_command="$2"

    if command -v "$tool_command" &>/dev/null; then
        local version=""
        case "$tool_command" in
            "swift") version=" ($($tool_command --version 2>/dev/null | head -1 | cut -d' ' -f3 || echo "unknown"))" ;;
            "python3") version=" ($($tool_command --version 2>&1 | head -1 | cut -d' ' -f2 || echo "unknown"))" ;;
            "node") version=" ($($tool_command --version 2>/dev/null || echo "unknown"))" ;;
            "npm") version=" ($($tool_command --version 2>/dev/null || echo "unknown"))" ;;
        esac
        echo -e "  ✅ ${GREEN}${tool_name}${NC}${version}"
    else
        echo -e "  ❌ ${RED}${tool_name}${NC} (not installed)"
    fi
}

# Check project status with detailed information
check_project_status() {
    local project_dir="$1"
    local project_name
    project_name=$(basename "$project_dir")

    cd "$project_dir"

    # Count files
    local swift_files
    swift_files=$(find . -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
    local test_files
    test_files=$(find . -name "*Test*.swift" -o -name "*test*.swift" 2>/dev/null | wc -l | tr -d ' ')
    local total_lines
    total_lines=$(find . -name "*.swift" -exec wc -l {} + 2>/dev/null | tail -1 | awk '{print $1}' || echo "0")

    # Git status
    local git_status="❌ No Git"
    local git_branch=""
    if git rev-parse --git-dir >/dev/null 2>&1; then
        git_branch=$(git branch --show-current 2>/dev/null || echo "unknown")
        local changes
        changes=$(git status --porcelain 2>/dev/null | wc -l | tr -d ' ')
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
            local violations
            violations=$(swiftlint --reporter json 2>/dev/null | grep -o '"severity":"warning"' | wc -l | tr -d ' ')
            local errors
            errors=$(swiftlint --reporter json 2>/dev/null | grep -o '"severity":"error"' | wc -l | tr -d ' ')
            if [[ $violations -gt 0 ]] || [[ $errors -gt 0 ]]; then
                lint_status="⚠️  $violations warnings, $errors errors"
            else
                lint_status="✅ Clean"
            fi
        fi
    fi

    # Build status
    local build_status="❓ Unknown"
    if [[ -f "*.xcodeproj/project.pbxproj" ]] || [[ -f "*.xcworkspace" ]]; then
        local scheme_name="$project_name"
        if xcodebuild -scheme "$scheme_name" -destination 'platform=macOS' build -quiet 2>/dev/null; then
            build_status="✅ Builds"
        else
            build_status="❌ Build fails"
        fi
    elif [[ -f "Package.swift" ]]; then
        if swift build -q 2>/dev/null; then
            build_status="✅ Builds"
        else
            build_status="❌ Build fails"
        fi
    fi

    # Automation status
    local automation_status="❌ None"
    if [[ -d "automation" ]] || [[ -f "automation/run_automation.sh" ]]; then
        automation_status="✅ Local"
    fi

    # GitHub workflows
    local workflow_status="❌ None"
    if [[ -d ".github/workflows" ]]; then
        local workflow_count
        workflow_count=$(find .github/workflows -name "*.yml" -o -name "*.yaml" 2>/dev/null | wc -l | tr -d ' ')
        workflow_status="✅ $workflow_count workflows"
    fi

    echo -e "  ${PURPLE}📁 $project_name${NC}"
    echo "     📊 Files: $swift_files Swift, $test_files tests, $total_lines lines"
    echo "     🌿 Git: $git_status$(if [[ -n $git_branch ]]; then echo " ($git_branch)"; fi)"
    echo "     🔍 Lint: $lint_status"
    echo "     🔨 Build: $build_status"
    echo "     🤖 Automation: $automation_status"
    echo "     🔄 CI/CD: $workflow_status"
    echo ""
}

# Show MCP integration status
show_mcp_integration() {
    print_section "MCP GitHub Integration Status"

    # Test MCP tools availability
    if command -v gh &>/dev/null; then
        echo -e "  📡 GitHub CLI: ${GREEN}Installed${NC}"
        if gh auth status &>/dev/null; then
            echo -e "  🔑 GitHub Auth: ${GREEN}Authenticated${NC}"
        else
            echo -e "  🔑 GitHub Auth: ${YELLOW}Not authenticated${NC}"
        fi
    else
        echo -e "  📡 GitHub CLI: ${RED}Not installed${NC}"
        echo -e "  🔑 GitHub Auth: ${RED}N/A${NC}"
    fi

    echo -e "  🛠️  MCP Workflow Tools: ${GREEN}Available${NC}"
    echo "     • mcp_workflow.sh - Local CI/CD mirroring"
    echo "     • master_automation_unified.sh - Unified project management"
    echo "     • GitHub API integration for workflow monitoring"
    echo ""
}

# Show workflow implementation summary
show_workflow_summary() {
    print_section "Workflow Implementation Summary"

    local total_projects=0
    local projects_with_workflows=0
    local projects_with_automation=0
    local projects_building=0
    local projects_clean_lint=0

    for project in "${PROJECTS_DIR}"/*; do
        if [[ -d "$project" ]]; then
            local project_name
            project_name=$(basename "$project")
            # Skip non-project directories
            if [[ "$project_name" == "Tools" ]] || [[ "$project_name" == "scripts" ]] || [[ "$project_name" == "Config" ]]; then
                continue
            fi

            total_projects=$((total_projects + 1))

            # Check workflows
            if [[ -d "${project}/.github/workflows" ]]; then
                projects_with_workflows=$((projects_with_workflows + 1))
            fi

            # Check automation
            if [[ -d "${project}/automation" ]] || [[ -f "${project}/automation/run_automation.sh" ]]; then
                projects_with_automation=$((projects_with_automation + 1))
            fi

            # Check build status
            cd "$project"
            if [[ -f "*.xcodeproj/project.pbxproj" ]] || [[ -f "*.xcworkspace" ]]; then
                local scheme_name="$project_name"
                if xcodebuild -scheme "$scheme_name" -destination 'platform=macOS' build -quiet 2>/dev/null; then
                    projects_building=$((projects_building + 1))
                fi
            elif [[ -f "Package.swift" ]]; then
                if swift build -q 2>/dev/null; then
                    projects_building=$((projects_building + 1))
                fi
            fi

            # Check lint status
            if command -v swiftlint &>/dev/null; then
                if swiftlint --quiet &>/dev/null; then
                    projects_clean_lint=$((projects_clean_lint + 1))
                fi
            fi
        fi
    done

    echo "  📱 Total projects: $total_projects"
    echo "  🔄 Projects with GitHub workflows: $projects_with_workflows/$total_projects"
    echo "  🤖 Projects with automation: $projects_with_automation/$total_projects"
    echo "  🔨 Projects building successfully: $projects_building/$total_projects"
    echo "  🔍 Projects with clean lint: $projects_clean_lint/$total_projects"
    echo ""

    # Overall status
    local overall_score=$((projects_with_workflows + projects_with_automation + projects_building + projects_clean_lint))
    local max_score=$((total_projects * 4))
    local percentage=$((overall_score * 100 / max_score))

    if [[ $percentage -ge 90 ]]; then
        echo -e "  🟢 ${GREEN}EXCELLENT${NC} - $percentage% workflow coverage"
    elif [[ $percentage -ge 75 ]]; then
        echo -e "  🟡 ${YELLOW}GOOD${NC} - $percentage% workflow coverage"
    elif [[ $percentage -ge 50 ]]; then
        echo -e "  🟠 ${YELLOW}FAIR${NC} - $percentage% workflow coverage"
    else
        echo -e "  🔴 ${RED}NEEDS ATTENTION${NC} - $percentage% workflow coverage"
    fi
    echo ""
}

# Show available commands
show_commands() {
    print_section "Available Commands"

    echo -e "  🔧 ${BLUE}Master Automation:${NC}"
    echo "     ./Tools/Automation/master_automation_unified.sh {list|run|all|status|format|lint|pods|fastlane|workflow|mcp|autofix|enhance|dashboard}"
    echo ""

    echo -e "  ⚡ ${BLUE}Workflow Manager:${NC}"
    echo "     ./Tools/Automation/workflow_manager_unified.sh {pre-commit|ios-setup|qa|deps|git-standardize} [project|all]"
    echo ""

    echo -e "  📊 ${BLUE}Dashboard:${NC}"
    echo "     ./Tools/Automation/dashboard_unified.sh (this command)"
    echo ""

    echo -e "  🤖 ${BLUE}AI Enhancement:${NC}"
    echo "     ./Tools/Automation/ai_enhancement_system.sh {analyze|auto-apply|report|status} [project]"
    echo ""
}

# Show quick actions
show_quick_actions() {
    print_section "Quick Actions"

    echo -e "  📝 Format all projects:     ${YELLOW}./Tools/Automation/master_automation_unified.sh format${NC}"
    echo -e "  🔍 Lint all projects:       ${YELLOW}./Tools/Automation/master_automation_unified.sh lint${NC}"
    echo -e "  🔨 Build all projects:      ${YELLOW}./Tools/Automation/master_automation_unified.sh all${NC}"
    echo -e "  📊 Architecture status:     ${YELLOW}./Tools/Automation/master_automation_unified.sh status${NC}"
    echo -e "  ⚡ Run QA on all projects:   ${YELLOW}./Tools/Automation/workflow_manager_unified.sh qa all${NC}"
    echo -e "  🔄 Update dependencies:     ${YELLOW}./Tools/Automation/workflow_manager_unified.sh deps all${NC}"
    echo ""
}

# Main dashboard function
show_dashboard() {
    print_header

    # Development Tools Status
    print_section "Development Tools Status"
    check_tool "Xcode Build System" "xcodebuild"
    check_tool "Swift Compiler" "swift"
    check_tool "SwiftLint" "swiftlint"
    check_tool "SwiftFormat" "swiftformat"
    check_tool "Fastlane" "fastlane"
    check_tool "CocoaPods" "pod"
    check_tool "Git" "git"
    check_tool "Python" "python3"
    check_tool "Node.js" "node"
    check_tool "NPM" "npm"
    check_tool "GitHub CLI" "gh"
    echo ""

    # MCP Integration Status
    show_mcp_integration

    # Projects Overview
    print_section "Projects Overview"

    local projects_found=0
    for project_dir in "${PROJECTS_DIR}"/*; do
        if [[ -d "$project_dir" ]]; then
            local project_name
            project_name=$(basename "$project_dir")
            # Skip non-project directories
            if [[ "$project_name" == "Tools" ]] || [[ "$project_name" == "scripts" ]] || [[ "$project_name" == "Config" ]]; then
                continue
            fi
            check_project_status "$project_dir"
            ((projects_found++))
        fi
    done

    if [[ $projects_found -eq 0 ]]; then
        echo "  ❌ No projects found in ${PROJECTS_DIR}/"
        echo ""
    fi

    # Workflow Summary
    show_workflow_summary

    # Commands and Actions
    show_commands
    show_quick_actions

    # Footer
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}📚 Documentation: ./Documentation/README.md${NC}"
    echo -e "${CYAN}🆘 Help: ./Tools/Automation/master_automation_unified.sh${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Main execution
case "${1:-}" in
    "summary")
        show_workflow_summary
        ;;
    "tools")
        print_section "Development Tools Status"
        check_tool "Xcode Build System" "xcodebuild"
        check_tool "Swift Compiler" "swift"
        check_tool "SwiftLint" "swiftlint"
        check_tool "SwiftFormat" "swiftformat"
        check_tool "Fastlane" "fastlane"
        check_tool "CocoaPods" "pod"
        check_tool "Git" "git"
        check_tool "Python" "python3"
        check_tool "Node.js" "node"
        check_tool "NPM" "npm"
        check_tool "GitHub CLI" "gh"
        ;;
    "mcp")
        show_mcp_integration
        ;;
    *)
        show_dashboard
        ;;
esac