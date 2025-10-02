#!/bin/bash
# Monitor all agents and restart any that have stopped

AGENTS_DIR="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents"
STATUS_FILE="${AGENTS_DIR}/agent_status.json"
LOG_FILE="${AGENTS_DIR}/monitor_agents.log"

log() {
  echo "[$(date)] $1" >> "${LOG_FILE}"
  echo "[$(date)] $1"
}

# Function to check if agent is running
is_agent_running() {
  local agent_name="$1"
  local pid_file="${AGENTS_DIR}/${agent_name}.pid"
  
  if [[ -f "${pid_file}" ]]; then
    local pid=$(cat "${pid_file}")
    if kill -0 "${pid}" 2>/dev/null; then
      return 0  # Running
    else
      return 1  # Not running
    fi
  else
    return 1  # No PID file
  fi
}

# Function to restart agent
restart_agent() {
  local agent_name="$1"
  local script_name="agent_${agent_name}.sh"
  
  if [[ "${agent_name}" == "public_api_agent" ]]; then
    script_name="public_api_agent.sh"
  fi
  
  log "Restarting ${agent_name}..."
  
  # Kill existing process if it exists
  if [[ -f "${AGENTS_DIR}/${agent_name}.pid" ]]; then
    local old_pid=$(cat "${AGENTS_DIR}/${agent_name}.pid")
    kill "${old_pid}" 2>/dev/null || true
    rm -f "${AGENTS_DIR}/${agent_name}.pid"
  fi
  
  # Start new instance
  cd "${AGENTS_DIR}"
  nohup bash "${script_name}" > "${agent_name}.log" 2>&1 &
  echo $! > "${AGENTS_DIR}/${agent_name}.pid"
  
  log "${agent_name} restarted with PID $(cat "${AGENTS_DIR}/${agent_name}.pid")"
}

log "Starting agent monitoring..."

while true; do
  log "Checking agent statuses..."
  
  # List of all agents to monitor
  agents=("build_agent" "debug_agent" "codegen_agent" "public_api_agent" "search_agent" "uiux_agent" "security_agent" "performance_agent" "documentation_agent" "testing_agent" "deployment_agent" "monitoring_agent" "backup_agent" "cleanup_agent" "notification_agent" "integration_agent" "validation_agent" "optimization_agent" "migration_agent" "analytics_agent" "todo_agent")
  
  stopped_agents=()
  
  for agent in "${agents[@]}"; do
    if ! is_agent_running "${agent}"; then
      stopped_agents+=("${agent}")
    fi
  done
  
  if [[ ${#stopped_agents[@]} -gt 0 ]]; then
    log "Found ${#stopped_agents[@]} stopped agents: ${stopped_agents[*]}"
    
    for agent in "${stopped_agents[@]}"; do
      restart_agent "${agent}"
    done
  else
    log "All agents are running"
  fi
  
  # Check every 30 seconds
  sleep 30
done
