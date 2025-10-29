#!/bin/bash
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"

collect_system_metrics() {
  local timestamp
  timestamp=$(date +%s)

  # CPU usage (macOS compatible)
  local cpu_usage
  cpu_usage=$(ps aux | awk '{sum += $3} END {print sum}' | tr -d ' ' | sed 's/[^0-9.]//g' || echo "0")

  # Memory usage (macOS compatible)
  local mem_usage
  mem_usage=$(ps aux | awk '{sum += $4} END {print sum}' | tr -d ' ' | sed 's/[^0-9.]//g' || echo "0")

  # Disk usage
  local disk_usage
  disk_usage=$(df -h "${WORKSPACE}" | tail -1 | awk '{print $5}' | tr -d '%' | sed 's/[^0-9.]//g' || echo "0")

  # Network activity (simplified)
  local network_activity
  network_activity=$(netstat -i 2>/dev/null | grep -c "en\|utun" || echo "0")

  # Process count
  local process_count
  process_count=$(ps aux | wc -l | tr -d ' ' | sed 's/[^0-9]//g' || echo "0")

  # Agent status summary
  local agent_status_summary="monitoring_active"
  if [[ -f ${AGENT_STATUS_FILE} ]]; then
    agent_status_summary=$(jq -r 'map(.id + ": " + .status) | join(", ")' "${AGENT_STATUS_FILE}" 2>/dev/null || echo "monitoring_active")
  fi

  # Debug logging
  echo "DEBUG: cpu_usage='${cpu_usage}', mem_usage='${mem_usage}', disk_usage='${disk_usage}', network_activity='${network_activity}', process_count='${process_count}'"

  # Create metrics JSON with proper number formatting
  local metrics
  metrics=$(jq -n \
    --arg timestamp "${timestamp}" \
    --argjson cpu "${cpu_usage:-0}" \
    --argjson mem "${mem_usage:-0}" \
    --argjson disk "${disk_usage:-0}" \
    --argjson net "${network_activity:-0}" \
    --argjson proc "${process_count:-0}" \
    --arg agents "${agent_status_summary}" \
    '{
            timestamp: ($timestamp | tonumber),
            cpu_usage: $cpu,
            memory_usage: $mem,
            disk_usage: $disk,
            network_activity: $net,
            process_count: $proc,
            agent_status: $agents
        }')

  echo "${metrics}"
}

collect_system_metrics
