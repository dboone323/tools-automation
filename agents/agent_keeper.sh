#!/opt/homebrew/bin/bash
# Quantum Agent Keeper - Ensures all agents stay alive and processing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/agent_keeper.log"
PID_FILE="${SCRIPT_DIR}/agent_keeper.pid"

# Agent configuration
AGENT_NAME="KeeperAgent"
export STATUS_FILE="${SCRIPT_DIR}/agent_status.json"
export TASK_QUEUE="${SCRIPT_DIR}/task_queue.json"
export PID=$$

# Source shared functions for task management
if [[ -f "${SCRIPT_DIR}/shared_functions.sh" ]]; then
    source "${SCRIPT_DIR}/shared_functions.sh"
fi

# Timeout protection function
run_with_timeout() {
    local timeout_seconds="$1"
    local command="$2"
    local timeout_msg="${3:-Operation timed out after ${timeout_seconds} seconds}"

    echo "[$(date)] ${AGENT_NAME}: Starting operation with ${timeout_seconds}s timeout..." >>"${LOG_FILE}"

    # Run command in background with timeout
    (
        eval "${command}" &
        local cmd_pid=$!

        # Wait for completion or timeout
        local count=0
        while [[ ${count} -lt ${timeout_seconds} ]] && kill -0 ${cmd_pid} 2>/dev/null; do
            sleep 1
            ((count++))
        done

        # Check if process is still running
        if kill -0 ${cmd_pid} 2>/dev/null; then
            echo "[$(date)] ${AGENT_NAME}: ${timeout_msg}" >>"${LOG_FILE}"
            kill -TERM ${cmd_pid} 2>/dev/null || true
            sleep 2
            kill -KILL ${cmd_pid} 2>/dev/null || true
            return 124 # Timeout exit code
        fi

        # Wait for process to get exit code
        wait ${cmd_pid} 2>/dev/null
        return $?
    )
}

# Resource limits checking function
check_resource_limits() {
    local operation_name="$1"

    echo "[$(date)] ${AGENT_NAME}: Checking resource limits for ${operation_name}..." >>"${LOG_FILE}"

    # Check available disk space (require at least 1GB)
    local available_space
    available_space=$(df -k "/Users/danielstevens/Desktop/Quantum-workspace" | tail -1 | awk '{print $4}')
    if [[ ${available_space} -lt 1048576 ]]; then # 1GB in KB
        echo "[$(date)] ${AGENT_NAME}: ❌ Insufficient disk space for ${operation_name}" >>"${LOG_FILE}"
        return 1
    fi

    # Check memory usage (require less than 90% usage)
    local mem_usage
    mem_usage=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
    if [[ ${mem_usage} -lt 100000 ]]; then # Rough check for memory pressure
        echo "[$(date)] ${AGENT_NAME}: ❌ High memory usage detected for ${operation_name}" >>"${LOG_FILE}"
        return 1
    fi

    # Check file count limits (prevent runaway keeper operations)
    local file_count
    file_count=$(find "/Users/danielstevens/Desktop/Quantum-workspace" -type f 2>/dev/null | wc -l)
    if [[ ${file_count} -gt 50000 ]]; then
        echo "[$(date)] ${AGENT_NAME}: ❌ Too many files in workspace for ${operation_name}" >>"${LOG_FILE}"
        return 1
    fi

    echo "[$(date)] ${AGENT_NAME}: ✅ Resource limits OK for ${operation_name}" >>"${LOG_FILE}"
    return 0
}

# Agent definitions with their capabilities
declare -A AGENT_CAPABILITIES
AGENT_CAPABILITIES["agent_analytics.sh"]="analytics,metrics,reporting"
AGENT_CAPABILITIES["agent_build.sh"]="build,compilation,xcode"
AGENT_CAPABILITIES["agent_cleanup.sh"]="cleanup,maintenance,optimization"
AGENT_CAPABILITIES["agent_codegen.sh"]="codegen,generation,automation"
AGENT_CAPABILITIES["code_review_agent.sh"]="review,quality,standards"
AGENT_CAPABILITIES["deployment_agent.sh"]="deployment,distribution,release"
AGENT_CAPABILITIES["documentation_agent.sh"]="docs,documentation,readme"
AGENT_CAPABILITIES["learning_agent.sh"]="learning,adaptation,improvement"
AGENT_CAPABILITIES["monitoring_agent.sh"]="monitoring,health,alerts"
AGENT_CAPABILITIES["performance_agent.sh"]="performance,optimization,speed"
AGENT_CAPABILITIES["quality_agent.sh"]="quality,testing,validation"
AGENT_CAPABILITIES["search_agent.sh"]="search,discovery,analysis"
AGENT_CAPABILITIES["security_agent.sh"]="security,audit,protection"
AGENT_CAPABILITIES["testing_agent.sh"]="testing,validation,verification"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

start_keeper() {
    if [[ -f "$PID_FILE" ]]; then
        if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            log "Agent keeper already running (PID: $(cat "$PID_FILE"))"
            return 1
        fi
    fi

    log "Starting Quantum Agent Keeper..."

    # Check resource limits before starting
    if ! check_resource_limits "keeper startup"; then
        log "Resource limits check failed, cannot start keeper"
        return 1
    fi

    # Create backup before starting keeper operations
    echo "[$(date)] ${AGENT_NAME}: Creating backup before keeper operations..." >>"${LOG_FILE}"
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup "global" "keeper_startup" >>"${LOG_FILE}" 2>&1 || true

    # Start background keeper
    (
        echo $$ >"$PID_FILE"

        # Initial agent deployment
        if ! deploy_all_agents; then
            log "Failed to deploy all agents"
        fi

        # Continuous monitoring loop
        while true; do
            if ! check_agent_health; then
                log "Health check failed"
            fi

            if ! balance_workload; then
                log "Workload balancing failed"
            fi

            if ! optimize_performance; then
                log "Performance optimization failed"
            fi

            sleep 15 # Check every 15 seconds
        done
    ) &

    local pid=$!
    log "Agent keeper started (PID: $pid)"
}

deploy_all_agents() {
    log "Deploying all agents..."

    local deployed=0
    for agent_script in "${!AGENT_CAPABILITIES[@]}"; do
        if [[ -f "$agent_script" ]]; then
            if ! deploy_agent "$agent_script"; then
                log "Failed to deploy $agent_script"
            else
                ((deployed++))
            fi
            sleep 0.3 # Stagger deployments
        fi
    done

    log "Deployed $deployed agents"
}

deploy_agent() {
    local agent_script="$1"
    local agent_name="${agent_script%.sh}"

    # Check if already running
    if pgrep -f "$agent_script" >/dev/null; then
        return 0
    fi

    log "Deploying $agent_name..."

    # Create agent environment
    export AGENT_NAME="$agent_name"
    export AGENT_SCRIPT="$agent_script"
    # shellcheck disable=SC2178
    export AGENT_CAPABILITIES="${AGENT_CAPABILITIES[$agent_script]}"

    # Start agent with monitoring
    (
        while true; do
            if [[ -f "$agent_script" ]]; then
                chmod +x "$agent_script"
                # Start agent and monitor it
                ./"$agent_script" daemon &
                local agent_pid=$!

                # Monitor agent health
                local start_time
                start_time=$(date +%s)
                while kill -0 $agent_pid 2>/dev/null; do
                    sleep 5
                    # Check if agent is still responsive (not stuck)
                    local current_time
                    current_time=$(date +%s)
                    if ((current_time - start_time > 300)); then # 5 minutes
                        # Reset start time if agent is still active
                        start_time=$current_time
                    fi
                done

                log "$agent_name exited (PID: $agent_pid), restarting in 3 seconds..."
                sleep 3
            else
                log "Agent script $agent_script not found, skipping..."
                sleep 60
            fi
        done
    ) &

    log "Deployed $agent_name with monitoring"
}

check_agent_health() {
    local healthy=0
    local unhealthy=0

    for agent_script in "${!AGENT_CAPABILITIES[@]}"; do
        local agent_name="${agent_script%.sh}"

        if pgrep -f "$agent_script" >/dev/null; then
            ((healthy++))
        else
            log "Agent $agent_name is not running, redeploying..."
            deploy_agent "$agent_script"
            ((unhealthy++))
        fi
    done

    if ((unhealthy > 0)); then
        log "Health check: $healthy healthy, $unhealthy redeployed"
    fi
}

balance_workload() {
    # Check if any agent is overloaded (>5 tasks) and redistribute
    local overloaded_agents
    overloaded_agents=$(python3 -c "
import json
with open('task_queue.json', 'r') as f:
    data = json.load(f)

agent_workload = {}
for task in data.get('tasks', []):
    if task.get('status') == 'in_progress':
        agent = task.get('assigned_agent', '')
        if agent:
            agent_workload[agent] = agent_workload.get(agent, 0) + 1

overloaded = [a for a, count in agent_workload.items() if count > 5]
print(' '.join(overloaded))
" 2>/dev/null)

    if [[ -n "$overloaded_agents" ]]; then
        log "Balancing workload from overloaded agents: $overloaded_agents"
        # Force redistribution
        python3 -c "
import json
with open('task_queue.json', 'r') as f:
    data = json.load(f)

tasks = data.get('tasks', [])
redistributed = 0

for task in tasks:
    if task.get('status') == 'in_progress' and task.get('assigned_agent') in ['$overloaded_agents']:
        task['status'] = 'queued'
        task['assigned_agent'] = None
        redistributed += 1

data['tasks'] = tasks
with open('task_queue.json', 'w') as f:
    json.dump(data, f, indent=2)

print(f'Redistributed {redistributed} tasks from overloaded agents')
" 2>/dev/null
    fi
}

optimize_performance() {
    # Check system resources and adjust agent count accordingly
    local cpu_usage
    cpu_usage=$(ps aux | awk '{sum += $3} END {print sum}')
    local mem_usage
    mem_usage=$(ps aux | awk '{sum += $4} END {print sum}')

    # If system is overloaded, reduce concurrent tasks
    if (($(echo "$cpu_usage > 80" | bc -l))) || (($(echo "$mem_usage > 80" | bc -l))); then
        log "System overloaded (CPU: ${cpu_usage}%, MEM: ${mem_usage}%), throttling agents..."
        # Reduce task assignments
        python3 -c "
import json
with open('task_queue.json', 'r') as f:
    data = json.load(f)

tasks = data.get('tasks', [])
throttled = 0

for task in tasks:
    if task.get('status') == 'in_progress':
        # Mark some tasks for later
        task['status'] = 'queued'
        task['throttled'] = True
        throttled += 1
        if throttled >= 5:  # Throttle 5 tasks
            break

data['tasks'] = tasks
with open('task_queue.json', 'w') as f:
    json.dump(data, f, indent=2)

print(f'Throttled {throttled} tasks due to system load')
" 2>/dev/null
    fi
}

stop_keeper() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            log "Agent keeper stopped (PID: $pid)"
        fi
        rm -f "$PID_FILE"
    fi

    # Stop all agents
    log "Stopping all agents..."
    for agent_script in "${!AGENT_CAPABILITIES[@]}"; do
        if pgrep -f "$agent_script" >/dev/null; then
            pkill -f "$agent_script"
        fi
    done
}

case "${1:-start}" in
start)
    start_keeper
    ;;
stop)
    stop_keeper
    ;;
restart)
    stop_keeper
    sleep 2
    start_keeper
    ;;
status)
    if [[ -f "$PID_FILE" ]]; then
        if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            log "Agent keeper running (PID: $(cat "$PID_FILE"))"

            # Count running agents
            running=0
            for agent_script in "${!AGENT_CAPABILITIES[@]}"; do
                if pgrep -f "$agent_script" >/dev/null; then
                    ((running++))
                fi
            done
            log "Agents running: $running/${#AGENT_CAPABILITIES[@]}"
            exit 0
        fi
    fi
    log "Agent keeper not running"
    exit 1
    ;;
*)
    echo "Usage: $0 {start|stop|restart|status}"
    echo ""
    echo "Commands:"
    echo "  start   - Start agent keeper and all agents"
    echo "  stop    - Stop agent keeper and all agents"
    echo "  restart - Restart agent keeper"
    echo "  status  - Show keeper and agent status"
    exit 1
    ;;
esac
