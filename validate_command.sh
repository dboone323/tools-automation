#!/bin/bash
# GitHub Copilot Pre-Command Validation Script
# Prevents common mistakes like shutting down background services

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuration
LOG_FILE="$HOME/.copilot_validation.log"

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" >>"$LOG_FILE"
}

error() {
    echo -e "${RED}ERROR: $1${NC}" >&2
    log "ERROR: $1"
}

warning() {
    echo -e "${YELLOW}WARNING: $1${NC}" >&2
    log "WARNING: $1"
}

success() {
    echo -e "${GREEN}✓ $1${NC}"
    log "SUCCESS: $1"
}

info() {
    echo -e "${BLUE}INFO: $1${NC}"
    log "INFO: $1"
}

# Check if a process is running on a specific port
check_port_usage() {
    local port=$1
    local process_info
    process_info=$(lsof -i :"$port" 2>/dev/null | head -2 | tail -1)
    if [ -n "$process_info" ]; then
        local pid
        pid=$(echo "$process_info" | awk '{print $2}')
        local process_name
        process_name=$(echo "$process_info" | awk '{print $1}')
        echo "PORT:$port|PID:$pid|PROCESS:$process_name"
        return 0
    fi
    return 1
}

# Check for running background services
check_background_services() {
    local services=("mcp_server" "mcp_controller" "ollama" "dashboard")
    local running_services=()

    for service in "${services[@]}"; do
        if pgrep -f "$service" >/dev/null 2>&1; then
            running_services+=("$service")
        fi
    done

    if [ ${#running_services[@]} -gt 0 ]; then
        echo "${running_services[*]}"
        return 0
    fi
    return 1
}

# Validate command safety
validate_command() {
    local command="$1"
    local is_background=${2:-false}
    local issues=()

    info "Validating command: $command"

    # Check 1: Background service interference (refined logic)
    # Only flag as interference if it's NOT a safe status check
    if echo "$command" | grep -q "curl\|wget\|http\|status\|test"; then
        # Safe operations: status checks to localhost services we know are running
        if echo "$command" | grep -q "localhost:5005/status\|127.0.0.1:5005/status" && check_background_services >/dev/null 2>&1; then
            success "Safe status check for MCP server - no interference risk"
        elif check_background_services >/dev/null 2>&1; then
            warning "Command may interfere with running background services"
            issues+=("POTENTIAL_SERVICE_INTERFERENCE")
        fi
    fi

    # Check 2: Port conflicts
    if echo "$command" | grep -q "python.*server\|mcp_server"; then
        local port_check
        if port_check=$(check_port_usage 5005); then
            error "Port 5005 already in use: $port_check"
            issues+=("PORT_CONFLICT_5005")
        fi
    fi

    # Check 3: Working directory validation (refined)
    # Only require working directory for commands that actually need it
    if echo "$command" | grep -q "python\|swift\|xcodebuild\|gradle\|mvn\|npm\|yarn\|pip\|cargo\|go build\|make" && ! echo "$command" | grep -q "cd "; then
        warning "Command may need specific working directory - ensure you're in the right location"
        issues+=("MISSING_WORKING_DIRECTORY")
    fi

    # Check 4: Background flag validation
    if echo "$command" | grep -q "server\|daemon\|watch\|serve" && [ "$is_background" = "false" ]; then
        warning "Long-running service command should use background execution"
        issues+=("SHOULD_USE_BACKGROUND")
    fi

    # Report issues
    if [ ${#issues[@]} -gt 0 ]; then
        error "Found ${#issues[@]} potential issues:"
        for issue in "${issues[@]}"; do
            echo "  - $issue" >&2
        done
        return 1
    else
        success "Command validation passed"
        return 0
    fi
}

# Main validation function
main() {
    local command="$1"
    local is_background="$2"

    log "Starting validation for command: $command (background: $is_background)"

    # Pre-command checklist
    info "Running pre-command validation checklist..."

    # Check for running services
    local running_services
    running_services=$(check_background_services)
    if check_background_services >/dev/null 2>&1; then
        info "Active background services: $running_services"
    else
        info "No background services currently running"
    fi

    # Validate the specific command
    if ! validate_command "$command" "$is_background"; then
        error "Command validation failed - review issues above"
        exit 1
    fi

    # Success
    success "All validations passed - command is safe to execute"
    log "Validation completed successfully"
}

# Show usage if no arguments
if [ $# -eq 0 ]; then
    echo "GitHub Copilot Command Validation Tool"
    echo "Usage: $0 <command> [is_background]"
    echo ""
    echo "Examples:"
    echo "  $0 'curl http://localhost:5005/status' false"
    echo "  $0 'python3 mcp_server.py' true"
    echo ""
    echo "This tool helps prevent common mistakes like shutting down background services."
    exit 1
fi

# Run validation
main "$1" "$2"
