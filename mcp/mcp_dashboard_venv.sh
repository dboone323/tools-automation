#!/bin/bash
# MCP Dashboard wrapper using virtual environment

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
# shellcheck disable=SC1091  # Expected for virtual environment activation scripts
source "${WORKSPACE_DIR}/.venv/bin/activate"
exec python3 "${WORKSPACE_DIR}/Tools/Automation/mcp_dashboard_flask.py" "$@"
