#!/bin/bash
# Performance Monitoring Agent: Tracks agent efficiency and system impact
# Monitors resource usage, task completion rates, and system health

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="PerformanceMonitor"
LOG_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/performance_monitor.log"

SLEEP_INTERVAL=300 # Check every 5 minutes

STATUS_FILE="$(dirname "$0")/agent_status.json"
TASK_QUEUE="$(dirname "$0")/task_queue.json"
PERFORMANCE_LOG="$(dirname "$0")/performance_metrics.json"
PID=$$

function update_status() {
  local status="$1"
  # Ensure status file exists and is valid JSON
  if [[ ! -s ${STATUS_FILE} ]]; then
    echo '{"agents":{"build_agent":{"status":"unknown","pid":null},"debug_agent":{"status":"unknown","pid":null},"codegen_agent":{"status":"unknown","pid":null},"uiux_agent":{"status":"unknown","pid":null},"testing_agent":{"status":"unknown","pid":null},"security_agent":{"status":"unknown","pid":null},"performance_monitor":{"status":"unknown","pid":null}},"last_update":0}' >"${STATUS_FILE}"
  fi
  jq ".agents.performance_monitor.status = \"${status}\" | .agents.performance_monitor.pid = ${PID} | .last_update = $(date +%s)" "${STATUS_FILE}" >"${STATUS_FILE}.tmp"
  if jq ".agents.performance_monitor.status = \"${status}\" | .agents.performance_monitor.pid = ${PID} | .last_update = $(date +%s)" "${STATUS_FILE}" >"${STATUS_FILE}.tmp" && [[ -s "${STATUS_FILE}.tmp" ]]; then
    mv "${STATUS_FILE}.tmp" "${STATUS_FILE}"
  else
    echo "[$(date)] ${AGENT_NAME}: Failed to update agent_status.json (jq or mv error)" >>"${LOG_FILE}"
    rm -f "${STATUS_FILE}.tmp"
  fi
}
trap 'update_status stopped; exit 0' SIGTERM SIGINT

# Function to collect system metrics
collect_system_metrics() {
  local timestamp
  timestamp=$(date +%s)

  # Get CPU usage
  local cpu_usage
  cpu_usage=$(ps aux | awk '{sum += $3} END {print sum}')

  # Get memory usage
  local mem_usage
  mem_usage=$(ps aux | awk '{sum += $4} END {print sum}')

  # Get disk usage
  local disk_usage
  disk_usage=$(df / | tail -1 | awk '{print $5}' | sed 's/%//')

  # Get process count
  local process_count
  process_count=$(ps aux | wc -l)

  # Get agent process count
  local agent_count
  agent_count=$(ps aux | grep -E "agent_|mcp_server" | grep -v grep | wc -l)

  echo "[$(date)] ${AGENT_NAME}: System Metrics - CPU: ${cpu_usage}%, Memory: ${mem_usage}%, Disk: ${disk_usage}%, Processes: ${process_count}, Agents: ${agent_count}" >>"${LOG_FILE}"

  # Store metrics
  local metrics
  metrics=$(jq -n \
    --arg timestamp "${timestamp}" \
    --arg cpu "${cpu_usage}" \
    --arg memory "${mem_usage}" \
    --arg disk "${disk_usage}" \
    --arg processes "${process_count}" \
    --arg agents "${agent_count}" \
    '{timestamp: $timestamp, cpu_usage: $cpu, memory_usage: $memory, disk_usage: $disk, process_count: $processes, agent_count: $agents}')

  # Initialize performance log if it doesn't exist
  if [[ ! -s ${PERFORMANCE_LOG} ]]; then
    echo '{"metrics": []}' >"${PERFORMANCE_LOG}"
  fi

  # Add new metrics
  jq ".metrics += [${metrics}]" "${PERFORMANCE_LOG}" >"${PERFORMANCE_LOG}.tmp"
  if [[ -s "${PERFORMANCE_LOG}.tmp" ]]; then
    mv "${PERFORMANCE_LOG}.tmp" "${PERFORMANCE_LOG}"
  fi
}

# Function to monitor agent performance
monitor_agent_performance() {
  echo "[$(date)] ${AGENT_NAME}: Monitoring agent performance..." >>"${LOG_FILE}"

  # Check agent status
  if [[ -s ${STATUS_FILE} ]]; then
    local running_agents
    running_agents=$(jq '.agents | to_entries[] | select(.value.status == "running") | .key' "${STATUS_FILE}")

    if [[ -n ${running_agents} ]]; then
      echo "[$(date)] ${AGENT_NAME}: Running agents: ${running_agents}" >>"${LOG_FILE}"
    else
      echo "[$(date)] ${AGENT_NAME}: No agents currently running" >>"${LOG_FILE}"
    fi

    # Check for idle agents
    local idle_agents
    idle_agents=$(jq '.agents | to_entries[] | select(.value.status == "idle") | .key' "${STATUS_FILE}")

    if [[ -n ${idle_agents} ]]; then
      echo "[$(date)] ${AGENT_NAME}: Idle agents: ${idle_agents}" >>"${LOG_FILE}"
    fi
  fi

  # Check task queue status
  if [[ -s ${TASK_QUEUE} ]]; then
    local queued_tasks
    local completed_tasks
    local failed_tasks

    queued_tasks=$(jq '.tasks | map(select(.status == "queued")) | length' "${TASK_QUEUE}")
    completed_tasks=$(jq '.tasks | map(select(.status == "completed")) | length' "${TASK_QUEUE}")
    failed_tasks=$(jq '.tasks | map(select(.status == "failed")) | length' "${TASK_QUEUE}")

    echo "[$(date)] ${AGENT_NAME}: Task Status - Queued: ${queued_tasks}, Completed: ${completed_tasks}, Failed: ${failed_tasks}" >>"${LOG_FILE}"

    # Calculate completion rate
    local total_tasks
    total_tasks=$((queued_tasks + completed_tasks + failed_tasks))
    if [[ ${total_tasks} -gt 0 ]]; then
      local completion_rate
      completion_rate=$((completed_tasks * 100 / total_tasks))
      echo "[$(date)] ${AGENT_NAME}: Task completion rate: ${completion_rate}%" >>"${LOG_FILE}"
    fi
  fi
}

# Function to analyze performance trends
analyze_performance_trends() {
  echo "[$(date)] ${AGENT_NAME}: Analyzing performance trends..." >>"${LOG_FILE}"

  if [[ ! -s ${PERFORMANCE_LOG} ]]; then
    echo "[$(date)] ${AGENT_NAME}: No performance data available for analysis" >>"${LOG_FILE}"
    return
  fi

  # Get last 10 measurements
  local recent_metrics
  recent_metrics=$(jq '.metrics | .[-10:]' "${PERFORMANCE_LOG}")

  if [[ -n ${recent_metrics} && ${recent_metrics} != "[]" ]]; then
    # Calculate averages
    local avg_cpu
    local avg_memory
    local avg_disk

    avg_cpu=$(echo "${recent_metrics}" | jq 'map(.cpu_usage | tonumber) | add / length')
    avg_memory=$(echo "${recent_metrics}" | jq 'map(.memory_usage | tonumber) | add / length')
    avg_disk=$(echo "${recent_metrics}" | jq 'map(.disk_usage | tonumber) | add / length')

    echo "[$(date)] ${AGENT_NAME}: Average Performance (last 10 measurements):" >>"${LOG_FILE}"
    echo "[$(date)] ${AGENT_NAME}:   CPU Usage: ${avg_cpu}%" >>"${LOG_FILE}"
    echo "[$(date)] ${AGENT_NAME}:   Memory Usage: ${avg_memory}%" >>"${LOG_FILE}"
    echo "[$(date)] ${AGENT_NAME}:   Disk Usage: ${avg_disk}%" >>"${LOG_FILE}"

    # Check for performance issues
    if (($(echo "${avg_cpu} > 80" | bc -l))); then
      echo "[$(date)] ${AGENT_NAME}: ⚠️  HIGH CPU USAGE DETECTED" >>"${LOG_FILE}"
    fi

    if (($(echo "${avg_memory} > 80" | bc -l))); then
      echo "[$(date)] ${AGENT_NAME}: ⚠️  HIGH MEMORY USAGE DETECTED" >>"${LOG_FILE}"
    fi

    if (($(echo "${avg_disk} > 90" | bc -l))); then
      echo "[$(date)] ${AGENT_NAME}: 🚨 CRITICAL DISK USAGE DETECTED" >>"${LOG_FILE}"
    fi
  fi
}

# Function to generate performance report
generate_performance_report() {
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local report_file
  report_file="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/PERFORMANCE_REPORT_${timestamp}.md"

  echo "[$(date)] ${AGENT_NAME}: Generating performance report..." >>"${LOG_FILE}"

  cat >"${report_file}" <<EOF
# Performance Monitoring Report
Generated: $(date)

## System Overview
This report contains performance metrics and analysis for the automated agent system.

## Current Metrics

### System Resources
- CPU Usage: Check agent logs for current values
- Memory Usage: Check agent logs for current values
- Disk Usage: Check agent logs for current values
- Process Count: Check agent logs for current values

### Agent Status
- Running Agents: Check agent_status.json for current status
- Task Queue: Check task_queue.json for pending/completed tasks

## Performance Analysis

### Trends
- Average CPU Usage (last 10 measurements)
- Average Memory Usage (last 10 measurements)
- Average Disk Usage (last 10 measurements)

### Alerts
- High CPU usage warnings (>80%)
- High memory usage warnings (>80%)
- Critical disk usage alerts (>90%)

## Recommendations

1. **Resource Monitoring**: Continue monitoring system resources
2. **Task Optimization**: Review task completion rates and bottlenecks
3. **Agent Efficiency**: Analyze agent performance and optimize as needed
4. **System Health**: Regular health checks and maintenance

## Raw Data
Performance metrics are stored in: ${PERFORMANCE_LOG}
Agent status is tracked in: ${STATUS_FILE}
Task queue status in: ${TASK_QUEUE}

---
Report generated by Performance Monitor Agent
EOF

  echo "[$(date)] ${AGENT_NAME}: Performance report generated: ${report_file}" >>"${LOG_FILE}"
}

# Function to perform comprehensive performance monitoring
perform_performance_monitoring() {
  echo "[$(date)] ${AGENT_NAME}: Starting comprehensive performance monitoring..." >>"${LOG_FILE}"

  collect_system_metrics
  monitor_agent_performance
  analyze_performance_trends
  generate_performance_report

  echo "[$(date)] ${AGENT_NAME}: Performance monitoring completed" >>"${LOG_FILE}"
}

echo "[$(date)] ${AGENT_NAME}: Performance Monitor Agent started successfully" >>"${LOG_FILE}"
echo "[$(date)] ${AGENT_NAME}: Monitoring system performance and agent efficiency" >>"${LOG_FILE}"

while true; do
  update_status running
  echo "[$(date)] ${AGENT_NAME}: Performing performance monitoring cycle..." >>"${LOG_FILE}"

  perform_performance_monitoring

  update_status idle
  echo "[$(date)] ${AGENT_NAME}: Sleeping for ${SLEEP_INTERVAL} seconds..." >>"${LOG_FILE}"
  sleep "${SLEEP_INTERVAL}"
done
