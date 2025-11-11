#!/bin/bash

# Service Startup Manager
# Manages startup and monitoring of required services for agents
# Part of Phase 3: Dependency Management

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SERVICES_DIR="${WORKSPACE_ROOT}/Tools/Automation/services"
LOG_FILE="${SERVICES_DIR}/service_manager.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
NC='\033[0m'

# Logging functions
log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_FILE}"
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
}

# Start Ollama service
start_ollama() {
    print_status "Starting Ollama service..."

    # Check if already running
    if pgrep -f "ollama serve" >/dev/null; then
        print_success "Ollama already running"
        return 0
    fi

    if ! command -v ollama &>/dev/null; then
        print_error "Ollama not installed"
        return 1
    fi

    print_info "Starting Ollama server..."
    nohup ollama serve >"${SERVICES_DIR}/ollama.log" 2>&1 &
    local pid=$!
    echo "$pid" >"${SERVICES_DIR}/ollama.pid"
    log "Ollama started with PID: $pid"

    # Wait for service to be ready
    local attempts=0
    while [[ $attempts -lt 15 ]]; do
        if curl -sf --max-time 2 "http://localhost:11434/api/tags" &>/dev/null; then
            print_success "Ollama service ready (PID: $pid)"
            return 0
        fi
        sleep 2
        ((attempts++))
    done

    print_error "Ollama service failed to start within 30 seconds"
    return 1
}

# Stop Ollama service
stop_ollama() {
    print_status "Stopping Ollama service..."

    if [[ -f "${SERVICES_DIR}/ollama.pid" ]]; then
        local pid
        pid=$(cat "${SERVICES_DIR}/ollama.pid")
        if kill -TERM "$pid" 2>/dev/null; then
            print_success "Ollama stopped (PID: $pid)"
            rm -f "${SERVICES_DIR}/ollama.pid"
            log "Ollama stopped (PID: $pid)"
            return 0
        else
            print_warning "Failed to stop Ollama (PID: $pid)"
        fi
    fi

    # Fallback: kill all ollama processes
    if pgrep -f "ollama serve" >/dev/null; then
        pkill -f "ollama serve"
        print_success "Ollama processes terminated"
        log "Ollama processes force-terminated"
        return 0
    fi

    print_info "Ollama not running"
    return 0
}

# Start MCP server
start_mcp() {
    local mcp_url="${MCP_URL:-http://127.0.0.1:5005}"
    print_status "Starting MCP server (${mcp_url})..."

    # Check if MCP server script exists
    local mcp_script="${WORKSPACE_ROOT}/Tools/Automation/start_mcp_server.sh"
    if [[ ! -f "$mcp_script" ]]; then
        print_warning "MCP startup script not found: $mcp_script"
        print_info "MCP server must be started manually"
        return 1
    fi

    # Check if already running
    if curl -sf --max-time 2 "${mcp_url}/health" &>/dev/null; then
        print_success "MCP server already running"
        return 0
    fi

    print_info "Starting MCP server..."
    bash "$mcp_script" >"${SERVICES_DIR}/mcp.log" 2>&1 &
    local pid=$!
    echo "$pid" >"${SERVICES_DIR}/mcp.pid"
    log "MCP started with PID: $pid"

    # Wait for service to be ready
    local attempts=0
    while [[ $attempts -lt 10 ]]; do
        if curl -sf --max-time 2 "${mcp_url}/health" &>/dev/null; then
            print_success "MCP server ready (PID: $pid)"
            return 0
        fi
        sleep 2
        ((attempts++))
    done

    print_error "MCP server failed to start within 20 seconds"
    return 1
}

# Stop MCP server
stop_mcp() {
    print_status "Stopping MCP server..."

    if [[ -f "${SERVICES_DIR}/mcp.pid" ]]; then
        local pid
        pid=$(cat "${SERVICES_DIR}/mcp.pid")
        if kill -TERM "$pid" 2>/dev/null; then
            print_success "MCP stopped (PID: $pid)"
            rm -f "${SERVICES_DIR}/mcp.pid"
            log "MCP stopped (PID: $pid)"
            return 0
        else
            print_warning "Failed to stop MCP (PID: $pid)"
        fi
    fi

    print_info "MCP not running (no PID file)"
    return 0
}

# Check service status
check_service_status() {
    print_status "Checking service status..."

    # Ollama status
    if curl -sf --max-time 2 "http://localhost:11434/api/tags" &>/dev/null; then
        local model_count
        model_count=$(curl -sf "http://localhost:11434/api/tags" 2>/dev/null | jq -r '.models | length' 2>/dev/null || echo "0")
        print_success "Ollama: Running (${model_count} models)"
    else
        print_error "Ollama: Not running"
    fi

    # MCP status
    local mcp_url="${MCP_URL:-http://127.0.0.1:5005}"
    if curl -sf --max-time 2 "${mcp_url}/health" &>/dev/null; then
        print_success "MCP: Running (${mcp_url})"
    else
        print_error "MCP: Not running (${mcp_url})"
    fi
}

# Start all services
start_all_services() {
    print_status "Starting all required services..."
    setup_directories

    start_ollama || print_warning "Ollama startup failed"
    start_mcp || print_warning "MCP startup failed"

    print_success "Service startup completed"
}

# Stop all services
stop_all_services() {
    print_status "Stopping all services..."

    stop_mcp || print_warning "MCP stop failed"
    stop_ollama || print_warning "Ollama stop failed"

    print_success "All services stopped"
}

# Restart all services
restart_all_services() {
    print_status "Restarting all services..."

    stop_all_services
    sleep 2
    start_all_services

    print_success "All services restarted"
}

# Clean up service files
cleanup() {
    print_status "Cleaning up service files..."

    rm -f "${SERVICES_DIR}/ollama.pid"
    rm -f "${SERVICES_DIR}/mcp.pid"

    print_success "Cleanup completed"
}

# Main execution
main() {
    setup_directories

    case "${1-}" in
    "start")
        start_all_services
        ;;
    "stop")
        stop_all_services
        ;;
    "restart")
        restart_all_services
        ;;
    "status")
        check_service_status
        ;;
    "start-ollama")
        start_ollama
        ;;
    "stop-ollama")
        stop_ollama
        ;;
    "start-mcp")
        start_mcp
        ;;
    "stop-mcp")
        stop_mcp
        ;;
    "cleanup")
        cleanup
        ;;
    *)
        cat <<'USAGE'
Service Startup Manager

Usage: ./service_manager.sh [command]

Commands:
  start          - Start all required services
  stop           - Stop all services
  restart        - Restart all services
  status         - Check service status
  start-ollama   - Start only Ollama service
  stop-ollama    - Stop only Ollama service
  start-mcp      - Start only MCP service
  stop-mcp       - Stop only MCP service
  cleanup        - Clean up service PID files

Environment Variables:
  MCP_URL=http://127.0.0.1:5005  - MCP server URL

Examples:
  ./service_manager.sh start
  ./service_manager.sh status
  ./service_manager.sh restart
USAGE
        exit 1
        ;;
    esac
}

# Execute main function
main "$@"
