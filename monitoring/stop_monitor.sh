#!/usr/bin/env bash
set -euo pipefail
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PIDFILE="$SCRIPT_DIR/logs/github_workflow_monitor.pid"
if [ -f "$PIDFILE" ]; then
	PID=$(cat "$PIDFILE")
	if kill -0 "$PID" 2>/dev/null; then
		kill "$PID"
		echo "sent SIGTERM to monitor pid $PID"
		sleep 1
		if kill -0 "$PID" 2>/dev/null; then
			echo "pid $PID still alive; sending SIGKILL"
			kill -9 "$PID" || true
		fi
	else
		echo "no process with pid $PID"
	fi
	rm -f "$PIDFILE"
else
	echo "no pidfile $PIDFILE"
fi
