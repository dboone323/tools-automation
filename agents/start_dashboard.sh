#!/bin/bash
# Start the Quantum Workspace Agent Dashboard Server
# This script ensures only one instance runs and uses a consistent port (8004)

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DASHBOARD_SERVER="${SCRIPT_DIR}/dashboard_api_server.py"
PID_FILE="${SCRIPT_DIR}/dashboard_server.pid"
LOG_FILE="${SCRIPT_DIR}/dashboard_server.log"

# Function to check if dashboard is running
is_dashboard_running() {
    if [[ -f "${PID_FILE}" ]]; then
        local pid
        pid=$(cat "${PID_FILE}")
        if ps -p "${pid}" > /dev/null 2>&1; then
            return 0
        else
            rm -f "${PID_FILE}"
            return 1
        fi
    fi
    return 1
}

# Function to start dashboard
start_dashboard() {
    if is_dashboard_running; then
        local pid
        pid=$(cat "${PID_FILE}")
        echo "✅ Dashboard server already running on PID ${pid}"
        echo "🌐 Dashboard URL: http://localhost:8004/dashboard"
        return 0
    fi
    
    echo "🚀 Starting Quantum Workspace Agent Dashboard..."
    
    # Start the dashboard server in background
    nohup python3 "${DASHBOARD_SERVER}" >> "${LOG_FILE}" 2>&1 &
    local new_pid=$!
    
    # Wait a moment for startup
    sleep 2
    
    # Verify it started successfully
    if ps -p "${new_pid}" > /dev/null 2>&1; then
        echo "✅ Dashboard server started successfully!"
        echo "📝 PID: ${new_pid}"
        echo "🌐 Dashboard URL: http://localhost:8004/dashboard"
        echo "📊 API URL: http://localhost:8004/api/dashboard-data"
        echo "📄 Logs: ${LOG_FILE}"
        return 0
    else
        echo "❌ Failed to start dashboard server"
        echo "📄 Check logs: ${LOG_FILE}"
        return 1
    fi
}

# Function to stop dashboard
stop_dashboard() {
    if is_dashboard_running; then
        local pid
        pid=$(cat "${PID_FILE}")
        echo "🛑 Stopping dashboard server (PID: ${pid})..."
        kill "${pid}"
        rm -f "${PID_FILE}"
        echo "✅ Dashboard server stopped"
    else
        echo "ℹ️  Dashboard server is not running"
    fi
}

# Function to restart dashboard
restart_dashboard() {
    echo "🔄 Restarting dashboard server..."
    stop_dashboard
    sleep 1
    start_dashboard
}

# Function to show status
show_status() {
    if is_dashboard_running; then
        local pid
        pid=$(cat "${PID_FILE}")
        echo "✅ Dashboard server is running"
        echo "📝 PID: ${pid}"
        echo "🌐 Dashboard URL: http://localhost:8004/dashboard"
        echo "📊 API URL: http://localhost:8004/api/dashboard-data"
        echo "📄 Logs: ${LOG_FILE}"
        
        # Test if it's responding
        if curl -s http://localhost:8004/api/dashboard-data > /dev/null; then
            echo "🟢 Server is responding to requests"
        else
            echo "🔴 Server is not responding to requests"
        fi
    else
        echo "❌ Dashboard server is not running"
    fi
}

# Main command handling
case "${1:-start}" in
    start)
        start_dashboard
        ;;
    stop)
        stop_dashboard
        ;;
    restart)
        restart_dashboard
        ;;
    status)
        show_status
        ;;
    *)
        echo "Usage: $0 {start|stop|restart|status}"
        echo ""
        echo "Commands:"
        echo "  start   - Start the dashboard server (default)"
        echo "  stop    - Stop the dashboard server"
        echo "  restart - Restart the dashboard server"
        echo "  status  - Show dashboard server status"
        exit 1
        ;;
esac