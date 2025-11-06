#!/usr/bin/env bash
# Lightweight agent monitoring wrapper
# Usage: agent_monitoring.sh <agent-name> <command> [args...]

set -euo pipefail

AGENT_NAME="$1"
shift || true
COMMAND=("$@")

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
MON_DIR="$ROOT_DIR/monitoring"
mkdir -p "$MON_DIR"

TIMESTAMP=$(date +%Y%m%d_%H%M%S)
LOGFILE="$MON_DIR/${AGENT_NAME}_$TIMESTAMP.log"

echo "[MONITOR] Starting agent: $AGENT_NAME" | tee -a "$LOGFILE"
echo "[MONITOR] Timestamp: $(date -u)" | tee -a "$LOGFILE"
echo "[MONITOR] Command: ${COMMAND[*]}" | tee -a "$LOGFILE"

# Check Ollama health before starting agent
echo "[MONITOR] Checking Ollama health..." | tee -a "$LOGFILE"
if command -v ./ollama_health.sh &>/dev/null; then
    health_status=$(./ollama_health.sh 2>/dev/null || echo '{"healthy": false, "issues": ["Health check failed"], "mem_free_mb": 0}')
    echo "[MONITOR] Ollama Health: $health_status" | tee -a "$LOGFILE"

    # Parse health status for circuit breaker
    if echo "$health_status" | jq -e '.healthy == false' >/dev/null 2>&1; then
        echo "[MONITOR] ERROR: Ollama health check failed - aborting agent execution" | tee -a "$LOGFILE"
        echo "[MONITOR] Health issues:" | tee -a "$LOGFILE"
        echo "$health_status" | jq -r '.issues[]' | sed 's/^/[MONITOR] /' | tee -a "$LOGFILE"
        exit 1
    fi
else
    echo "[MONITOR] WARNING: ollama_health.sh not found - skipping health check" | tee -a "$LOGFILE"
fi

# Start the command in background so we can monitor it
("${COMMAND[@]}") &
AGENT_PID=$!

echo "[MONITOR] Agent PID: $AGENT_PID" | tee -a "$LOGFILE"

# Monitoring loop: sample every 2 seconds until process exits
while kill -0 "$AGENT_PID" 2>/dev/null; do
    echo "--- SAMPLE $(date -u) ---" >>"$LOGFILE"
    echo "[PS]" >>"$LOGFILE"
    ps -o pid,ppid,%cpu,%mem,etime,stat,command -p "$AGENT_PID" >>"$LOGFILE" 2>&1 || true
    echo "[TOP]" >>"$LOGFILE"
    # macOS top one-shot (requires -l 1), fallback if not available
    if command -v top >/dev/null 2>&1; then
        top -l 1 -pid "$AGENT_PID" -stats pid,command,cpu,mem >>"$LOGFILE" 2>&1 || true
    else
        ps -o pid,ppid,%cpu,%mem,etime,stat,command -p "$AGENT_PID" >>"$LOGFILE" 2>&1 || true
    fi
    echo "[LSOF]" >>"$LOGFILE"
    if command -v lsof >/dev/null 2>&1; then
        lsof -p "$AGENT_PID" 2>>"$LOGFILE" | head -n 200 >>"$LOGFILE" || true
    fi
    echo "[VMSTAT]" >>"$LOGFILE"
    if command -v vm_stat >/dev/null 2>&1; then
        vm_stat 2>>"$LOGFILE" | head -n 40 >>"$LOGFILE" || true
    fi
    # Periodic Ollama health check (every 10 samples = 20 seconds)
    if [[ $(($(date +%s) % 20)) -eq 0 ]]; then
        echo "[OLLAMA_HEALTH]" >>"$LOGFILE"
        if command -v ./ollama_health.sh &>/dev/null; then
            ./ollama_health.sh >>"$LOGFILE" 2>&1 || echo "Health check failed" >>"$LOGFILE"
        fi
    fi
    sleep 2
done

wait "$AGENT_PID" || AG_EXIT_CODE=$?
AG_EXIT_CODE=${AG_EXIT_CODE:-0}

echo "[MONITOR] Agent finished with exit code: $AG_EXIT_CODE" | tee -a "$LOGFILE"
echo "[MONITOR] Final snapshot: $(date -u)" >>"$LOGFILE"
ps -o pid,ppid,%cpu,%mem,etime,stat,command -p "$AGENT_PID" >>"$LOGFILE" 2>&1 || true

echo "[MONITOR] Log saved to: $LOGFILE"

exit "$AG_EXIT_CODE"
