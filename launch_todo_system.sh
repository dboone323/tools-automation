#!/bin/bash
# Unified Todo Management System Launcher with Autonomous Integration
# Launches the dashboard API, todo agent, and autonomous systems for 100% autonomy

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
DASHBOARD_PORT=5001
AGENT_LOG="$PROJECT_ROOT/logs/unified_todo_agent.log"
API_LOG="$PROJECT_ROOT/logs/todo_dashboard_api.log"

# Autonomous system scripts
AUTONOMOUS_LAUNCHER="$PROJECT_ROOT/autonomous_launcher.sh"
AUTONOMOUS_ORCHESTRATOR="$PROJECT_ROOT/autonomous_orchestrator.sh"
INTELLIGENT_ORCHESTRATOR="$PROJECT_ROOT/intelligent_orchestrator.sh"
MCP_AUTO_RESTART="$PROJECT_ROOT/mcp_auto_restart.sh"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

log_autonomous() {
    echo -e "${PURPLE}[AUTONOMOUS]${NC} $1"
}

# Create logs directory
mkdir -p "$PROJECT_ROOT/logs"

# Function to check if port is available
check_port() {
    local port=$1
    if lsof -Pi :$port -sTCP:LISTEN -t >/dev/null; then
        return 1
    else
        return 0
    fi
}

# Function to wait for service to be ready
wait_for_service() {
    local url=$1
    local max_attempts=30
    local attempt=1

    log_info "Waiting for service at $url to be ready..."

    while [ $attempt -le $max_attempts ]; do
        if curl -s --max-time 5 "$url" >/dev/null 2>&1; then
            log_success "Service is ready!"
            return 0
        fi

        log_info "Attempt $attempt/$max_attempts - service not ready yet..."
        sleep 2
        ((attempt++))
    done

    log_error "Service failed to start within expected time"
    return 1
}

# Function to start dashboard API
start_dashboard_api() {
    log_info "Starting Todo Dashboard API..."

    if ! check_port $DASHBOARD_PORT; then
        log_error "Port $DASHBOARD_PORT is already in use"
        return 1
    fi

    # Start API server in background
    cd "$PROJECT_ROOT"
    nohup python3 todo_dashboard_api.py --port $DASHBOARD_PORT >"$API_LOG" 2>&1 &
    API_PID=$!

    echo $API_PID >"$PROJECT_ROOT/logs/dashboard_api.pid"

    # Wait for API to be ready
    if wait_for_service "http://localhost:$DASHBOARD_PORT/api/todo/dashboard"; then
        log_success "Dashboard API started successfully (PID: $API_PID)"
        log_info "Dashboard available at: http://localhost:$DASHBOARD_PORT"
        return 0
    else
        log_error "Failed to start Dashboard API"
        kill $API_PID 2>/dev/null || true
        return 1
    fi
}

# Function to start unified todo agent
start_unified_agent() {
    log_info "Starting Unified Todo Agent..."

    # Check if agent is already running
    if pgrep -f "unified_todo_agent.sh" >/dev/null; then
        log_warning "Unified Todo Agent is already running"
        return 0
    fi

    # Start agent in background
    cd "$PROJECT_ROOT"
    nohup bash agents/unified_todo_agent.sh >"$AGENT_LOG" 2>&1 &
    AGENT_PID=$!

    echo $AGENT_PID >"$PROJECT_ROOT/logs/unified_todo_agent.pid"

    # Give agent time to initialize
    sleep 3

    if kill -0 $AGENT_PID 2>/dev/null; then
        log_success "Unified Todo Agent started successfully (PID: $AGENT_PID)"
        return 0
    else
        log_error "Failed to start Unified Todo Agent"
        return 1
    fi
}

# Function to check system health
check_system_health() {
    log_info "Performing system health check..."

    local issues=0

    # Check if required files exist
    local required_files=(
        "unified_todo_manager.py"
        "mcp_todo_integration.py"
        "todo_dashboard_api.py"
        "agents/unified_todo_agent.sh"
        "todo_dashboard.html"
    )

    for file in "${required_files[@]}"; do
        if [[ ! -f "$PROJECT_ROOT/$file" ]]; then
            log_error "Required file missing: $file"
            ((issues++))
        fi
    done

    # Check Python dependencies
    if ! python3 -c "import flask, flask_cors" 2>/dev/null; then
        log_error "Required Python packages not installed (flask, flask-cors)"
        ((issues++))
    fi

    # Check if agents directory exists
    if [[ ! -d "$PROJECT_ROOT/agents" ]]; then
        log_error "Agents directory not found"
        ((issues++))
    fi

    if [[ $issues -eq 0 ]]; then
        log_success "System health check passed"
        return 0
    else
        log_error "System health check failed with $issues issues"
        return 1
    fi
}

# Function to stop all services
stop_services() {
    log_info "Stopping all services..."

    # Stop API server
    if [[ -f "$PROJECT_ROOT/logs/dashboard_api.pid" ]]; then
        API_PID=$(cat "$PROJECT_ROOT/logs/dashboard_api.pid")
        if kill -0 $API_PID 2>/dev/null; then
            log_info "Stopping Dashboard API (PID: $API_PID)..."
            kill $API_PID
            sleep 2
            if kill -0 $API_PID 2>/dev/null; then
                kill -9 $API_PID 2>/dev/null || true
            fi
        fi
        rm -f "$PROJECT_ROOT/logs/dashboard_api.pid"
    fi

    # Stop unified agent
    if [[ -f "$PROJECT_ROOT/logs/unified_todo_agent.pid" ]]; then
        AGENT_PID=$(cat "$PROJECT_ROOT/logs/unified_todo_agent.pid")
        if kill -0 $AGENT_PID 2>/dev/null; then
            log_info "Stopping Unified Todo Agent (PID: $AGENT_PID)..."
            kill $AGENT_PID
            sleep 2
            if kill -0 $AGENT_PID 2>/dev/null; then
                kill -9 $AGENT_PID 2>/dev/null || true
            fi
        fi
        rm -f "$PROJECT_ROOT/logs/unified_todo_agent.pid"
    fi

    # Kill any remaining processes
    pkill -f "todo_dashboard_api.py" || true
    pkill -f "unified_todo_agent.sh" || true

    log_success "All services stopped"
}

# Function to start autonomous systems
start_autonomous_systems() {
    log_autonomous "Starting autonomous systems for 100% autonomy..."

    if [[ ! -x "$AUTONOMOUS_LAUNCHER" ]]; then
        log_error "Autonomous launcher not found: $AUTONOMOUS_LAUNCHER"
        return 1
    fi

    if "$AUTONOMOUS_LAUNCHER" start; then
        log_success "Autonomous systems started successfully"
        log_autonomous "System now operates with full autonomy - MCP servers, agents, and tools will be managed automatically"
        return 0
    else
        log_error "Failed to start autonomous systems"
        return 1
    fi
}

# Function to stop autonomous systems
stop_autonomous_systems() {
    log_autonomous "Stopping autonomous systems..."

    if [[ -x "$AUTONOMOUS_LAUNCHER" ]]; then
        "$AUTONOMOUS_LAUNCHER" stop || true
    fi

    log_success "Autonomous systems stopped"
}

# Function to show autonomous status
show_autonomous_status() {
    echo
    log_autonomous "=== Autonomous System Status ==="

    if [[ -x "$AUTONOMOUS_LAUNCHER" ]]; then
        "$AUTONOMOUS_LAUNCHER" status
    else
        log_error "Autonomous launcher not available"
    fi
}

# Function to show status
show_status() {
    echo
    log_info "=== System Status ==="

    # Check API server
    if [[ -f "$PROJECT_ROOT/logs/dashboard_api.pid" ]]; then
        API_PID=$(cat "$PROJECT_ROOT/logs/dashboard_api.pid")
        if kill -0 $API_PID 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Dashboard API running (PID: $API_PID)"
            echo "  URL: http://localhost:$DASHBOARD_PORT"
        else
            echo -e "${RED}✗${NC} Dashboard API not running (stale PID file)"
        fi
    else
        echo -e "${RED}✗${NC} Dashboard API not running"
    fi

    # Check unified agent
    if [[ -f "$PROJECT_ROOT/logs/unified_todo_agent.pid" ]]; then
        AGENT_PID=$(cat "$PROJECT_ROOT/logs/unified_todo_agent.pid")
        if kill -0 $AGENT_PID 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Unified Todo Agent running (PID: $AGENT_PID)"
        else
            echo -e "${RED}✗${NC} Unified Todo Agent not running (stale PID file)"
        fi
    else
        echo -e "${RED}✗${NC} Unified Todo Agent not running"
    fi

    # Show autonomous status
    show_autonomous_status

    # Show recent logs
    echo
    log_info "=== Recent API Logs ==="
    if [[ -f "$API_LOG" ]]; then
        tail -5 "$API_LOG" 2>/dev/null || echo "No API logs available"
    else
        echo "No API logs available"
    fi

    echo
    log_info "=== Recent Agent Logs ==="
    if [[ -f "$AGENT_LOG" ]]; then
        tail -5 "$AGENT_LOG" 2>/dev/null || echo "No agent logs available"
    else
        echo "No agent logs available"
    fi
}

# Function to show usage
show_usage() {
    cat <<EOF
Unified Todo Management System Launcher with Autonomous Integration

USAGE:
    $0 [COMMAND]

COMMANDS:
    start               Start all services (dashboard API + unified agent)
    start-autonomous    Start all services + autonomous systems (100% autonomy)
    stop                Stop all services
    stop-autonomous     Stop all services + autonomous systems
    restart             Restart all services
    restart-autonomous  Restart all services + autonomous systems
    status              Show status of all services
    status-autonomous   Show status of autonomous systems only
    health              Run system health check
    logs                Show recent logs from all services

AUTONOMOUS FEATURES:
    The autonomous system provides 100% autonomy with:
    • Automatic MCP server restart on failures
    • Intelligent component orchestration based on task requirements
    • Service health monitoring and auto-recovery
    • Resource-aware scaling and optimization
    • Predictive maintenance and system optimization

EXAMPLES:
    $0 start                    # Start basic todo system
    $0 start-autonomous         # Start with full autonomy
    $0 status                   # Check all services
    $0 status-autonomous        # Check autonomous systems only
    $0 restart-autonomous       # Full system restart with autonomy

SERVICES:
    - Todo Dashboard API (http://localhost:$DASHBOARD_PORT)
    - Unified Todo Agent (background processing)
    - Autonomous Orchestrator (intelligent management)
    - MCP Auto-Restart Manager (failure recovery)
    - Intelligent Component Orchestrator (smart scaling)

EOF
}

# Main logic
case "${1:-start}" in
start)
    log_info "Starting Unified Todo Management System..."

    # Perform health check
    if ! check_system_health; then
        log_error "System health check failed. Please fix issues before starting."
        exit 1
    fi

    # Start services
    if start_dashboard_api && start_unified_agent; then
        log_success "Unified Todo Management System started successfully!"
        echo
        log_info "Access the dashboard at: http://localhost:$DASHBOARD_PORT"
        log_info "Use '$0 status' to check service status"
        log_info "Use '$0 logs' to view recent logs"
        log_info "Use '$0 start-autonomous' to enable 100% autonomy"
    else
        log_error "Failed to start all services"
        stop_services
        exit 1
    fi
    ;;

start-autonomous)
    log_info "Starting Unified Todo Management System with 100% autonomy..."

    # Perform health check
    if ! check_system_health; then
        log_error "System health check failed. Please fix issues before starting."
        exit 1
    fi

    # Start basic services
    if start_dashboard_api && start_unified_agent; then
        log_success "Basic services started successfully"
    else
        log_error "Failed to start basic services"
        stop_services
        exit 1
    fi

    # Start autonomous systems
    if start_autonomous_systems; then
        log_success "Complete autonomous system started successfully!"
        echo
        log_autonomous "🎯 SYSTEM ACHIEVING 100% AUTONOMY"
        log_info "Dashboard: http://localhost:$DASHBOARD_PORT"
        log_info "All components will be managed automatically"
        log_info "Use '$0 status' to monitor the autonomous system"
    else
        log_error "Failed to start autonomous systems"
        stop_services
        exit 1
    fi
    ;;

stop)
    stop_services
    ;;

stop-autonomous)
    stop_services
    stop_autonomous_systems
    ;;

restart)
    log_info "Restarting Unified Todo Management System..."
    stop_services
    sleep 2
    exec "$0" start
    ;;

restart-autonomous)
    log_info "Restarting Unified Todo Management System with autonomy..."
    stop_services
    stop_autonomous_systems
    sleep 3
    exec "$0" start-autonomous
    ;;

status)
    show_status
    ;;

status-autonomous)
    show_autonomous_status
    ;;

health)
    if check_system_health; then
        log_success "System is healthy"
    else
        log_error "System has health issues"
        exit 1
    fi
    ;;

logs)
    echo
    log_info "=== Dashboard API Logs ==="
    if [[ -f "$API_LOG" ]]; then
        tail -20 "$API_LOG" 2>/dev/null || echo "No logs available"
    else
        echo "No API logs available"
    fi

    echo
    log_info "=== Unified Agent Logs ==="
    if [[ -f "$AGENT_LOG" ]]; then
        tail -20 "$AGENT_LOG" 2>/dev/null || echo "No logs available"
    else
        echo "No agent logs available"
    fi
    ;;

*)
    show_usage
    exit 1
    ;;
esac
