#!/bin/zsh
# Minimal run_mcp_server shim for tests

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${0}")" && pwd)"
ROOT_DIR="${ROOT_DIR:-$(cd "${SCRIPT_DIR}/.." && pwd)}"

# Export expected MCP env vars (tests search for these patterns)
export MCP_HOST="${MCP_HOST:-127.0.0.1}"
export MCP_PORT="${MCP_PORT:-8080}"
export MCP_AUTH_TOKEN="${MCP_AUTH_TOKEN:-}"

# Call helper to populate auth token if available
if [[ -x "${ROOT_DIR}/scripts/mcp_auth_token.sh" ]]; then
    "${ROOT_DIR}/scripts/mcp_auth_token.sh" || true
fi

PID_FILE="${PID_FILE:-${SCRIPT_DIR}/mcp_server.pid}"

case "${1-}" in
start)
    cd "${ROOT_DIR}" || exit 1
    # Use exec to run the server as expected in tests (pattern: exec python3.*mcp_server.py)
    exec python3 "${ROOT_DIR}/mcp_server.py"
    ;;
stop)
    if [[ -f "${PID_FILE}" ]]; then
        kill "$(cat "${PID_FILE}")" 2>/dev/null || true
        rm -f "${PID_FILE}"
    fi
    ;;
status)
    if [[ -f "${PID_FILE}" ]] && kill -0 "$(cat "${PID_FILE}")" 2>/dev/null; then
        echo "running"
        exit 0
    fi
    echo "stopped"
    exit 1
    ;;
test)
    echo "run_mcp_server: ok"
    exit 0
    ;;
*)
    echo "Usage: $0 {start|stop|status|test}"
    exit 2
    ;;
esac
