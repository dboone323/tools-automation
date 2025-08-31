#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
LOGDIR="$SCRIPT_DIR/logs"
echo "Logs: $LOGDIR"
for svc in mcp_server github_workflow_monitor; do
	PIDFILE="$LOGDIR/${svc}.pid"
	if [ -f "$PIDFILE" ]; then
		PID=$(cat "$PIDFILE")
		if kill -0 "$PID" 2>/dev/null; then
			echo "$svc: running (pid $PID)"
		else
			echo "$svc: pidfile exists but process not running"
		fi
	else
		echo "$svc: not running (no pidfile)"
	fi
done
echo "--- tail of logs ---"
tail -n 20 "$LOGDIR/mcp_server.out" || true
tail -n 20 "$LOGDIR/github_workflow_monitor.out" || true
