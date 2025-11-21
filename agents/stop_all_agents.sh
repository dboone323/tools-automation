#!/usr/bin/env bash
#
# stop_all_agents.sh - Gracefully stop all running agents
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

PID_DIR="${SCRIPT_DIR}/status"
LOG_FILE="${SCRIPT_DIR}/logs/stop_all_agents.log"
mkdir -p "$(dirname "$LOG_FILE")"

TIMEOUT=10  # Seconds to wait before forcing kill

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

stop_agent() {
    local pid="$1"
    local agent_name="$2"
    
    if ! ps -p "$pid" > /dev/null; then
        log "ℹ️  $agent_name (PID: $pid) not running"
        return 0
    fi
    
    log "🛑 Stopping $agent_name (PID: $pid)..."
    
    # Send SIGTERM for graceful shutdown
    kill -TERM "$pid" 2>/dev/null || true
    
    # Wait for process to exit
    local elapsed=0
    while ps -p "$pid" > /dev/null && [[ $elapsed -lt $TIMEOUT ]]; do
        sleep 1
        ((elapsed++))
    done
    
    # Force kill if still running
    if ps -p "$pid" > /dev/null; then
        log "⚠️  Force killing $agent_name (PID: $pid)"
        kill -9 "$pid" 2>/dev/null || true
        sleep 0.5
    fi
    
    if ! ps -p "$pid" > /dev/null; then
        log "✅ Stopped $agent_name"
        return 0
    else
        log "❌ Failed to stop $agent_name"
        return 1
    fi
}

echo -e "${BLUE}=== Stopping All Agents ===${NC}"
log "======================================"
log "Stopping all agents..."

STOPPED_COUNT=0
FAILED_COUNT=0

# Stop agents from PID files
if [[ -d "$PID_DIR" ]]; then
    for pid_file in "$PID_DIR"/*.pid; do
        [[ ! -f "$pid_file" ]] && continue
        
        agent_name=$(basename "$pid_file" .pid)
        pid=$(cat "$pid_file")
        
        if stop_agent "$pid" "$agent_name"; then
            ((STOPPED_COUNT++))
            rm -f "$pid_file"
        else
            ((FAILED_COUNT++))
        fi
    done
fi

# Catch any remaining agent processes
REMAINING=$(pgrep -f "agent.*\.sh" || true)
if [[ -n "$REMAINING" ]]; then
    log "⚠️  Found additional agent processes, stopping..."
    while IFS= read -r pid; do
        # Get process command
        cmd=$(ps -p "$pid" -o comm= 2>/dev/null || echo "unknown")
        if stop_agent "$pid" "$cmd"; then
            ((STOPPED_COUNT++))
        else
            ((FAILED_COUNT++))
        fi
    done <<< "$REMAINING"
fi

# Summary
echo ""
log "======================================"
log "Stopped: $STOPPED_COUNT agent(s)"
[[ $FAILED_COUNT -gt 0 ]] && log "Failed: $FAILED_COUNT agent(s)"
log "Shutdown complete"

if [[ $FAILED_COUNT -eq 0 ]]; then
    echo -e "${GREEN}✅ All agents stopped successfully${NC}"
else
    echo -e "${YELLOW}⚠️  Some agents failed to stop. Check logs: $LOG_FILE${NC}"
fi
