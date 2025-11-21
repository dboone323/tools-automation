        #!/usr/bin/env bash
        # Auto-injected health & reliability shim

        DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer shared helpers when available
if [[ -f "$DIR/shared_functions.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/shared_functions.sh"
fi

if [[ -f "$DIR/agent_helpers.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/agent_helpers.sh"
fi

set -euo pipefail

AGENT_NAME="auto_restart_project_health_agent.sh"
LOG_FILE="${LOG_FILE:-$DIR/${AGENT_NAME}.log}"
PID=$$

if type update_agent_status >/dev/null 2>&1; then
  trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; exit 0' SIGTERM SIGINT
else
  trap 'exit 0' SIGTERM SIGINT
fi

if [[ "${1-}" == "--health" || "${1-}" == "health" || "${1-}" == "-h" ]]; then
  if type agent_health_check >/dev/null 2>&1; then
    agent_health_check
    exit $?
  fi
  issues=()
  if [[ ! -w "/tmp" ]]; then
    issues+=("tmp_not_writable")
  fi
  if [[ ! -d "$DIR" ]]; then
    issues+=("cwd_missing")
  fi
  if [[ ${#issues[@]} -gt 0 ]]; then
    printf '{"ok":false,"issues":["%s"]}\n' "${issues[*]}"
    exit 2
  fi
  printf '{"ok":true}\n'
  exit 0
fi

# Original agent script continues below
#!/bin/bash
# Auto-restart script for Project Health Agent

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
AGENT_SCRIPT="${SCRIPT_DIR}/project_health_agent.sh"
PID_FILE="${AGENT_SCRIPT}.pid"
LOG_FILE="${SCRIPT_DIR}/project_health_agent_restart.log"

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

    log_message "Starting Project Health Agent..."
    nohup "$AGENT_SCRIPT" >>"${SCRIPT_DIR}/project_health_agent.log" 2>&1 &
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
    log_message "Restarting Project Health Agent..."
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
        echo "Project Health Agent is running (PID: $(cat "$PID_FILE"))"
    else
        echo "Project Health Agent is not running"
    fi
    ;;
*)
    echo "Usage: $0 {start|stop|restart|status}"
    exit 1
    ;;
esac
