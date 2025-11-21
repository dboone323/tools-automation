#!/usr/bin/env bash
#
# install_server_services.sh - Install all server launchd services
#

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
LAUNCH_AGENTS_DIR="${HOME}/Library/LaunchAgents"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}=== Installing Server Auto-Start Services ===${NC}"
echo ""

# Create LaunchAgents directory if it doesn't exist
mkdir -p "$LAUNCH_AGENTS_DIR"

# List of services to install
SERVICES=(
    "com.tools-automation.mcp-server"
    "com.tools-automation.docker-monitoring"
    "com.tools-automation.docker-quality"
)

INSTALLED=0
FAILED=0

for service in "${SERVICES[@]}"; do
    PLIST_NAME="${service}.plist"
    PLIST_SOURCE="${REPO_ROOT}/${PLIST_NAME}"
    PLIST_DEST="${LAUNCH_AGENTS_DIR}/${PLIST_NAME}"
    
    if [[ ! -f "$PLIST_SOURCE" ]]; then
        echo -e "${YELLOW}⚠️  ${PLIST_NAME} not found, skipping...${NC}"
        continue
    fi
    
    # Unload if already loaded
    if launchctl list | grep -q "$service"; then
        echo -e "${YELLOW}Unloading existing ${service}...${NC}"
        launchctl unload "$PLIST_DEST" 2>/dev/null || true
        sleep 1
    fi
    
    # Copy and load
    echo -e "${GREEN}Installing ${service}...${NC}"
    cp "$PLIST_SOURCE" "$PLIST_DEST"
    chmod 644 "$PLIST_DEST"
    
    if launchctl load "$PLIST_DEST"; then
        echo -e "${GREEN}✅ ${service} installed and loaded${NC}"
        ((INSTALLED++))
    else
        echo -e "${RED}❌ Failed to load ${service}${NC}"
        ((FAILED++))
    fi
    echo ""
done

# Summary
echo -e "${BLUE}=== Installation Summary ===${NC}"
echo "Installed: $INSTALLED service(s)"
[[ $FAILED -gt 0 ]] && echo -e "${YELLOW}Failed: $FAILED service(s)${NC}"

if [[ $INSTALLED -gt 0 ]]; then
    echo ""
    echo -e "${GREEN}Services will auto-start on boot and auto-restart on failure!${NC}"
    echo ""
    echo "Management commands:"
    echo -e "  Check status: ${BLUE}launchctl list | grep tools-automation${NC}"
    echo -e "  View logs:    ${BLUE}tail -f /tmp/mcp-server.log${NC}"
fi

