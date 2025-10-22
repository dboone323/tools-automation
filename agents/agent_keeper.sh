#!/bin/bash
# Quantum Agent Keeper - Ensures all agents stay alive and processing

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/agent_keeper.log"
PID_FILE="${SCRIPT_DIR}/agent_keeper.pid"

# Agent definitions with their capabilities
declare -A AGENT_CAPABILITIES=(
    ["agent_analytics.sh"]="analytics,metrics,reporting"
    ["agent_build.sh"]="build,compilation,xcode"
    ["agent_cleanup.sh"]="cleanup,maintenance,optimization"
    ["agent_codegen.sh"]="codegen,generation,automation"
    ["code_review_agent.sh"]="review,quality,standards"
    ["deployment_agent.sh"]="deployment,distribution,release"
    ["documentation_agent.sh"]="docs,documentation,readme"
    ["learning_agent.sh"]="learning,adaptation,improvement"
    ["monitoring_agent.sh"]="monitoring,health,alerts"
    ["performance_agent.sh"]="performance,optimization,speed"
    ["quality_agent.sh"]="quality,testing,validation"
    ["search_agent.sh"]="search,discovery,analysis"
    ["security_agent.sh"]="security,audit,protection"
    ["testing_agent.sh"]="testing,validation,verification"
)

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

    # Start background keeper
    (
        echo $$ >"$PID_FILE"

        # Initial agent deployment
        deploy_all_agents

        # Continuous monitoring loop
        while true; do
            check_agent_health
            balance_workload
            optimize_performance
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
            deploy_agent "$agent_script"
            ((deployed++))
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
                local start_time=$(date +%s)
                while kill -0 $agent_pid 2>/dev/null; do
                    sleep 5
                    # Check if agent is still responsive (not stuck)
                    local current_time=$(date +%s)
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
    local overloaded_agents=$(python3 -c "
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
    local cpu_usage=$(ps aux | awk '{sum += $3} END {print sum}')
    local mem_usage=$(ps aux | awk '{sum += $4} END {print sum}')

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
