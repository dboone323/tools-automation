#!/opt/homebrew/bin/bash
# Intelligent Component Orchestrator
# Dynamically manages MCP servers, agents, and tools based on task requirements
# Provides 100% autonomous operation with intelligent decision making

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$SCRIPT_DIR"
INTELLIGENT_ORCHESTRATOR_LOG="$PROJECT_ROOT/logs/intelligent_orchestrator.log"
INTELLIGENT_ORCHESTRATOR_PID="$PROJECT_ROOT/logs/intelligent_orchestrator.pid"
TASK_ANALYSIS_CACHE="$PROJECT_ROOT/cache/task_analysis.json"

# Service endpoints
MCP_HOST="${MCP_HOST:-127.0.0.1}"
MCP_PORT="${MCP_PORT:-5005}"
DASHBOARD_PORT="${DASHBOARD_PORT:-5001}"

# Intelligence settings
ANALYSIS_INTERVAL="${ANALYSIS_INTERVAL:-60}"
DECISION_THRESHOLD="${DECISION_THRESHOLD:-0.7}"
RESOURCE_CHECK_INTERVAL="${RESOURCE_CHECK_INTERVAL:-30}"
ADAPTIVE_SCALING="${ADAPTIVE_SCALING:-true}"

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
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${BLUE}[INTELLIGENT-ORCHESTRATOR]${NC} $1" | tee -a "$INTELLIGENT_ORCHESTRATOR_LOG"
}

log_success() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${GREEN}[INTELLIGENT-ORCHESTRATOR]${NC} $1" | tee -a "$INTELLIGENT_ORCHESTRATOR_LOG"
}

log_warning() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${YELLOW}[INTELLIGENT-ORCHESTRATOR]${NC} $1" | tee -a "$INTELLIGENT_ORCHESTRATOR_LOG"
}

log_error() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${RED}[INTELLIGENT-ORCHESTRATOR]${NC} $1" | tee -a "$INTELLIGENT_ORCHESTRATOR_LOG"
}

log_decision() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${PURPLE}[INTELLIGENT-ORCHESTRATOR]${NC} $1" | tee -a "$INTELLIGENT_ORCHESTRATOR_LOG"
}

log_action() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${CYAN}[INTELLIGENT-ORCHESTRATOR]${NC} $1" | tee -a "$INTELLIGENT_ORCHESTRATOR_LOG"
}

log_intelligence() {
    echo -e "$(date '+%Y-%m-%d %H:%M:%S') ${WHITE}[INTELLIGENT-ORCHESTRATOR]${NC} $1" | tee -a "$INTELLIGENT_ORCHESTRATOR_LOG"
}

# Create necessary directories
mkdir -p "$PROJECT_ROOT/logs"
mkdir -p "$PROJECT_ROOT/cache"
mkdir -p "$PROJECT_ROOT/services"

# Global state tracking
declare -A COMPONENT_STATUS
declare -A COMPONENT_LOAD
declare -A COMPONENT_CAPABILITIES
declare -A ACTIVE_TASKS
declare -A RESOURCE_USAGE

# Component definitions
define_components() {
    # MCP Server capabilities
    COMPONENT_CAPABILITIES["mcp_server"]="mcp,tools,agents,orchestration,health_monitoring,plugin_system,circuit_breaker,redis_cache"

    # Todo Dashboard capabilities
    COMPONENT_CAPABILITIES["todo_dashboard"]="todo_management,dashboard,api,web_interface,real_time_updates"

    # Unified Todo Agent capabilities
    COMPONENT_CAPABILITIES["unified_todo_agent"]="todo_processing,analysis,assignment,execution,monitoring"

    # Auto-restart Agents capabilities
    COMPONENT_CAPABILITIES["auto_restart_agents"]="agent_monitoring,health_checks,auto_restart,service_management"

    # Ollama capabilities (if available)
    COMPONENT_CAPABILITIES["ollama"]="ai_inference,language_models,text_generation,embeddings"

    # Initialize status
    for component in "${!COMPONENT_CAPABILITIES[@]}"; do
        COMPONENT_STATUS[$component]="unknown"
        COMPONENT_LOAD[$component]=0
    done
}

# Task analysis and requirements
analyze_task_requirements() {
    log_intelligence "Analyzing current task requirements..."

    local pending_todos=0
    local critical_todos=0
    local agent_tasks=0

    # Get todo statistics
    if python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT')
try:
    from unified_todo_manager import todo_manager, TodoStatus, TodoPriority
    todos = todo_manager.get_todos()
    pending = [t for t in todos if t.status == TodoStatus.PENDING]
    critical = [t for t in pending if t.priority == TodoPriority.CRITICAL]
    print(f'{len(pending)} {len(critical)}')
except Exception as e:
    print('0 0')
" 2>/dev/null; then
        read -r pending_todos critical_todos <<<"$(python3 -c "
import sys
sys.path.insert(0, '$PROJECT_ROOT')
try:
    from unified_todo_manager import todo_manager, TodoStatus, TodoPriority
    todos = todo_manager.get_todos()
    pending = [t for t in todos if t.status == TodoStatus.PENDING]
    critical = [t for t in pending if t.priority == TodoPriority.CRITICAL]
    print(f'{len(pending)} {len(critical)}')
except Exception as e:
    print('0 0')
" 2>/dev/null)"
    fi

    # Get agent task count
    if [[ -f "$PROJECT_ROOT/agents/agent_status.json" ]]; then
        agent_tasks=$(python3 -c "
import json
with open('$PROJECT_ROOT/agents/agent_status.json', 'r') as f:
    status = json.load(f)
active_tasks = sum(len(agent.get('active_tasks', [])) for agent in status.values())
print(active_tasks)
" 2>/dev/null || echo "0")
    fi

    # Analyze MCP server load
    local mcp_load=0
    if check_component_health "mcp_server"; then
        mcp_load=$(curl -s "http://${MCP_HOST}:${MCP_PORT}/api/metrics/load" 2>/dev/null | python3 -c "
import sys, json
try:
    data = json.load(sys.stdin)
    print(int(data.get('active_connections', 0) * 10))  # Rough load estimate
except:
    print('0')
" 2>/dev/null || echo "0")
    fi

    # Store analysis results
    cat >"$TASK_ANALYSIS_CACHE" <<EOF
{
  "timestamp": $(date +%s),
  "pending_todos": $pending_todos,
  "critical_todos": $critical_todos,
  "agent_tasks": $agent_tasks,
  "mcp_load": $mcp_load,
  "system_load": $(uptime | awk '{print $NF}' | sed 's/,//')
}
EOF

    log_intelligence "Task analysis: $pending_todos pending todos, $critical_todos critical, $agent_tasks agent tasks, MCP load: $mcp_load"
}

# Component health checking
check_component_health() {
    local component=$1

    case "$component" in
    "mcp_server")
        if curl -s --max-time 5 "http://${MCP_HOST}:${MCP_PORT}/health" >/dev/null 2>&1; then
            COMPONENT_STATUS[$component]="healthy"
            return 0
        else
            COMPONENT_STATUS[$component]="unhealthy"
            return 1
        fi
        ;;
    "todo_dashboard")
        if curl -s --max-time 5 "http://localhost:${DASHBOARD_PORT}/api/todo/dashboard" >/dev/null 2>&1; then
            COMPONENT_STATUS[$component]="healthy"
            return 0
        else
            COMPONENT_STATUS[$component]="unhealthy"
            return 1
        fi
        ;;
    "unified_todo_agent")
        if pgrep -f "unified_todo_agent.sh" >/dev/null 2>&1; then
            COMPONENT_STATUS[$component]="healthy"
            return 0
        else
            COMPONENT_STATUS[$component]="unhealthy"
            return 1
        fi
        ;;
    "auto_restart_agents")
        if bash agents/start_recommended_agents.sh status >/dev/null 2>&1; then
            COMPONENT_STATUS[$component]="healthy"
            return 0
        else
            COMPONENT_STATUS[$component]="unhealthy"
            return 1
        fi
        ;;
    "ollama")
        if curl -s --max-time 5 "http://localhost:11434/api/tags" >/dev/null 2>&1; then
            COMPONENT_STATUS[$component]="healthy"
            return 0
        else
            COMPONENT_STATUS[$component]="unhealthy"
            return 1
        fi
        ;;
    *)
        COMPONENT_STATUS[$component]="unknown"
        return 1
        ;;
    esac
}

# Intelligent decision making
make_intelligent_decisions() {
    log_decision "Making intelligent orchestration decisions..."

    # Load task analysis
    local analysis_data="{}"
    if [[ -f "$TASK_ANALYSIS_CACHE" ]]; then
        analysis_data=$(cat "$TASK_ANALYSIS_CACHE")
    fi

    local pending_todos=$(echo "$analysis_data" | python3 -c "import sys, json; print(json.load(sys.stdin).get('pending_todos', 0))" 2>/dev/null || echo "0")
    local critical_todos=$(echo "$analysis_data" | python3 -c "import sys, json; print(json.load(sys.stdin).get('critical_todos', 0))" 2>/dev/null || echo "0")
    local agent_tasks=$(echo "$analysis_data" | python3 -c "import sys, json; print(json.load(sys.stdin).get('agent_tasks', 0))" 2>/dev/null || echo "0")
    local mcp_load=$(echo "$analysis_data" | python3 -c "import sys, json; print(json.load(sys.stdin).get('mcp_load', 0))" 2>/dev/null || echo "0")

    # Decision 1: MCP Server management
    if [[ $pending_todos -gt 0 || $agent_tasks -gt 0 ]]; then
        if [[ "${COMPONENT_STATUS[mcp_server]}" != "healthy" ]]; then
            log_decision "Tasks detected but MCP server unhealthy - starting MCP server"
            start_component "mcp_server"
        fi
    elif [[ $pending_todos -eq 0 && $agent_tasks -eq 0 && $mcp_load -lt 20 ]]; then
        # Low activity - could consider scaling down, but keep running for now
        log_decision "Low activity detected - maintaining MCP server"
    fi

    # Decision 2: Todo Dashboard management
    if [[ $pending_todos -gt 5 || $critical_todos -gt 0 ]]; then
        if [[ "${COMPONENT_STATUS[todo_dashboard]}" != "healthy" ]]; then
            log_decision "High todo volume detected - starting todo dashboard"
            start_component "todo_dashboard"
        fi
    fi

    # Decision 3: Agent management
    if [[ $pending_todos -gt 10 || $critical_todos -gt 1 ]]; then
        if [[ "${COMPONENT_STATUS[unified_todo_agent]}" != "healthy" ]]; then
            log_decision "High task load detected - starting unified todo agent"
            start_component "unified_todo_agent"
        fi
    fi

    # Decision 4: Auto-restart agents
    if [[ "${COMPONENT_STATUS[unified_todo_agent]}" == "healthy" ]]; then
        if [[ "${COMPONENT_STATUS[auto_restart_agents]}" != "healthy" ]]; then
            log_decision "Todo agent active - ensuring auto-restart agents are running"
            start_component "auto_restart_agents"
        fi
    fi

    # Decision 5: AI services (Ollama)
    local needs_ai=false
    # Check if any pending todos require AI processing
    if [[ $pending_todos -gt 0 ]]; then
        # Could analyze todo content for AI requirements here
        needs_ai=true
    fi

    if [[ "$needs_ai" == "true" && "${COMPONENT_STATUS[ollama]}" != "healthy" ]]; then
        log_decision "AI processing needed - starting Ollama service"
        start_component "ollama"
    fi

    # Decision 6: Resource-based scaling
    # Get system metrics
    local cpu_usage=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    if command -v free >/dev/null 2>&1; then
        # Linux
        local mem_usage=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    else
        # macOS - use vm_stat (rough estimate)
        local mem_usage=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.' | awk '{print $1 * 4096 / 1024 / 1024 / 1024 * 100}') # Rough percentage
    fi

    if [[ $(echo "$cpu_usage > 80" | bc -l) -eq 1 ]]; then
        log_decision "High CPU usage ($cpu_usage%) - considering load shedding"
        # Could stop non-critical components here
    fi

    if [[ $mem_usage -gt 85 ]]; then
        log_decision "High memory usage ($mem_usage%) - monitoring for optimization"
    fi
}

# Component management
start_component() {
    local component=$1

    log_action "Starting component: $component"

    case "$component" in
    "mcp_server")
        bash mcp/servers/start_mcp_server.sh >/dev/null 2>&1 &
        ;;
    "todo_dashboard")
        bash launch_todo_system.sh start >/dev/null 2>&1 &
        ;;
    "unified_todo_agent")
        bash agents/unified_todo_agent.sh >/dev/null 2>&1 &
        ;;
    "auto_restart_agents")
        bash agents/start_recommended_agents.sh start >/dev/null 2>&1 &
        ;;
    "ollama")
        bash ollama_service.sh start >/dev/null 2>&1 &
        ;;
    esac

    # Wait a bit for startup
    sleep 5

    # Verify startup
    if check_component_health "$component"; then
        log_success "Component started successfully: $component"
    else
        log_warning "Component may not have started properly: $component"
    fi
}

stop_component() {
    local component=$1

    log_action "Stopping component: $component"

    case "$component" in
    "mcp_server")
        bash mcp_auto_restart.sh stop >/dev/null 2>&1
        ;;
    "todo_dashboard")
        bash launch_todo_system.sh stop >/dev/null 2>&1
        ;;
    "unified_todo_agent")
        pkill -f "unified_todo_agent.sh" >/dev/null 2>&1
        ;;
    "auto_restart_agents")
        bash agents/start_recommended_agents.sh stop >/dev/null 2>&1
        ;;
    "ollama")
        bash ollama_service.sh stop >/dev/null 2>&1
        ;;
    esac

    COMPONENT_STATUS[$component]="stopped"
    log_success "Component stopped: $component"
}

# Predictive analytics
predictive_actions() {
    log_intelligence "Running predictive analytics..."

    # Analyze patterns from recent activity
    local current_hour=$(date +%H)
    local day_of_week=$(date +%u) # 1=Monday, 7=Sunday

    # Peak hours prediction
    if [[ $current_hour -ge 9 && $current_hour -le 17 ]]; then
        log_intelligence "Peak hours detected - ensuring full service availability"
        # Ensure all critical components are running during work hours
        for component in mcp_server todo_dashboard unified_todo_agent; do
            if [[ "${COMPONENT_STATUS[$component]}" != "healthy" ]]; then
                log_decision "Starting $component for peak hours coverage"
                start_component "$component"
            fi
        done
    fi

    # Weekend patterns
    if [[ $day_of_week -ge 6 ]]; then
        log_intelligence "Weekend detected - maintaining minimal services"
        # Could scale down non-essential services on weekends
    fi

    # Maintenance windows
    if [[ $current_hour -eq 3 ]]; then # 3 AM maintenance
        log_intelligence "Maintenance window - performing system optimization"
        # Trigger maintenance tasks
        cleanup_old_files
    fi
}

# System optimization
cleanup_old_files() {
    log_action "Performing system cleanup..."

    # Clean old logs (keep last 7 days)
    find "$PROJECT_ROOT/logs" -name "*.log" -mtime +7 -delete 2>/dev/null || true

    # Clean old cache files
    find "$PROJECT_ROOT/cache" -name "*.json" -mtime +1 -delete 2>/dev/null || true

    # Clean old reports
    find "$PROJECT_ROOT/reports" -name "*.json" -mtime +30 -delete 2>/dev/null || true

    log_success "System cleanup completed"
}

# Resource monitoring
monitor_resources() {
    local cpu=$(top -bn1 | grep "Cpu(s)" | sed "s/.*, *\([0-9.]*\)%* id.*/\1/" | awk '{print 100 - $1}')
    if command -v free >/dev/null 2>&1; then
        local mem=$(free | grep Mem | awk '{printf "%.0f", $3/$2 * 100.0}')
    else
        local mem=$(vm_stat | grep 'Pages active' | awk '{print $3}' | tr -d '.' | awk '{print $1 * 4096 / 1024 / 1024 / 1024 * 100}')
    fi
    local disk=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

    RESOURCE_USAGE["cpu"]=$cpu
    RESOURCE_USAGE["memory"]=$mem
    RESOURCE_USAGE["disk"]=$disk

    # Log resource usage
    echo "$(date +%s),$cpu,$mem,$disk" >>"$PROJECT_ROOT/logs/resource_usage.csv"
}

# Main orchestration loop
intelligent_orchestration_loop() {
    log_info "Starting Intelligent Component Orchestrator"

    # Disable strict error checking for the orchestration loop to prevent exit on failures
    set +euo pipefail

    while true; do
        local cycle_start=$(date +%s)

        # Analyze current requirements
        analyze_task_requirements

        # Check all component health
        for component in "${!COMPONENT_CAPABILITIES[@]}"; do
            check_component_health "$component"
        done

        # Make intelligent decisions
        make_intelligent_decisions

        # Run predictive actions
        predictive_actions

        # Monitor resources
        monitor_resources

        # Calculate cycle time
        local cycle_end=$(date +%s)
        local cycle_duration=$((cycle_end - cycle_start))
        local sleep_time=$((ANALYSIS_INTERVAL - cycle_duration))

        if [[ $sleep_time -gt 0 ]]; then
            sleep "$sleep_time"
        else
            log_warning "Analysis cycle took longer than expected (${cycle_duration}s)"
        fi
    done
}

# Service management functions
start_intelligent_orchestrator() {
    log_info "Starting Intelligent Component Orchestrator..."

    # Check if already running
    if [[ -f "$INTELLIGENT_ORCHESTRATOR_PID" ]]; then
        local existing_pid=$(cat "$INTELLIGENT_ORCHESTRATOR_PID")
        if kill -0 "$existing_pid" 2>/dev/null; then
            log_success "Intelligent orchestrator already running (PID: $existing_pid)"
            return 0
        else
            log_warning "Removing stale PID file"
            rm -f "$INTELLIGENT_ORCHESTRATOR_PID"
        fi
    fi

    # Initialize components
    define_components

    # Start orchestration loop in background
    nohup bash -c "source '$0'; intelligent_orchestration_loop" >/dev/null 2>&1 &
    local orchestrator_pid=$!

    # Save PID
    echo "$orchestrator_pid" >"$INTELLIGENT_ORCHESTRATOR_PID"

    log_success "Intelligent Component Orchestrator started (PID: $orchestrator_pid)"
    log_info "System will now operate with 100% autonomy"
}

stop_intelligent_orchestrator() {
    log_info "Stopping Intelligent Component Orchestrator..."

    if [[ -f "$INTELLIGENT_ORCHESTRATOR_PID" ]]; then
        local pid=$(cat "$INTELLIGENT_ORCHESTRATOR_PID")
        if kill -0 "$pid" 2>/dev/null; then
            kill -TERM "$pid" 2>/dev/null || true
            sleep 5
            if kill -0 "$pid" 2>/dev/null; then
                kill -KILL "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$INTELLIGENT_ORCHESTRATOR_PID"
        log_success "Intelligent orchestrator stopped"
    else
        log_warning "Intelligent orchestrator PID file not found"
    fi
}

status_intelligent_orchestrator() {
    echo
    log_info "=== Intelligent Component Orchestrator Status ==="

    local is_running=0

    if [[ -f "$INTELLIGENT_ORCHESTRATOR_PID" ]]; then
        local pid=$(cat "$INTELLIGENT_ORCHESTRATOR_PID")
        if kill -0 "$pid" 2>/dev/null; then
            echo -e "${GREEN}✓${NC} Intelligent orchestrator running (PID: $pid)"
            is_running=1
        else
            echo -e "${RED}✗${NC} Intelligent orchestrator not running (stale PID)"
        fi
    else
        echo -e "${RED}✗${NC} Intelligent orchestrator not running"
    fi

    echo
    log_info "=== Component Status ==="
    for component in "${!COMPONENT_STATUS[@]}"; do
        local status="${COMPONENT_STATUS[$component]}"
        local capabilities="${COMPONENT_CAPABILITIES[$component]}"

        case "$status" in
        "healthy")
            echo -e "${GREEN}✓${NC} $component"
            ;;
        "unhealthy")
            echo -e "${RED}✗${NC} $component"
            ;;
        "stopped")
            echo -e "${YELLOW}⏸${NC} $component"
            ;;
        *)
            echo -e "${BLUE}?${NC} $component"
            ;;
        esac
        echo "   Capabilities: $capabilities"
    done

    echo
    log_info "=== Task Analysis ==="
    if [[ -f "$TASK_ANALYSIS_CACHE" ]]; then
        cat "$TASK_ANALYSIS_CACHE" | python3 -c "
import sys, json, time
data = json.load(sys.stdin)
print(f'Pending todos: {data.get(\"pending_todos\", 0)}')
print(f'Critical todos: {data.get(\"critical_todos\", 0)}')
print(f'Agent tasks: {data.get(\"agent_tasks\", 0)}')
print(f'MCP load: {data.get(\"mcp_load\", 0)}')
print(f'Last analysis: {time.strftime(\"%H:%M:%S\", time.localtime(data.get(\"timestamp\", 0)))}')
" 2>/dev/null || echo "Analysis data unavailable"
    else
        echo "No task analysis available"
    fi

    echo
    log_info "=== Resource Usage ==="
    echo "CPU: ${RESOURCE_USAGE["cpu"]:-?}%"
    echo "Memory: ${RESOURCE_USAGE["memory"]:-?}%"
    echo "Disk: ${RESOURCE_USAGE["disk"]:-?}%"

    echo
    log_info "=== Recent Intelligence Logs ==="
    if [[ -f "$INTELLIGENT_ORCHESTRATOR_LOG" ]]; then
        tail -10 "$INTELLIGENT_ORCHESTRATOR_LOG" 2>/dev/null | grep -E "(INTELLIGENT|DECISION)" || echo "No recent intelligence logs"
    else
        echo "No logs available"
    fi

    return $((1 - is_running))
}

# Command handling - only run if not sourced
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    case "${1:-start}" in
    start)
        start_intelligent_orchestrator
        ;;
    stop)
        stop_intelligent_orchestrator
        ;;
    restart)
        stop_intelligent_orchestrator
        sleep 2
        start_intelligent_orchestrator
        ;;
    status)
        status_intelligent_orchestrator
        ;;
    analyze)
        analyze_task_requirements
        ;;
    decide)
        make_intelligent_decisions
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status|analyze|decide}"
        echo
        echo "Intelligent Component Orchestrator"
        echo "Provides 100% autonomous operation with intelligent decision making"
        echo
        echo "Commands:"
        echo "  start   - Start the intelligent orchestrator"
        echo "  stop    - Stop the intelligent orchestrator"
        echo "  restart - Restart the intelligent orchestrator"
        echo "  status  - Show orchestrator and component status"
        echo "  analyze - Run task analysis"
        echo "  decide  - Make orchestration decisions"
        exit 1
        ;;
    esac
fi
