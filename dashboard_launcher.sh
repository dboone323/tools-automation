#!/bin/bash
# Dashboard Launcher: Manage the unified dashboard agent

DASHBOARD_AGENT_SCRIPT="$(dirname "$0")/agents/working_dashboard.sh"
DASHBOARD_PID_FILE="$(dirname "$0")/dashboard_agent.pid"
LOG_FILE="$(dirname "$0")/dashboard_launcher.log"

log_message() {
	local level="$1"
	local message="$2"
	echo "[$(date)] [${level}] ${message}" >>"${LOG_FILE}"
}

# Check if dashboard agent is running
is_dashboard_running() {
	if [[ -f ${DASHBOARD_PID_FILE} ]]; then
		local pid=$(cat "${DASHBOARD_PID_FILE}")
		if kill -0 "${pid}" 2>/dev/null; then
			return 0 # Running
		else
			rm -f "${DASHBOARD_PID_FILE}"
		fi
	fi
	return 1 # Not running
}

# Start dashboard agent
start_dashboard() {
	if is_dashboard_running; then
		log_message "INFO" "Dashboard agent is already running"
		echo "Dashboard agent is already running"
		return 0
	fi

	if [[ ! -f ${DASHBOARD_AGENT_SCRIPT} ]]; then
		log_message "ERROR" "Dashboard agent script not found: ${DASHBOARD_AGENT_SCRIPT}"
		echo "Error: Dashboard agent script not found"
		return 1
	fi

	log_message "INFO" "Starting dashboard agent..."
	echo "Starting dashboard agent..."

	# Start the dashboard agent in background
	nohup "${DASHBOARD_AGENT_SCRIPT}" >>"${LOG_FILE}" 2>&1 &
	local pid=$!
	echo "${pid}" >"${DASHBOARD_PID_FILE}"

	sleep 2

	if is_dashboard_running; then
		log_message "INFO" "Dashboard agent started successfully (PID: ${pid})"
		echo "Dashboard agent started successfully (PID: ${pid})"
		echo "Dashboard will be available at: http://localhost:8080"
		return 0
	else
		log_message "ERROR" "Failed to start dashboard agent"
		echo "Error: Failed to start dashboard agent"
		rm -f "${DASHBOARD_PID_FILE}"
		return 1
	fi
}

# Stop dashboard agent
stop_dashboard() {
	if ! is_dashboard_running; then
		log_message "INFO" "Dashboard agent is not running"
		echo "Dashboard agent is not running"
		return 0
	fi

	local pid=$(cat "${DASHBOARD_PID_FILE}")
	log_message "INFO" "Stopping dashboard agent (PID: ${pid})"
	echo "Stopping dashboard agent (PID: ${pid})..."

	# Send notification to stop server
	local notification_file="$(dirname "$0")/agents/communication/UnifiedDashboard_notification.txt"
	echo "$(date +%s)|stop_server|" >>"${notification_file}"

	sleep 3

	# Force kill if still running
	if kill -0 "${pid}" 2>/dev/null; then
		kill "${pid}"
		sleep 2
		if kill -0 "${pid}" 2>/dev/null; then
			kill -9 "${pid}"
		fi
	fi

	rm -f "${DASHBOARD_PID_FILE}"
	log_message "INFO" "Dashboard agent stopped"
	echo "Dashboard agent stopped"
}

# Restart dashboard agent
restart_dashboard() {
	log_message "INFO" "Restarting dashboard agent..."
	echo "Restarting dashboard agent..."
	stop_dashboard
	sleep 2
	start_dashboard
}

# Get dashboard status
status_dashboard() {
	if is_dashboard_running; then
		local pid=$(cat "${DASHBOARD_PID_FILE}")
		echo "Dashboard agent is running (PID: ${pid})"
		echo "Dashboard URL: http://localhost:8080"
		return 0
	else
		echo "Dashboard agent is not running"
		return 1
	fi
}

# Show dashboard logs
logs_dashboard() {
	if [[ -f ${LOG_FILE} ]]; then
		echo "=== Dashboard Launcher Logs ==="
		tail -50 "${LOG_FILE}"
	else
		echo "No dashboard logs found"
	fi

	local agent_log="$(dirname "$0")/agents/unified_dashboard.log"
	if [[ -f ${agent_log} ]]; then
		echo ""
		echo "=== Dashboard Agent Logs ==="
		tail -20 "${agent_log}"
	fi
}

# Open dashboard in browser
open_dashboard() {
	if is_dashboard_running; then
		if command -v open &>/dev/null; then
			open "http://localhost:8080"
			echo "Opening dashboard in browser..."
		elif command -v xdg-open &>/dev/null; then
			xdg-open "http://localhost:8080"
			echo "Opening dashboard in browser..."
		else
			echo "Dashboard URL: http://localhost:8080"
			echo "Please open this URL in your browser"
		fi
	else
		echo "Dashboard agent is not running. Start it first with: $0 start"
	fi
}

# Show help
show_help() {
	echo "Dashboard Launcher - Manage the unified dashboard agent"
	echo ""
	echo "Usage: $0 <command>"
	echo ""
	echo "Commands:"
	echo "  start     Start the dashboard agent"
	echo "  stop      Stop the dashboard agent"
	echo "  restart   Restart the dashboard agent"
	echo "  status    Show dashboard status"
	echo "  logs      Show dashboard logs"
	echo "  open      Open dashboard in browser"
	echo "  help      Show this help message"
	echo ""
	echo "Examples:"
	echo "  $0 start    # Start the dashboard"
	echo "  $0 open     # Open dashboard in browser"
	echo "  $0 logs     # View recent logs"
}

# Main command processing
case "${1:-help}" in
"start")
	start_dashboard
	;;
"stop")
	stop_dashboard
	;;
"restart")
	restart_dashboard
	;;
"status")
	status_dashboard
	;;
"logs")
	logs_dashboard
	;;
"open")
	open_dashboard
	;;
"help" | "-h" | "--help")
	show_help
	;;
*)
	echo "Unknown command: $1"
	echo ""
	show_help
	exit 1
	;;
esac
