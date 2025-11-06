#!/bin/bash
# Auto-restart script for Code Analysis Agent

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/code_analysis_agent.sh"
PID_FILE="${AGENT_SCRIPT}.pid"
LOG_FILE="${SCRIPT_DIR}/code_analysis_agent_restart.log"

# Function to log messages
log_message() {
    echo "[$(date)] $*" >>"$LOG_FILE"
}

# Function to check if agent is running
is_running() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            return 0
        else
            rm -f "$PID_FILE"
        fi
    fi
    return 1
}

# Function to start agent
start_agent() {
    if is_running; then
        log_message "Agent is already running"
        return 0
    fi

    log_message "Starting Code Analysis Agent..."
    nohup "$AGENT_SCRIPT" >>"${SCRIPT_DIR}/code_analysis_agent.log" 2>&1 &
    local pid=$!
    echo $pid >"$PID_FILE"
    log_message "Agent started with PID: $pid"
}

# Function to stop agent
stop_agent() {
    if [[ -f "$PID_FILE" ]]; then
        local pid
        pid=$(cat "$PID_FILE")
        if kill -0 "$pid" 2>/dev/null; then
            log_message "Stopping agent (PID: $pid)..."
            kill "$pid"
            sleep 2
            if kill -0 "$pid" 2>/dev/null; then
                kill -9 "$pid" 2>/dev/null || true
            fi
        fi
        rm -f "$PID_FILE"
        log_message "Agent stopped"
    else
        log_message "No PID file found - agent may not be running"
    fi
}

# Function to restart agent
restart_agent() {
    log_message "Restarting Code Analysis Agent..."
    stop_agent
    sleep 2
    start_agent
}

# Main command handling
case "${1:-start}" in
start)
    start_agent
    ;;
stop)
    stop_agent
    ;;
restart)
    restart_agent
    ;;
status)
    if is_running; then
        echo "Code Analysis Agent is running (PID: $(cat "$PID_FILE"))"
    else
        echo "Code Analysis Agent is not running"
    fi
    ;;
*)
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac
