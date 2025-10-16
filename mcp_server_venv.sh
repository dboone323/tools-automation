#!/bin/bash
# MCP Server wrapper using virtual environment

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
source "${WORKSPACE_DIR}/.venv/bin/activate"
exec python3 "${WORKSPACE_DIR}/Tools/Automation/mcp_server.py" "$@"
