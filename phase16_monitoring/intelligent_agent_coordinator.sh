#!/bin/bash

# Phase 16: Intelligent Agent Coordination and Load Balancing System

set -euo pipefail

WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_COORD_DIR="$WORKSPACE_ROOT/agent_coordination"
COORD_LOG="$WORKSPACE_ROOT/logs/agent_coordination.log"
AGENT_STATUS_FILE="$AGENT_COORD_DIR/agent_status.json"
TASK_QUEUE_FILE="$AGENT_COORD_DIR/task_queue.json"
LOAD_BALANCE_CONFIG="$AGENT_COORD_DIR/load_balance_config.json"

# Create coordination directory
mkdir -p "$AGENT_COORD_DIR" "$WORKSPACE_ROOT/logs"

# Logging function
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$COORD_LOG"
}

# Initialize coordination system
init_coordination_system() {
    # Initialize agent status tracking
    cat > "$AGENT_STATUS_FILE" << 'EOF'
{
  "agents": {},
  "last_updated": null,
  "system_health": {
    "total_agents": 0,
    "active_agents": 0,
    "idle_agents": 0,
    "overloaded_agents": 0
  }
}
EOF

    # Initialize task queue
    cat > "$TASK_QUEUE_FILE" << 'EOF'
{
  "queue": [],
  "processing": {},
  "completed": [],
  "failed": [],
  "last_updated": null
}
EOF

    # Initialize load balancing configuration
    cat > "$LOAD_BALANCE_CONFIG" << 'EOF'
{
  "load_balancing": {
    "strategy": "adaptive",
    "max_tasks_per_agent": 3,
    "task_timeout_seconds": 300,
    "health_check_interval": 60,
    "overload_threshold": 0.8,
    "underload_threshold": 0.3
  },
  "agent_capabilities": {
    "code_generation": ["codegen_agent", "ai_code_review_agent"],
    "testing": ["testing_agent", "quality_agent"],
    "monitoring": ["performance_monitor", "health_monitor"],
    "deployment": ["deployment_agent", "build_agent"],
    "analysis": ["code_analysis_agent", "security_agent"]
  },
  "task_priorities": {
    "critical": 100,
    "high": 75,
    "medium": 50,
    "low": 25
  }
}
EOF

    log "Initialized agent coordination system"
}

# Register an agent with the coordination system
register_agent() {
    local agent_name;
    agent_name="$1"
    local capabilities;
    capabilities="$2"
    local max_concurrent_tasks;
    max_concurrent_tasks="${3:-2}"

    local timestamp;

    timestamp=$(date +%s)

    jq --arg agent "$agent_name" \
       --arg capabilities "$capabilities" \
       --argjson max_tasks "$max_concurrent_tasks" \
       --argjson timestamp "$timestamp" \
       '.agents[$agent] = {
            name: $agent,
            capabilities: ($capabilities | split(",") | map(gsub("^\\s+|\\s+$"; ""))),
            status: "idle",
            current_tasks: [],
            max_concurrent_tasks: $max_tasks,
            performance_metrics: {
                total_tasks_completed: 0,
                average_task_time: 0,
                success_rate: 1.0,
                last_active: $timestamp
            },
            health: {
                last_check: $timestamp,
                consecutive_failures: 0,
                load_factor: 0.0
            }
        } | .last_updated = $timestamp' "$AGENT_STATUS_FILE" > "${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "$AGENT_STATUS_FILE"

    log "Registered agent: $agent_name (capabilities: $capabilities, max_tasks: $max_concurrent_tasks)"
}

# Update agent status
update_agent_status() {
    local agent_name;
    agent_name="$1"
    local status;
    status="$2"
    local current_load;
    current_load="${3:-0}"

    local timestamp;

    timestamp=$(date +%s)

    jq --arg agent "$agent_name" \
       --arg status "$status" \
       --argjson load "$current_load" \
       --argjson timestamp "$timestamp" \
       '.agents[$agent].status = $status |
        .agents[$agent].health.load_factor = $load |
        .agents[$agent].health.last_check = $timestamp |
        .last_updated = $timestamp' "$AGENT_STATUS_FILE" > "${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "$AGENT_STATUS_FILE"
}

# Submit task to coordination system
submit_task() {
    local task_type;
    task_type="$1"
    local task_data;
    task_data="$2"
    local priority;
    priority="${3:-medium}"
    local timeout_seconds;
    timeout_seconds="${4:-300}"

    local task_id;

    task_id="task_$(date +%s)_$RANDOM"
    local timestamp;
    timestamp=$(date +%s)
    local priority_value;
    priority_value=$(jq -r ".task_priorities.$priority // 50" "$LOAD_BALANCE_CONFIG")

    local task_json;

    task_json=$(jq -n \
        --arg id "$task_id" \
        --arg type "$task_type" \
        --arg data "$task_data" \
        --arg priority "$priority" \
        --argjson priority_value "$priority_value" \
        --argjson timeout "$timeout_seconds" \
        --argjson submitted "$timestamp" \
        '{
            id: $id,
            type: $type,
            data: $data,
            priority: $priority,
            priority_value: $priority_value,
            timeout_seconds: $timeout,
            submitted_at: $submitted,
            status: "queued",
            assigned_agent: null,
            started_at: null,
            completed_at: null
        }')

    # Add to queue
    jq --argjson task "$task_json" '.queue += [$task] | .last_updated = now | sort_by(.priority_value) | reverse' "$TASK_QUEUE_FILE" > "${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "$TASK_QUEUE_FILE"

    log "Submitted task: $task_id (type: $task_type, priority: $priority)"

    echo "$task_id"
}

# Find best agent for task
find_best_agent() {
    local task_type;
    task_type="$1"

    # Get agents capable of handling this task type
    local capable_agents
    capable_agents=$(jq -r ".agent_capabilities.$task_type // [] | join(\" \")" "$LOAD_BALANCE_CONFIG")

    if [[ -z "$capable_agents" ]]; then
        # Fallback: find agents that can handle similar tasks
        capable_agents=$(jq -r '.agents | to_entries[] | select(.value.status == "idle" or (.value.current_tasks | length) < .value.max_concurrent_tasks) | .key' "$AGENT_STATUS_FILE" | tr '\n' ' ')
    fi

    local best_agent;

    best_agent=""
    local best_score;
    best_score=0

    for agent in $capable_agents; do
        # Check if agent exists and is available
        if jq -e ".agents.$agent" "$AGENT_STATUS_FILE" >/dev/null 2>&1; then
            local status;
            status=$(jq -r ".agents.$agent.status" "$AGENT_STATUS_FILE")
            local current_tasks;
            current_tasks=$(jq -r ".agents.$agent.current_tasks | length" "$AGENT_STATUS_FILE")
            local max_tasks;
            max_tasks=$(jq -r ".agents.$agent.max_concurrent_tasks" "$AGENT_STATUS_FILE")
            local load_factor;
            load_factor=$(jq -r ".agents.$agent.health.load_factor" "$AGENT_STATUS_FILE")
            local success_rate;
            success_rate=$(jq -r ".agents.$agent.performance_metrics.success_rate" "$AGENT_STATUS_FILE")

            # Skip if overloaded
            if (( $(echo "$load_factor > 0.8" | bc -l 2>/dev/null || echo "0") )) || (( current_tasks >= max_tasks )); then
                continue
            fi

            # Calculate agent score (0-100)
            local score;
            score=0

            # Availability score (0-40)
            if [[ "$status" == "idle" ]]; then
                score=40
            elif (( current_tasks < max_tasks )); then
                score=$((40 - (current_tasks * 10)))
            fi

            # Performance score (0-40)
            score=$((score + (success_rate * 40 / 1)))

            # Load balance score (0-20)
            local load_penalty;
            load_penalty=$(echo "scale=0; $load_factor * 20" | bc -l 2>/dev/null || echo "0")
            score=$((score - load_penalty))

            if (( score > best_score )); then
                best_agent="$agent"
                best_score=$score
            fi
        fi
    done

    if [[ -n "$best_agent" ]]; then
        jq -n --arg agent "$best_agent" --argjson score "$best_score" '{agent: $agent, score: $score}'
    else
        echo '{"error": "no_suitable_agent"}'
    fi
}

# Assign task to agent
assign_task() {
    local task_id;
    task_id="$1"
    local agent_name;
    agent_name="$2"

    local timestamp;

    timestamp=$(date +%s)

    # Update task status
    jq --arg task_id "$task_id" \
       --arg agent "$agent_name" \
       --argjson timestamp "$timestamp" \
       '(.queue[] | select(.id == $task_id) | .status = "assigned", .assigned_agent = $agent, .started_at = $timestamp)' "$TASK_QUEUE_FILE" > "${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "$TASK_QUEUE_FILE"

    # Move to processing
    local task_data
    task_data=$(jq -c ".queue[] | select(.id == \"$task_id\")" "$TASK_QUEUE_FILE")

    if [[ -n "$task_data" ]]; then
        jq --arg task_id "$task_id" \
           --argjson task "$task_data" \
           '.processing[$task_id] = $task' "$TASK_QUEUE_FILE" > "${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "$TASK_QUEUE_FILE"

        # Remove from queue
        jq --arg task_id "$task_id" 'del(.queue[] | select(.id == $task_id))' "$TASK_QUEUE_FILE" > "${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "$TASK_QUEUE_FILE"

        # Update agent status
        jq --arg agent "$agent_name" \
           --arg task_id "$task_id" \
           '.agents[$agent].current_tasks += [$task_id]' "$AGENT_STATUS_FILE" > "${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "$AGENT_STATUS_FILE"

        log "Assigned task $task_id to agent $agent_name"
        echo "assigned"
    else
        echo "task_not_found"
    fi
}

# Complete task
complete_task() {
    local task_id;
    task_id="$1"
    local success;
    success="$2"
    local result;
    result="${3:-}"

    local timestamp;

    timestamp=$(date +%s)

    # Get task data
    local task_data
    task_data=$(jq -c ".processing.$task_id" "$TASK_QUEUE_FILE")

    if [[ -z "$task_data" ]]; then
        echo "task_not_found"
        return 1
    fi

    local agent_name;

    agent_name=$(echo "$task_data" | jq -r '.assigned_agent')
    local task_type;
    task_type=$(echo "$task_data" | jq -r '.type')
    local start_time;
    start_time=$(echo "$task_data" | jq -r '.started_at')
    local duration;
    duration=$((timestamp - start_time))

    # Update task as completed
    local updated_task
    updated_task=$(echo "$task_data" | jq --argjson completed "$timestamp" \
                                          --argjson duration "$duration" \
                                          --arg result "$result" \
                                          '.status = "completed", .completed_at = $completed, .duration_seconds = $duration, .result = $result')

    jq --arg task_id "$task_id" \
       --argjson task "$updated_task" \
       '.completed += [$task] | del(.processing[$task_id])' "$TASK_QUEUE_FILE" > "${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "$TASK_QUEUE_FILE"

    # Update agent status
    jq --arg agent "$agent_name" \
       --arg task_id "$task_id" \
       --argjson success "$success" \
       --argjson duration "$duration" \
       '.agents[$agent].current_tasks = (.agents[$agent].current_tasks - [$task_id]) |
        .agents[$agent].performance_metrics.total_tasks_completed += 1 |
        .agents[$agent].performance_metrics.success_rate = (
            (.agents[$agent].performance_metrics.success_rate * (.agents[$agent].performance_metrics.total_tasks_completed - 1) + $success) /
            .agents[$agent].performance_metrics.total_tasks_completed
        ) |
        .agents[$agent].performance_metrics.average_task_time = (
            (.agents[$agent].performance_metrics.average_task_time * (.agents[$agent].performance_metrics.total_tasks_completed - 1) + $duration) /
            .agents[$agent].performance_metrics.total_tasks_completed
        )' "$AGENT_STATUS_FILE" > "${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "$AGENT_STATUS_FILE"

    log "Completed task $task_id (agent: $agent_name, success: $success, duration: ${duration}s)"
    echo "completed"
}

# Process task queue (main coordination loop)
process_task_queue() {
    log "Processing task queue..."

    # Get pending tasks ordered by priority
    local pending_tasks
    pending_tasks=$(jq -c '.queue | sort_by(.priority_value) | reverse[]' "$TASK_QUEUE_FILE")

    echo "$pending_tasks" | while read -r task; do
        if [[ -z "$task" ]]; then
            continue
        fi

        local task_id;

        task_id=$(echo "$task" | jq -r '.id')
        local task_type;
        task_type=$(echo "$task" | jq -r '.type')

        log "Processing task: $task_id (type: $task_type)"

        # Find best agent
        local agent_result
        agent_result=$(find_best_agent "$task_type")

        if echo "$agent_result" | jq -e '.error' >/dev/null 2>&1; then
            log "No suitable agent found for task $task_id"
            continue
        fi

        local agent_name;

        agent_name=$(echo "$agent_result" | jq -r '.agent')

        # Assign task
        local assign_result
        assign_result=$(assign_task "$task_id" "$agent_name")

        if [[ "$assign_result" == "assigned" ]]; then
            log "Successfully assigned task $task_id to $agent_name"

            # Here you would typically trigger the actual agent execution
            # For now, we'll simulate completion after a short delay
            (
                sleep 2
                # Simulate random success/failure
                local success;
                success=$((RANDOM % 10 > 1 ? 1 : 0))
                complete_task "$task_id" "$success" "simulated_result"
            ) &
        fi
    done
}

# Get system status
get_system_status() {
    local agent_count;
    agent_count=$(jq '.agents | length' "$AGENT_STATUS_FILE")
    local active_agents;
    active_agents=$(jq '.agents | to_entries[] | select(.value.status == "busy") | .key' "$AGENT_STATUS_FILE" | wc -l)
    local idle_agents;
    idle_agents=$(jq '.agents | to_entries[] | select(.value.status == "idle") | .key' "$AGENT_STATUS_FILE" | wc -l)
    local queued_tasks;
    queued_tasks=$(jq '.queue | length' "$TASK_QUEUE_FILE")
    local processing_tasks;
    processing_tasks=$(jq '.processing | length' "$TASK_QUEUE_FILE")

    jq -n \
        --argjson agent_count "$agent_count" \
        --argjson active_agents "$active_agents" \
        --argjson idle_agents "$idle_agents" \
        --argjson queued_tasks "$queued_tasks" \
        --argjson processing_tasks "$processing_tasks" \
        '{
            system_status: {
                total_agents: $agent_count,
                active_agents: $active_agents,
                idle_agents: $idle_agents,
                queued_tasks: $queued_tasks,
                processing_tasks: $processing_tasks
            },
            timestamp: now | todateiso8601
        }'
}

# CLI interface
case "${1:-help}" in
    "init")
        init_coordination_system
        ;;
    "register")
        if [[ $# -lt 3 ]]; then
            echo "Usage: $0 register <agent_name> <capabilities> [max_tasks]"
            exit 1
        fi
        register_agent "$2" "$3" "${4:-2}"
        ;;
    "submit")
        if [[ $# -lt 3 ]]; then
            echo "Usage: $0 submit <task_type> <task_data> [priority] [timeout]"
            exit 1
        fi
        submit_task "$2" "$3" "${4:-medium}" "${5:-300}"
        ;;
    "process")
        process_task_queue
        ;;
    "status")
        get_system_status
        ;;
    "complete")
        if [[ $# -lt 3 ]]; then
            echo "Usage: $0 complete <task_id> <success> [result]"
            exit 1
        fi
        complete_task "$2" "$3" "${4:-}"
        ;;
    "help"|*)
        echo "Intelligent Agent Coordination and Load Balancing System v1.0"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  init                    - Initialize coordination system"
        echo "  register <name> <caps>  - Register an agent"
        echo "  submit <type> <data>    - Submit a task"
        echo "  process                 - Process task queue"
        echo "  status                  - Show system status"
        echo "  complete <id> <succ>    - Mark task as completed"
        echo "  help                    - Show this help"
        ;;
esac