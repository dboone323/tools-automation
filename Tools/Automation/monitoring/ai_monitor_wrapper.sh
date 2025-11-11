#!/bin/bash
# Autorestart wrapper for AI monitoring (path-agnostic)

set -euo pipefail

# Resolve repository root (prefer git), fallback relative to this file
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "$SCRIPT_DIR" && git rev-parse --show-toplevel 2>/dev/null || cd "$SCRIPT_DIR/../../.." && pwd)"

MONITOR_DIR="$REPO_ROOT/Tools/Automation/monitoring"
LOG_FILE="$MONITOR_DIR/autorestart.log"
MONITOR_SCRIPT="$MONITOR_DIR/ai_monitor.sh"

mkdir -p "$MONITOR_DIR"

while true; do
    echo "Starting AI monitor at $(date)" >>"$LOG_FILE"
    "$MONITOR_SCRIPT" || true
    exit_code=$?
    echo "AI monitor exited with code ${exit_code} at $(date)" >>"$LOG_FILE"

    if [[ ${exit_code} -eq 0 ]]; then
        echo "Clean exit, not restarting" >>"$LOG_FILE"
        break
    else
        echo "Restarting in 10 seconds..." >>"$LOG_FILE"
        sleep 10
    fi
done
