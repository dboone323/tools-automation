#!/bin/bash
# Monitoring Agent: Monitors system health, performance, and anomalies with Ollama analysis

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="monitoring_agent.sh"
WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
LOG_FILE="${WORKSPACE}/Tools/Automation/agents/monitoring_agent.log"
NOTIFICATION_FILE="${WORKSPACE}/Tools/Automation/agents/communication/${AGENT_NAME}_notification.txt"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/Tools/Automation/agents/task_queue.json"
OLLAMA_ENDPOINT="http://localhost:11434"
MONITORING_DATA_FILE="${WORKSPACE}/Tools/Automation/agents/monitoring_data.json"

# Logging function
log() {
  echo "[$(date)] ${AGENT_NAME}: $*" >>"${LOG_FILE}"
}

# Ollama Integration Functions
ollama_query() {
  local prompt="$1"
  local model="${2:-codellama}"

  curl -s -X POST "${OLLAMA_ENDPOINT}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"${model}\", \"prompt\": \"${prompt}\", \"stream\": false}" |
    jq -r '.response // empty'
}

analyze_system_health() {
  local metrics="$1"

  local prompt="Analyze these system health metrics and identify potential issues:

${metrics}

Provide:
1. Current system health assessment
2. Performance bottlenecks
3. Resource utilization analysis
4. Anomaly detection
5. Recommendations for optimization
6. Predictive maintenance suggestions

Focus on macOS development environment metrics."

  local analysis
  analysis=$(ollama_query "${prompt}")

  if [[ -n ${analysis} ]]; then
    echo "${analysis}"
    return 0
  else
    log "ERROR: Failed to analyze system health with Ollama"
    return 1
  fi
}

detect_anomalies() {
  local current_metrics="$1"
  local historical_data="$2"

  local prompt="Compare current metrics with historical data to detect anomalies:

Current Metrics:
${current_metrics}

Historical Data:
${historical_data}

Identify:
1. Unusual patterns or spikes
2. Performance degradation trends
3. Resource leaks
4. System stability issues
5. Predictive failure indicators

Provide anomaly analysis and recommended actions."

  local anomaly_analysis
  anomaly_analysis=$(ollama_query "${prompt}")

  if [[ -n ${anomaly_analysis} ]]; then
    echo "${anomaly_analysis}"
    return 0
  else
    log "ERROR: Failed to detect anomalies with Ollama"
    return 1
  fi
}

generate_monitoring_report() {
  local time_period="$1"

  if [[ ! -f ${MONITORING_DATA_FILE} ]]; then
    log "No monitoring data available"
    return 1
  fi

  local data
  data=$(cat "${MONITORING_DATA_FILE}")

  local prompt="Generate a comprehensive monitoring report for the last ${time_period}. Analyze:

${data}

Include:
1. System performance summary
2. Resource utilization trends
3. Error and warning analysis
4. Agent activity summary
5. Recommendations for improvements
6. Predictive insights

Format as a professional monitoring report."

  local report
  report=$(ollama_query "${prompt}")

  if [[ -n ${report} ]]; then
    echo "${report}"
    return 0
  else
    log "ERROR: Failed to generate monitoring report with Ollama"
    return 1
  fi
}

# Update agent status to available when starting
update_status() {
  local status="$1"
  if command -v jq &>/dev/null; then
    jq ".agents[\"${AGENT_NAME}\"].status = \"${status}\" | .agents[\"${AGENT_NAME}\"].last_seen = $(date +%s)" "${AGENT_STATUS_FILE}" >"${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "${AGENT_STATUS_FILE}"
  fi
  log "Status updated to ${status}"
}

# Collect system metrics
collect_system_metrics() {
  local timestamp
  timestamp=$(date +%s)

  # CPU usage
  local cpu_usage
  cpu_usage=$(top -l 1 | grep "CPU usage" | awk '{print $3}' | tr -d '%')

  # Memory usage
  local mem_usage
  mem_usage=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.')

  # Disk usage
  local disk_usage
  disk_usage=$(df -h "${WORKSPACE}" | tail -1 | awk '{print $5}' | tr -d '%')

  # Network activity
  local network_activity
  network_activity=$(netstat -i | awk '/(en|utun)/ {count++} END {print count+0}')

  # Process count
  local process_count
  process_count=$(ps aux | wc -l)

  # Agent status summary
  local agent_status_summary
  if [[ -f ${AGENT_STATUS_FILE} ]]; then
    agent_status_summary=$(jq '.agents | to_entries | map("\(.key): \(.value.status)") | join(", ")' "${AGENT_STATUS_FILE}" 2>/dev/null || echo "No agent data")
  else
    agent_status_summary="No agent status file"
  fi

  # Create metrics JSON
  local metrics
  metrics=$(jq -n \
    --arg timestamp "${timestamp}" \
    --arg cpu "${cpu_usage}" \
    --arg mem "${mem_usage}" \
    --arg disk "${disk_usage}" \
    --arg net "${network_activity}" \
    --arg proc "${process_count}" \
    --arg agents "${agent_status_summary}" \
    '{
            timestamp: ($timestamp | tonumber),
            cpu_usage: ($cpu | tonumber),
            memory_usage: ($mem | tonumber),
            disk_usage: ($disk | tonumber),
            network_activity: ($net | tonumber),
            process_count: ($proc | tonumber),
            agent_status: $agents
        }')

  echo "${metrics}"
}

# Store monitoring data
store_monitoring_data() {
  local metrics="$1"

  # Initialize data file if it doesn't exist
  if [[ ! -f ${MONITORING_DATA_FILE} ]]; then
    echo '{"metrics": []}' >"${MONITORING_DATA_FILE}"
  fi

  # Add new metrics to the array
  jq ".metrics += [${metrics}]" "${MONITORING_DATA_FILE}" >"${MONITORING_DATA_FILE}.tmp" && mv "${MONITORING_DATA_FILE}.tmp" "${MONITORING_DATA_FILE}"

  # Keep only last 1000 entries to prevent file from growing too large
  jq '.metrics |= .[-1000:]' "${MONITORING_DATA_FILE}" >"${MONITORING_DATA_FILE}.tmp" && mv "${MONITORING_DATA_FILE}.tmp" "${MONITORING_DATA_FILE}"
}

# Process a specific task
process_task() {
  local task_id="$1"
  log "Processing task ${task_id}"

  # Get task details
  if command -v jq &>/dev/null; then
    local task_desc
    task_desc=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .description" "${TASK_QUEUE_FILE}")
    local task_type
    task_type=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .type" "${TASK_QUEUE_FILE}")
    log "Task description: ${task_desc}"
    log "Task type: ${task_type}"

    # Process based on task type
    case "${task_type}" in
    "monitor" | "monitoring" | "health_check")
      run_monitoring_analysis "${task_desc}"
      ;;
    "report")
      generate_monitoring_report "24 hours"
      ;;
    *)
      log "Unknown task type: ${task_type}"
      ;;
    esac

    # Mark task as completed
    update_task_status "${task_id}" "completed"
    log "Task ${task_id} completed"
  fi
}

# Update task status
update_task_status() {
  local task_id="$1"
  local status="$2"
  if command -v jq &>/dev/null; then
    jq "(.tasks[] | select(.id == \"${task_id}\") | .status) = \"${status}\"" "${TASK_QUEUE_FILE}" >"${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "${TASK_QUEUE_FILE}"
  fi
}

# Monitoring analysis function
run_monitoring_analysis() {
  local task_desc="$1"
  log "Running monitoring analysis for: ${task_desc}"

  # Collect current metrics
  local current_metrics
  current_metrics=$(collect_system_metrics)

  # Store metrics
  store_monitoring_data "${current_metrics}"

  # Analyze system health with Ollama
  log "Analyzing system health with Ollama..."
  local health_analysis
  health_analysis=$(analyze_system_health "${current_metrics}")
  if [[ -n ${health_analysis} ]]; then
    log "System health analysis completed"
  fi

  # Check for anomalies if we have historical data
  if [[ -f ${MONITORING_DATA_FILE} ]]; then
    local historical_data
    historical_data=$(jq '.metrics[-10:]' "${MONITORING_DATA_FILE}" 2>/dev/null || echo "[]")

    if [[ ${historical_data} != "[]" ]]; then
      log "Detecting anomalies..."
      local anomaly_analysis
      anomaly_analysis=$(detect_anomalies "${current_metrics}" "${historical_data}")
      if [[ -n ${anomaly_analysis} ]]; then
        log "Anomaly detection completed"
      fi
    fi
  fi

  # Generate alerts for critical issues
  local cpu_threshold=80
  local mem_threshold=85
  local disk_threshold=90

  local cpu_usage
  cpu_usage=$(echo "${current_metrics}" | jq -r '.cpu_usage')
  local mem_usage
  mem_usage=$(echo "${current_metrics}" | jq -r '.memory_usage')
  local disk_usage
  disk_usage=$(echo "${current_metrics}" | jq -r '.disk_usage')

  if (($(echo "${cpu_usage} > ${cpu_threshold}" | bc -l 2>/dev/null || echo "0"))); then
    log "ALERT: High CPU usage detected: ${cpu_usage}%"
  fi

  if (($(echo "${mem_usage} > ${mem_threshold}" | bc -l 2>/dev/null || echo "0"))); then
    log "ALERT: High memory usage detected: ${mem_usage}%"
  fi

  if (($(echo "${disk_usage} > ${disk_threshold}" | bc -l 2>/dev/null || echo "0"))); then
    log "ALERT: High disk usage detected: ${disk_usage}%"
  fi

  log "Monitoring analysis completed"
}

# Main agent loop
log "Starting monitoring agent..."
update_status "available"

# Track processed tasks to avoid duplicates
declare -A processed_tasks

while true; do
  # Collect metrics every iteration
  current_metrics=$(collect_system_metrics)
  store_monitoring_data "${current_metrics}"

  # Check for new task notifications
  if [[ -f ${NOTIFICATION_FILE} ]]; then
    while IFS='|' read -r _ action task_id; do
      if [[ ${action} == "execute_task" && -z ${processed_tasks[${task_id}]} ]]; then
        update_status "busy"
        process_task "${task_id}"
        update_status "available"
        processed_tasks[${task_id}]="completed"
        log "Marked task ${task_id} as processed"
      fi
    done <"${NOTIFICATION_FILE}"

    # Clear processed notifications to prevent re-processing
    true >"${NOTIFICATION_FILE}"
  fi

  # Update last seen timestamp
  update_status "available"

  sleep 60 # Check every 60 seconds for monitoring
done
