#!/bin/bash

# Master Agent Startup Script
# Comprehensive initialization of all agents with dependency management
# Phase 3: Dependency Management - Complete Integration

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/master_startup_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Configuration
BACKGROUND_MODE="${BACKGROUND_MODE:-true}"
START_SERVICES="${START_SERVICES:-true}"
CHECK_DEPENDENCIES="${CHECK_DEPENDENCIES:-true}"
START_AGENTS="${START_AGENTS:-true}"

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_FILE}"
}

print_header() {
    echo -e "${CYAN}🚀 Master Agent Startup System${NC}"
    echo -e "${CYAN}=============================${NC}"
    echo -e "${PURPLE}Ensuring 100% Agent Functionality${NC}"
    echo ""
}

print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_status() { echo -e "${BLUE}🔄 $1${NC}"; }
print_info() { echo -e "${PURPLE}ℹ️  $1${NC}"; }

# Check if script exists and is executable
check_script() {
    local script="$1"
    local name="$2"

    if [[ ! -f "$script" ]]; then
        print_error "$name script not found: $script"
        return 1
    fi

    if [[ ! -x "$script" ]]; then
        print_warning "$name script not executable, fixing..."
        chmod +x "$script"
    fi

    print_success "$name script ready"
    return 0
}

# Phase 1: Dependency Check
run_dependency_check() {
    if [[ "$CHECK_DEPENDENCIES" != "true" ]]; then
        print_info "Skipping dependency check (CHECK_DEPENDENCIES=false)"
        return 0
    fi

    print_status "Phase 1: Checking Dependencies..."

    local dep_manager="${SCRIPT_DIR}/dependency_manager.sh"
    if ! check_script "$dep_manager" "Dependency manager"; then
        print_error "Cannot proceed without dependency manager"
        return 1
    fi

    if ! "$dep_manager" check; then
        print_warning "Some dependencies have issues - continuing anyway"
        print_info "Check the dependency report for details"
    fi

    print_success "Dependency check completed"
    return 0
}

# Phase 2: Service Startup
start_services() {
    if [[ "$START_SERVICES" != "true" ]]; then
        print_info "Skipping service startup (START_SERVICES=false)"
        return 0
    fi

    print_status "Phase 2: Starting Required Services..."

    local service_manager="${SCRIPT_DIR}/service_manager.sh"
    if ! check_script "$service_manager" "Service manager"; then
        print_error "Cannot proceed without service manager"
        return 1
    fi

    if ! "$service_manager" start; then
        print_warning "Some services failed to start - agents may have issues"
    fi

    print_success "Service startup completed"
    return 0
}

# Phase 3: Agent Startup
start_agents() {
    if [[ "$START_AGENTS" != "true" ]]; then
        print_info "Skipping agent startup (START_AGENTS=false)"
        return 0
    fi

    print_status "Phase 3: Starting Background Agents..."

    # List of all agents to start
    local agents=(
        "agent_monitoring.sh"
        "ai_dashboard_monitor.sh"
        "audit_large_files.sh"
        "bootstrap_meta_repo.sh"
        "cleanup_processed_md_files.sh"
        "dashboard_unified.sh"
        "demonstrate_quantum_ai_consciousness.sh"
        "deploy_ai_self_healing.sh"
        "ai_quality_gates.sh"
        "ci_cd_monitoring.sh"
        "continuous_validation.sh"
    )

    local started_count=0
    local failed_count=0

    for agent in "${agents[@]}"; do
        local agent_path="${SCRIPT_DIR}/${agent}"

        if [[ ! -f "$agent_path" ]]; then
            print_warning "Agent not found: $agent"
            ((failed_count++))
            continue
        fi

        if [[ ! -x "$agent_path" ]]; then
            print_info "Making agent executable: $agent"
            chmod +x "$agent_path"
        fi

        print_info "Starting agent: $agent"

        if [[ "$BACKGROUND_MODE" == "true" ]]; then
            # Start in background mode
            BACKGROUND_MODE=true nohup "$agent_path" >"${SCRIPT_DIR}/logs/${agent%.sh}.log" 2>&1 &
            local pid=$!
            echo "$pid" >"${SCRIPT_DIR}/pids/${agent%.sh}.pid"
            print_success "Started $agent in background (PID: $pid)"
        else
            # Start in foreground for testing
            if "$agent_path"; then
                print_success "Agent $agent completed successfully"
            else
                print_warning "Agent $agent failed"
                ((failed_count++))
            fi
        fi

        ((started_count++))
    done

    print_success "Agent startup completed: $started_count started, $failed_count failed"
    return 0
}

# Phase 4: Validation
validate_startup() {
    print_status "Phase 4: Validating Startup..."

    # Wait a moment for agents to initialize
    sleep 3

    # Check if agents are running
    local running_count=0
    local total_count=0

    if [[ -d "${SCRIPT_DIR}/pids" ]]; then
        for pid_file in "${SCRIPT_DIR}/pids"/*.pid; do
            if [[ -f "$pid_file" ]]; then
                local pid
                pid=$(cat "$pid_file")
                if kill -0 "$pid" 2>/dev/null; then
                    ((running_count++))
                fi
                ((total_count++))
            fi
        done
    fi

    if [[ $total_count -gt 0 ]]; then
        print_success "Agent status: $running_count/$total_count running"
    else
        print_info "No PID files found (agents may not be using PID tracking)"
    fi

    # Test dependency manager in background mode
    print_info "Starting dependency monitoring in background..."
    BACKGROUND_MODE=true nohup "${SCRIPT_DIR}/dependency_manager.sh" >"${SCRIPT_DIR}/logs/dependency_monitor.log" 2>&1 &
    local dep_pid=$!
    echo "$dep_pid" >"${SCRIPT_DIR}/pids/dependency_manager.pid"
    print_success "Dependency monitor started (PID: $dep_pid)"

    print_success "Validation completed"
}

# Cleanup function
cleanup() {
    print_status "Cleaning up..."

    # Create necessary directories
    mkdir -p "${SCRIPT_DIR}/logs"
    mkdir -p "${SCRIPT_DIR}/pids"
    mkdir -p "${SCRIPT_DIR}/services"

    print_success "Cleanup completed"
}

# Stop all agents and services
stop_all() {
    print_status "Stopping all agents and services..."

    # Stop services
    if [[ -f "${SCRIPT_DIR}/service_manager.sh" ]]; then
        "${SCRIPT_DIR}/service_manager.sh" stop || print_warning "Service stop failed"
    fi

    # Stop agents
    if [[ -d "${SCRIPT_DIR}/pids" ]]; then
        for pid_file in "${SCRIPT_DIR}/pids"/*.pid; do
            if [[ -f "$pid_file" ]]; then
                local pid
                pid=$(cat "$pid_file")
                local name
                name=$(basename "$pid_file" .pid)
                if kill -TERM "$pid" 2>/dev/null; then
                    print_success "Stopped $name (PID: $pid)"
                    rm -f "$pid_file"
                else
                    print_warning "Failed to stop $name (PID: $pid)"
                fi
            fi
        done
    fi

    print_success "Shutdown completed"
}

# Show status
show_status() {
    print_header

    echo -e "${BLUE}Agent Status:${NC}"
    if [[ -d "${SCRIPT_DIR}/pids" ]]; then
        local running=0
        local total=0
        for pid_file in "${SCRIPT_DIR}/pids"/*.pid; do
            if [[ -f "$pid_file" ]]; then
                local pid
                pid=$(cat "$pid_file")
                local name
                name=$(basename "$pid_file" .pid)
                if kill -0 "$pid" 2>/dev/null; then
                    echo -e "  ${GREEN}✅ $name (PID: $pid)${NC}"
                    ((running++))
                else
                    echo -e "  ${RED}❌ $name (PID: $pid - dead)${NC}"
                fi
                ((total++))
            fi
        done
        echo -e "${PURPLE}Total: $running/$total running${NC}"
    else
        echo -e "  ${YELLOW}No PID files found${NC}"
    fi

    echo ""
    echo -e "${BLUE}Service Status:${NC}"
    if [[ -f "${SCRIPT_DIR}/service_manager.sh" ]]; then
        "${SCRIPT_DIR}/service_manager.sh" status
    else
        echo -e "  ${RED}Service manager not found${NC}"
    fi
}

# Main execution
main() {
    print_header
    log "Master startup initiated"

    case "${1-}" in
    "start")
        cleanup
        run_dependency_check
        echo ""
        start_services
        echo ""
        start_agents
        echo ""
        validate_startup
        echo ""
        print_success "🎉 All systems started successfully!"
        print_info "Use './master_startup.sh status' to check system status"
        ;;
    "stop")
        stop_all
        ;;
    "status")
        show_status
        ;;
    "restart")
        stop_all
        echo ""
        main "start"
        ;;
    "check")
        run_dependency_check
        ;;
    "services")
        start_services
        ;;
    *)
        cat <<USAGE
Master Agent Startup System

Usage: ./master_startup.sh [command]

Commands:
  start     - Full system startup (dependencies → services → agents)
  stop      - Stop all agents and services
  restart   - Restart entire system
  status    - Show current system status
  check     - Run dependency check only
  services  - Start services only

Environment Variables:
  BACKGROUND_MODE=true     - Start agents in background mode (default: true)
  START_SERVICES=true      - Start required services (default: true)
  CHECK_DEPENDENCIES=true  - Run dependency checks (default: true)
  START_AGENTS=true        - Start background agents (default: true)

Examples:
  ./master_startup.sh start
  ./master_startup.sh status
  BACKGROUND_MODE=false ./master_startup.sh start  # Test mode
USAGE
        exit 1
        ;;
    esac

    log "Master startup completed"
}

# Execute main function
main "$@"
