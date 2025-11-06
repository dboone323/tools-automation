#!/bin/bash

# Master Automation Controller for Unified Code Architecture
# Enhanced with AI-Powered Ollama Integration
CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECTS_DIR="${CODE_DIR}/Projects"
WORKSPACE_ROOT="${CODE_DIR}"
DOCS_DIR="${CODE_DIR}/Documentation"

# Source AI-enhanced automation functions
if [[ -f "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ]]; then
    # shellcheck disable=SC1091  # Expected when analyzing individual files that source others
    source "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh"
fi

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
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

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_ai() {
    echo -e "${PURPLE}[🤖 AI-ENHANCED]${NC} $1"
}

print_section() {
    echo -e "${BLUE}=== $1 ===${NC}"
}

# Run a command under the agent monitoring wrapper
run_with_monitoring() {
    local name="$1"
    shift || true
    local agent_script_dir="${CODE_DIR}/Tools/Automation"
    local monitor_script="${agent_script_dir}/agent_monitoring.sh"
    mkdir -p "${agent_script_dir}/monitoring"
    if [[ -x "${monitor_script}" ]]; then
        # Use the monitoring wrapper which will run the command and collect logs
        "${monitor_script}" "${name}" "$@"
        return $?
    else
        # Fallback to direct execution
        "$@"
        return $?
    fi
}

# Enhanced status check with AI capabilities
status_with_ai() {
    print_status "Quantum Workspace Status with AI Enhancement"
    echo ""

    # Skip TODO export during status check for faster performance
    # TODO export can be run separately with: ./Tools/Automation/export_todos_json.sh
    # case "${STATUS_TODO_MODE:-limited}" in
    # off) ;;
    # limited)
    #   export TODO_EXPORT_FAST=1
    #   bash "${CODE_DIR}/Tools/Automation/export_todos_json.sh" || true
    #   ;;
    # full)
    #   bash "${CODE_DIR}/Tools/Automation/export_todos_json.sh" || true
    #   ;;
    # esac

    # Check Ollama health
    if command -v ollama &>/dev/null; then
        local ollama_version
        ollama_version=$(ollama --version 2>/dev/null | grep -o 'ollama version is [0-9.]*' | cut -d' ' -f4 || echo "unknown")
        print_ai "Ollama detected: v${ollama_version}"

        # Check server status
        if ollama list &>/dev/null; then
            local model_count
            model_count=$(ollama list | tail -n +2 | wc -l | tr -d ' ')
            print_ai "Ollama server running with ${model_count} models"

            # Check for cloud models
            local cloud_models
            cloud_models=$(ollama list | grep -c "cloud" || echo "0")
            if [[ ${cloud_models} -gt 0 ]]; then
                print_ai "Cloud models available: ${cloud_models}"
            fi
        else
            print_warning "Ollama server not running"
        fi
    else
        print_error "Ollama not installed"
    fi

    echo ""

    # Original status functionality
    list_projects_with_ai_insights
}

# Enhanced project listing with AI insights
list_projects_with_ai_insights() {
    print_status "Projects in Quantum workspace (AI-Enhanced):"

    local total_projects=0
    local ai_enhanced_projects=0
    local total_swift_files=0

    for project in "${PROJECTS_DIR}"/*; do
        if [[ -d ${project} ]]; then
            local project_name
            project_name=$(basename "${project}")
            local swift_files
            swift_files=$(find "${project}" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
            total_swift_files=$((total_swift_files + swift_files))
            total_projects=$((total_projects + 1))

            # Check for AI enhancements
            local ai_status=""
            local ai_file_count
            ai_file_count=$(find "${project}" -name "AI_*" -type f 2>/dev/null | wc -l | tr -d ' ')
            if [[ ${ai_file_count} -gt 0 ]]; then
                ai_status=" 🤖 AI Enhanced (${ai_file_count} files)"
                ai_enhanced_projects=$((ai_enhanced_projects + 1))
            elif compgen -G "${project}/Services/AIEnhanced*" >/dev/null; then
                ai_status=" 🤖 AI Integrated"
                ai_enhanced_projects=$((ai_enhanced_projects + 1))
            else
                ai_status=" 🤖 Ready for AI"
            fi

            # Check for automation
            local automation_status=""
            if [[ -d "${project}/automation" ]] || [[ -d "${project}/Tools/Automation" ]]; then
                automation_status=" ✅ automation"
            else
                automation_status=" ❌ no automation"
            fi

            echo "  📱 ${project_name}: ${swift_files} Swift files${automation_status}${ai_status}"

            # Quick AI insight if Ollama is available
            if command -v ollama &>/dev/null && ollama list &>/dev/null; then
                generate_quick_ai_insight "${project_name}" "${swift_files}"
            fi
        fi
    done

    echo ""
    print_ai "Summary: ${total_projects} projects, ${total_swift_files} Swift files, ${ai_enhanced_projects} AI-enhanced"
}

# Generate quick AI insight for a project
generate_quick_ai_insight() {
    local project_name="$1"
    local file_count="$2"

    if [[ ${file_count} -gt 0 ]]; then
        local insight_prompt="In one sentence, suggest the most valuable AI enhancement for a Swift project called '${project_name}' with ${file_count} files:"
        local ai_insight
        # Use Ollama adapter instead of direct calls
        local adapter_input
        adapter_input=$(jq -n \
            --arg task "dashboardSummary" \
            --arg prompt "$insight_prompt" \
            '{task: $task, prompt: $prompt}')
        ai_insight=$(echo "$adapter_input" | ./ollama_client.sh 2>/dev/null | jq -r '.text // "AI enhancement available"' 2>/dev/null | head -1 || echo "AI enhancement available")
        echo "     💡 ${ai_insight}"
    fi
}

# AI-enhanced project automation
run_project_automation_with_ai() {
    local project_name="$1"
    local project_path="${PROJECTS_DIR}/${project_name}"

    if [[ ! -d ${project_path} ]]; then
        print_error "Project ${project_name} not found"
        return 1
    fi

    print_ai "Running AI-enhanced automation for ${project_name}..."

    # Check if AI-enhanced automation is available
    if command -v ollama &>/dev/null && [[ -f "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ]]; then
        # Run AI-powered analysis under heavy monitoring
        print_ai "Performing AI analysis (monitored)..."
        run_with_monitoring "ai_enhanced" bash "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" analyze "${project_name}"

        # Generate missing components with AI (monitored)
        print_ai "Generating missing components (monitored)..."
        run_with_monitoring "ai_enhanced" bash "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" generate "${project_name}"

        # Perform AI code review (monitored)
        print_ai "Conducting AI code review (monitored)..."
        run_with_monitoring "ai_enhanced" bash "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" review "${project_name}"

        # Performance optimization analysis (monitored)
        print_ai "Analyzing performance optimizations (monitored)..."
        run_with_monitoring "ai_enhanced" bash "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" optimize "${project_name}"
    else
        print_warning "AI-enhanced automation not available, running standard automation"
    fi

    # Standard automation tasks
    run_standard_project_automation "${project_name}"

    # Generate AI summary report
    generate_ai_automation_summary "${project_name}"
}

# Standard project automation (existing functionality)
run_standard_project_automation() {
    local project_name="$1"
    local project_path="${PROJECTS_DIR}/${project_name}"

    print_status "Running standard automation for ${project_name}..."

    # Format code if SwiftFormat is available
    if command -v swiftformat &>/dev/null; then
        print_status "Formatting Swift code..."
        swiftformat "${project_path}" --config "${CODE_DIR}/.swiftformat" 2>/dev/null || true
    fi

    # Lint code if SwiftLint is available
    if command -v swiftlint &>/dev/null; then
        print_status "Linting Swift code..."
        if cd "${project_path}"; then
            # Run swiftlint with timeout to prevent hanging on problematic projects
            (
                swiftlint --quiet &
                pid=$!
                sleep 30
                if kill -0 $pid 2>/dev/null; then
                    kill $pid 2>/dev/null
                    print_warning "SwiftLint timed out for ${project_name}"
                fi
            ) &
            wait $!
        fi
    fi

    # Run project-specific automation if available
    if [[ -f "${project_path}/automation/run.sh" ]]; then
        print_status "Running project-specific automation..."
        bash "${project_path}/automation/run.sh" || print_warning "Project automation failed"
    fi
}

# Generate AI automation summary
generate_ai_automation_summary() {
    local project_name="$1"
    local project_path="${PROJECTS_DIR}/${project_name}"

    if command -v ollama &>/dev/null && ollama list &>/dev/null; then
        print_ai "Generating automation summary for ${project_name}..."

        # Gather automation results
        local ai_files
        ai_files=$(find "${project_path}" -name "AI_*" -type f | wc -l | tr -d ' ')
        local swift_files
        swift_files=$(find "${project_path}" -name "*.swift" | wc -l | tr -d ' ')

        local summary_prompt
        summary_prompt="Generate a brief automation summary for Swift project '${project_name}':
- Swift files: ${swift_files}
- AI analyses generated: ${ai_files}
- Automation completed: $(date)

Provide:
1. Key achievements
2. Next recommended actions
3. Priority items for development team

Keep it concise and actionable."

        local ai_summary
        # Use Ollama adapter instead of direct calls
        local adapter_input
        adapter_input=$(jq -n \
            --arg task "dashboardSummary" \
            --arg prompt "$summary_prompt" \
            '{task: $task, prompt: $prompt}')
        ai_summary=$(echo "$adapter_input" | ./ollama_client.sh 2>/dev/null | jq -r '.text // "Summary generation completed"' 2>/dev/null || echo "Summary generation completed")

        # Save summary
        local summary_file
        summary_file="${project_path}/AUTOMATION_SUMMARY_$(date +%Y%m%d).md"
        {
            echo "# Automation Summary for ${project_name}"
            echo "Generated: $(date)"
            echo ""
            echo "${ai_summary}"
        } >"${summary_file}"

        print_success "Automation summary saved to ${summary_file}"
    fi
}

# AI-enhanced automation for all projects
run_all_projects_with_ai() {
    print_ai "Running AI-enhanced automation for ALL projects..."

    # Check prerequisites
    if ! command -v ollama &>/dev/null; then
        print_error "Ollama not found. Install Ollama to use AI enhancements."
        return 1
    fi

    if ! ollama list &>/dev/null; then
        print_warning "Starting Ollama server..."
        ollama serve &
        sleep 5
    fi

    local processed_projects=0
    local successful_projects=0

    for project in "${PROJECTS_DIR}"/*; do
        if [[ -d ${project} ]]; then
            local project_name
            project_name=$(basename "${project}")
            local swift_files
            swift_files=$(find "${project}" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')

            if [[ ${swift_files} -gt 0 ]]; then
                print_ai "Processing ${project_name} (${swift_files} Swift files)..."

                if run_project_automation_with_ai "${project_name}"; then
                    successful_projects=$((successful_projects + 1))
                fi

                processed_projects=$((processed_projects + 1))
                echo ""
            else
                print_warning "Skipping ${project_name} (no Swift files)"
            fi
        fi
    done

    # Generate workspace-wide AI insights
    generate_workspace_ai_insights "${processed_projects}" "${successful_projects}"

    print_ai "AI-enhanced automation completed: ${successful_projects}/${processed_projects} projects successful"
}

# Generate workspace-wide AI insights
generate_workspace_ai_insights() {
    local processed="$1"
    local successful="$2"

    print_ai "Generating workspace-wide AI insights..."

    if command -v ollama &>/dev/null && ollama list &>/dev/null; then
        local insights_prompt
        insights_prompt="Generate workspace-wide insights for Quantum development workspace:

Projects processed: ${processed}
Successfully enhanced: ${successful}
Total AI analyses: $(find "${PROJECTS_DIR}" -name "AI_*" | wc -l)
Workspace structure: CodingReviewer, PlannerApp, AvoidObstaclesGame, MomentumFinance, HabitQuest

Provide:
1. Overall workspace health assessment
2. Cross-project integration opportunities
3. Shared component recommendations
4. Development workflow optimizations
5. AI integration strategy for maximum impact

Focus on actionable insights for the development team."

        local workspace_insights
        # Use Ollama adapter instead of direct calls
        local adapter_input
        adapter_input=$(jq -n \
            --arg task "dashboardSummary" \
            --arg prompt "$insights_prompt" \
            '{task: $task, prompt: $prompt}')
        workspace_insights=$(echo "$adapter_input" | ./ollama_client.sh 2>/dev/null | jq -r '.text // "Workspace analysis completed"' 2>/dev/null || echo "Workspace analysis completed")

        # Save workspace insights
        local insights_file
        insights_file="${CODE_DIR}/WORKSPACE_AI_INSIGHTS_$(date +%Y%m%d).md"
        {
            echo "# Quantum Workspace AI Insights"
            echo "Generated: $(date)"
            echo ""
            echo "${workspace_insights}"
            echo ""
            echo "## Automation Statistics"
            echo "- Projects processed: ${processed}"
            echo "- Successfully enhanced: ${successful}"
            echo "- AI analyses generated: $(find "${PROJECTS_DIR}" -name "AI_*" | wc -l)"
        } >"${insights_file}"

        print_success "Workspace AI insights saved to ${insights_file}"
    fi
}

# Show enhanced usage
show_enhanced_usage() {
    echo "AI-Enhanced Master Automation Controller for Quantum Workspace"
    echo ""
    echo "Usage: $0 [command] [project_name]"
    echo ""
    echo "Standard Commands:"
    echo "  status          - Show workspace status with AI insights"
    echo "  list            - List all projects with AI enhancement status"
    echo "  run <name>      - Run AI-enhanced automation for specific project"
    echo "  all             - Run AI-enhanced automation for all projects"
    echo ""
    echo "AI Commands:"
    echo "  ai-status       - Check Ollama health and available models"
    echo "  ai-analyze <name> - AI analysis of specific project"
    echo "  ai-review <name>  - AI code review of specific project"
    echo "  ai-optimize <name> - AI performance optimization analysis"
    echo "  ai-generate <name> - Generate missing components with AI"
    echo "  ai-docs [project] - AI documentation generation (all projects if no arg)"
    echo "  ai-code-review [project] - AI code review (all projects if no arg)"
    echo "  ai-predictive   - AI predictive analytics for timelines/bottlenecks"
    echo "  ai-agents       - Run complete AI agent suite (docs + review + predictive)"
    echo "  ai-all          - Run full AI enhancement for all projects"
    echo ""
    echo "Integration Commands:"
    echo "  setup-ai        - Set up AI integration for workspace"
    echo "  update-models   - Update/pull latest Ollama models"
    echo "  ai-insights     - Generate workspace-wide AI insights"
    echo ""
    echo "Advanced Analytics:"
    echo "  analytics       - Run advanced predictive analytics engine"
    echo "  code-health     - Generate code health metrics JSON"
    echo ""
    echo "Security & Compliance:"
    echo "  security-audit    - Run enhanced Phase 6 security audit with compliance checks"
    echo "  security-scan [project] - Run vulnerability scanning (all projects if no arg)"
    echo "  compliance-check [project] - Run compliance validation (all projects if no arg)"
    echo "  audit-trail     - Generate comprehensive audit trail report"
    echo "  encryption-status - Check encryption configuration status"
    echo "  security-all    - Run complete security & compliance suite"
    echo ""
    echo "Workspace Management:"
    echo "  workspace       - Validate workspace configuration integrity"
    echo "  prevent-duplicates - Run comprehensive workspace duplication prevention"
    echo ""
    echo "Maintenance Commands:"
    echo "  cleanup         - Run retention policy cleanup (5-backup rule)"
    echo "  retention       - Alias for cleanup command"
    echo ""
    echo "Developer Productivity:"
    echo "  generate-tests [project] - Generate XCTest skeletons (to AutoTests/)"
    echo ""
    echo "Examples:"
    echo "  $0 status"
    echo "  $0 ai-all"
    echo "  $0 run CodingReviewer"
    echo "  $0 ai-analyze PlannerApp"
}

# Set up AI integration for the workspace
setup_ai_integration() {
    print_ai "Setting up AI integration for Quantum workspace..."

    # Check Ollama installation
    if ! command -v ollama &>/dev/null; then
        print_error "Ollama not found. Please install Ollama v0.12+"
        echo "Install with: brew install ollama"
        return 1
    fi

    # Start Ollama server if not running
    if ! ollama list &>/dev/null; then
        print_ai "Starting Ollama server..."
        ollama serve &
        sleep 5
    fi

    # Pull essential models (local models only)
    local essential_models=("llama3.2:3b" "codellama:7b" "mistral:7b")

    for model in "${essential_models[@]}"; do
        print_ai "Checking model: ${model}"
        if ! ollama list | grep -q "${model}"; then
            if [[ ${model} == *"-cloud" ]]; then
                print_ai "Cloud model ${model} will be pulled on first use"
            else
                print_ai "Pulling model: ${model}"
                ollama pull "${model}" || print_warning "Failed to pull ${model}"
            fi
        else
            print_success "Model ${model} already available"
        fi
    done

    # Make AI-enhanced automation executable
    chmod +x "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" 2>/dev/null || true

    print_success "AI integration setup completed"
}

# Update Ollama models
update_ollama_models() {
    print_ai "Updating Ollama models..."

    if ! command -v ollama &>/dev/null; then
        print_error "Ollama not found"
        return 1
    fi

    # Get list of current models
    local current_models
    current_models=$(ollama list | tail -n +2 | awk '{print $1}' | grep -v "cloud")

    for model in ${current_models}; do
        print_ai "Updating model: ${model}"
        ollama pull "${model}" || print_warning "Failed to update ${model}"
    done

    print_success "Model updates completed"
}

# Format code using SwiftFormat
format_code() {
    local project_name="${1-}"

    if [[ -n ${project_name} ]]; then
        local project_path="${PROJECTS_DIR}/${project_name}"
        if [[ ! -d ${project_path} ]]; then
            print_error "Project ${project_name} not found"
            return 1
        fi
        print_status "Formatting Swift code in ${project_name}..."
        swiftformat "${project_path}" --exclude "*.backup" 2>/dev/null
        print_success "Code formatting completed for ${project_name}"
    else
        print_status "Formatting Swift code in all projects..."
        for project in "${PROJECTS_DIR}"/*; do
            if [[ -d ${project} ]]; then
                local project_name
                project_name=$(basename "${project}")
                if [[ ${project_name} != "Tools" && ${project_name} != "scripts" && ${project_name} != "Config" ]]; then
                    print_status "Formatting ${project_name}..."
                    swiftformat "${project}" --exclude "*.backup" 2>/dev/null
                fi
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
            print_error "Project ${project_name} not found"
            return 1
        fi
        print_status "Linting Swift code in ${project_name}..."
        cd "${project_path}" && swiftlint
        print_success "Code linting completed for ${project_name}"
    else
        print_status "Linting Swift code in all projects..."
        for project in "${PROJECTS_DIR}"/*; do
            if [[ -d ${project} ]]; then
                local project_name
                project_name=$(basename "${project}")
                if [[ ${project_name} != "Tools" && ${project_name} != "scripts" && ${project_name} != "Config" ]]; then
                    print_status "Linting ${project_name}..."
                    cd "${project}" && swiftlint
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

    if [[ ! -d ${project_path} ]]; then
        print_error "Project ${project_name} not found"
        return 1
    fi

    print_status "Initializing CocoaPods for ${project_name}..."
    cd "${project_path}" || return 1

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
        print_error "Project ${project_name} not found"
        return 1
    fi

    print_status "Setting up Fastlane for ${project_name}..."
    cd "${project_path}" || return 1

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
    if command -v "${tool}" &>/dev/null; then
        local version=""
        case "${tool}" in
        "swift") version=" ($(${tool} --version 2>/dev/null | head -1 | cut -d' ' -f3 || echo "unknown"))" ;;
        "python3") version=" ($(${tool} --version 2>&1 | head -1 | cut -d' ' -f2 || echo "unknown"))" ;;
        "node") version=" ($(${tool} --version 2>/dev/null || echo "unknown"))" ;;
        "npm") version=" ($(${tool} --version 2>/dev/null || echo "unknown"))" ;;
        esac
        echo -e "  ✅ ${GREEN}${description}${NC}${version}"
    else
        echo -e "  ❌ ${RED}${description}${NC} (not installed)"
    fi
}

list_projects() {
    print_section "Available Projects"
    for project in "${PROJECTS_DIR}"/*; do
        if [[ -d ${project} ]]; then
            local project_name
            project_name=$(basename "${project}")
            local swift_files
            swift_files=$(find "${project}" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
            local has_automation=""
            local has_tests=""
            local has_docs=""

            if [[ -d "${project}/automation" ]] || [[ -f "${project}/automation/run_automation.sh" ]]; then
                has_automation=" (✅ automation)"
            else
                has_automation=" (❌ no automation)"
            fi

            if find "${project}" -name "*Test*.swift" -o -name "*Tests.swift" | grep -q .; then
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

# Run retention policy cleanup
run_retention_policy() {
    print_status "Running retention policy cleanup..."

    local retention_script="${CODE_DIR}/retention_policy_manager.sh"

    if [[ ! -f ${retention_script} ]]; then
        print_error "Retention policy script not found at: ${retention_script}"
        return 1
    fi

    if [[ ! -x ${retention_script} ]]; then
        print_warning "Making retention policy script executable..."
        chmod +x "${retention_script}"
    fi

    print_status "Executing retention policy cleanup..."
    if bash "${retention_script}"; then
        print_success "Retention policy cleanup completed successfully"
    else
        print_error "Retention policy cleanup failed"
        return 1
    fi
}

# Run advanced predictive analytics
run_advanced_analytics() {
    print_status "Running Advanced Predictive Analytics Engine..."

    local analytics_script="${CODE_DIR}/Tools/run_advanced_analytics.sh"

    if [[ ! -f ${analytics_script} ]]; then
        print_error "Advanced analytics script not found at: ${analytics_script}"
        return 1
    fi

    if [[ ! -x ${analytics_script} ]]; then
        print_warning "Making analytics script executable..."
        chmod +x "${analytics_script}"
    fi

    print_status "Executing advanced predictive analytics..."
    if bash "${analytics_script}"; then
        print_success "Advanced predictive analytics completed successfully"
    else
        print_error "Advanced predictive analytics failed"
        return 1
    fi
}

# Validate workspace configuration integrity
validate_workspace_configuration() {
    print_section "Workspace Configuration Validation"

    local workspace_file="${WORKSPACE_ROOT}/Code.code-workspace"
    local issues_found=0

    # Check if primary workspace file exists
    if [[ ! -f ${workspace_file} ]]; then
        print_error "Primary workspace file not found: ${workspace_file}"
        issues_found=$((issues_found + 1))
    else
        print_success "Primary workspace file exists: ${workspace_file}"
    fi

    # Check for duplicate workspace files (excluding known backup locations)
    local duplicate_workspaces
    duplicate_workspaces=$(find "${WORKSPACE_ROOT}" -name "*.code-workspace" -type f | grep -v "^${workspace_file}$" | grep -v "/Archive/" | grep -v "/Workspace_Backup_" | grep -v "/\.vscode/backups/")

    if [[ -n ${duplicate_workspaces} ]]; then
        print_error "Duplicate workspace files found:"
        echo "${duplicate_workspaces}" | while read -r file; do
            echo "  ❌ ${file}"
        done
        issues_found=$((issues_found + 1))
    else
        print_success "No duplicate workspace files detected (excluding backups)"
    fi

    # Validate workspace JSON structure
    if [[ -f ${workspace_file} ]]; then
        if command -v jq &>/dev/null; then
            if jq empty "${workspace_file}" 2>/dev/null; then
                print_success "Workspace JSON structure is valid"
            else
                print_error "Workspace JSON structure is invalid"
                issues_found=$((issues_found + 1))
            fi
        else
            print_warning "jq not available - skipping JSON validation"
        fi
    fi

    # Check for required workspace sections
    if [[ -f ${workspace_file} ]]; then
        local has_folders
        local has_settings
        local has_extensions

        has_folders=$(grep -c '"folders"' "${workspace_file}" 2>/dev/null || echo "0")
        has_settings=$(grep -c '"settings"' "${workspace_file}" 2>/dev/null || echo "0")
        has_extensions=$(grep -c '"extensions"' "${workspace_file}" 2>/dev/null || echo "0")

        if [[ ${has_folders} -gt 0 ]]; then
            print_success "Workspace contains folders configuration"
        else
            print_warning "Workspace missing folders configuration"
        fi

        if [[ ${has_settings} -gt 0 ]]; then
            print_success "Workspace contains settings configuration"
        else
            print_warning "Workspace missing settings configuration"
        fi

        if [[ ${has_extensions} -gt 0 ]]; then
            print_success "Workspace contains extensions recommendations"
        else
            print_warning "Workspace missing extensions recommendations"
        fi
    fi

    # Check for workspace backup integrity
    local backup_dir="${WORKSPACE_ROOT}/.vscode/backups"
    if [[ -d ${backup_dir} ]]; then
        local backup_count
        backup_count=$(find "${backup_dir}" -name "*.code-workspace.backup" -type f | wc -l | tr -d ' ')
        if [[ ${backup_count} -gt 0 ]]; then
            print_success "Workspace backups found: ${backup_count} backup(s)"
        else
            print_warning "No workspace backups found in ${backup_dir}"
        fi
    else
        print_warning "Workspace backup directory not found: ${backup_dir}"
    fi

    # Summary
    echo ""
    if [[ ${issues_found} -eq 0 ]]; then
        print_success "✅ Workspace configuration validation passed"
        return 0
    else
        print_error "❌ Workspace configuration validation failed: ${issues_found} issue(s) found"
        echo ""
        print_status "Recommendations:"
        echo "  • Run workspace consolidation if duplicates found"
        echo "  • Ensure primary workspace file exists and is valid JSON"
        echo "  • Maintain regular backups of workspace configuration"
        return 1
    fi
}

# Run workspace duplication prevention
run_workspace_duplication_prevention() {
    print_status "Running Workspace Duplication Prevention..."

    local prevention_script="${CODE_DIR}/Tools/Automation/prevent_workspace_duplication.sh"

    if [[ ! -f ${prevention_script} ]]; then
        print_error "Workspace duplication prevention script not found at: ${prevention_script}"
        return 1
    fi

    if [[ ! -x ${prevention_script} ]]; then
        print_warning "Making workspace duplication prevention script executable..."
        chmod +x "${prevention_script}"
    fi

    print_status "Executing workspace duplication prevention..."
    if bash "${prevention_script}" validate; then
        print_success "Workspace duplication prevention completed successfully"
    else
        print_error "Workspace duplication prevention failed"
        return 1
    fi
}

# Add security task to task queue
add_security_task() {
    local task_id="$1"
    local task_type="$2"
    local description="$3"
    local agent="$4"

    local task_queue_file="${CODE_DIR}/Tools/Automation/agents/communication/task_queue.json"

    # Create task queue file if it doesn't exist
    if [[ ! -f ${task_queue_file} ]]; then
        echo '{"tasks": []}' >"${task_queue_file}"
    fi

    # Create task JSON
    local task_json
    task_json=$(jq -n \
        --arg id "${task_id}" \
        --arg type "${task_type}" \
        --arg desc "${description}" \
        --arg agent "${agent}" \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{id: $id, type: $type, description: $desc, agent: $agent, timestamp: $timestamp, status: "queued"}')

    # Add task to queue
    jq --argjson task "${task_json}" '.tasks += [$task]' "${task_queue_file}" >"${task_queue_file}.tmp" && mv "${task_queue_file}.tmp" "${task_queue_file}"
}

add_ai_task() {
    local task_id="$1"
    local task_type="$2"
    local description="$3"
    local agent="$4"

    local task_queue_file="${CODE_DIR}/Tools/Automation/agents/communication/task_queue.json"

    # Create task queue file if it doesn't exist
    if [[ ! -f ${task_queue_file} ]]; then
        echo '{"tasks": []}' >"${task_queue_file}"
    fi

    # Create task JSON
    local task_json
    task_json=$(jq -n \
        --arg id "${task_id}" \
        --arg type "${task_type}" \
        --arg desc "${description}" \
        --arg agent "${agent}" \
        --arg timestamp "$(date -u +"%Y-%m-%dT%H:%M:%SZ")" \
        '{id: $id, type: $type, description: $desc, agent: $agent, timestamp: $timestamp, status: "queued"}')

    # Add task to queue
    jq --argjson task "${task_json}" '.tasks += [$task]' "${task_queue_file}" >"${task_queue_file}.tmp" && mv "${task_queue_file}.tmp" "${task_queue_file}"
}

# Main execution logic with AI enhancements# Main execution logic with AI enhancements
main() {
    case "${1-}" in
    "status" | "")
        status_with_ai
        ;;
    "list")
        list_projects_with_ai_insights
        ;;
    "run")
        run_project_automation_with_ai "$2"
        ;;
    "all")
        run_all_projects_with_ai
        ;;
    "ai-status")
        if [[ -f "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ]]; then
            run_with_monitoring "ai_enhanced" bash "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" health
        else
            print_error "AI-enhanced automation not found"
        fi
        ;;
    "ai-analyze")
        if [[ -f "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ]]; then
            run_with_monitoring "ai_enhanced" bash "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" analyze "$2"
        else
            print_error "AI-enhanced automation not found"
        fi
        ;;
    "ai-review")
        if [[ -f "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ]]; then
            run_with_monitoring "ai_enhanced" bash "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" review "$2"
        else
            print_error "AI-enhanced automation not found"
        fi
        ;;
    "ai-optimize")
        if [[ -f "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ]]; then
            run_with_monitoring "ai_enhanced" bash "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" optimize "$2"
        else
            print_error "AI-enhanced automation not found"
        fi
        ;;
    "ai-generate")
        if [[ -f "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ]]; then
            run_with_monitoring "ai_enhanced" bash "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" generate "$2"
        else
            print_error "AI-enhanced automation not found"
        fi
        ;;
    "ai-all")
        if [[ -f "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ]]; then
            run_with_monitoring "ai_enhanced" bash "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ai-all
        else
            print_status "🤖 Running Complete AI Agent Suite..."
            # Queue documentation generation for all projects
            for project in $(list_projects | grep "  •" | sed 's/.*• \([^:]*\):.*/\1/'); do
                add_ai_task "ai_docs_${project}" "documentation" "AI documentation generation for ${project}" "ai_docs_agent.sh"
                add_ai_task "ai_code_review_${project}" "code_review" "AI code review for ${project}" "ai_code_review_agent.sh"
                echo "execute_task|ai_docs_${project}" >>"${CODE_DIR}/Tools/Automation/agents/communication/ai_docs_agent.sh_notification.txt"
                echo "execute_task|ai_code_review_${project}" >>"${CODE_DIR}/Tools/Automation/agents/communication/ai_code_review_agent.sh_notification.txt"
            done
            # Add predictive analytics
            add_ai_task "ai_predictive_analytics" "predictive" "AI predictive analytics for project timelines and bottlenecks" "ai_predictive_analytics_agent.sh"
            echo "execute_task|ai_predictive_analytics" >"${CODE_DIR}/Tools/Automation/agents/communication/ai_predictive_analytics_agent.sh_notification.txt"
            print_success "Complete AI agent suite queued. Check agent logs for comprehensive results."
        fi
        ;;
    "setup-ai")
        setup_ai_integration
        ;;
    "update-models")
        update_ollama_models
        ;;
    "ai-insights")
        generate_workspace_ai_insights 5 5 # Placeholder values
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
    "analytics")
        run_advanced_analytics
        ;;
    "code-health")
        print_status "Generating code health metrics..."
        if command -v python3 >/dev/null 2>&1; then
            python3 "${CODE_DIR}/Tools/Automation/code_health_dashboard.py" || print_warning "code health generation failed"
        else
            print_error "python3 not found; cannot run code health generator"
            exit 1
        fi
        ;;
    "workspace")
        validate_workspace_configuration
        ;;
    "prevent-duplicates")
        run_workspace_duplication_prevention
        ;;
    "cleanup")
        run_retention_policy
        ;;
    "retention")
        run_retention_policy
        ;;
    "generate-tests")
        shift || true
        if [[ -n ${1-} ]]; then
            print_status "Generating tests for project: $1 (monitored)"
            run_with_monitoring "ai_tests" bash "${CODE_DIR}/Tools/Automation/ai_generate_swift_tests.sh" --project "$1"
        else
            print_status "Generating tests for all projects (monitored)..."
            run_with_monitoring "ai_tests" bash "${CODE_DIR}/Tools/Automation/ai_generate_swift_tests.sh"
        fi
        ;;
    "security-audit")
        print_status "🔒 Running Enhanced Phase 6 Security Audit..."
        local audit_script="${CODE_DIR}/Tools/Automation/security_audit.sh"
        if [[ ! -f ${audit_script} ]]; then
            print_error "Security audit script not found at: ${audit_script}"
            exit 1
        fi
        if [[ ! -x ${audit_script} ]]; then
            print_warning "Making security audit script executable..."
            chmod +x "${audit_script}"
        fi
        print_status "Executing comprehensive security audit (monitored)..."
        if run_with_monitoring "security_audit" bash "${audit_script}"; then
            print_success "Enhanced security audit completed successfully"
        else
            print_error "Security audit failed - check output above for details"
            exit 1
        fi
        ;;
    "security-scan")
        print_status "🔒 Running Security Vulnerability Scan..."
        if [[ -n ${2-} ]]; then
            print_status "Scanning project: $2"
            # Add task to queue
            add_security_task "security_scan_$2" "security" "Security scan for $2" "security_agent.sh"
            # Notify agent
            echo "execute_task|security_scan_$2" >"${CODE_DIR}/Tools/Automation/agents/communication/security_agent.sh_notification.txt"
        else
            print_status "Scanning all projects..."
            for project in $(list_projects | grep "  •" | sed 's/.*• \([^:]*\):.*/\1/'); do
                add_security_task "security_scan_${project}" "security" "Security scan for ${project}" "security_agent.sh"
                echo "execute_task|security_scan_${project}" >>"${CODE_DIR}/Tools/Automation/agents/communication/security_agent.sh_notification.txt"
            done
        fi
        print_success "Security scan tasks queued. Check agent logs for results."
        ;;
    "compliance-check")
        print_status "📋 Running Compliance Validation..."
        if [[ -n ${2-} ]]; then
            print_status "Checking compliance for project: $2"
            add_security_task "compliance_check_$2" "audit" "Compliance check for $2" "audit_agent.sh"
            echo "execute_task|compliance_check_$2" >"${CODE_DIR}/Tools/Automation/agents/communication/audit_agent.sh_notification.txt"
        else
            print_status "Checking compliance for all projects..."
            for project in $(list_projects | grep "  •" | sed 's/.*• \([^:]*\):.*/\1/'); do
                add_security_task "compliance_check_${project}" "audit" "Compliance check for ${project}" "audit_agent.sh"
                echo "execute_task|compliance_check_${project}" >>"${CODE_DIR}/Tools/Automation/agents/communication/audit_agent.sh_notification.txt"
            done
        fi
        print_success "Compliance check tasks queued. Check agent logs for results."
        ;;
    "audit-trail")
        print_status "📊 Generating Audit Trail Report..."
        add_security_task "generate_audit_report" "audit" "Generate comprehensive audit trail report" "audit_agent.sh"
        echo "execute_task|generate_audit_report" >"${CODE_DIR}/Tools/Automation/agents/communication/audit_agent.sh_notification.txt"
        print_success "Audit trail generation queued. Check agent logs for results."
        ;;
    "encryption-status")
        print_status "🔐 Checking Encryption Status..."
        add_security_task "encryption_status" "encryption" "Check encryption configuration status" "encryption_agent.sh"
        echo "execute_task|encryption_status" >"${CODE_DIR}/Tools/Automation/agents/communication/encryption_agent.sh_notification.txt"
        print_success "Encryption status check queued. Check agent logs for results."
        ;;
    "security-all")
        print_status "🛡️ Running Complete Security & Compliance Suite..."
        # Add workspace-wide tasks first
        add_security_task "generate_audit_report" "audit" "Generate comprehensive audit trail report" "audit_agent.sh"
        add_security_task "encryption_status" "encryption" "Check encryption configuration status" "encryption_agent.sh"
        echo "execute_task|generate_audit_report" >"${CODE_DIR}/Tools/Automation/agents/communication/audit_agent.sh_notification.txt"
        echo "execute_task|encryption_status" >"${CODE_DIR}/Tools/Automation/agents/communication/encryption_agent.sh_notification.txt"
        # Queue project-specific security tasks
        for project in $(list_projects | grep "  •" | sed 's/.*• \([^:]*\):.*/\1/'); do
            add_security_task "security_scan_${project}" "security" "Security scan for ${project}" "security_agent.sh"
            add_security_task "compliance_check_${project}" "audit" "Compliance check for ${project}" "audit_agent.sh"
            echo "execute_task|security_scan_${project}" >>"${CODE_DIR}/Tools/Automation/agents/communication/security_agent.sh_notification.txt"
            echo "execute_task|compliance_check_${project}" >>"${CODE_DIR}/Tools/Automation/agents/communication/audit_agent.sh_notification.txt"
        done
        print_success "Complete security suite queued. Check agent logs for comprehensive results."
        ;;
    "ai-docs")
        print_status "📚 Running AI Documentation Generation..."
        if [[ -n ${2-} ]]; then
            print_status "Generating documentation for project: $2"
            add_ai_task "ai_docs_$2" "documentation" "AI documentation generation for $2" "ai_docs_agent.sh"
            echo "execute_task|ai_docs_$2" >"${CODE_DIR}/Tools/Automation/agents/communication/ai_docs_agent.sh_notification.txt"
        else
            print_status "Generating documentation for all projects..."
            for project in $(list_projects | grep "  •" | sed 's/.*• \([^:]*\):.*/\1/'); do
                add_ai_task "ai_docs_${project}" "documentation" "AI documentation generation for ${project}" "ai_docs_agent.sh"
                echo "execute_task|ai_docs_${project}" >>"${CODE_DIR}/Tools/Automation/agents/communication/ai_docs_agent.sh_notification.txt"
            done
        fi
        print_success "AI documentation generation tasks queued. Check agent logs for results."
        ;;
    "ai-code-review")
        print_status "🔍 Running AI Code Review..."
        if [[ -n ${2-} ]]; then
            print_status "Reviewing code for project: $2"
            add_ai_task "ai_code_review_$2" "code_review" "AI code review for $2" "ai_code_review_agent.sh"
            echo "execute_task|ai_code_review_$2" >"${CODE_DIR}/Tools/Automation/agents/communication/ai_code_review_agent.sh_notification.txt"
        else
            print_status "Reviewing code for all projects..."
            for project in $(list_projects | grep "  •" | sed 's/.*• \([^:]*\):.*/\1/'); do
                add_ai_task "ai_code_review_${project}" "code_review" "AI code review for ${project}" "ai_code_review_agent.sh"
                echo "execute_task|ai_code_review_${project}" >>"${CODE_DIR}/Tools/Automation/agents/communication/ai_code_review_agent.sh_notification.txt"
            done
        fi
        print_success "AI code review tasks queued. Check agent logs for results."
        ;;
    "ai-predictive")
        print_status "🔮 Running AI Predictive Analytics..."
        add_ai_task "ai_predictive_analytics" "predictive" "AI predictive analytics for project timelines and bottlenecks" "ai_predictive_analytics_agent.sh"
        echo "execute_task|ai_predictive_analytics" >"${CODE_DIR}/Tools/Automation/agents/communication/ai_predictive_analytics_agent.sh_notification.txt"
        print_success "AI predictive analytics task queued. Check agent logs for results."
        ;;
    "ai-agents")
        print_status "🤖 Running Complete AI Agent Suite..."
        # Queue documentation generation for all projects
        for project in $(list_projects | grep "  •" | sed 's/.*• \([^:]*\):.*/\1/'); do
            add_ai_task "ai_docs_${project}" "documentation" "AI documentation generation for ${project}" "ai_docs_agent.sh"
            add_ai_task "ai_code_review_${project}" "code_review" "AI code review for ${project}" "ai_code_review_agent.sh"
            echo "execute_task|ai_docs_${project}" >>"${CODE_DIR}/Tools/Automation/agents/communication/ai_docs_agent.sh_notification.txt"
            echo "execute_task|ai_code_review_${project}" >>"${CODE_DIR}/Tools/Automation/agents/communication/ai_code_review_agent.sh_notification.txt"
        done
        # Add predictive analytics
        add_ai_task "ai_predictive_analytics" "predictive" "AI predictive analytics for project timelines and bottlenecks" "ai_predictive_analytics_agent.sh"
        echo "execute_task|ai_predictive_analytics" >"${CODE_DIR}/Tools/Automation/agents/communication/ai_predictive_analytics_agent.sh_notification.txt"
        print_success "Complete AI agent suite queued. Check agent logs for comprehensive results."
        ;;
    "quantum-analysis")
        echo "🌀 Running Quantum Analysis..."
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        "${SCRIPT_DIR}/quantum_tools_integration.sh" analysis
        ;;
    "quantum-build")
        echo "⚡ Running Quantum Build Optimization..."
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        "${SCRIPT_DIR}/quantum_tools_integration.sh" build
        ;;
    "quantum-deploy")
        echo "🌌 Running Quantum Deployment..."
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        "${SCRIPT_DIR}/quantum_tools_integration.sh" deploy
        ;;
    "quantum-monitor")
        echo "👁️  Starting Quantum Monitoring..."
        SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
        "${SCRIPT_DIR}/quantum_tools_integration.sh" monitor
        ;;
    *)
        show_enhanced_usage
        ;;
    esac
}

# Execute main function
main "$@"
