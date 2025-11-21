#!/usr/bin/env bash
# Production Monitoring Dashboard
# Real-time view of autonomy system health

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
BLUE='\033[0;34m'
NC='\033[0m'

clear

while true; do
    clear
    echo "╔══════════════════════════════════════════════════════════════════════╗"
    echo "║          Agent System Autonomy - Production Dashboard               ║"
    echo "║                  $(date '+%Y-%m-%d %H:%M:%S')                                  ║"
    echo "╚══════════════════════════════════════════════════════════════════════╝"
    echo ""
    
    # System Status
    echo -e "${BLUE}━━━ SYSTEM STATUS ━━━${NC}"
    
    # Configuration
    if cd "$SCRIPT_DIR/../agents" && ./agent_config_discovery.sh workspace-root > /dev/null 2>&1; then
        echo -e "✅ Configuration Discovery: ${GREEN}OPERATIONAL${NC}"
    else
        echo -e "❌ Configuration Discovery: ${RED}FAILED${NC}"
    fi
    
    # Monitoring Daemon
    if [[ -f "$SCRIPT_DIR/monitoring_daemon.pid" ]] && kill -0 $(cat "$SCRIPT_DIR/monitoring_daemon.pid") 2>/dev/null; then
        echo -e "✅ Monitoring Daemon: ${GREEN}RUNNING${NC} (PID: $(cat "$SCRIPT_DIR/monitoring_daemon.pid"))"
    else
        echo -e "❌ Monitoring Daemon: ${RED}STOPPED${NC}"
    fi
    
    # Redis
    if redis-cli ping > /dev/null 2>&1; then
        echo -e "✅ Redis: ${GREEN}CONNECTED${NC}"
    else
        echo -e "⚠️  Redis: ${YELLOW}IN-MEMORY FALLBACK${NC}"
    fi
    
    echo ""
    
    # Metrics Summary
    echo -e "${BLUE}━━━ METRICS (LAST HOUR) ━━━${NC}"
    
    if python3 "$SCRIPT_DIR/metrics_collector.py" --summary --hours 1 2>&1 | grep -A 20 "Agents:" | head -15; then
        :
    else
        echo "⚠️  Metrics unavailable"
    fi
    
    echo ""
    
    # AI Decisions (if any)
    echo -e "${BLUE}━━━ AI DECISIONS (LAST HOUR) ━━━${NC}"
    
    AI_STATS=$(python3 "$SCRIPT_DIR/ai_decision_engine.py" --agent "all" --type "any" --metrics --hours 1 2>/dev/null || echo "")
    
    if [[ -n "$AI_STATS" ]]; then
        echo "$AI_STATS" | grep "Total Decisions\|Avg Confidence\|Success Rate" | head -5
    else
        echo "No AI decisions in last hour"
    fi
    
    echo ""
    
    # Active Agents (from state manager)
    echo -e "${BLUE}━━━ ACTIVE AGENTS ━━━${NC}"
    
    ACTIVE_AGENTS=$(python3 "$SCRIPT_DIR/state_manager.py" --no-redis stats 2>/dev/null | jq -r '.active_agents' || echo "0")
    echo "Active Agents: $ACTIVE_AGENTS"
    
    echo ""
    
    # Database Sizes
    echo -e "${BLUE}━━━ DATABASE STATUS ━━━${NC}"
    
    if [[ -f "$SCRIPT_DIR/metrics.db" ]]; then
        METRICS_SIZE=$(ls -lh "$SCRIPT_DIR/metrics.db" | awk '{print $5}')
        echo "Metrics DB: $METRICS_SIZE"
    fi
    
    if [[ -f "$SCRIPT_DIR/ai_decisions.db" ]]; then
        AI_SIZE=$(ls -lh "$SCRIPT_DIR/ai_decisions.db" | awk '{print $5}')
        echo "AI Decisions DB: $AI_SIZE"
    fi
    
    echo ""
    echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo "Press Ctrl+C to exit | Refreshing every 10 seconds..."
    
    sleep 10
done
