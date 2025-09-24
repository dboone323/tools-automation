#!/bin/bash

# Unified Master Automation Controller for Quantum-workspace
# Consolidates all automation functionality across projects

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

# Quantum enhancement features
QUANTUM_MODE="${QUANTUM_MODE:-true}"
AI_ORCHESTRATION="${AI_ORCHESTRATION:-true}"
CROSS_PROJECT_DEPS="${CROSS_PROJECT_DEPS:-true}"

# Load shared automation library if available
SHARED_LIB="${TOOLS_DIR}/Automation/lib/automation_lib.sh"
if [[ -f "$SHARED_LIB" ]]; then
    # shellcheck source=/dev/null
    source "$SHARED_LIB"
fi

# Output functions
print_header() {
    echo -e "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC}              🚀 QUANTUM WORKSPACE - MASTER AUTOMATION                ${CYAN}║${NC}"
    echo -e "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

print_section() {
    echo -e "${BLUE}📋 $1${NC}"
    echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
}

print_status() {
    echo -e "${BLUE}[AUTOMATION]${NC} $1"
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

print_quantum() {
    echo -e "${PURPLE}⚛️  $1${NC}"
}

# Export TODOs as JSON for agent/automation integration
export_todos_json() {
    if [[ -f "${TOOLS_DIR}/Automation/export_todos_json.sh" ]]; then
        bash "${TOOLS_DIR}/Automation/export_todos_json.sh"
    fi
}

# List available projects with status
list_projects() {
    print_section "Available Projects"
    for project in "${PROJECTS_DIR}"/*; do
        if [[ -d "$project" ]]; then
            local project_name
            project_name=$(basename "$project")
            local swift_files
            swift_files=$(find "$project" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
            local has_automation=""
            local has_tests=""
            local has_docs=""

            if [[ -d "${project}/automation" ]] || [[ -f "${project}/automation/run_automation.sh" ]]; then
                has_automation=" (✅ automation)"
            else
                has_automation=" (❌ no automation)"
            fi

            if find "$project" -name "*Test*.swift" -o -name "*Tests.swift" | grep -q .; then
                has_tests=" (🧪 tests)"
            fi

            if [[ -d "${DOCS_DIR}/API/${project_name}_API.md" ]] || [[ -f "${project}/README.md" ]]; then
                has_docs=" (📚 docs)"
            fi

            echo "  • ${project_name}: ${swift_files} Swift files${has_automation}${has_tests}${has_docs}"
        fi
    done
    echo ""
}

# Show unified architecture status
show_status() {
    print_section "Quantum Workspace Status"

    echo "📍 Location: ${WORKSPACE_ROOT}"
    echo "📊 Projects: $(find "${PROJECTS_DIR}" -maxdepth 1 -type d | tail -n +2 | wc -l | tr -d ' ')"

    # Check tool availability
    echo ""
    print_section "Development Tools"
    check_tool "xcodebuild" "Xcode Build System"
    check_tool "swift" "Swift Compiler"
    check_tool "swiftlint" "SwiftLint"
    check_tool "swiftformat" "SwiftFormat"
    check_tool "fastlane" "Fastlane"
    check_tool "pod" "CocoaPods"
    check_tool "git" "Git"
    check_tool "python3" "Python"
    check_tool "node" "Node.js"
    check_tool "npm" "NPM"

    echo ""
    list_projects
}

# Check if a tool is available
check_tool() {
    local tool="$1"
    local description="$2"
    if command -v "$tool" &>/dev/null; then
        local version=""
        case "$tool" in
            "swift") version=" ($($tool --version 2>/dev/null | head -1 | cut -d' ' -f3 || echo "unknown"))" ;;
            "python3") version=" ($($tool --version 2>&1 | head -1 | cut -d' ' -f2 || echo "unknown"))" ;;
            "node") version=" ($($tool --version 2>/dev/null || echo "unknown"))" ;;
            "npm") version=" ($($tool --version 2>/dev/null || echo "unknown"))" ;;
        esac
        echo -e "  ✅ ${GREEN}${description}${NC}${version}"
    else
        echo -e "  ❌ ${RED}${description}${NC} (not installed)"
    fi
}

# Run automation for specific project
run_project_automation() {
    local project_name="$1"
    local project_path="${PROJECTS_DIR}/${project_name}"

    if [[ ! -d "$project_path" ]]; then
        print_error "Project $project_name not found"
        return 1
    fi

    print_status "Running automation for $project_name..."

    # Try project-specific automation first
    if [[ -f "${project_path}/automation/run_automation.sh" ]]; then
        cd "$project_path" && bash automation/run_automation.sh
        print_success "$project_name automation completed"
    # Try enhanced workflow
    elif [[ -f "${TOOLS_DIR}/Automation/enhanced_workflow.sh" ]]; then
        bash "${TOOLS_DIR}/Automation/enhanced_workflow.sh" "pre-commit" "$project_name"
        print_success "$project_name enhanced workflow completed"
    else
        print_warning "No automation script found for $project_name - running basic checks"
        run_basic_checks "$project_name"
    fi
}

# Run automation for all projects
run_all_automation() {
    print_section "Running Automation for All Projects"

    for project in "${PROJECTS_DIR}"/*; do
        if [[ -d "$project" ]]; then
            local project_name
            project_name=$(basename "$project")

            # Skip non-project directories
            if [[ "$project_name" == "Tools" || "$project_name" == "scripts" || "$project_name" == "Config" ]]; then
                continue
            fi

            print_status "Processing $project_name..."
            if run_project_automation "$project_name"; then
                print_success "$project_name completed successfully"
            else
                print_warning "$project_name had issues (continuing...)"
            fi
            echo ""
        fi
    done

    print_success "All project automations completed"
}

# Run basic checks (lint, format, build) for a project
run_basic_checks() {
    local project_name="$1"
    local project_path="${PROJECTS_DIR}/${project_name}"

    cd "$project_path"

    # Format code
    if command -v swiftformat &>/dev/null; then
        print_status "Formatting $project_name..."
        swiftformat . --exclude "*.backup" 2>/dev/null || true
    fi

    # Lint code
    if command -v swiftlint &>/dev/null; then
        print_status "Linting $project_name..."
        swiftlint || print_warning "Linting found issues in $project_name"
    fi

    # Build project
    if [[ -f "${project_name}.xcodeproj/project.pbxproj" ]]; then
        print_status "Building $project_name..."
        xcodebuild -project "${project_name}.xcodeproj" -scheme "$project_name" -configuration Debug build || print_warning "Build failed for $project_name"
    fi
}

# Format code using SwiftFormat
format_code() {
    local project_name="${1:-}"

    if [[ -n "$project_name" ]]; then
        local project_path="${PROJECTS_DIR}/${project_name}"
        if [[ ! -d "$project_path" ]]; then
            print_error "Project $project_name not found"
            return 1
        fi
        print_status "Formatting Swift code in $project_name..."
        swiftformat "$project_path" --exclude "*.backup" 2>/dev/null
        print_success "Code formatting completed for $project_name"
    else
        print_status "Formatting Swift code in all projects..."
        for project in "${PROJECTS_DIR}"/*; do
            if [[ -d "$project" ]]; then
                local project_name
                project_name=$(basename "$project")
                if [[ "$project_name" != "Tools" && "$project_name" != "scripts" && "$project_name" != "Config" ]]; then
                    print_status "Formatting $project_name..."
                    swiftformat "$project" --exclude "*.backup" 2>/dev/null
                fi
            fi
        done
        print_success "Code formatting completed for all projects"
    fi
}

# Lint code using SwiftLint
lint_code() {
    local project_name="${1:-}"

    if [[ -n "$project_name" ]]; then
        local project_path="${PROJECTS_DIR}/${project_name}"
        if [[ ! -d "$project_path" ]]; then
            print_error "Project $project_name not found"
            return 1
        fi
        print_status "Linting Swift code in $project_name..."
        cd "$project_path" && swiftlint
        print_success "Code linting completed for $project_name"
    else
        print_status "Linting Swift code in all projects..."
        for project in "${PROJECTS_DIR}"/*; do
            if [[ -d "$project" ]]; then
                local project_name
                project_name=$(basename "$project")
                if [[ "$project_name" != "Tools" && "$project_name" != "scripts" && "$project_name" != "Config" ]]; then
                    print_status "Linting $project_name..."
                    cd "$project" && swiftlint
                fi
            fi
        done
        print_success "Code linting completed for all projects"
    fi
}

# Initialize CocoaPods for a project
init_pods() {
    local project_name="$1"
    local project_path="${PROJECTS_DIR}/${project_name}"

    if [[ ! -d "$project_path" ]]; then
        print_error "Project $project_name not found"
        return 1
    fi

    print_status "Initializing CocoaPods for $project_name..."
    cd "$project_path"

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

    if [[ ! -d "$project_path" ]]; then
        print_error "Project $project_name not found"
        return 1
    fi

    print_status "Setting up Fastlane for $project_name..."
    cd "$project_path"

    if [[ ! -d "fastlane" ]]; then
        print_status "Initializing Fastlane..."
        fastlane init
        print_success "Fastlane initialized"
    else
        print_status "Fastlane already configured"
    fi
}

# Main execution
main() {
    # Export TODOs for integration
    export_todos_json

    case "${1:-}" in
        "list")
            list_projects
            ;;
        "run")
            if [[ -n "${2:-}" ]]; then
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
            if [[ -n "${2:-}" ]]; then
                init_pods "$2"
            else
                echo "Usage: $0 pods <project_name>"
                list_projects
                exit 1
            fi
            ;;
        "fastlane")
            if [[ -n "${2:-}" ]]; then
                init_fastlane "$2"
            else
                echo "Usage: $0 fastlane <project_name>"
                list_projects
                exit 1
            fi
            ;;
        "workflow")
            if [[ -n "${2:-}" ]] && [[ -n "${3:-}" ]]; then
                "${TOOLS_DIR}/Automation/enhanced_workflow.sh" "$2" "$3"
            else
                echo "Usage: $0 workflow <command> <project_name>"
                echo "Available workflow commands: pre-commit, ios-setup, qa, deps"
                exit 1
            fi
            ;;
        "dashboard")
            "${TOOLS_DIR}/Automation/workflow_dashboard.sh"
            ;;
        "unified")
            "${TOOLS_DIR}/Automation/unified_dashboard.sh"
            ;;
        "docs")
            if [[ -n "${2:-}" ]]; then
                case "${2}" in
                    "api")
                        if [[ -n "${3:-}" ]]; then
                            "${TOOLS_DIR}/Automation/docs_automation.sh" api "$3"
                        else
                            echo "Usage: $0 docs api <project_name>"
                            exit 1
                        fi
                        ;;
                    "tutorial")
                        if [[ -n "${3:-}" ]]; then
                            "${TOOLS_DIR}/Automation/docs_automation.sh" tutorial "$3"
                        else
                            echo "Usage: $0 docs tutorial <tutorial_name>"
                            exit 1
                        fi
                        ;;
                    "examples")
                        "${TOOLS_DIR}/Automation/docs_automation.sh" examples
                        ;;
                    "all")
                        "${TOOLS_DIR}/Automation/docs_automation.sh" all
                        ;;
                    "index")
                        "${TOOLS_DIR}/Automation/docs_automation.sh" index
                        ;;
                    *)
                        echo "Usage: $0 docs {api <project>|tutorial <name>|examples|all|index}"
                        exit 1
                        ;;
                esac
            else
                echo "Usage: $0 docs {api <project>|tutorial <name>|examples|all|index}"
                exit 1
            fi
            ;;
        "mcp")
            if [[ -n "${2:-}" ]]; then
                if [[ "${2}" == "status" || "${2}" == "autofix-all" ]]; then
                    "${TOOLS_DIR}/Automation/mcp_workflow.sh" "$2"
                elif [[ -n "${3:-}" ]]; then
                    "${TOOLS_DIR}/Automation/mcp_workflow.sh" "$2" "$3"
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
            if [[ -n "${2:-}" ]]; then
                "${TOOLS_DIR}/Automation/intelligent_autofix.sh" fix "$2"
            else
                "${TOOLS_DIR}/Automation/intelligent_autofix.sh" fix-all
            fi
            ;;
        "validate")
            if [[ -n "${2:-}" ]]; then
                "${TOOLS_DIR}/Automation/intelligent_autofix.sh" validate "$2"
            else
                echo "Usage: $0 validate <project_name>"
                exit 1
            fi
            ;;
        "rollback")
            if [[ -n "${2:-}" ]]; then
                "${TOOLS_DIR}/Automation/intelligent_autofix.sh" rollback "$2"
            else
                echo "Usage: $0 rollback <project_name>"
                exit 1
            fi
            ;;
        "enhance")
            if [[ -n "${2:-}" ]]; then
                if [[ "${2}" == "analyze-all" || "${2}" == "auto-apply-all" || "${2}" == "report" || "${2}" == "status" ]]; then
                    "${TOOLS_DIR}/Automation/ai_enhancement_system.sh" "$2"
                elif [[ -n "${3:-}" ]]; then
                    "${TOOLS_DIR}/Automation/ai_enhancement_system.sh" "$2" "$3"
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
        "quantum")
            if [[ "$QUANTUM_MODE" == "true" ]]; then
                print_quantum "Activating Quantum Enhancement Mode"
                "${TOOLS_DIR}/Automation/universal_workflow_manager.sh" "$@"
            else
                print_warning "Quantum mode is disabled"
            fi
            ;;
        *)
            print_header
            echo "🏗️  Quantum Workspace - Unified Master Automation Controller"
            echo ""
            echo "Usage: $0 {list|run <project>|all|status|format [project]|lint [project]|pods <project>|fastlane <project>|workflow <command> <project>|mcp <command> <project>|autofix [project]|validate <project>|rollback <project>|enhance <command> [project]|dashboard|unified|docs <command>|quantum <command>}"
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
            echo "  mcp <cmd> <proj>       # MCP GitHub workflow integration"
            echo "  autofix [project]      # Run intelligent auto-fix with safety checks"
            echo "  validate <project>     # Run comprehensive validation checks"
            echo "  rollback <project>     # Rollback last auto-fix if backup exists"
            echo "  enhance <cmd> [proj]   # AI-powered enhancement system"
            echo "  dashboard              # Show comprehensive workflow status dashboard"
            echo "  unified                # Show unified workflow status across all projects"
            echo "  docs <command>         # Documentation automation"
            echo "  quantum <command>      # Quantum enhancement mode (advanced features)"
            echo ""
            exit 1
            ;;
    esac
}

# Run main function with all arguments
main "$@"