#!/bin/bash

# Dynamic configuration discovery
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=./agent_config_discovery.sh
if [[ -f "${SCRIPT_DIR}/agent_config_discovery.sh" ]]; then
    source "${SCRIPT_DIR}/agent_config_discovery.sh"
    WORKSPACE_ROOT=$(get_workspace_root)
    AGENTS_DIR=$(get_agents_dir)
    MCP_URL=$(get_mcp_url)
else
    echo "ERROR: agent_config_discovery.sh not found"
    exit 1
fi
# Test project health agent for auto-restart testing
echo "Test project health agent started with PID: $$"
if [[ "$TEST_MODE" == "true" ]]; then
    sleep 10
else
    while true; do
        sleep 1
    done
fi
