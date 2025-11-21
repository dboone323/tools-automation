#!/usr/bin/env bash
#
# validate_autonomy.sh - Validate full autonomy system setup
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
AGENTS_DIR="${REPO_ROOT}/agents"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Autonomy System Validation ===${NC}"
echo ""

ERRORS=0
WARNINGS=0

# Test 1: Check launchd service
echo -e "${BLUE}[1/6]${NC} Checking launchd supervisor service..."
if launchctl list | grep -q "com.tools-automation.agent-supervisor"; then
    echo -e "  ${GREEN}✅ Supervisor service is loaded${NC}"
else
    echo -e "  ${RED}❌ Supervisor service not loaded${NC}"
    echo "      Run: ./scripts/install_agent_service.sh"
    ((ERRORS++))
fi

# Test 2: Check daily restart schedule
echo -e "${BLUE}[2/6]${NC} Checking daily restart schedule..."
if [[ -f "${HOME}/Library/LaunchAgents/com.tools-automation.daily-restart.plist" ]]; then
    if launchctl list | grep -q "com.tools-automation.daily-restart"; then
        echo -e "  ${GREEN}✅ Daily restart scheduled${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Daily restart plist exists but not loaded${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "  ${YELLOW}⚠️  Daily restart not configured${NC}"
    echo "      Run: cp ${REPO_ROOT}/com.tools-automation.daily-restart.plist ~/Library/LaunchAgents/"
    echo "      Then: launchctl load ~/Library/LaunchAgents/com.tools-automation.daily-restart.plist"
    ((WARNINGS++))
fi

# Test 3: Check if agents are running
echo -e "${BLUE}[3/6]${NC} Checking agent processes..."
RUNNING_COUNT=$(pgrep -f "agent.*\.sh" 2>/dev/null | wc -l | tr -d ' ')
if [[ $RUNNING_COUNT -gt 0 ]]; then
    echo -e "  ${GREEN}✅ $RUNNING_COUNT agent(s) running${NC}"
else
    echo -e "  ${YELLOW}⚠️  No agents currently running${NC}"
    echo "      Start agents: ${AGENTS_DIR}/start_all_agents.sh"
    ((WARNINGS++))
fi

# Test 4: Check orchestration scripts exist and are executable
echo -e "${BLUE}[4/6]${NC} Checking orchestration scripts..."
REQUIRED_SCRIPTS=(
    "${AGENTS_DIR}/start_all_agents.sh"
    "${AGENTS_DIR}/stop_all_agents.sh"
    "${AGENTS_DIR}/restart_all_agents.sh"
)
for script in "${REQUIRED_SCRIPTS[@]}"; do
    if [[ -x "$script" ]]; then
        echo -e "  ${GREEN}✅ $(basename "$script")${NC}"
    else
        echo -e "  ${RED}❌ $(basename "$script") missing or not executable${NC}"
        ((ERRORS++))
    fi
done

# Test 5: Check auto-restart monitor health
echo -e "${BLUE}[5/6]${NC} Checking auto-restart monitor..."
if pgrep -f "auto_restart_monitor.sh" > /dev/null; then
    echo -e "  ${GREEN}✅ Auto-restart monitor running${NC}"
    
    # Check monitor config
    if grep -q "SLEEP_INTERVAL=30" "${AGENTS_DIR}/auto_restart_monitor.sh"; then
        echo -e "  ${GREEN}✅ Enhanced health check interval (30s)${NC}"
    else
        echo -e "  ${YELLOW}⚠️  Using default health check interval${NC}"
        ((WARNINGS++))
    fi
else
    echo -e "  ${YELLOW}⚠️  Auto-restart monitor not running${NC}"
    ((WARNINGS++))
fi

# Test 6: Verify log directories
echo -e "${BLUE}[6/6]${NC} Checking log infrastructure..."
if [[ -d "${AGENTS_DIR}/logs" ]]; then
    LOG_COUNT=$(find "${AGENTS_DIR}/logs" -name "*.log" 2>/dev/null | wc -l | tr -d ' ')
    echo -e "  ${GREEN}✅ Log directory exists ($LOG_COUNT log files)${NC}"
else
    echo -e "  ${YELLOW}⚠️  Log directory missing${NC}"
    mkdir -p "${AGENTS_DIR}/logs"
    ((WARNINGS++))
fi

# Summary
echo ""
echo -e "${BLUE}=== Summary ===${NC}"
if [[ $ERRORS -eq 0 && $WARNINGS -eq 0 ]]; then
    echo -e "${GREEN}✅ Perfect! Full autonomy system is configured and operational${NC}"
    echo ""
    echo "System Status:"
    echo "  • Supervisor service: Active"
    echo "  • Daily rotation: Scheduled (3:00 AM)"
    echo "  • Agent health checks: 30-second intervals"
    echo "  • Auto-restart: Enabled"
    echo ""
    exit 0
elif [[ $ERRORS -eq 0 ]]; then
    echo -e "${YELLOW}⚠️  System operational with $WARNINGS warning(s)${NC}"
    echo ""
    exit 0
else
    echo -e "${RED}❌ System has $ERRORS error(s) and $WARNINGS warning(s)${NC}"
    echo ""
    echo "Please address the errors above to achieve full autonomy."
    exit 1
fi
