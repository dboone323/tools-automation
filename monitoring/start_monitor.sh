#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
VENV="$SCRIPT_DIR/.venv/bin/python"
LOGDIR="$SCRIPT_DIR/logs"
mkdir -p "$LOGDIR"
nohup "$VENV" "$SCRIPT_DIR/github_workflow_monitor.py" >"$LOGDIR/github_workflow_monitor.out" 2>"$LOGDIR/github_workflow_monitor.err" &
echo $! >"$LOGDIR/github_workflow_monitor.pid"
echo "started monitor pid $(cat "$LOGDIR/github_workflow_monitor.pid")"
