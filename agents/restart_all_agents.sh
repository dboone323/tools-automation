#!/usr/bin/env bash
#
# restart_all_agents.sh - Gracefully restart all agents (for daily rotation)
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

LOG_FILE="${SCRIPT_DIR}/logs/restart_all_agents.log"
mkdir -p "$(dirname "$LOG_FILE")"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

echo -e "${BLUE}=== Restarting All Agents ===${NC}"
log "=========================================="
log "Daily agent restart initiated"

# Stop all agents
log "Stopping all agents..."
if bash "${SCRIPT_DIR}/stop_all_agents.sh"; then
    log "✅ All agents stopped"
else
    log "⚠️  Some agents failed to stop gracefully"
fi

# Wait a moment for cleanup
sleep 2

# Clear stale PID files
log "Cleaning up stale resources..."
rm -f "${SCRIPT_DIR}/status"/*.pid

# Start all agents
log "Starting all agents..."
if bash "${SCRIPT_DIR}/start_all_agents.sh"; then
    log "✅ All agents started"
else
    log "⚠️  Some agents failed to start"
fi

# Health check
sleep 5
RUNNING_COUNT=$(pgrep -f "agent.*\.sh" | wc -l | tr -d ' ')

log "=========================================="
log "Restart complete. $RUNNING_COUNT agent(s) running"

if [[ $RUNNING_COUNT -gt 0 ]]; then
    echo -e "${GREEN}✅ Agent restart successful${NC}"
    echo "  Running agents: $RUNNING_COUNT"
else
    echo -e "${RED}❌ Agent restart failed - no agents running${NC}"
    exit 1
fi

# Send health report (if notification agent exists)
if command -v notify-send >/dev/null 2>&1; then
    notify-send "Agent Restart" "$RUNNING_COUNT agents restarted successfully"
fi
