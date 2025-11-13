#!/opt/homebrew/bin/bash
# MCP Server Auto-Restart Manager
# Provides automatic restart capabilities for MCP servers with health monitoring
# Integrates with the autonomous orchestrator for 100% system autonomy

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
MCP_AUTO_RESTART_LOG="$PROJECT_ROOT/logs/mcp_auto_restart.log"
MCP_AUTO_RESTART_PID="$PROJECT_ROOT/logs/mcp_auto_restart.pid"

# MCP Server settings
MCP_HOST="${MCP_HOST:-127.0.0.1}"
MCP_PORT="${MCP_PORT:-5005}"
# MCP server configuration
MCP_VENV_PATH="${MCP_VENV_PATH:-$PROJECT_ROOT/.venv}"
MCP_SERVER_SCRIPT="${MCP_SERVER_SCRIPT:-$PROJECT_ROOT/mcp_server.py}"

# Auto-restart settings
HEALTH_CHECK_INTERVAL="${HEALTH_CHECK_INTERVAL:-30}"
RESTART_DELAY="${RESTART_DELAY:-30}"
MAX_RESTART_ATTEMPTS="${MAX_RESTART_ATTEMPTS:-5}"
HEALTH_TIMEOUT="${HEALTH_TIMEOUT:-10}"
STARTUP_GRACE_PERIOD="${STARTUP_GRACE_PERIOD:-60}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}[MCP-AUTO-RESTART]${NC} $1" | tee -a "$MCP_AUTO_RESTART_LOG"
}

log_success() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}[MCP-AUTO-RESTART]${NC} $1" | tee -a "$MCP_AUTO_RESTART_LOG"
}

log_warning() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}[MCP-AUTO-RESTART]${NC} $1" | tee -a "$MCP_AUTO_RESTART_LOG"
}

log_error() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}[MCP-AUTO-RESTART]${NC} $1" | tee -a "$MCP_AUTO_RESTART_LOG"
}

log_action() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${CYAN}[MCP-AUTO-RESTART]${NC} $1" | tee -a "$MCP_AUTO_RESTART_LOG"
}

# Create necessary directories
mkdir -p "$PROJECT_ROOT/logs"
mkdir -p "$PROJECT_ROOT/services"

# Global state
RESTART_COUNT=0
LAST_RESTART_TIME=0
HEALTH_CHECK_COUNT=0
CONSECUTIVE_FAILURES=0
LAST_HEALTHY_TIME=$(date +%s)

# Health check functions
check_mcp_health() {
    local timeout=$HEALTH_TIMEOUT
    local start_time=$(date +%s)

    log_info "Checking MCP server health at http://${MCP_HOST}:${MCP_PORT}/health"

    # Use curl with timeout
    if curl -s --max-time "$timeout" --connect-timeout "$timeout" \
        "http://${MCP_HOST}:${MCP_PORT}/health" >/dev/null 2>&1; then

        local response_time=$(($(date +%s) - start_time))
        log_success "MCP server healthy (response time: ${response_time}s)"
        CONSECUTIVE_FAILURES=0
        LAST_HEALTHY_TIME=$(date +%s)
        return 0
    else
        log_warning "MCP server health check failed"
        ((CONSECUTIVE_FAILURES++))
        return 1
    fi
}

check_mcp_process() {
    # Check if MCP server process is running
    local mcp_pid_file="$PROJECT_ROOT/services/mcp.pid"

    if [[ -f "$mcp_pid_file" ]]; then
        local pid=$(cat "$mcp_pid_file")
        if kill -0 "$pid" 2>/dev/null; then
            log_info "MCP server process running (PID: $pid)"
            return 0
        else
            log_warning "MCP server process not running (stale PID file)"
            rm -f "$mcp_pid_file"
            return 1
        fi
    else
        log_warning "MCP server PID file not found"
        return 1
    fi
}

# Server management functions
start_mcp_server() {
    log_action "Starting MCP server..."

    # Check if virtual environment exists
    if [[ ! -d "$MCP_VENV_PATH" ]]; then
        log_error "MCP virtual environment not found: $MCP_VENV_PATH"
        return 1
    fi

    # Check if server script exists
    if [[ ! -f "$MCP_SERVER_SCRIPT" ]]; then
        log_error "MCP server script not found: $MCP_SERVER_SCRIPT"
        return 1
    fi

    # Activate virtual environment and start server
    cd "$PROJECT_ROOT"

    # Start server in background
    (
        source "$MCP_VENV_PATH/bin/activate"
        export PYTHONPATH="$PROJECT_ROOT:$PYTHONPATH"
        export MCP_HOST="$MCP_HOST"
        export MCP_PORT="$MCP_PORT"

        python3 "$MCP_SERVER_SCRIPT" &
        echo $! >"$PROJECT_ROOT/services/mcp.pid"
    ) >/dev/null 2>&1

    # Wait for startup
    log_info "Waiting for MCP server to start (grace period: ${STARTUP_GRACE_PERIOD}s)"
    sleep "$STARTUP_GRACE_PERIOD"

    # Verify startup
    if check_mcp_health; then
        log_success "MCP server started successfully"
        RESTART_COUNT=$((RESTART_COUNT + 1))
        LAST_RESTART_TIME=$(date +%s)
        return 0
    else
        log_error "MCP server failed to start properly"
        return 1
    fi
}

stop_mcp_server() {
    log_action "Stopping MCP server..."

    local mcp_pid_file="$PROJECT_ROOT/services/mcp.pid"

    if [[ -f "$mcp_pid_file" ]]; then
        local pid=$(cat "$mcp_pid_file")

        # Try graceful shutdown first
        kill -TERM "$pid" 2>/dev/null || true
        sleep 10

        # Force kill if still running
        if kill -0 "$pid" 2>/dev/null; then
            log_warning "Force killing MCP server process"
            kill -KILL "$pid" 2>/dev/null || true
            sleep 2
        fi

        rm -f "$mcp_pid_file"
        log_success "MCP server stopped"
    else
        log_warning "MCP server PID file not found"
    fi
}

restart_mcp_server() {
    local force_restart=${1:-false}

    if [[ "$force_restart" == "true" ]]; then
        log_action "Force restarting MCP server"
    else
        log_action "Restarting MCP server (attempt $((RESTART_COUNT + 1))/$MAX_RESTART_ATTEMPTS)"
    fi

    # Check restart limits
    if [[ $RESTART_COUNT -ge $MAX_RESTART_ATTEMPTS && "$force_restart" != "true" ]]; then
        log_error "Maximum restart attempts reached ($MAX_RESTART_ATTEMPTS)"
        log_error "Manual intervention required"
        return 1
    fi

    # Stop existing server
    stop_mcp_server

    # Wait before restart
    if [[ "$force_restart" != "true" ]]; then
        log_info "Waiting ${RESTART_DELAY}s before restart..."
        sleep "$RESTART_DELAY"
    fi

    # Start new server
    if start_mcp_server; then
        return 0
    else
        log_error "Failed to restart MCP server"
        return 1
    fi
}

# Monitoring and decision making
monitor_and_manage() {
    ((HEALTH_CHECK_COUNT++))

    local current_time=$(date +%s)
    local time_since_last_restart=$((current_time - LAST_RESTART_TIME))
    local time_since_last_healthy=$((current_time - LAST_HEALTHY_TIME))

    log_info "Health check #$HEALTH_CHECK_COUNT - Failures: $CONSECUTIVE_FAILURES"

    # Check if server is running
    if ! check_mcp_process; then
        log_info "MCP server not running - attempting to start it"
        if restart_mcp_server 2>/dev/null; then
            log_success "MCP server started successfully"
        else
            log_warning "Failed to start MCP server, will retry on next cycle"
            ((CONSECUTIVE_FAILURES++))
        fi
        return
    fi

    # Perform health check
    if ! check_mcp_health 2>/dev/null; then
        log_warning "MCP server health check failed"

        # Decision: Restart based on consecutive failures
        if [[ $CONSECUTIVE_FAILURES -ge 3 ]]; then
            log_warning "Multiple consecutive failures detected ($CONSECUTIVE_FAILURES)"
            restart_mcp_server 2>/dev/null || log_error "Failed to restart MCP server"
        elif [[ $time_since_last_healthy -gt 300 ]]; then # 5 minutes
            log_warning "Server unhealthy for more than 5 minutes"
            restart_mcp_server 2>/dev/null || log_error "Failed to restart MCP server"
        else
            log_info "Waiting for server to recover..."
        fi
    else
        # Server is healthy
        if [[ $CONSECUTIVE_FAILURES -gt 0 ]]; then
            log_success "MCP server recovered after $CONSECUTIVE_FAILURES failures"
        fi
        CONSECUTIVE_FAILURES=0
        LAST_HEALTHY_TIME=$(date +%s)
    fi

    # Periodic maintenance checks
    if [[ $((HEALTH_CHECK_COUNT % 10)) -eq 0 ]]; then
        log_info "Performing periodic maintenance checks"

        # Check disk space
        local disk_usage=$(df "$PROJECT_ROOT" 2>/dev/null | tail -1 | awk '{print $5}' | sed 's/%//' || echo "0")
        if [[ $disk_usage -gt 90 ]]; then
            log_warning "High disk usage detected: ${disk_usage}%"
            # Could trigger cleanup here
        fi

        # Check memory usage
        if command -v free >/dev/null 2>&1; then
            # Linux
            local mem_usage=$(free 2>/dev/null | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}' || echo "0")
        else
            # macOS - use vm_stat (rough estimate)
            local mem_usage=$(vm_stat 2>/dev/null | grep "Pages active" | awk '{print $3}' | tr -d '.' | awk '{print $1 * 4096 / 1024 / 1024 / 1024 * 100}' || echo "0")
        fi
        if [[ $mem_usage -gt 85 ]]; then
            log_warning "High memory usage detected: ${mem_usage}%"
            # Could trigger restart or optimization
        fi
    fi
}

# Emergency recovery
emergency_recovery() {
    log_error "EMERGENCY: Initiating MCP server emergency recovery"

    # Force stop any existing processes
    pkill -9 -f "mcp_server.py" >/dev/null 2>&1 || true
    pkill -9 -f "python3.*mcp_server.py" >/dev/null 2>&1 || true

    # Clean up PID files
    rm -f "$PROJECT_ROOT/services/mcp.pid"

    # Force restart
    log_action "Force restarting MCP server in emergency mode"
    RESTART_COUNT=0 # Reset counter for emergency
    restart_mcp_server "true"
}

# Main monitoring loop
monitoring_loop() {
    log_info "Starting MCP server auto-restart monitoring loop"
    log_info "Health check interval: ${HEALTH_CHECK_INTERVAL}s"
    log_info "Max restart attempts: $MAX_RESTART_ATTEMPTS"

    # Disable strict error checking for the monitoring loop to prevent exit on failures
    set +euo pipefail

    while true; do
        local cycle_start=$(date +%s)

        monitor_and_manage

        # Emergency check
        if [[ $CONSECUTIVE_FAILURES -ge 10 ]]; then
            log_error "Critical failure threshold reached ($CONSECUTIVE_FAILURES consecutive failures)"
            emergency_recovery
        fi

        local cycle_end=$(date +%s)
        local cycle_duration=$((cycle_end - cycle_start))
        local sleep_time=$((HEALTH_CHECK_INTERVAL - cycle_duration))

        if [[ $sleep_time -gt 0 ]]; then
            sleep "$sleep_time"
        else
            log_warning "Health check cycle took longer than expected (${cycle_duration}s)"
        fi
    done
}

# Service management functions
start_auto_restart() {
    log_info "Starting MCP Server Auto-Restart Manager..."

    # Check if already running
    if [[ -f "$MCP_AUTO_RESTART_PID" ]]; then
        local existing_pid=$(cat "$MCP_AUTO_RESTART_PID")
        if kill -0 "$existing_pid" 2>/dev/null; then
            log_success "Auto-restart manager already running (PID: $existing_pid)"
            return 0
        else
            log_warning "Removing stale PID file"
            rm -f "$MCP_AUTO_RESTART_PID"
        fi
    fi

    # Start monitoring loop in background
    log_info "Starting background monitoring loop..."
    nohup bash -c "source '$0'; monitoring_loop" >/dev/null 2>&1 &
    local manager_pid=$!
    log_info "Background process started with PID: $manager_pid"

    # Save PID
    echo "$manager_pid" >"$MCP_AUTO_RESTART_PID"

    log_success "MCP Server Auto-Restart Manager started (PID: $manager_pid)"
}

stop_auto_restart() {
    log_info "Stopping MCP Server Auto-Restart Manager..."

    if [[ -f "$MCP_AUTO_RESTART_PID" ]]; then
        local pid=$(cat "$MCP_AUTO_RESTART_PID")
        if kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || true
            sleep 5
            if kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$MCP_AUTO_RESTART_PID"
        log_success "Auto-restart manager stopped"
    else
        log_warning "Auto-restart manager PID file not found"
    fi
}

status_auto_restart() {
    echo
    log_info "=== MCP Server Auto-Restart Manager Status ==="

    local is_running=0

    if [[ -f "$MCP_AUTO_RESTART_PID" ]]; then
        local pid=$(cat "$MCP_AUTO_RESTART_PID")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Auto-restart manager running (PID: $pid)"
            is_running=1
        else
            echo -e "${RED}✗${NC} Auto-restart manager not running (stale PID)"
        fi
    else
        echo -e "${RED}✗${NC} Auto-restart manager not running"
    fi

    echo
    log_info "=== MCP Server Status ==="
    if check_mcp_process && check_mcp_health; then
        echo -e "${GREEN}✓${NC} MCP server healthy"
    elif check_mcp_process; then
        echo -e "${YELLOW}⚠${NC} MCP server running but unhealthy"
    else
        echo -e "${RED}✗${NC} MCP server not running"
    fi

    echo
    log_info "=== Statistics ==="
    echo "Restart count: $RESTART_COUNT"
    echo "Health checks performed: $HEALTH_CHECK_COUNT"
    echo "Consecutive failures: $CONSECUTIVE_FAILURES"
    echo "Last healthy: $(date -d "@$LAST_HEALTHY_TIME" '+%Y-%m-%d %H:%M:%S' 2>/dev/null || echo 'never')"

    echo
    log_info "=== Recent Logs ==="
    if [[ -f "$MCP_AUTO_RESTART_LOG" ]]; then
        tail -10 "$MCP_AUTO_RESTART_LOG" 2>/dev/null || echo "No logs available"
    else
        echo "No logs available"
    fi

    return $((1 - is_running))
}

# Command handling - only run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-start}" in
    start)
        start_auto_restart
        ;;
    stop)
        stop_auto_restart
        ;;
    restart)
        stop_auto_restart
        sleep 2
        start_auto_restart
        ;;
    status)
        status_auto_restart
        ;;
    monitor)
        monitor_and_manage
        ;;
    emergency)
        emergency_recovery
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|monitor|emergency}"
        echo
        echo "MCP Server Auto-Restart Manager"
        echo "Provides automatic restart capabilities for MCP servers"
        echo
        echo "Commands:"
        echo "  start     - Start the auto-restart manager"
        echo "  stop      - Stop the auto-restart manager"
        echo "  restart   - Restart the auto-restart manager"
        echo "  status    - Show manager and MCP server status"
        echo "  monitor   - Run a single monitoring cycle"
        echo "  emergency - Trigger emergency recovery protocol"
        exit 1
        ;;
    esac
fi
