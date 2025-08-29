#!/usr/bin/env bash
# Simple helper to run MCP server as a background daemon (non-root)
set -euo pipefail

MCP_PY="$(dirname "$0")/mcp_server.py"
LOG_DIR="$(dirname "$0")/logs"
mkdir -p "$LOG_DIR"

# Log rotation settings
MAX_LOG_BYTES=${MAX_LOG_BYTES:-1048576} # 1MB
MAX_LOG_COUNT=${MAX_LOG_COUNT:-5}
LOG_FILE="$LOG_DIR/mcp_server.log"

rotate_logs() {
	if [[ -f $LOG_FILE && $(stat -f%z "$LOG_FILE" 2>/dev/null || echo 0) -ge $MAX_LOG_BYTES ]]; then
		# rotate
		for ((i = MAX_LOG_COUNT - 1; i >= 1; i--)); do
			if [[ -f "$LOG_FILE.$i" ]]; then
				mv "$LOG_FILE.$i" "$LOG_FILE.$((i + 1))" || true
			fi
		done
		if [[ -f $LOG_FILE ]]; then
			mv "$LOG_FILE" "$LOG_FILE.1" || true
		fi
	fi
	# trim older than MAX_LOG_COUNT
	if [[ -f "$LOG_FILE.$((MAX_LOG_COUNT + 1))" ]]; then
		rm -f "$LOG_FILE.$((MAX_LOG_COUNT + 1))" || true
	fi
}

rotate_logs

# If port already bound, show existing process and exit
PORT_CHECK=${MCP_PORT:-5005}
existing=$(lsof -iTCP -sTCP:LISTEN -P -n | grep ":${PORT_CHECK} " || true)
if [[ -n $existing ]]; then
	echo "Port ${PORT_CHECK} already in use by:"
	echo "$existing"
	# Try to extract PID
	pid=$(echo "$existing" | awk '{print $2}' | head -n1 || true)
	if [[ -n $pid ]]; then
		echo "$pid" >"$LOG_DIR/mcp_server.pid" || true
		echo "Not starting new server. Existing PID saved to $LOG_DIR/mcp_server.pid"
		exit 0
	else
		echo "Unable to determine PID for existing listener; not starting new server."
		exit 1
	fi
fi

nohup python3 "$MCP_PY" >"$LOG_FILE" 2>&1 &
echo $! >"$LOG_DIR/mcp_server.pid"
echo "MCP server started (pid=$(cat $LOG_DIR/mcp_server.pid)), logs: $LOG_FILE"
