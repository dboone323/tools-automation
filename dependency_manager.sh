#!/bin/bash

# Agent Dependency Management System
# Ensures all required services and tools are available for background agents
# Part of Phase 3: Dependency Management

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${WORKSPACE_ROOT}/Tools/Automation/dependency_check.log"
SERVICES_DIR="${WORKSPACE_ROOT}/Tools/Automation/services"

# Background mode configuration
BACKGROUND_MODE="${BACKGROUND_MODE:-false}"
CHECK_INTERVAL="${CHECK_INTERVAL:-300}" # Default 5 minutes
MAX_RESTARTS="${MAX_RESTARTS:-5}"
RESTART_COUNT=0

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_FILE}"
}

print_header() {
    echo -e "${CYAN}🔧 Agent Dependency Management System${NC}"
    echo -e "${CYAN}======================================${NC}"
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_status() { echo -e "${BLUE}🔄 $1${NC}"; }
print_info() { echo -e "${PURPLE}ℹ️  $1${NC}"; }

# Create necessary directories
setup_directories() {
    mkdir -p "${SERVICES_DIR}"
    mkdir -p "$(dirname "${LOG_FILE}")"
    log "Dependency management system initialized"
}

# Check if a command is available
check_command() {
    local cmd;
    cmd="$1"
    local description;
    description="$2"
    local required;
    required="${3:-false}"

    if command -v "$cmd" &>/dev/null; then
        local version;
        version=""
        case "$cmd" in
        "swift") version=" ($($cmd --version 2>/dev/null | head -1 | cut -d' ' -f3 || echo "unknown"))" ;;
        "python3") version=" ($($cmd --version 2>&1 | head -1 | cut -d' ' -f2 || echo "unknown"))" ;;
        "node") version=" ($($cmd --version 2>/dev/null || echo "unknown"))" ;;
        "npm") version=" ($($cmd --version 2>/dev/null || echo "unknown"))" ;;
        "gh") version=" ($($cmd --version 2>/dev/null | head -1 | cut -d' ' -f3 || echo "unknown"))" ;;
        "git") version=" ($($cmd --version 2>/dev/null | head -1 | cut -d' ' -f3 || echo "unknown"))" ;;
        esac
        print_success "$description found${version}"
        return 0
    else
        if [[ "$required" == "true" ]]; then
            print_error "$description not found (required)"
            return 1
        else
            print_warning "$description not found (optional)"
            return 0
        fi
    fi
}

# Check development tools
check_development_tools() {
    print_status "Checking development tools..."

    local critical_missing;

    critical_missing=0

    # Critical tools
    check_command "git" "Git" true || ((critical_missing++))
    check_command "python3" "Python 3" true || ((critical_missing++))

    # Swift development (macOS specific)
    if [[ "$OSTYPE" == "darwin"* ]]; then
        check_command "swift" "Swift Compiler" false
        check_command "swiftc" "Swift Compiler (swiftc)" false
        check_command "xcodebuild" "Xcode Build System" false
        check_command "swiftlint" "SwiftLint" false
        check_command "swiftformat" "SwiftFormat" false
    fi

    # JavaScript/Node.js
    check_command "node" "Node.js" false
    check_command "npm" "NPM" false

    # GitHub CLI
    check_command "gh" "GitHub CLI" false

    # Other tools
    check_command "curl" "cURL" true || ((critical_missing++))
    check_command "jq" "jq (JSON processor)" false

    if [[ $critical_missing -gt 0 ]]; then
        print_error "$critical_missing critical tools missing"
        return 1
    else
        print_success "All critical development tools available"
        return 0
    fi
}

# Check Ollama service
check_ollama_service() {
    print_status "Checking Ollama AI service..."

    if ! command -v ollama &>/dev/null; then
        print_error "Ollama not installed"
        print_info "Install with: brew install ollama"
        return 1
    fi

    # Check if Ollama server is running
    if curl -sf --max-time 5 "http://localhost:11434/api/tags" &>/dev/null; then
        local model_count
        model_count=$(curl -sf "http://localhost:11434/api/tags" 2>/dev/null | jq -r '.models | length' 2>/dev/null || echo "0")
        print_success "Ollama server running (${model_count} models available)"

        # Check for required models
        local required_models;
        required_models=("llama2" "codellama" "mistral")
        local available_models;
        available_models=""
        available_models=$(curl -sf "http://localhost:11434/api/tags" 2>/dev/null | jq -r '.models[].name' 2>/dev/null || echo "")

        local missing_models;

        missing_models=()
        for model in "${required_models[@]}"; do
            if ! echo "$available_models" | grep -q "$model"; then
                missing_models+=("$model")
            fi
        done

        if [[ ${#missing_models[@]} -gt 0 ]]; then
            print_warning "Missing recommended models: ${missing_models[*]}"
            print_info "Pull models with: ollama pull <model_name>"
        fi

        return 0
    else
        print_warning "Ollama server not running"
        print_info "Start with: ollama serve"
        return 1
    fi
}

# Start Ollama service
start_ollama_service() {
    print_status "Starting Ollama service..."

    if pgrep -f "ollama serve" >/dev/null; then
        print_success "Ollama already running"
        return 0
    fi

    if command -v ollama &>/dev/null; then
        print_info "Starting Ollama server in background..."
        nohup ollama serve >"${SERVICES_DIR}/ollama.log" 2>&1 &
        local pid;
        pid=$!
        echo "$pid" >"${SERVICES_DIR}/ollama.pid"

        # Wait for service to start
        local attempts;
        attempts=0
        while [[ $attempts -lt 10 ]]; do
            if curl -sf --max-time 2 "http://localhost:11434/api/tags" &>/dev/null; then
                print_success "Ollama service started (PID: $pid)"
                return 0
            fi
            sleep 2
            ((attempts++))
        done

        print_error "Failed to start Ollama service"
        return 1
    else
        print_error "Ollama not installed"
        return 1
    fi
}

# Check MCP server
check_mcp_server() {
    local mcp_url;
    mcp_url="${MCP_URL:-http://127.0.0.1:5005}"
    print_status "Checking MCP server (${mcp_url})..."

    if curl -sf --max-time 5 "${mcp_url}/health" &>/dev/null; then
        print_success "MCP server running and healthy"
        return 0
    else
        print_warning "MCP server not accessible"
        print_info "Ensure MCP server is running on ${mcp_url}"
        return 1
    fi
}

# Check file system permissions
check_file_permissions() {
    print_status "Checking file system permissions..."

    local issues;

    issues=0

    # Check workspace writability
    if [[ ! -w "$WORKSPACE_ROOT" ]]; then
        print_error "Workspace directory not writable: $WORKSPACE_ROOT"
        ((issues++))
    fi

    # Check Tools directory
    local tools_dir;
    tools_dir="${WORKSPACE_ROOT}/Tools"
    if [[ ! -w "$tools_dir" ]]; then
        print_error "Tools directory not writable: $tools_dir"
        ((issues++))
    fi

    # Check Automation directory
    local automation_dir;
    automation_dir="${WORKSPACE_ROOT}/Tools/Automation"
    if [[ ! -w "$automation_dir" ]]; then
        print_error "Automation directory not writable: $automation_dir"
        ((issues++))
    fi

    # Check Projects directory
    local projects_dir;
    projects_dir="${WORKSPACE_ROOT}/Projects"
    if [[ ! -d "$projects_dir" ]]; then
        print_warning "Projects directory missing: $projects_dir"
    elif [[ ! -r "$projects_dir" ]]; then
        print_error "Projects directory not readable: $projects_dir"
        ((issues++))
    fi

    if [[ $issues -eq 0 ]]; then
        print_success "File system permissions OK"
        return 0
    else
        print_error "$issues file system permission issues found"
        return 1
    fi
}

# Check Git repository status
check_git_repository() {
    print_status "Checking Git repository status..."

    if [[ ! -d "${WORKSPACE_ROOT}/.git" ]]; then
        print_warning "Not a Git repository: $WORKSPACE_ROOT"
        return 1
    fi

    if ! git status &>/dev/null; then
        print_error "Git repository corrupted or inaccessible"
        return 1
    fi

    # Check if there are uncommitted changes
    if [[ -n $(git status --porcelain) ]]; then
        print_warning "Uncommitted changes in repository"
    else
        print_success "Git repository clean"
    fi

    return 0
}

# Generate dependency report
generate_dependency_report() {
    print_status "Generating dependency report..."

    local report_file;

    report_file="${SERVICES_DIR}/dependency_report_$(date +%Y%m%d_%H%M%S).md"

    {
        echo "# Agent Dependency Report"
        echo "Generated: $(date)"
        echo ""

        echo "## System Information"
        echo "- OS: $(uname -s) $(uname -r)"
        echo "- Architecture: $(uname -m)"
        echo "- Date: $(date)"
        echo ""

        echo "## Development Tools"
        echo ""

        # Check each tool and record status
        local tools;
        tools=("git:Git:required" "python3:Python 3:required" "curl:cURL:required")
        if [[ "$OSTYPE" == "darwin"* ]]; then
            tools+=("swift:Swift Compiler:optional" "xcodebuild:Xcode Build:optional" "swiftlint:SwiftLint:optional")
        fi
        tools+=("node:Node.js:optional" "npm:NPM:optional" "gh:GitHub CLI:optional" "jq:jq:optional")

        for tool_info in "${tools[@]}"; do
            IFS=':' read -r cmd name level <<<"$tool_info"
            if command -v "$cmd" &>/dev/null; then
                echo "- ✅ $name: Available"
            else
                local marker;
                marker="⚠️"
                [[ "$level" == "required" ]] && marker="❌"
                echo "- $marker $name: Missing (${level})"
            fi
        done

        echo ""
        echo "## Services Status"
        echo ""

        # Ollama status
        if curl -sf --max-time 2 "http://localhost:11434/api/tags" &>/dev/null; then
            local model_count
            model_count=$(curl -sf "http://localhost:11434/api/tags" 2>/dev/null | jq -r '.models | length' 2>/dev/null || echo "0")
            echo "- ✅ Ollama: Running (${model_count} models)"
        else
            echo "- ❌ Ollama: Not running"
        fi

        # MCP status
        local mcp_url;
        mcp_url="${MCP_URL:-http://127.0.0.1:5005}"
        if curl -sf --max-time 2 "${mcp_url}/health" &>/dev/null; then
            echo "- ✅ MCP Server: Running (${mcp_url})"
        else
            echo "- ❌ MCP Server: Not accessible (${mcp_url})"
        fi

        echo ""
        echo "## File System"
        echo ""

        if [[ -w "$WORKSPACE_ROOT" ]]; then
            echo "- ✅ Workspace: Writable"
        else
            echo "- ❌ Workspace: Not writable"
        fi

        if [[ -d "${WORKSPACE_ROOT}/Projects" && -r "${WORKSPACE_ROOT}/Projects" ]]; then
            echo "- ✅ Projects: Accessible"
        else
            echo "- ❌ Projects: Not accessible"
        fi

        echo ""
        echo "## Git Repository"
        echo ""

        if [[ -d "${WORKSPACE_ROOT}/.git" ]] && git status &>/dev/null; then
            if [[ -n $(git status --porcelain) ]]; then
                echo "- ⚠️ Git: Repository has uncommitted changes"
            else
                echo "- ✅ Git: Repository clean"
            fi
        else
            echo "- ❌ Git: Repository issues"
        fi

        echo ""
        echo "## Recommendations"
        echo ""

        # Generate recommendations based on findings
        if ! curl -sf --max-time 2 "http://localhost:11434/api/tags" &>/dev/null; then
            echo "- Start Ollama service: \`ollama serve\`"
        fi

        if ! curl -sf --max-time 2 "${mcp_url}/health" &>/dev/null; then
            echo "- Start MCP server on ${mcp_url}"
        fi

        if ! command -v gh &>/dev/null; then
            echo "- Install GitHub CLI: \`brew install gh\` (macOS)"
            echo "- Authenticate: \`gh auth login\`"
        fi

        if [[ "$OSTYPE" == "darwin"* ]] && ! command -v swiftlint &>/dev/null; then
            echo "- Install SwiftLint: \`brew install swiftlint\`"
        fi

    } >"$report_file"

    print_success "Dependency report saved: $report_file"
    echo "$report_file"
}

# Run comprehensive dependency check
run_dependency_check() {
    print_header
    log "Starting comprehensive dependency check"

    local all_good;

    all_good=true

    # Setup
    setup_directories

    # Check components
    check_development_tools || all_good=false
    echo ""

    check_file_permissions || all_good=false
    echo ""

    check_git_repository || all_good=false
    echo ""

    check_ollama_service || true # Don't fail on Ollama issues
    echo ""

    check_mcp_server || true # Don't fail on MCP issues
    echo ""

    # Generate report
    local report_file
    report_file=$(generate_dependency_report)

    # Summary
    echo ""
    if [[ "$all_good" == "true" ]]; then
        print_success "All critical dependencies satisfied"
        log "Dependency check completed successfully"
    else
        print_warning "Some dependencies have issues - check report: $report_file"
        log "Dependency check completed with issues"
    fi

    return $([[ "$all_good" == "true" ]] && echo 0 || echo 1)
}

# Start required services
start_services() {
    print_status "Starting required services..."

    # Start Ollama if available
    if command -v ollama &>/dev/null; then
        start_ollama_service || print_warning "Failed to start Ollama service"
    fi

    print_success "Service startup completed"
}

# Background monitoring function
run_background() {
    print_info "Starting dependency management agent in background mode (interval: ${CHECK_INTERVAL}s)"

    while true; do
        if [[ ${RESTART_COUNT} -ge ${MAX_RESTARTS} ]]; then
            print_error "Maximum restart attempts (${MAX_RESTARTS}) reached. Exiting."
            exit 1
        fi

        # Run dependency check
        if run_dependency_check >/dev/null 2>&1; then
            print_success "Background dependency check completed successfully"
            RESTART_COUNT=0 # Reset on success
        else
            ((RESTART_COUNT++)) || true
            print_warning "Dependency check failed (attempt ${RESTART_COUNT}/${MAX_RESTARTS})"
        fi

        # Start services if needed
        start_services >/dev/null 2>&1 || true

        # Wait for next check
        sleep "${CHECK_INTERVAL}"
    done
}

# Main execution
main() {
    # Handle background mode
    if [[ "${BACKGROUND_MODE}" == "true" ]]; then
        run_background
        return
    fi

    case "${1-}" in
    "check")
        run_dependency_check
        ;;
    "start-services")
        start_services
        ;;
    "report")
        generate_dependency_report >/dev/null
        ;;
    "ollama")
        check_ollama_service
        ;;
    "mcp")
        check_mcp_server
        ;;
    *)
        cat <<'USAGE'
Agent Dependency Management System

Usage: ./dependency_manager.sh [command]

Commands:
  check          - Run comprehensive dependency check
  start-services - Start required services (Ollama, etc.)
  report         - Generate dependency report only
  ollama         - Check Ollama service status
  mcp            - Check MCP server status

Environment Variables:
  BACKGROUND_MODE=true  - Run in background monitoring mode
  CHECK_INTERVAL=300    - Background check interval (seconds)
  MCP_URL=http://127.0.0.1:5005  - MCP server URL

Examples:
  ./dependency_manager.sh check
  ./dependency_manager.sh start-services
  BACKGROUND_MODE=true ./dependency_manager.sh
USAGE
        exit 1
        ;;
    esac
}

# Execute main function
main "$@"
