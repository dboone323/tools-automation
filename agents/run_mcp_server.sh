#!/bin/zsh
set -euo pipefail
ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
export MCP_HOST="127.0.0.1"
export MCP_PORT="5005"
export MCP_AUTH_TOKEN="$(./security/mcp_auth_token.sh --get)"
cd "$ROOT_DIR"
exec python3 "$ROOT_DIR/mcp_server.py"
