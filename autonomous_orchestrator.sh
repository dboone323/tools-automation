#!/opt/homebrew/bin/bash
# Autonomous System Orchestrator
# Monitors and manages MCP servers, agents, tools, and services with auto-restart capabilities
# Provides 100% autonomy for the entire system

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
ORCHESTRATOR_LOG="$PROJECT_ROOT/logs/autonomous_orchestrator.log"
ORCHESTRATOR_PID="$PROJECT_ROOT/logs/autonomous_orchestrator.pid"
CONFIG_FILE="$PROJECT_ROOT/config/autonomous_config.json"

# Service configurations
MCP_HOST="${MCP_HOST:-127.0.0.1}"
MCP_PORT="${MCP_PORT:-5005}"
DASHBOARD_PORT="${DASHBOARD_PORT:-5001}"
OLLAMA_PORT="${OLLAMA_PORT:-11434}"

# Auto-restart settings
MCP_RESTART_ATTEMPTS="${MCP_RESTART_ATTEMPTS:-3}"
MCP_RESTART_DELAY="${MCP_RESTART_DELAY:-30}"
SERVICE_CHECK_INTERVAL="${SERVICE_CHECK_INTERVAL:-60}"
ORCHESTRATION_CYCLE="${ORCHESTRATION_CYCLE:-300}"

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
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}[ORCHESTRATOR]${NC} $1" | tee -a "$ORCHESTRATOR_LOG"
}

log_success() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}[ORCHESTRATOR]${NC} $1" | tee -a "$ORCHESTRATOR_LOG"
}

log_warning() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}[ORCHESTRATOR]${NC} $1" | tee -a "$ORCHESTRATOR_LOG"
}

log_error() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}[ORCHESTRATOR]${NC} $1" | tee -a "$ORCHESTRATOR_LOG"
}

log_decision() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${PURPLE}[ORCHESTRATOR]${NC} $1" | tee -a "$ORCHESTRATOR_LOG"
}

log_action() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${CYAN}[ORCHESTRATOR]${NC} $1" | tee -a "$ORCHESTRATOR_LOG"
}

# Create necessary directories
mkdir -p "$PROJECT_ROOT/logs"
mkdir -p "$PROJECT_ROOT/config"
mkdir -p "$PROJECT_ROOT/services"

# Global state tracking
declare -A SERVICE_STATUS
declare -A SERVICE_PIDS
declare -A SERVICE_RESTART_COUNT
declare -A SERVICE_LAST_CHECK
declare -A SERVICE_HEALTH_HISTORY

# Initialize configuration
init_config() {
    if [[ ! -f "$CONFIG_FILE" ]]; then
        cat >"$CONFIG_FILE" <<EOF
{
  "services": {
    "mcp_server": {
      "enabled": true,
      "auto_restart": true,
      "max_restarts": 5,
      "health_check_url": "http://${MCP_HOST}:${MCP_PORT}/health",
      "start_command": "bash mcp/servers/start_mcp_server.sh",
      "restart_delay": 30,
      "critical": true
    },
    "todo_dashboard": {
      "enabled": true,
      "auto_restart": true,
      "max_restarts": 3,
      "health_check_url": "http://localhost:${DASHBOARD_PORT}/api/todo/dashboard",
      "start_command": "bash launch_todo_system.sh start",
      "restart_delay": 15,
      "critical": false
    },
    "ollama": {
      "enabled": false,
      "auto_restart": true,
      "max_restarts": 2,
      "health_check_url": "http://localhost:${OLLAMA_PORT}/api/tags",
      "start_command": "bash ollama_service.sh start",
      "restart_delay": 60,
      "critical": false
    }
  },
  "agents": {
    "unified_todo_agent": {
      "enabled": true,
      "auto_restart": true,
      "max_restarts": 3,
      "check_command": "pgrep -f unified_todo_agent.sh",
      "start_command": "bash agents/unified_todo_agent.sh",
      "restart_delay": 20
    },
    "auto_restart_agents": {
      "enabled": true,
      "auto_restart": true,
      "max_restarts": 2,
      "check_command": "bash agents/start_recommended_agents.sh status",
      "start_command": "bash agents/start_recommended_agents.sh start",
      "restart_delay": 45
    }
  },
  "orchestration": {
    "cycle_interval": 300,
    "intelligence_enabled": true,
    "auto_scaling": true,
    "resource_monitoring": true,
    "predictive_actions": true
  },
  "autonomy": {
    "level": "full",
    "decision_making": "ai_assisted",
    "emergency_protocols": true,
    "self_healing": true,
    "adaptive_scheduling": true
  }
}
EOF
        log_success "Created autonomous orchestrator configuration"
    fi
}

# Load configuration
load_config() {
    if [[ -f "$CONFIG_FILE" ]]; then
        # Simple JSON parsing for bash (limited)
        CONFIG_CONTENT=$(cat "$CONFIG_FILE")
        log_info "Configuration loaded"
    else
        log_error "Configuration file not found: $CONFIG_FILE"
        return 1
    fi
}

# Check if service is healthy
check_service_health() {
    local service_name;
    service_name=$1
    local health_url;
    health_url=$2

    SERVICE_LAST_CHECK[$service_name]=$(date +%s)

    if curl -s --max-time 5 "$health_url" >/dev/null 2>&1; then
        SERVICE_STATUS[$service_name]="healthy"
        SERVICE_HEALTH_HISTORY[$service_name]="${SERVICE_HEALTH_HISTORY[$service_name]:-}1"
        return 0
    else
        SERVICE_STATUS[$service_name]="unhealthy"
        SERVICE_HEALTH_HISTORY[$service_name]="${SERVICE_HEALTH_HISTORY[$service_name]:-}0"
        return 1
    fi
}

# Check if process is running
check_process_health() {
    local service_name;
    service_name=$1
    local check_command;
    check_command=$2

    SERVICE_LAST_CHECK[$service_name]=$(date +%s)

    if eval "$check_command" >/dev/null 2>&1; then
        SERVICE_STATUS[$service_name]="healthy"
        SERVICE_HEALTH_HISTORY[$service_name]="${SERVICE_HEALTH_HISTORY[$service_name]:-}1"
        return 0
    else
        SERVICE_STATUS[$service_name]="unhealthy"
        SERVICE_HEALTH_HISTORY[$service_name]="${SERVICE_HEALTH_HISTORY[$service_name]:-}0"
        return 1
    fi
}

# Start a service
start_service() {
    local service_name;
    service_name=$1
    local start_command;
    start_command=$2

    log_action "Starting service: $service_name"

    if eval "$start_command" >/dev/null 2>&1; then
        SERVICE_RESTART_COUNT[$service_name]=$((SERVICE_RESTART_COUNT[$service_name] + 1))
        log_success "Service started: $service_name"
        return 0
    else
        log_error "Failed to start service: $service_name"
        return 1
    fi
}

# Restart a service with backoff
restart_service() {
    local service_name;
    service_name=$1
    local start_command;
    start_command=$2
    local restart_delay;
    restart_delay=$3
    local max_restarts;
    max_restarts=$4

    local current_restarts;

    current_restarts=${SERVICE_RESTART_COUNT[$service_name]:-0}

    if [[ $current_restarts -ge $max_restarts ]]; then
        log_error "Service $service_name has exceeded max restart attempts ($max_restarts)"
        return 1
    fi

    log_warning "Restarting service: $service_name (attempt $((current_restarts + 1))/$max_restarts)"

    # Stop existing instances first
    stop_service "$service_name"

    # Wait before restart
    sleep "$restart_delay"

    # Start service
    if start_service "$service_name" "$start_command"; then
        return 0
    else
        return 1
    fi
}

# Stop a service
stop_service() {
    local service_name;
    service_name=$1

    log_action "Stopping service: $service_name"

    # Try graceful shutdown first
    case "$service_name" in
    "mcp_server")
        if [[ -f "$PROJECT_ROOT/services/mcp.pid" ]]; then
            local pid;
            pid=$(cat "$PROJECT_ROOT/services/mcp.pid")
            kill -TERM "$pid" 2>/dev/null || true
            sleep 5
            if kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null || true
            fi
            rm -f "$PROJECT_ROOT/services/mcp.pid"
        fi
        ;;
    "todo_dashboard")
        bash launch_todo_system.sh stop >/dev/null 2>&1 || true
        ;;
    "ollama")
        bash ollama_service.sh stop >/dev/null 2>&1 || true
        ;;
    "unified_todo_agent")
        pkill -f "unified_todo_agent.sh" >/dev/null 2>&1 || true
        ;;
    "auto_restart_agents")
        bash agents/start_recommended_agents.sh stop >/dev/null 2>&1 || true
        ;;
    esac

    log_success "Service stopped: $service_name"
}

# Monitor and manage services
monitor_services() {
    log_info "Monitoring services..."

    # Monitor MCP server
    if [[ "${CONFIG_SERVICES_MCP_SERVER_ENABLED:-true}" == "true" ]]; then
        if ! check_service_health "mcp_server" "http://${MCP_HOST}:${MCP_PORT}/health"; then
            log_warning "MCP server unhealthy"
            if [[ "${CONFIG_SERVICES_MCP_SERVER_AUTO_RESTART:-true}" == "true" ]]; then
                restart_service "mcp_server" "bash mcp/servers/start_mcp_server.sh" \
                    "${CONFIG_SERVICES_MCP_SERVER_RESTART_DELAY:-30}" \
                    "${CONFIG_SERVICES_MCP_SERVER_MAX_RESTARTS:-5}"
            fi
        else
            log_success "MCP server healthy"
        fi
    fi

    # Monitor todo dashboard
    if [[ "${CONFIG_SERVICES_TODO_DASHBOARD_ENABLED:-true}" == "true" ]]; then
        if ! check_service_health "todo_dashboard" "http://localhost:${DASHBOARD_PORT}/api/todo/dashboard"; then
            log_warning "Todo dashboard unhealthy"
            if [[ "${CONFIG_SERVICES_TODO_DASHBOARD_AUTO_RESTART:-true}" == "true" ]]; then
                restart_service "todo_dashboard" "bash launch_todo_system.sh start" \
                    "${CONFIG_SERVICES_TODO_DASHBOARD_RESTART_DELAY:-15}" \
                    "${CONFIG_SERVICES_TODO_DASHBOARD_MAX_RESTARTS:-3}"
            fi
        else
            log_success "Todo dashboard healthy"
        fi
    fi

    # Monitor unified todo agent
    if [[ "${CONFIG_AGENTS_UNIFIED_TODO_AGENT_ENABLED:-true}" == "true" ]]; then
        if ! check_process_health "unified_todo_agent" "pgrep -f unified_todo_agent.sh"; then
            log_warning "Unified todo agent unhealthy"
            if [[ "${CONFIG_AGENTS_UNIFIED_TODO_AGENT_AUTO_RESTART:-true}" == "true" ]]; then
                restart_service "unified_todo_agent" "bash agents/unified_todo_agent.sh" \
                    "${CONFIG_AGENTS_UNIFIED_TODO_AGENT_RESTART_DELAY:-20}" \
                    "${CONFIG_AGENTS_UNIFIED_TODO_AGENT_MAX_RESTARTS:-3}"
            fi
        else
            log_success "Unified todo agent healthy"
        fi
    fi

    # Monitor auto-restart agents
    if [[ "${CONFIG_AGENTS_AUTO_RESTART_AGENTS_ENABLED:-true}" == "true" ]]; then
        if ! check_process_health "auto_restart_agents" "bash agents/start_recommended_agents.sh status"; then
            log_warning "Auto-restart agents unhealthy"
            if [[ "${CONFIG_AGENTS_AUTO_RESTART_AGENTS_AUTO_RESTART:-true}" == "true" ]]; then
                restart_service "auto_restart_agents" "bash agents/start_recommended_agents.sh start" \
                    "${CONFIG_AGENTS_AUTO_RESTART_AGENTS_RESTART_DELAY:-45}" \
                    "${CONFIG_AGENTS_AUTO_RESTART_AGENTS_MAX_RESTARTS:-2}"
            fi
        else
            log_success "Auto-restart agents healthy"
        fi
    fi
}

# Intelligent orchestration decisions
make_orchestration_decisions() {
    log_decision "Making intelligent orchestration decisions..."

    # Get system metrics
    local cpu_usage;
    cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    if command -v free >/dev/null 2>&1; then
        # Linux
        local mem_usage;
        mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    else
        # macOS - use vm_stat (rough estimate)
        local mem_usage;
        mem_usage=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.' | awk '{print $1 * 4096 / 1024 / 1024 / 1024 * 100}') # Rough percentage
    fi
    local disk_usage;
    disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

    log_info "System metrics - CPU: ${cpu_usage}%, Memory: ${mem_usage}%, Disk: ${disk_usage}%"

    # Decision: Scale services based on load
    if [[ $(echo "$cpu_usage > 80" | bc -l) -eq 1 ]]; then
        log_decision "High CPU usage detected - considering service optimization"
        # Could implement service scaling or optimization here
    fi

    if [[ $mem_usage -gt 85 ]]; then
        log_decision "High memory usage detected - monitoring for service restarts"
    fi

    # Decision: Check for pending todos and trigger processing
    local pending_todos;
    pending_todos=$(python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT')
try:
    from unified_todo_manager import todo_manager, TodoStatus
    todos = todo_manager.get_todos(status=TodoStatus.PENDING)
    print(len(todos))
except:
    print('0')
" 2>/dev/null || echo "0")

    if [[ $pending_todos -gt 10 ]]; then
        log_decision "High pending todo count ($pending_todos) - triggering processing"
        # Trigger todo processing
        bash agents/unified_todo_agent.sh process >/dev/null 2>&1 &
    fi

    # Decision: Check MCP server load and consider scaling
    if check_service_health "mcp_server" "http://${MCP_HOST}:${MCP_PORT}/health"; then
        # Get MCP server metrics
        local mcp_metrics;
        mcp_metrics=$(curl -s "http://${MCP_HOST}:${MCP_PORT}/api/metrics/system" 2>/dev/null || echo "{}")
        # Could analyze metrics and make scaling decisions
    fi

    # Decision: Predictive maintenance
    local current_hour;
    current_hour=$(date +%H)
    if [[ $current_hour -eq 2 ]]; then # 2 AM maintenance window
        log_decision "Maintenance window - performing system optimization"
        # Could trigger maintenance tasks here
    fi
}

# Execute autonomous actions
execute_autonomous_actions() {
    log_action "Executing autonomous actions..."

    # Action: Clean up old logs
    find "$PROJECT_ROOT/logs" -name "*.log" -mtime +7 -delete 2>/dev/null || true

    # Action: Archive old reports
    find "$PROJECT_ROOT/reports" -name "*.json" -mtime +30 -exec mv {} "$PROJECT_ROOT/archives/" \; 2>/dev/null || true

    # Action: Health check all agents
    if [[ -f "$PROJECT_ROOT/agents/agent_status.json" ]]; then
        python3 -c "
import json
import time
with open('$PROJECT_ROOT/agents/agent_status.json', 'r') as f:
    status = json.load(f)

unhealthy_agents = []
for agent, data in status.items():
    last_heartbeat = data.get('last_heartbeat', 0)
    if time.time() - last_heartbeat > 600:  # 10 minutes
        unhealthy_agents.append(agent)

if unhealthy_agents:
    print(f'Unhealthy agents: {unhealthy_agents}')
    # Could trigger agent restart here
" 2>/dev/null || true
    fi

    # Update system metrics
    {
        echo "timestamp:$(date +%s)"
        echo "cpu:$(top -bn1 | grep 'Cpu(s)' | sed 's/.*, *\([0-9.]*\)%* id.*/\1/' | awk '{print 100 - $1}')"
        if command -v free >/dev/null 2>&1; then
            echo "memory:$(free | grep Mem | awk '{printf \"%.0f\", $3/$2 * 100.0}')"
        else
            echo "memory:$(vm_stat | grep 'Pages active' | awk '{print $3}' | tr -d '.' | awk '{print $1 * 4096 / 1024 / 1024 / 1024 * 100}')"
        fi
        echo "disk:$(df / | tail -1 | awk '{print $5}' | sed 's/%//')"
    } >"$PROJECT_ROOT/logs/system_metrics.log"
}

# Emergency response system
emergency_response() {
    log_error "EMERGENCY: System instability detected!"

    # Critical service check
    local critical_services_down;
    critical_services_down=0

    if ! check_service_health "mcp_server" "http://${MCP_HOST}:${MCP_PORT}/health"; then
        ((critical_services_down++))
    fi

    # If critical services are down, attempt emergency restart
    if [[ $critical_services_down -gt 0 ]]; then
        log_error "Critical services down: $critical_services_down"

        # Emergency restart protocol
        log_action "Initiating emergency restart protocol"

        # Stop all services
        stop_service "todo_dashboard"
        stop_service "unified_todo_agent"
        stop_service "auto_restart_agents"

        # Restart MCP server with priority
        if [[ "${CONFIG_SERVICES_MCP_SERVER_ENABLED:-true}" == "true" ]]; then
            log_action "Emergency restart: MCP server"
            restart_service "mcp_server" "bash mcp/servers/start_mcp_server.sh" 5 10
        fi

        # Restart other services
        sleep 10
        if [[ "${CONFIG_SERVICES_TODO_DASHBOARD_ENABLED:-true}" == "true" ]]; then
            restart_service "todo_dashboard" "bash launch_todo_system.sh start" 5 5
        fi

        log_warning "Emergency restart protocol completed"
    fi
}

# Main orchestration loop
orchestration_loop() {
    log_info "Starting autonomous orchestration loop"

    # Disable strict error checking for the orchestration loop to prevent exit on failures
    set +euo pipefail

    while true; do
        local cycle_start;
        cycle_start=$(date +%s)

        # Monitor all services
        monitor_services

        # Make intelligent decisions
        make_orchestration_decisions

        # Execute autonomous actions
        execute_autonomous_actions

        # Emergency response check
        local unhealthy_count;
        unhealthy_count=0
        for status in "${SERVICE_STATUS[@]}"; do
            if [[ "$status" == "unhealthy" ]]; then
                ((unhealthy_count++))
            fi
        done

        if [[ $unhealthy_count -gt 2 ]]; then
            emergency_response
        fi

        # Calculate sleep time to maintain cycle interval
        local cycle_end;
        cycle_end=$(date +%s)
        local cycle_duration;
        cycle_duration=$((cycle_end - cycle_start))
        local sleep_time;
        sleep_time=$((ORCHESTRATION_CYCLE - cycle_duration))

        if [[ $sleep_time -gt 0 ]]; then
            log_info "Orchestration cycle complete. Sleeping for ${sleep_time}s..."
            sleep "$sleep_time"
        else
            log_warning "Orchestration cycle took longer than expected (${cycle_duration}s)"
        fi
    done
}

# Service management functions
start_orchestrator() {
    log_info "Starting Autonomous System Orchestrator..."

    # Check if already running
    if [[ -f "$ORCHESTRATOR_PID" ]]; then
        local existing_pid;
        existing_pid=$(cat "$ORCHESTRATOR_PID")
        if kill -0 "$existing_pid" 2>/dev/null; then
            log_success "Orchestrator already running (PID: $existing_pid)"
            return 0
        else
            log_warning "Removing stale PID file"
            rm -f "$ORCHESTRATOR_PID"
        fi
    fi

    # Initialize configuration
    init_config
    load_config

    # Start orchestration loop in background
    nohup bash -c "source '$0'; orchestration_loop" >/dev/null 2>&1 &
    local orchestrator_pid;
    orchestrator_pid=$!

    # Save PID
    echo "$orchestrator_pid" >"$ORCHESTRATOR_PID"

    log_success "Autonomous System Orchestrator started (PID: $orchestrator_pid)"
    log_info "Monitoring and managing all system components autonomously"
}

stop_orchestrator() {
    log_info "Stopping Autonomous System Orchestrator..."

    if [[ -f "$ORCHESTRATOR_PID" ]]; then
        local pid;
        pid=$(cat "$ORCHESTRATOR_PID")
        if kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || true
            sleep 5
            if kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$ORCHESTRATOR_PID"
        log_success "Orchestrator stopped"
    else
        log_warning "Orchestrator PID file not found"
    fi
}

status_orchestrator() {
    echo
    log_info "=== Autonomous System Orchestrator Status ==="

    local is_running;

    is_running=0

    if [[ -f "$ORCHESTRATOR_PID" ]]; then
        local pid;
        pid=$(cat "$ORCHESTRATOR_PID")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Orchestrator running (PID: $pid)"
            is_running=1
        else
            echo -e "${RED}✗${NC} Orchestrator not running (stale PID)"
        fi
    else
        echo -e "${RED}✗${NC} Orchestrator not running"
    fi

    echo
    log_info "=== Service Status ==="
    for service in "${!SERVICE_STATUS[@]}"; do
        local status;
        status="${SERVICE_STATUS[$service]}"
        local last_check;
        last_check="${SERVICE_LAST_CHECK[$service]:-never}"
        local restarts;
        restarts="${SERVICE_RESTART_COUNT[$service]:-0}"

        if [[ "$status" == "healthy" ]]; then
            echo -e "${GREEN}✓${NC} $service (restarts: $restarts, last check: $last_check)"
        else
            echo -e "${RED}✗${NC} $service (restarts: $restarts, last check: $last_check)"
        fi
    done

    echo
    log_info "=== Recent Orchestrator Logs ==="
    if [[ -f "$ORCHESTRATOR_LOG" ]]; then
        tail -10 "$ORCHESTRATOR_LOG" 2>/dev/null || echo "No logs available"
    else
        echo "No logs available"
    fi

    return $((1 - is_running))
}

# Command handling - only run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-start}" in
    start)
        start_orchestrator
        ;;
    stop)
        stop_orchestrator
        ;;
    restart)
        stop_orchestrator
        sleep 2
        start_orchestrator
        ;;
    status)
        status_orchestrator
        ;;
    monitor)
        monitor_services
        ;;
    emergency)
        emergency_response
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|monitor|emergency}"
        echo
        echo "Autonomous System Orchestrator"
        echo "Manages MCP servers, agents, and tools with auto-restart capabilities"
        echo
        echo "Commands:"
        echo "  start     - Start the autonomous orchestrator"
        echo "  stop      - Stop the orchestrator"
        echo "  restart   - Restart the orchestrator"
        echo "  status    - Show orchestrator and service status"
        echo "  monitor   - Run a single monitoring cycle"
        echo "  emergency - Trigger emergency response protocol"
        exit 1
        ;;
    esac
fi
