#!/bin/bash

# Serve Dashboard Agent
# Simple HTTP server to serve dashboard files

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_DIR="${SCRIPT_DIR}/dashboard"
LOG_FILE="${SCRIPT_DIR}/logs/serve_dashboard.log"
STATUS_FILE="${SCRIPT_DIR}/status/serve_dashboard.status"
PORT=${PORT:-8080}
HOST=${HOST:-localhost}

# Create directories
mkdir -p "${SCRIPT_DIR}/logs"
mkdir -p "${SCRIPT_DIR}/status"
mkdir -p "${DASHBOARD_DIR}"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log() {
    echo "$(date '+%Y-%m-%d %H:%M:%S') - $*" | tee -a "${LOG_FILE}"
}

update_status() {
    echo "$*" >"${STATUS_FILE}"
}

check_dependencies() {
    log "Checking dependencies..."

    local missing_deps=()

    if ! command -v python3 >/dev/null 2>&1 && ! command -v python >/dev/null 2>&1; then
        missing_deps+=("python")
    fi

    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log "ERROR: Missing dependencies: ${missing_deps[*]}"
        update_status "ERROR: Missing dependencies"
        return 1
    fi

    log "All dependencies available"
    return 0
}

create_sample_dashboard() {
    local dashboard_file="${DASHBOARD_DIR}/index.html"

    if [[ ! -f "${dashboard_file}" ]]; then
        log "Creating sample dashboard..."

        cat >"${dashboard_file}" <<'EOF'
<!DOCTYPE html>
<html lang="en">
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
    <title>Agent Dashboard</title>
    <style>
        body { font-family: Arial, sans-serif; margin: 20px; }
        .status { padding: 10px; margin: 10px 0; border-radius: 5px; }
        .healthy { background-color: #d4edda; color: #155724; }
        .warning { background-color: #fff3cd; color: #856404; }
        .error { background-color: #f8d7da; color: #721c24; }
    </style>
</head>
<body>
    <h1>🤖 Agent Dashboard</h1>
    <div id="status" class="status healthy">
        Dashboard loading...
    </div>
    <div id="agents">
        <h2>Agent Status</h2>
        <p>Loading agent information...</p>
    </div>
    <script>
        async function updateStatus() {
            try {
                const response = await fetch('/api/status');
                const data = await response.json();
                document.getElementById('status').textContent = data.message;
                document.getElementById('status').className = 'status ' + data.status;
            } catch (error) {
                document.getElementById('status').textContent = 'Unable to connect to server';
                document.getElementById('status').className = 'status error';
            }
        }
        updateStatus();
        setInterval(updateStatus, 30000);
    </script>
</body>
</html>
EOF

        log "Sample dashboard created: ${dashboard_file}"
    fi
}

start_server() {
    log "Starting dashboard server on ${HOST}:${PORT}..."

    # Check if port is available
    if lsof -Pi :${PORT} -sTCP:LISTEN -t >/dev/null 2>&1; then
        log "ERROR: Port ${PORT} is already in use"
        update_status "ERROR: Port ${PORT} in use"
        return 1
    fi

    # Try Python 3 first, then Python 2
    if command -v python3 >/dev/null 2>&1; then
        PYTHON_CMD="python3"
    elif command -v python >/dev/null 2>&1; then
        PYTHON_CMD="python"
    else
        log "ERROR: No Python interpreter found"
        update_status "ERROR: No Python found"
        return 1
    fi

    # Start server in background
    cd "${DASHBOARD_DIR}"
    nohup ${PYTHON_CMD} -m http.server ${PORT} >"${LOG_FILE}.server" 2>&1 &
    local server_pid=$!

    # Wait a moment for server to start
    sleep 2

    # Check if server is running
    if kill -0 ${server_pid} 2>/dev/null; then
        echo ${server_pid} >"${SCRIPT_DIR}/status/dashboard_server.pid"
        log "Dashboard server started successfully (PID: ${server_pid})"
        update_status "RUNNING: Server on ${HOST}:${PORT} (PID: ${server_pid})"
        return 0
    else
        log "ERROR: Failed to start dashboard server"
        update_status "ERROR: Server failed to start"
        return 1
    fi
}

stop_server() {
    log "Stopping dashboard server..."

    local pid_file="${SCRIPT_DIR}/status/dashboard_server.pid"

    if [[ -f "${pid_file}" ]]; then
        local server_pid=$(cat "${pid_file}")

        if kill -0 ${server_pid} 2>/dev/null; then
            kill ${server_pid}
            sleep 2

            if kill -0 ${server_pid} 2>/dev/null; then
                kill -9 ${server_pid} 2>/dev/null
                log "Force killed server (PID: ${server_pid})"
            else
                log "Server stopped gracefully (PID: ${server_pid})"
            fi
        else
            log "Server process ${server_pid} not found"
        fi

        rm -f "${pid_file}"
    else
        log "No PID file found - checking for running servers..."

        # Try to find and kill any python http.server processes
        local pids=$(pgrep -f "python.*http.server.*${PORT}" 2>/dev/null || true)
        if [[ -n "${pids}" ]]; then
            echo "${pids}" | xargs kill 2>/dev/null || true
            sleep 1
            echo "${pids}" | xargs kill -9 2>/dev/null || true
            log "Killed ${#pids[@]} server processes"
        fi
    fi

    update_status "STOPPED"
}

check_server_health() {
    local pid_file="${SCRIPT_DIR}/status/dashboard_server.pid"

    if [[ -f "${pid_file}" ]]; then
        local server_pid=$(cat "${pid_file}")

        if kill -0 ${server_pid} 2>/dev/null; then
            # Test if server responds
            if curl -s --max-time 5 "http://${HOST}:${PORT}/" >/dev/null 2>&1; then
                update_status "HEALTHY: Server responding on ${HOST}:${PORT}"
                return 0
            else
                update_status "WARNING: Server not responding"
                return 1
            fi
        else
            update_status "ERROR: Server process died"
            rm -f "${pid_file}"
            return 1
        fi
    else
        update_status "STOPPED: No server running"
        return 1
    fi
}

# Source shared functions
if [[ -f "${SCRIPT_DIR}/shared_functions.sh" ]]; then
    source "${SCRIPT_DIR}/shared_functions.sh"
fi

# Main
main() {
    case "${1:-start}" in
    start)
        if check_dependencies && create_sample_dashboard && start_server; then
            log "Dashboard server started successfully"
            check_server_health
        else
            log "Failed to start dashboard server"
            exit 1
        fi
        ;;
    stop)
        stop_server
        ;;
    restart)
        stop_server
        sleep 2
        if check_dependencies && create_sample_dashboard && start_server; then
            log "Dashboard server restarted successfully"
            check_server_health
        fi
        ;;
    status)
        check_server_health
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        exit 1
        ;;
    esac
}

# If run directly, execute main
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
