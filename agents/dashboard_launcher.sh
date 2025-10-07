#!/bin/bash
# Dashboard Launcher Script

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

DASHBOARD_AGENT="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/unified_dashboard_agent.sh"
DASHBOARD_PID_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/dashboard_server.pid"
LOG_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/dashboard_launcher.log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date)] [${level}] ${message}" >>"${LOG_FILE}"
  echo -e "${BLUE}[$(date)]${NC} [${level}] ${message}"
}

# Check if dashboard is already running
is_dashboard_running() {
  if [[ -f ${DASHBOARD_PID_FILE} ]]; then
    local pid
    pid="$(<"${DASHBOARD_PID_FILE}")"
    if kill -0 "${pid}" 2>/dev/null; then
      return 0 # Running
    else
      rm -f "${DASHBOARD_PID_FILE}"
      return 1 # Not running
    fi
  fi
  return 1 # Not running
}

# Start dashboard
start_dashboard() {
  if is_dashboard_running; then
    echo -e "${YELLOW}Dashboard is already running!${NC}"
    return 1
  fi

  log_message "INFO" "Starting Unified Dashboard Agent..."

  # Start the dashboard agent in background
  nohup "${DASHBOARD_AGENT}" >>"${LOG_FILE}" 2>&1 &
  local agent_pid=$!

  # Wait a moment for the agent to start
  sleep 2

  # Check if agent is still running
  if kill -0 "${agent_pid}" 2>/dev/null; then
    echo "${agent_pid}" >"/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/dashboard_agent.pid"
    log_message "INFO" "Dashboard agent started with PID ${agent_pid}"
    echo -e "${GREEN}✅ Dashboard agent started successfully!${NC}"
    echo -e "${BLUE}🌐 Dashboard will be available at: http://localhost:8080${NC}"
    echo -e "${YELLOW}📊 Dashboard updates every 30 seconds${NC}"
    return 0
  else
    log_message "ERROR" "Failed to start dashboard agent"
    echo -e "${RED}❌ Failed to start dashboard agent${NC}"
    return 1
  fi
}

# Stop dashboard
stop_dashboard() {
  if ! is_dashboard_running; then
    echo -e "${YELLOW}Dashboard is not running${NC}"
    return 0
  fi

  log_message "INFO" "Stopping dashboard..."

  # Stop the dashboard server
  if [[ -f ${DASHBOARD_PID_FILE} ]]; then
    local server_pid
    server_pid="$(<"${DASHBOARD_PID_FILE}")"
    if kill -0 "${server_pid}" 2>/dev/null; then
      kill "${server_pid}"
      log_message "INFO" "Dashboard server stopped (PID ${server_pid})"
    fi
    rm -f "${DASHBOARD_PID_FILE}"
  fi

  # Stop the dashboard agent
  local agent_pid_file="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/dashboard_agent.pid"
  if [[ -f ${agent_pid_file} ]]; then
    local agent_pid
    agent_pid="$(<"${agent_pid_file}")"
    if kill -0 "${agent_pid}" 2>/dev/null; then
      kill "${agent_pid}"
      log_message "INFO" "Dashboard agent stopped (PID ${agent_pid})"
    fi
    rm -f "${agent_pid_file}"
  fi

  echo -e "${GREEN}✅ Dashboard stopped successfully${NC}"
}

# Restart dashboard
restart_dashboard() {
  echo -e "${YELLOW}Restarting dashboard...${NC}"
  stop_dashboard
  sleep 2
  start_dashboard
}

# Show dashboard status
show_status() {
  if is_dashboard_running; then
    local pid
    pid="$(<"${DASHBOARD_PID_FILE}")"
    echo -e "${GREEN}✅ Dashboard is running${NC}"
    echo -e "${BLUE}🌐 Dashboard URL: http://localhost:8080${NC}"
    echo -e "${BLUE}🔢 Server PID: ${pid}${NC}"

    # Show agent status
    local agent_pid_file="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/dashboard_agent.pid"
    if [[ -f ${agent_pid_file} ]]; then
      local agent_pid
      agent_pid="$(<"${agent_pid_file}")"
      echo -e "${BLUE}🤖 Agent PID: ${agent_pid}${NC}"
    fi
  else
    echo -e "${RED}❌ Dashboard is not running${NC}"
  fi
}

# Show help
show_help() {
  echo "Unified Dashboard Launcher"
  echo ""
  echo "Usage: $0 [command]"
  echo ""
  echo "Commands:"
  echo "  start     Start the dashboard"
  echo "  stop      Stop the dashboard"
  echo "  restart   Restart the dashboard"
  echo "  status    Show dashboard status"
  echo "  help      Show this help message"
  echo ""
  echo "Examples:"
  echo "  $0 start    # Start the dashboard"
  echo "  $0 status   # Check if dashboard is running"
  echo "  $0 stop     # Stop the dashboard"
}

# Main script logic
case "${1:-start}" in
"start")
  start_dashboard
  ;;
"stop")
  stop_dashboard
  ;;
"restart")
  restart_dashboard
  ;;
"status")
  show_status
  ;;
"help" | "-h" | "--help")
  show_help
  ;;
*)
  echo -e "${RED}Unknown command: $1${NC}"
  echo ""
  show_help
  exit 1
  ;;
esac
