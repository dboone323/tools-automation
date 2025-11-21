#!/usr/bin/env bash
#
# install_agent_service.sh - Install system-level agent supervisor service
#
# This script installs a LaunchAgent that starts the agent supervisor on boot
# and keeps it running 24/7 with automatic restarts on failure.

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
PLIST_NAME="com.tools-automation.agent-supervisor.plist"
PLIST_SOURCE="${REPO_ROOT}/${PLIST_NAME}"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"
PLIST_DEST="${LAUNCH_AGENTS_DIR}/${PLIST_NAME}"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Agent Supervisor Service Installation ===${NC}"
echo ""

# Check if plist file exists
if [[ ! -f "$PLIST_SOURCE" ]]; then
    echo -e "${RED}Error: ${PLIST_NAME} not found at ${PLIST_SOURCE}${NC}"
    exit 1
fi

# Create LaunchAgents directory if it doesn't exist
if [[ ! -d "$LAUNCH_AGENTS_DIR" ]]; then
    echo -e "${YELLOW}Creating LaunchAgents directory...${NC}"
    mkdir -p "$LAUNCH_AGENTS_DIR"
fi

# Check if service is already loaded
if launchctl list | grep -q "com.tools-automation.agent-supervisor"; then
    echo -e "${YELLOW}Service is already loaded. Unloading first...${NC}"
    launchctl unload "$PLIST_DEST" 2>/dev/null || true
    sleep 1
fi

# Copy plist to LaunchAgents directory
echo -e "${GREEN}Installing service...${NC}"
cp "$PLIST_SOURCE" "$PLIST_DEST"

# Set correct permissions
chmod 644 "$PLIST_DEST"

# Load the service
echo -e "${GREEN}Loading service...${NC}"
launchctl load "$PLIST_DEST"

# Wait a moment for the service to start
sleep 2

# Check if service is running
if launchctl list | grep -q "com.tools-automation.agent-supervisor"; then
    echo ""
    echo -e "${GREEN}✅ Service installed and running!${NC}"
    echo ""
    echo "Service details:"
    echo "  Name: com.tools-automation.agent-supervisor"
    echo "  Location: ${PLIST_DEST}"
    echo "  Logs: /tmp/agent-supervisor.log"
    echo "  Error logs: /tmp/agent-supervisor-error.log"
    echo ""
    echo "Management commands:"
    echo -e "  Start:   ${BLUE}launchctl load ${PLIST_DEST}${NC}"
    echo -e "  Stop:    ${BLUE}launchctl unload ${PLIST_DEST}${NC}"
    echo -e "  Restart: ${BLUE}launchctl unload ${PLIST_DEST} && launchctl load ${PLIST_DEST}${NC}"
    echo -e "  Status:  ${BLUE}launchctl list | grep agent-supervisor${NC}"
    echo -e "  Logs:    ${BLUE}tail -f /tmp/agent-supervisor.log${NC}"
    echo ""
    echo -e "${YELLOW}Note: Service will auto-start on system boot${NC}"
else
    echo -e "${RED}Error: Service failed to start${NC}"
    echo "Check logs: tail /tmp/agent-supervisor-error.log"
    exit 1
fi
