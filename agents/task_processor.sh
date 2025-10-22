#!/bin/bash
# Quantum Task Processor - Continuous background task acceleration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ACCELERATOR="${SCRIPT_DIR}/task_accelerator.py"
LOG_FILE="${SCRIPT_DIR}/task_processor.log"
PID_FILE="${SCRIPT_DIR}/task_processor.pid"

log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "$LOG_FILE"
}

start_processor() {
    if [[ -f "$PID_FILE" ]]; then
        if kill -0 "$(cat "$PID_FILE")" 2>/dev/null; then
            log "Task processor already running (PID: $(cat "$PID_FILE"))"
            return 1
        fi
    fi

    log "Starting Quantum Task Processor..."

    # Start background process
    (
        echo $$ >"$PID_FILE"

        while true; do
            log "Running acceleration cycle..."

            # Run acceleration cycle
            if python3 "$ACCELERATOR" cycle >>"$LOG_FILE" 2>&1; then
                log "Acceleration cycle completed successfully"
            else
                log "Acceleration cycle failed"
            fi

            # Check progress
            python3 "$ACCELERATOR" report >>"$LOG_FILE" 2>&1

            # Wait before next cycle (30 seconds)
            sleep 30
        done
    ) &

    local pid=$!
    echo $pid >"$PID_FILE"
    log "Task processor started (PID: $pid)"
}

stop_processor() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            kill "$pid" 2>/dev/null
            log "Task processor stopped (PID: $pid)"
        fi
        rm -f "$PID_FILE"
    fi
}

status_processor() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log "Task processor running (PID: $pid)"
            return 0
        else
            log "Task processor PID file exists but process not running"
            rm -f "$PID_FILE"
            return 1
        fi
    else
        log "Task processor not running"
        return 1
    fi
}

case "${1:-start}" in
start)
    start_processor
    ;;
stop)
    stop_processor
    ;;
restart)
    stop_processor
    sleep 2
    start_processor
    ;;
status)
    status_processor
    ;;
*)
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac
