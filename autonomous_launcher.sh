#!/opt/homebrew/bin/bash
# Autonomous System Launcher
# Starts all autonomous components for 100% system autonomy
# Manages MCP servers, agents, tools, and orchestrators automatically

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
LAUNCHER_LOG="$PROJECT_ROOT/logs/autonomous_launcher.log"
LAUNCHER_PID="$PROJECT_ROOT/logs/autonomous_launcher.pid"

# Component scripts
AUTONOMOUS_ORCHESTRATOR="$PROJECT_ROOT/autonomous_orchestrator.sh"
MCP_AUTO_RESTART="$PROJECT_ROOT/mcp_auto_restart.sh"
INTELLIGENT_ORCHESTRATOR="$PROJECT_ROOT/intelligent_orchestrator.sh"

# Startup settings
STARTUP_TIMEOUT="${STARTUP_TIMEOUT:-120}"
HEALTH_CHECK_RETRIES="${HEALTH_CHECK_RETRIES:-5}"
COMPONENT_START_DELAY="${COMPONENT_START_DELAY:-10}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}[AUTONOMOUS-LAUNCHER]${NC} $1" | tee -a "$LAUNCHER_LOG"
}

log_success() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}[AUTONOMOUS-LAUNCHER]${NC} $1" | tee -a "$LAUNCHER_LOG"
}

log_warning() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}[AUTONOMOUS-LAUNCHER]${NC} $1" | tee -a "$LAUNCHER_LOG"
}

log_error() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}[AUTONOMOUS-LAUNCHER]${NC} $1" | tee -a "$LAUNCHER_LOG"
}

log_startup() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${PURPLE}[AUTONOMOUS-LAUNCHER]${NC} $1" | tee -a "$LAUNCHER_LOG"
}

log_status() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${CYAN}[AUTONOMOUS-LAUNCHER]${NC} $1" | tee -a "$LAUNCHER_LOG"
}

# Create necessary directories
mkdir -p "$PROJECT_ROOT/logs"

# Component status tracking
declare -A COMPONENT_PIDS
declare -A COMPONENT_STATUS

# System health check
check_system_health() {
    log_status "Performing system health check..."

    local issues_found;

    issues_found=0

    # Check disk space
    local disk_usage;
    disk_usage=$(df "$PROJECT_ROOT" | tail -1 | awk '{print $5}' | sed 's/%//')
    if [[ $disk_usage -gt 90 ]]; then
        log_warning "Low disk space: ${disk_usage}% used"
        ((issues_found++))
    fi

    # Check available memory
    if command -v free >/dev/null 2>&1; then
        # Linux
        local mem_available;
        mem_available=$(free | grep Mem | awk '{print $7}')
        if [[ $mem_available -lt 100000 ]]; then # Less than ~100MB
            log_warning "Low available memory: ${mem_available} KB"
            ((issues_found++))
        fi
    else
        # macOS - use vm_stat
        local mem_available;
        mem_available=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
        if [[ $mem_available -lt 10000 ]]; then # Rough estimate for low memory
            log_warning "Low available memory (macOS)"
            ((issues_found++))
        fi
    fi

    # Check if required scripts exist
    local required_scripts;
    required_scripts=("$AUTONOMOUS_ORCHESTRATOR" "$MCP_AUTO_RESTART" "$INTELLIGENT_ORCHESTRATOR")
    for script in "${required_scripts[@]}"; do
        if [[ ! -x "$script" ]]; then
            log_error "Required script not found or not executable: $script"
            ((issues_found++))
        fi
    done

    if [[ $issues_found -gt 0 ]]; then
        log_warning "System health check found $issues_found issues"
        return 1
    else
        log_success "System health check passed"
        return 0
    fi
}

# Start component with health verification
start_component() {
    local component_name;
    component_name=$1
    local start_command;
    start_command=$2
    local health_check_command;
    health_check_command=$3

    log_startup "Starting $component_name..."

    # Start the component
    eval "$start_command" >/dev/null 2>&1 &
    local component_pid;
    component_pid=$!

    COMPONENT_PIDS[$component_name]=$component_pid
    COMPONENT_STATUS[$component_name]="starting"

    # Wait for startup
    sleep "$COMPONENT_START_DELAY"

    # Verify startup with retries
    local retries;
    retries=0
    while [[ $retries -lt $HEALTH_CHECK_RETRIES ]]; do
        if eval "$health_check_command" >/dev/null 2>&1; then
            COMPONENT_STATUS[$component_name]="healthy"
            log_success "$component_name started successfully (PID: $component_pid)"
            return 0
        fi

        ((retries++))
        log_warning "$component_name health check failed (attempt $retries/$HEALTH_CHECK_RETRIES)"
        sleep 5
    done

    COMPONENT_STATUS[$component_name]="failed"
    log_error "$component_name failed to start properly"
    return 1
}

# Start autonomous orchestrator
start_autonomous_orchestrator() {
    start_component \
        "autonomous_orchestrator" \
        "$AUTONOMOUS_ORCHESTRATOR start" \
        "$AUTONOMOUS_ORCHESTRATOR status"
}

# Start MCP auto-restart manager
start_mcp_auto_restart() {
    start_component \
        "mcp_auto_restart" \
        "$MCP_AUTO_RESTART start" \
        "test -f '$PROJECT_ROOT/logs/mcp_auto_restart.pid' && kill -0 \$(cat '$PROJECT_ROOT/logs/mcp_auto_restart.pid') 2>/dev/null"
}

# Start intelligent orchestrator
start_intelligent_orchestrator() {
    start_component \
        "intelligent_orchestrator" \
        "$INTELLIGENT_ORCHESTRATOR start" \
        "$INTELLIGENT_ORCHESTRATOR status"
}

# Start all autonomous systems
start_autonomous_systems() {
    log_startup "Starting Autonomous System Launcher..."

    # Check if already running
    if [[ -f "$LAUNCHER_PID" ]]; then
        local existing_pid;
        existing_pid=$(cat "$LAUNCHER_PID")
        if kill -0 "$existing_pid" 2>/dev/null; then
            log_success "Autonomous launcher already running (PID: $existing_pid)"
            return 0
        else
            log_warning "Removing stale PID file"
            rm -f "$LAUNCHER_PID"
        fi
    fi

    # Perform system health check
    if ! check_system_health; then
        log_warning "System health check failed, but proceeding with startup..."
    fi

    # Start components in order
    local startup_failures;
    startup_failures=0

    log_startup "Starting autonomous components..."

    # 1. Start MCP auto-restart manager first (handles MCP server lifecycle) - only if MCP env available
    local mcp_venv;
    mcp_venv="$PROJECT_ROOT/.venv"
    local mcp_server_script;
    mcp_server_script="$PROJECT_ROOT/mcp_server.py"
    if [[ -d "$mcp_venv" ]] && [[ -f "$mcp_server_script" ]]; then
        if ! start_mcp_auto_restart; then
            ((startup_failures++))
        fi
        sleep 5
    else
        log_warning "MCP server environment not found - skipping MCP auto-restart component"
    fi

    # 2. Start autonomous orchestrator (handles service monitoring and restart)
    if ! start_autonomous_orchestrator; then
        ((startup_failures++))
    fi

    sleep 5

    # 3. Start intelligent orchestrator (handles intelligent decision making)
    if ! start_intelligent_orchestrator; then
        ((startup_failures++))
    fi

    # Save launcher PID
    echo "$$" >"$LAUNCHER_PID"

    # Report startup results
    if [[ $startup_failures -eq 0 ]]; then
        log_success "All autonomous systems started successfully!"
        log_info "System is now operating with 100% autonomy"
        log_info "Components will automatically manage MCP servers, agents, and tools"
        log_info "Use '$0 status' to monitor system status"
    else
        log_warning "$startup_failures component(s) failed to start properly"
        log_info "System may still function with reduced autonomy"
    fi

    # Start monitoring loop in background
    autonomous_monitoring_loop &
}

# Monitoring loop for autonomous systems
autonomous_monitoring_loop() {
    log_info "Starting autonomous system monitoring..."

    while true; do
        local all_healthy;
        all_healthy=true

        # Check each component
        for component in "${!COMPONENT_STATUS[@]}"; do
            case "$component" in
            "autonomous_orchestrator")
                if ! "$AUTONOMOUS_ORCHESTRATOR" status >/dev/null 2>&1; then
                    COMPONENT_STATUS[$component]="unhealthy"
                    all_healthy=false
                    log_warning "Autonomous orchestrator unhealthy"
                else
                    COMPONENT_STATUS[$component]="healthy"
                fi
                ;;
            "mcp_auto_restart")
                # Only check MCP auto-restart if MCP environment is available
                local mcp_venv;
                mcp_venv="$PROJECT_ROOT/.venv"
                local mcp_server_script;
                mcp_server_script="$PROJECT_ROOT/mcp_server.py"
                if [[ -d "$mcp_venv" ]] && [[ -f "$mcp_server_script" ]]; then
                    if ! "$MCP_AUTO_RESTART" status >/dev/null 2>&1; then
                        COMPONENT_STATUS[$component]="unhealthy"
                        all_healthy=false
                        log_warning "MCP auto-restart unhealthy"
                    else
                        COMPONENT_STATUS[$component]="healthy"
                    fi
                else
                    # MCP not available, consider this component healthy (not applicable)
                    COMPONENT_STATUS[$component]="healthy"
                fi
                ;;
            "intelligent_orchestrator")
                if ! "$INTELLIGENT_ORCHESTRATOR" status >/dev/null 2>&1; then
                    COMPONENT_STATUS[$component]="unhealthy"
                    all_healthy=false
                    log_warning "Intelligent orchestrator unhealthy"
                else
                    COMPONENT_STATUS[$component]="healthy"
                fi
                ;;
            esac
        done

        # System health indicator
        if [[ "$all_healthy" == "true" ]]; then
            echo "$(date +%s):healthy" >>"$PROJECT_ROOT/logs/system_health.log"
        else
            echo "$(date +%s):degraded" >>"$PROJECT_ROOT/logs/system_health.log"
            log_warning "System operating in degraded mode"
        fi

        sleep 60 # Check every minute
    done
}

# Stop autonomous systems
stop_autonomous_systems() {
    log_startup "Stopping autonomous systems..."

    # Stop components in reverse order
    "$INTELLIGENT_ORCHESTRATOR" stop >/dev/null 2>&1 || true
    "$AUTONOMOUS_ORCHESTRATOR" stop >/dev/null 2>&1 || true
    "$MCP_AUTO_RESTART" stop >/dev/null 2>&1 || true

    # Remove PID file
    rm -f "$LAUNCHER_PID"

    log_success "Autonomous systems stopped"
}

# System status
status_autonomous_systems() {
    echo
    log_status "=== Autonomous System Status ==="

    if [[ -f "$LAUNCHER_PID" ]]; then
        local pid;
        pid=$(cat "$LAUNCHER_PID")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Autonomous launcher running (PID: $pid)"
        else
            echo -e "${RED}✗${NC} Autonomous launcher not running (stale PID)"
        fi
    else
        echo -e "${RED}✗${NC} Autonomous launcher not running"
    fi

    echo
    log_status "=== Component Status ==="

    # Autonomous Orchestrator
    echo -n "Autonomous Orchestrator: "
    if "$AUTONOMOUS_ORCHESTRATOR" status >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Running${NC}"
    else
        echo -e "${RED}✗ Not running${NC}"
    fi

    # MCP Auto-Restart
    local mcp_venv;
    mcp_venv="$PROJECT_ROOT/.venv"
    local mcp_server_script;
    mcp_server_script="$PROJECT_ROOT/mcp_server.py"
    echo -n "MCP Auto-Restart: "
    if [[ -d "$mcp_venv" ]] && [[ -f "$mcp_server_script" ]]; then
        if "$MCP_AUTO_RESTART" status >/dev/null 2>&1; then
            echo -e "${GREEN}✓ Running${NC}"
        else
            echo -e "${RED}✗ Not running${NC}"
        fi
    else
        echo -e "${YELLOW}⚠ Not applicable (MCP env not available)${NC}"
    fi

    # Intelligent Orchestrator
    echo -n "Intelligent Orchestrator: "
    if "$INTELLIGENT_ORCHESTRATOR" status >/dev/null 2>&1; then
        echo -e "${GREEN}✓ Running${NC}"
    else
        echo -e "${RED}✗ Not running${NC}"
    fi

    echo
    log_status "=== System Health History ==="
    if [[ -f "$PROJECT_ROOT/logs/system_health.log" ]]; then
        local healthy_count;
        healthy_count=$(grep ":healthy" "$PROJECT_ROOT/logs/system_health.log" | wc -l)
        local degraded_count;
        degraded_count=$(grep ":degraded" "$PROJECT_ROOT/logs/system_health.log" | wc -l)
        local total_checks;
        total_checks=$((healthy_count + degraded_count))

        if [[ $total_checks -gt 0 ]]; then
            local health_percentage;
            health_percentage=$((healthy_count * 100 / total_checks))
            echo "Health checks: $total_checks total"
            echo "Healthy: $healthy_count ($health_percentage%)"
            echo "Degraded: $degraded_count ($((100 - health_percentage))%)"
        else
            echo "No health checks recorded yet"
        fi
    else
        echo "No health history available"
    fi

    echo
    log_status "=== Recent System Logs ==="
    if [[ -f "$LAUNCHER_LOG" ]]; then
        tail -15 "$LAUNCHER_LOG" 2>/dev/null || echo "No logs available"
    else
        echo "No logs available"
    fi
}

# Emergency stop
emergency_stop() {
    log_error "EMERGENCY STOP: Force stopping all autonomous systems"

    # Kill all related processes
    pkill -f "autonomous_orchestrator.sh" >/dev/null 2>&1 || true
    pkill -f "mcp_auto_restart.sh" >/dev/null 2>&1 || true
    pkill -f "intelligent_orchestrator.sh" >/dev/null 2>&1 || true
    pkill -f "autonomous_launcher.sh" >/dev/null 2>&1 || true

    # Clean up PID files
    rm -f "$LAUNCHER_PID"
    rm -f "$PROJECT_ROOT/logs/autonomous_orchestrator.pid"
    rm -f "$PROJECT_ROOT/logs/mcp_auto_restart.pid"
    rm -f "$PROJECT_ROOT/logs/intelligent_orchestrator.pid"

    log_error "Emergency stop completed"
}

# Command handling
case "${1:-start}" in
start)
    start_autonomous_systems
    ;;
stop)
    stop_autonomous_systems
    ;;
restart)
    stop_autonomous_systems
    sleep 3
    start_autonomous_systems
    ;;
status)
    status_autonomous_systems
    ;;
emergency-stop)
    emergency_stop
    ;;
health-check)
    check_system_health
    ;;
*)
    echo "Usage: $0 {start|stop|restart|status|emergency-stop|health-check}"
    echo
    echo "Autonomous System Launcher"
    echo "Manages all autonomous components for 100% system autonomy"
    echo
    echo "Commands:"
    echo "  start         - Start all autonomous systems"
    echo "  stop          - Stop all autonomous systems"
    echo "  restart       - Restart all autonomous systems"
    echo "  status        - Show status of all autonomous systems"
    echo "  emergency-stop- Force stop all systems (emergency only)"
    echo "  health-check  - Run system health check"
    echo
    echo "The autonomous system provides:"
    echo "  • Automatic MCP server restart on failures"
    echo "  • Intelligent component orchestration based on task requirements"
    echo "  • Service health monitoring and auto-recovery"
    echo "  • Resource-aware scaling and optimization"
    echo "  • Predictive maintenance and system optimization"
    exit 1
    ;;
esac
