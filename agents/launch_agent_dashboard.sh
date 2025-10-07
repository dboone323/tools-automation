#!/bin/bash
# Agent Dashboard Launcher
# Starts the dashboard API server and opens the dashboard

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
AGENTS_DIR="${WORKSPACE}/Tools/Automation/agents"
LOG_FILE="${AGENTS_DIR}/dashboard_launcher.log"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
  echo "[$(date)] $*" >>"${LOG_FILE}"
  echo -e "${BLUE}[$(date)]${NC} $*"
}

# Check if server is running
is_server_running() {
  if pgrep -f "Python.*dashboard_api_server.py" >/dev/null; then
    return 0
  else
    return 1
  fi
}

# Start the dashboard server
start_server() {
  if is_server_running; then
    echo -e "${YELLOW}Dashboard server is already running${NC}"
    return 1
  fi

  log "Starting Agent Dashboard API Server..."
  cd "${AGENTS_DIR}" || {
    log "Failed to change to agents directory"
    echo -e "${RED}❌ Failed to access agents directory${NC}"
    return 1
  }

  # Start server in background
  python3 dashboard_api_server.py &
  local server_pid=$!

  # Wait for server to start
  sleep 3

  if is_server_running; then
    echo "${server_pid}" >"${AGENTS_DIR}/dashboard_server.pid"
    log "Dashboard server started with PID ${server_pid}"
    echo -e "${GREEN}✅ Agent Dashboard Server Started!${NC}"
    echo -e "${BLUE}🌐 Dashboard URL: http://localhost:8004/dashboard${NC}"
    echo -e "${YELLOW}📊 Auto-refreshes every 30 seconds${NC}"
    echo -e "${BLUE}📈 Shows live agent status and task progress${NC}"
    return 0
  else
    log "Failed to start dashboard server"
    echo -e "${RED}❌ Failed to start dashboard server${NC}"
    return 1
  fi
}

# Stop the dashboard server
stop_server() {
  if ! is_server_running; then
    echo -e "${YELLOW}Dashboard server is not running${NC}"
    return 0
  fi

  log "Stopping dashboard server..."

  # Kill server process
  pkill -f "Python.*dashboard_api_server.py"

  # Remove PID file
  rm -f "${AGENTS_DIR}/dashboard_server.pid"

  log "Dashboard server stopped"
  echo -e "${GREEN}✅ Dashboard server stopped${NC}"
}

# Show status
show_status() {
  if is_server_running; then
    local pid
    pid=$(pgrep -f "Python.*dashboard_api_server.py")
    echo -e "${GREEN}✅ Dashboard server is running${NC}"
    echo -e "${BLUE}🔢 Process ID: ${pid}${NC}"
    echo -e "${BLUE}🌐 URL: http://localhost:8004/dashboard${NC}"
  else
    echo -e "${RED}❌ Dashboard server is not running${NC}"
  fi
}

# Open dashboard in browser
open_dashboard() {
  if is_server_running; then
    echo -e "${BLUE}Opening dashboard in browser...${NC}"
    open "http://localhost:8004/dashboard"
  else
    echo -e "${RED}Dashboard server is not running. Start it first with: $0 start${NC}"
  fi
}

# Main logic
command="${1:-start}"
case "$command" in
"start")
  start_server
  ;;
"stop")
  stop_server
  ;;
"restart")
  stop_server
  sleep 2
  start_server
  ;;
"status")
  show_status
  ;;
"open")
  open_dashboard
  ;;
"help" | "-h" | "--help")
  echo "Agent Dashboard Launcher"
  echo ""
  echo "Usage: $0 [command]"
  echo ""
  echo "Commands:"
  echo "  start   - Start the dashboard server"
  echo "  stop    - Stop the dashboard server"
  echo "  restart - Restart the dashboard server"
  echo "  status  - Show server status"
  echo "  open    - Open dashboard in browser"
  echo "  help    - Show this help"
  echo ""
  echo "The dashboard shows live agent status, task progress, and system metrics."
  ;;
*)
  echo -e "${RED}Unknown command: $command${NC}"
  echo "Use '$0 help' for usage information"
  exit 1
  ;;
esac
