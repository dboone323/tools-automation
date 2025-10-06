#!/bin/bash
# Agent Control: Unified agent management interface
# Commands: start, stop, restart, status, list
# Author: Quantum Workspace AI Agent System
# Created: 2025-10-06 (Phase 5)

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
STATUS_FILE="${SCRIPT_DIR}/agent_status.json"

# Core agents (Tier 1 & 2)
CORE_AGENTS=(
  "agent_supervisor.sh"
  "agent_analytics.sh"
  "agent_validation.sh"
  "agent_integration.sh"
  "agent_notification.sh"
  "agent_optimization.sh"
  "agent_backup.sh"
  "agent_cleanup.sh"
  "agent_security.sh"
  "agent_test_quality.sh"
)

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [agent_control] $*"
}

start_agent() {
  local agent="$1"
  local agent_path="${SCRIPT_DIR}/${agent}"
  
  if [[ ! -f ${agent_path} ]]; then
    log "❌ Agent not found: ${agent}"
    return 1
  fi
  
  # Check if already running
  if pgrep -f "${agent}" &>/dev/null; then
    log "⚠️  ${agent} is already running"
    return 0
  fi
  
  log "▶️  Starting ${agent}..."
  "${agent_path}" daemon &>/dev/null &
  local pid=$!
  
  sleep 1
  
  if ps -p "${pid}" &>/dev/null; then
    log "✅ ${agent} started (PID: ${pid})"
    return 0
  else
    log "❌ Failed to start ${agent}"
    return 1
  fi
}

stop_agent() {
  local agent="$1"
  
  log "⏹️  Stopping ${agent}..."
  
  pkill -f "${agent}" 2>/dev/null || {
    log "⚠️  ${agent} not running"
    return 0
  }
  
  sleep 1
  
  if ! pgrep -f "${agent}" &>/dev/null; then
    log "✅ ${agent} stopped"
    return 0
  else
    log "❌ Failed to stop ${agent}"
    return 1
  fi
}

restart_agent() {
  local agent="$1"
  
  log "🔄 Restarting ${agent}..."
  stop_agent "${agent}"
  sleep 2
  start_agent "${agent}"
}

show_status() {
  log "📊 Agent Status Report"
  echo ""
  printf "%-35s %-10s %-10s\n" "AGENT" "STATUS" "PID"
  printf "%-35s %-10s %-10s\n" "-----" "------" "---"
  
  for agent in "${CORE_AGENTS[@]}"; do
    local pid
    pid=$(pgrep -f "${agent}" 2>/dev/null | head -1 || echo "N/A")
    
    if [[ ${pid} != "N/A" ]]; then
      printf "%-35s %-10s %-10s\n" "${agent}" "🟢 Running" "${pid}"
    else
      printf "%-35s %-10s %-10s\n" "${agent}" "🔴 Stopped" "-"
    fi
  done
  
  echo ""
  log "Total processes: $(pgrep -f 'agent.*\.sh' | wc -l | tr -d ' ')"
}

list_agents() {
  log "📋 Available Agents"
  echo ""
  echo "Tier 1: Core Operations (Always Running)"
  echo "  - agent_supervisor.sh"
  echo "  - agent_analytics.sh"
  echo "  - agent_validation.sh"
  echo "  - agent_integration.sh"
  echo "  - agent_notification.sh"
  echo ""
  echo "Tier 2: Automation & Maintenance (Scheduled)"
  echo "  - agent_optimization.sh"
  echo "  - agent_backup.sh"
  echo "  - agent_cleanup.sh"
  echo "  - agent_security.sh"
  echo "  - agent_test_quality.sh"
  echo ""
  echo "Use: ./agent_control.sh start <agent>"
}

start_all() {
  log "🚀 Starting all core agents..."
  
  local success=0
  local failed=0
  
  for agent in "${CORE_AGENTS[@]}"; do
    if start_agent "${agent}"; then
      ((success++))
    else
      ((failed++))
    fi
  done
  
  log "Summary: ${success} started, ${failed} failed"
}

stop_all() {
  log "⏹️  Stopping all agents..."
  
  for agent in "${CORE_AGENTS[@]}"; do
    stop_agent "${agent}" || true
  done
  
  log "All agents stopped"
}

# Main command handler
case "${1:-}" in
  start)
    if [[ $# -eq 1 ]]; then
      start_all
    else
      start_agent "$2"
    fi
    ;;
  stop)
    if [[ $# -eq 1 ]]; then
      stop_all
    else
      stop_agent "$2"
    fi
    ;;
  restart)
    if [[ $# -eq 1 ]]; then
      log "🔄 Restarting all agents..."
      stop_all
      sleep 2
      start_all
    else
      restart_agent "$2"
    fi
    ;;
  status)
    show_status
    ;;
  list)
    list_agents
    ;;
  *)
    echo "Usage: $0 {start|stop|restart|status|list} [agent_name]"
    echo ""
    echo "Commands:"
    echo "  start [agent]    - Start specific agent or all agents"
    echo "  stop [agent]     - Stop specific agent or all agents"
    echo "  restart [agent]  - Restart specific agent or all agents"
    echo "  status           - Show status of all core agents"
    echo "  list             - List available agents by tier"
    echo ""
    echo "Examples:"
    echo "  $0 start                    # Start all core agents"
    echo "  $0 start agent_security.sh  # Start specific agent"
    echo "  $0 stop agent_backup.sh     # Stop specific agent"
    echo "  $0 restart                  # Restart all agents"
    echo "  $0 status                   # Show agent status"
    exit 1
    ;;
esac
