#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$SCRIPT_DIR/.venv/bin/python"
LOGDIR="$SCRIPT_DIR/logs"
mkdir -p "$LOGDIR"
nohup "$VENV" "$SCRIPT_DIR/mcp_server.py" >"$LOGDIR/mcp_server.out" 2>"$LOGDIR/mcp_server.err" &
echo $! >"$LOGDIR/mcp_server.pid"
echo "started mcp pid $(cat "$LOGDIR/mcp_server.pid")"
