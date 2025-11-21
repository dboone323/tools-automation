#!/usr/bin/env bash
#
# start_all_agents.sh - Start all enabled agents in priority order
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Dynamic configuration discovery
if [[ -f "${SCRIPT_DIR}/agent_config_discovery.sh" ]]; then
    source "${SCRIPT_DIR}/agent_config_discovery.sh"
    WORKSPACE_ROOT=$(get_workspace_root)
    AGENTS_DIR=$(get_agents_dir)
fi

# Source shared functions
if [[ -f "${SCRIPT_DIR}/shared_functions.sh" ]]; then
    source "${SCRIPT_DIR}/shared_functions.sh"
fi

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Priority order for agent startup
PRIORITY_AGENTS=(
    "agent_control.sh"
    "agent_supervisor.sh"
    "auto_restart_monitor.sh"
)

# PID directory
PID_DIR="${AGENTS_DIR}/status"
mkdir -p "$PID_DIR"

LOG_FILE="${AGENTS_DIR}/logs/start_all_agents.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

start_agent() {
    local agent_script="$1"
    local agent_name=$(basename "$agent_script")
    
    # Skip if not executable
    if [[ ! -x "$agent_script" ]]; then
        log "⚠️  Skipping $agent_name (not executable)"
        return 1
    fi
    
    # Check if already running
    if pgrep -f "$agent_name" > /dev/null; then
        log "ℹ️  $agent_name already running"
        return 0
    fi
    
    # Start the agent in background
    log "🚀 Starting $agent_name..."
    nohup bash "$agent_script" >> "${AGENTS_DIR}/logs/${agent_name}.log" 2>&1 &
    local pid=$!
    
    # Save PID
    echo "$pid" > "${PID_DIR}/${agent_name}.pid"
    
    # Wait a moment to ensure it started
    sleep 0.5
    
    # Verify it's running
    if ps -p "$pid" > /dev/null; then
        log "✅ Started $agent_name (PID: $pid)"
        return 0
    else
        log "❌ Failed to start $agent_name"
        return 1
    fi
}

echo -e "${BLUE}=== Starting All Agents ===${NC}"
log "======================================"
log "Starting all agents..."

# Start priority agents first
for agent_name in "${PRIORITY_AGENTS[@]}"; do
    agent_script="${AGENTS_DIR}/${agent_name}"
    if [[ -f "$agent_script" ]]; then
        start_agent "$agent_script"
        sleep 1  # Stagger startup
    fi
done

# Start remaining agents (excluding priority ones and utility scripts)
for agent_script in "${AGENTS_DIR}"/agent_*.sh "${AGENTS_DIR}"/*_agent.sh; do
    [[ ! -f "$agent_script" ]] && continue
    
    agent_name=$(basename "$agent_script")
    
    # Skip priority agents (already started)
    skip=false
    for priority in "${PRIORITY_AGENTS[@]}"; do
        if [[ "$agent_name" == "$priority" ]]; then
            skip=true
            break
        fi
    done
    [[ "$skip" == "true" ]] && continue
    
    # Skip utility scripts
    [[ "$agent_name" == "agent_config_discovery.sh" ]] && continue
    [[ "$agent_name" == "shared_functions.sh" ]] && continue
    [[ "$agent_name" == *"migrate"* ]] && continue
    [[ "$agent_name" == *"template"* ]] && continue
    
    # Skip if auto-restart is disabled
    if [[ -f "${SCRIPT_DIR}/shared_functions.sh" ]]; then
        if ! should_auto_restart "$agent_name" 2>/dev/null; then
            log "⏭️  Skipping $agent_name (auto-restart disabled)"
            continue
        fi
    fi
    
    start_agent "$agent_script"
    sleep 0.3  # Brief pause between agents
done

# Summary
echo ""
log "======================================"
RUNNING_COUNT=$(pgrep -f "agent.*\.sh" | wc -l | tr -d ' ')
log "Startup complete. $RUNNING_COUNT agent(s) running"
echo -e "${GREEN}✅ Agent startup complete${NC}"
echo ""
echo "View logs: tail -f ${AGENTS_DIR}/logs/*.log"
echo "Stop all: ${AGENTS_DIR}/stop_all_agents.sh"
