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
# Mock workflow optimization agent for testing
echo "Mock workflow optimization agent started with PID: $$"

# In TEST_MODE, sleep longer to allow tests to complete
if [[ "$TEST_MODE" == "true" ]]; then
    sleep 30  # Sleep long enough for all tests to check if it's running
else
    while true; do
        sleep 1
    done
fi
