#!/usr/bin/env bash
# Enhanced Agent Supervisor: Coordinates all agents with orchestrator integration

AGENTS_DIR="/Users/danielstevens/Desktop/Code/Tools/Automation/agents"
LOG_FILE="$AGENTS_DIR/supervisor.log"
ORCHESTRATOR_LOG="$AGENTS_DIR/task_orchestrator.log"
COMMUNICATION_DIR="$AGENTS_DIR/communication"

# Enhanced agent list with new specialized agents
declare -A AGENT_PIDS
declare -A AGENT_LOGS
AGENT_LOGS=(
	["agent_build.sh"]="$AGENTS_DIR/build_agent.log"
	["agent_debug.sh"]="$AGENTS_DIR/debug_agent.log"
	["agent_codegen.sh"]="$AGENTS_DIR/codegen_agent.log"
	["uiux_agent.sh"]="$AGENTS_DIR/uiux_agent.log"
	["apple_pro_agent.sh"]="$AGENTS_DIR/apple_pro_agent.log"
	["collab_agent.sh"]="$AGENTS_DIR/collab_agent.log"
	["updater_agent.sh"]="$AGENTS_DIR/updater_agent.log"
	["search_agent.sh"]="$AGENTS_DIR/search_agent.log"
	["task_orchestrator.sh"]="$AGENTS_DIR/task_orchestrator.log"
	["pull_request_agent.sh"]="$AGENTS_DIR/pull_request_agent.log"
	["auto_update_agent.sh"]="$AGENTS_DIR/auto_update_agent.log"
	["knowledge_base_agent.sh"]="$AGENTS_DIR/knowledge_base_agent.log"
)

# Agent health monitoring
declare -A AGENT_HEALTH
declare -A AGENT_LAST_SEEN
declare -A AGENT_RESTART_COUNT

# Communication channels
ORCHESTRATOR_NOTIFICATION="$COMMUNICATION_DIR/task_orchestrator_notification.txt"
SUPERVISOR_STATUS_FILE="$AGENTS_DIR/supervisor_status.json"

# Restart throttling
RESTART_LIMIT=5
RESTART_WINDOW=600  # 10 minutes
RESTART_THROTTLE=60 # 1 minute between restarts

# Initialize directories
mkdir -p "$COMMUNICATION_DIR"

# Initialize supervisor status
if [[ ! -f $SUPERVISOR_STATUS_FILE ]]; then
	echo '{"status": "starting", "agents": {}, "last_health_check": 0, "system_health": "unknown"}' >"$SUPERVISOR_STATUS_FILE"
fi

log_message() {
	local level="$1"
	local message="$2"
	echo "[$(date)] [$level] $message" >>"$LOG_FILE"
}

# Enhanced log rotation with compression
rotate_log() {
	local log_file="$1"
	local max_size=10485760 # 10MB

	if [[ -f $log_file ]]; then
		local size=$(stat -f%z "$log_file" 2>/dev/null || stat -c%s "$log_file" 2>/dev/null || echo "0")
		if ((size > max_size)); then
			# Compress old log
			gzip -c "$log_file" >"${log_file}.old.gz"
			echo "[$(date)] Log rotated and compressed: $log_file" >"$log_file"
			log_message "INFO" "Rotated log: $log_file (was ${size} bytes)"
		fi
	fi
}

# Start agent with enhanced monitoring
start_agent() {
	local agent_script="$1"
	local agent_name=$(basename "$agent_script" .sh)

	# Check if agent is already running
	if [[ -n ${AGENT_PIDS[$agent_script]} ]]; then
		local old_pid=${AGENT_PIDS[$agent_script]}
		if kill -0 "$old_pid" 2>/dev/null; then
			log_message "WARNING" "$agent_script already running with PID $old_pid"
			return
		fi
	fi

	# Start agent
	nohup bash "$AGENTS_DIR/$agent_script" >>"${AGENT_LOGS[$agent_script]}" 2>&1 &
	local new_pid=$!
	AGENT_PIDS[$agent_script]=$new_pid
	AGENT_HEALTH[$agent_script]="healthy"
	AGENT_LAST_SEEN[$agent_script]=$(date +%s)
	AGENT_RESTART_COUNT[$agent_script]=0

	# Create PID file
	echo $new_pid >"$AGENTS_DIR/${agent_name}.pid"

	log_message "INFO" "Started $agent_script with PID $new_pid"

	# Notify orchestrator
	notify_orchestrator "agent_started" "$agent_name"
}

# Enhanced restart with circuit breaker
restart_agent() {
	local agent_script="$1"
	local agent_name=$(basename "$agent_script" .sh)
	local current_time=$(date +%s)

	# Circuit breaker logic
	local last_restart=${AGENT_LAST_SEEN[$agent_script]:-0}
	local restart_count=${AGENT_RESTART_COUNT[$agent_script]:-0}

	# Check restart throttling
	if ((current_time - last_restart < RESTART_THROTTLE)); then
		log_message "WARNING" "Throttling restart of $agent_script (too soon)"
		return
	fi

	# Check restart limit
	if ((restart_count >= RESTART_LIMIT)); then
		if ((current_time - last_restart < RESTART_WINDOW)); then
			log_message "ERROR" "Restart limit reached for $agent_script. Manual intervention required."
			AGENT_HEALTH[$agent_script]="critical"
			notify_orchestrator "agent_critical" "$agent_name"
			return
		else
			AGENT_RESTART_COUNT[$agent_script]=0
		fi
	fi

	# Kill existing process
	local pid=${AGENT_PIDS[$agent_script]}
	if [[ -n $pid ]]; then
		kill "$pid" 2>/dev/null
		log_message "INFO" "Killed $agent_script (PID $pid) for restart"
	fi

	# Clean up PID file
	rm -f "$AGENTS_DIR/${agent_name}.pid"

	# Start new instance
	start_agent "$agent_script"
	AGENT_RESTART_COUNT[$agent_script]=$((restart_count + 1))

	log_message "INFO" "Restarted $agent_script (attempt ${AGENT_RESTART_COUNT[$agent_script]}/$RESTART_LIMIT)"
}

# Monitor agent health with enhanced checks
monitor_agent_health() {
	local current_time=$(date +%s)
	local unhealthy_count=0

	for agent_script in "${!AGENT_LOGS[@]}"; do
		local log_file="${AGENT_LOGS[$agent_script]}"
		local agent_name=$(basename "$agent_script" .sh)

		# Rotate logs
		rotate_log "$log_file"

		# Check if agent is still running
		local pid_file="$AGENTS_DIR/${agent_name}.pid"
		if [[ -f $pid_file ]]; then
			local expected_pid=$(cat "$pid_file")
			if ! kill -0 "$expected_pid" 2>/dev/null; then
				log_message "WARNING" "$agent_script process $expected_pid not found"
				AGENT_HEALTH[$agent_script]="crashed"
				restart_agent "$agent_script"
				((unhealthy_count++))
				continue
			fi
		fi

		# Analyze log for health indicators
		if [[ -f $log_file ]]; then
			local recent_lines=$(tail -20 "$log_file" 2>/dev/null)

			# Check for critical errors
			if echo "$recent_lines" | grep -qi "critical\|fatal\|panic"; then
				log_message "ERROR" "Critical error detected in $agent_script"
				AGENT_HEALTH[$agent_script]="critical"
				restart_agent "$agent_script"
				((unhealthy_count++))
				continue
			fi

			# Check for repeated errors
			local error_count=$(echo "$recent_lines" | grep -ci "error\|failed\|exception")
			if [[ $error_count -gt 5 ]]; then
				log_message "WARNING" "High error rate in $agent_script ($error_count errors in recent logs)"
				AGENT_HEALTH[$agent_script]="degraded"
				((unhealthy_count++))
			else
				AGENT_HEALTH[$agent_script]="healthy"
			fi

			# Update last seen
			AGENT_LAST_SEEN[$agent_script]=$current_time
		fi
	done

	# Update system health status
	if [[ $unhealthy_count -eq 0 ]]; then
		update_system_health "healthy"
	elif [[ $unhealthy_count -lt 3 ]]; then
		update_system_health "degraded"
	else
		update_system_health "critical"
	fi

	return $unhealthy_count
}

# Update system health status
update_system_health() {
	local health_status="$1"

	if command -v jq &>/dev/null; then
		jq --arg status "$health_status" --arg timestamp "$(date +%s)" \
			'.system_health = $status | .last_health_check = ($timestamp | tonumber)' \
			"$SUPERVISOR_STATUS_FILE" >"$SUPERVISOR_STATUS_FILE.tmp" && mv "$SUPERVISOR_STATUS_FILE.tmp" "$SUPERVISOR_STATUS_FILE"
	fi
}

# Notify orchestrator of events
notify_orchestrator() {
	local event_type="$1"
	local agent_name="$2"
	local timestamp=$(date +%s)

	if [[ -f $ORCHESTRATOR_NOTIFICATION ]]; then
		echo "$timestamp|$event_type|$agent_name" >>"$ORCHESTRATOR_NOTIFICATION"
		log_message "INFO" "Notified orchestrator: $event_type for $agent_name"
	fi
}

# Enhanced inter-agent communication
facilitate_agent_communication() {
	# Check for agent-to-agent messages
	for comm_file in "$COMMUNICATION_DIR"/*_message.txt; do
		if [[ -f $comm_file ]]; then
			local sender=$(basename "$comm_file" "_message.txt")
			local message=$(cat "$comm_file")

			if [[ -n $message ]]; then
				log_message "INFO" "Inter-agent message from $sender: $message"

				# Route message to appropriate agent
				route_message "$sender" "$message"

				# Clear message
				>"$comm_file"
			fi
		fi
	done
}

# Route messages between agents
route_message() {
	local sender="$1"
	local message="$2"

	# Parse message type and recipient
	local msg_type=$(echo "$message" | cut -d'|' -f1)
	local recipient=$(echo "$message" | cut -d'|' -f2)
	local content=$(echo "$message" | cut -d'|' -f3-)

	case "$recipient" in
	"orchestrator")
		notify_orchestrator "$msg_type" "$sender"
		;;
	"all_agents")
		broadcast_to_agents "$msg_type" "$content"
		;;
	*)
		# Direct message to specific agent
		local recipient_notification="$COMMUNICATION_DIR/${recipient}_notification.txt"
		if [[ -f $recipient_notification ]]; then
			echo "$(date +%s)|$msg_type|$content" >>"$recipient_notification"
			log_message "INFO" "Routed message from $sender to $recipient"
		fi
		;;
	esac
}

# Broadcast message to all agents
broadcast_to_agents() {
	local msg_type="$1"
	local content="$2"
	local timestamp=$(date +%s)

	for agent_script in "${!AGENT_LOGS[@]}"; do
		local agent_name=$(basename "$agent_script" .sh)
		local notification_file="$COMMUNICATION_DIR/${agent_name}_notification.txt"

		if [[ -f $notification_file ]]; then
			echo "$timestamp|$msg_type|$content" >>"$notification_file"
		fi
	done

	log_message "INFO" "Broadcasted $msg_type to all agents"
}

# Generate comprehensive health report
generate_health_report() {
	local report_file="$AGENTS_DIR/health_reports/health_report_$(date +%Y%m%d_%H%M%S).md"
	mkdir -p "$(dirname "$report_file")"

	{
		echo "# Agent Health Report"
		echo "Generated: $(date)"
		echo ""

		echo "## System Overview"
		if [[ -f $SUPERVISOR_STATUS_FILE ]] && command -v jq &>/dev/null; then
			local system_health=$(jq -r '.system_health' "$SUPERVISOR_STATUS_FILE")
			local last_check=$(jq -r '.last_health_check' "$SUPERVISOR_STATUS_FILE")
			echo "- **System Health**: $system_health"
			echo "- **Last Health Check**: $(date -r "$last_check" 2>/dev/null || echo "Unknown")"
		fi
		echo ""

		echo "## Agent Status"
		echo "| Agent | Status | PID | Restarts | Last Seen |"
		echo "|-------|--------|-----|----------|-----------|"

		for agent_script in "${!AGENT_LOGS[@]}"; do
			local agent_name=$(basename "$agent_script" .sh)
			local status=${AGENT_HEALTH[$agent_script]:-"unknown"}
			local pid=${AGENT_PIDS[$agent_script]:-"N/A"}
			local restarts=${AGENT_RESTART_COUNT[$agent_script]:-0}
			local last_seen=${AGENT_LAST_SEEN[$agent_script]:-0}

			local last_seen_formatted="Never"
			if [[ $last_seen != "0" ]]; then
				last_seen_formatted=$(date -r "$last_seen" 2>/dev/null || echo "Unknown")
			fi

			echo "| $agent_name | $status | $pid | $restarts | $last_seen_formatted |"
		done
		echo ""

		echo "## Recent Activity"
		echo "### Supervisor Logs (Last 10 entries)"
		tail -10 "$LOG_FILE" | while read -r line; do
			echo "- $line"
		done
		echo ""

		echo "### Orchestrator Activity"
		if [[ -f $ORCHESTRATOR_LOG ]]; then
			tail -5 "$ORCHESTRATOR_LOG" | while read -r line; do
				echo "- $line"
			done
		fi

	} >"$report_file"

	log_message "INFO" "Health report generated: $report_file"
}

# Emergency shutdown procedure
emergency_shutdown() {
	local reason="$1"
	log_message "CRITICAL" "Emergency shutdown initiated: $reason"

	# Notify all agents of shutdown
	broadcast_to_agents "emergency_shutdown" "System shutting down: $reason"

	# Gracefully stop all agents
	for agent_script in "${!AGENT_PIDS[@]}"; do
		local pid=${AGENT_PIDS[$agent_script]}
		if [[ -n $pid ]] && kill -0 "$pid" 2>/dev/null; then
			log_message "INFO" "Stopping $agent_script (PID $pid)"
			kill "$pid" 2>/dev/null
			wait "$pid" 2>/dev/null
		fi
	done

	# Final status update
	update_system_health "shutdown"
	log_message "CRITICAL" "Emergency shutdown complete"
	exit 1
}

# Main supervisor loop with enhanced monitoring
log_message "INFO" "Enhanced Agent Supervisor starting..."

# Trap signals for graceful shutdown
trap 'emergency_shutdown "Signal received"' INT TERM

# Start all agents
log_message "INFO" "Starting all agents..."
for agent_script in "${!AGENT_LOGS[@]}"; do
	if [[ -f "$AGENTS_DIR/$agent_script" ]]; then
		start_agent "$agent_script"
	else
		log_message "WARNING" "Agent script not found: $agent_script"
	fi
done

# Main monitoring loop
while true; do
	# Monitor agent health
	monitor_agent_health
	local unhealthy_count=$?

	# Facilitate inter-agent communication
	facilitate_agent_communication

	# Generate periodic health report (every 15 minutes)
	local current_minute=$(date +%M)
	if [[ $((current_minute % 15)) -eq 0 ]]; then
		generate_health_report
	fi

	# Emergency check - if too many agents are unhealthy
	if [[ $unhealthy_count -gt 3 ]]; then
		emergency_shutdown "Too many unhealthy agents ($unhealthy_count)"
	fi

	# Rotate supervisor log
	rotate_log "$LOG_FILE"

	sleep 60 # Check every minute
done
