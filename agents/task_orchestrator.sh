#!/bin/bash
# Task Orchestrator Agent: Central coordinator for all agents with intelligent task distribution

AGENT_NAME="TaskOrchestrator"
LOG_FILE="$(dirname "$0")/task_orchestrator.log"
TASK_QUEUE_FILE="$(dirname "$0")/task_queue.json"
AGENT_STATUS_FILE="$(dirname "$0")/agent_status.json"
COMMUNICATION_DIR="$(dirname "$0")/communication"

# Agent capabilities and priorities
declare -A AGENT_CAPABILITIES
AGENT_CAPABILITIES=(
	["agent_build.sh"]="build,test,compile,xcode"
	["agent_debug.sh"]="debug,fix,diagnose,troubleshoot"
	["agent_codegen.sh"]="generate,code,create,implement"
	["uiux_agent.sh"]="ui,ux,interface,design,user_experience"
	["apple_pro_agent.sh"]="ios,swift,apple,frameworks"
	["collab_agent.sh"]="coordinate,plan,organize,collaborate"
	["updater_agent.sh"]="update,upgrade,modernize,enhance"
	["search_agent.sh"]="search,find,locate,discover"
	["pull_request_agent.sh"]="pr,pull_request,merge,review"
	["auto_update_agent.sh"]="auto_update,enhancement,best_practices"
	["knowledge_base_agent.sh"]="knowledge,learn,share,best_practices"
)

# Agent priority levels (higher number = higher priority)
declare -A AGENT_PRIORITY
AGENT_PRIORITY=(
	["agent_build.sh"]="8"
	["agent_debug.sh"]="9"
	["pull_request_agent.sh"]="7"
	["auto_update_agent.sh"]="6"
	["agent_codegen.sh"]="5"
	["uiux_agent.sh"]="4"
	["apple_pro_agent.sh"]="4"
	["collab_agent.sh"]="3"
	["updater_agent.sh"]="3"
	["search_agent.sh"]="2"
	["knowledge_base_agent.sh"]="1"
)

# Task types and their requirements
declare -A TASK_REQUIREMENTS
TASK_REQUIREMENTS=(
	["build"]="agent_build.sh"
	["test"]="agent_build.sh"
	["debug"]="agent_debug.sh"
	["fix"]="agent_debug.sh"
	["generate"]="agent_codegen.sh"
	["create"]="agent_codegen.sh"
	["ui"]="uiux_agent.sh"
	["ux"]="uiux_agent.sh"
	["ios"]="apple_pro_agent.sh"
	["swift"]="apple_pro_agent.sh"
	["coordinate"]="collab_agent.sh"
	["plan"]="collab_agent.sh"
	["update"]="updater_agent.sh"
	["search"]="search_agent.sh"
	["pr"]="pull_request_agent.sh"
	["auto_update"]="auto_update_agent.sh"
	["knowledge"]="knowledge_base_agent.sh"
)

# Initialize directories and files
mkdir -p "${COMMUNICATION_DIR}"

# Initialize task queue if it doesn't exist
if [[ ! -f ${TASK_QUEUE_FILE} ]]; then
	echo '{"tasks": [], "completed": [], "failed": []}' >"${TASK_QUEUE_FILE}"
fi

# Initialize agent status if it doesn't exist
if [[ ! -f ${AGENT_STATUS_FILE} ]]; then
	echo '{"agents": {}}' >"${AGENT_STATUS_FILE}"
fi

log_message() {
	local level="$1"
	local message="$2"
	echo "[$(date)] [${level}] ${message}" >>"${LOG_FILE}"
}

# Update agent status
update_agent_status() {
	local agent="$1"
	local status="$2"
	local last_seen=$(date +%s)

	# Read current status
	local current_status
	if [[ -f ${AGENT_STATUS_FILE} ]]; then
		current_status=$(cat "${AGENT_STATUS_FILE}")
	else
		current_status='{"agents": {}}'
	fi

	# Update agent status using jq if available, otherwise use sed
	if command -v jq &>/dev/null; then
		echo "${current_status}" | jq --arg agent "${agent}" --arg status "${status}" --arg last_seen "${last_seen}" \
			'.agents[$agent] = {"status": $status, "last_seen": $last_seen, "tasks_completed": (.agents[$agent].tasks_completed // 0)}' >"${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "${AGENT_STATUS_FILE}"
	else
		# Fallback to basic JSON manipulation
		sed -i.bak "s/\"${agent}\": {[^}]*}/\"${agent}\": {\"status\": \"${status}\", \"last_seen\": \"${last_seen}\", \"tasks_completed\": 0}/g" "${AGENT_STATUS_FILE}"
		rm -f "${AGENT_STATUS_FILE}.bak"
	fi

	log_message "INFO" "Updated status for ${agent}: ${status}"
}

# Add task to queue
add_task() {
	local task_type="$1"
	local task_description="$2"
	local priority="${3:-5}"
	local assigned_agent=""
	local task_id=$(date +%s%N | cut -b1-13)

	# Determine best agent for task
	assigned_agent=$(select_best_agent "${task_type}")

	if [[ -z ${assigned_agent} ]]; then
		log_message "WARNING" "No suitable agent found for task type: ${task_type}"
		return 1
	fi

	# Create task object
	local task="{\"id\": \"${task_id}\", \"type\": \"${task_type}\", \"description\": \"${task_description}\", \"priority\": ${priority}, \"assigned_agent\": \"${assigned_agent}\", \"status\": \"queued\", \"created\": $(date +%s), \"dependencies\": []}"

	# Add to queue using jq if available
	if command -v jq &>/dev/null; then
		jq --argjson task "${task}" '.tasks += [$task]' "${TASK_QUEUE_FILE}" >"${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "${TASK_QUEUE_FILE}"
	else
		# Fallback: append to tasks array manually
		sed -i.bak 's/"tasks": \[/&'"${task}"', /' "${TASK_QUEUE_FILE}"
		rm -f "${TASK_QUEUE_FILE}.bak"
	fi

	log_message "INFO" "Added task ${task_id} (${task_type}) assigned to ${assigned_agent}"

	# Notify assigned agent
	notify_agent "${assigned_agent}" "new_task" "${task_id}"
}

# Select best agent for task based on capabilities and current load
select_best_agent() {
	local task_type="$1"
	local best_agent=""
	local best_score=0

	# Check if task type has specific requirement
	if [[ -n ${TASK_REQUIREMENTS[${task_type}]} ]]; then
		best_agent="${TASK_REQUIREMENTS[${task_type}]}"
		if [[ -f "$(dirname "$0")/${best_agent}" ]]; then
			echo "${best_agent}"
			return 0
		fi
	fi

	# Score agents based on capabilities and priority
	for agent in "${!AGENT_CAPABILITIES[@]}"; do
		if [[ ! -f "$(dirname "$0")/${agent}" ]]; then
			continue
		fi

		local score=0
		local capabilities="${AGENT_CAPABILITIES[${agent}]}"
		local priority="${AGENT_PRIORITY[${agent}]}"

		# Check if agent has relevant capabilities
		if [[ ${capabilities} == *"${task_type}"* ]]; then
			score=$((score + 10))
		fi

		# Add priority score
		score=$((score + priority))

		# Check agent status (prefer available agents)
		local agent_status=$(get_agent_status "${agent}")
		if [[ ${agent_status} == "available" ]]; then
			score=$((score + 5))
		elif [[ ${agent_status} == "busy" ]]; then
			score=$((score - 3))
		fi

		if [[ ${score} -gt ${best_score} ]]; then
			best_score=${score}
			best_agent="${agent}"
		fi
	done

	echo "${best_agent}"
}

# Get agent status
get_agent_status() {
	local agent="$1"

	if [[ ! -f ${AGENT_STATUS_FILE} ]]; then
		echo "unknown"
		return
	fi

	if command -v jq &>/dev/null; then
		jq -r ".agents[\"${agent}\"].status // \"unknown\"" "${AGENT_STATUS_FILE}"
	else
		grep -o "\"${agent}\": {\"status\": \"[^\"]*\"" "${AGENT_STATUS_FILE}" | grep -o '"status": "[^"]*"' | cut -d'"' -f4 || echo "unknown"
	fi
}

# Notify agent of new task or status change
notify_agent() {
	local agent="$1"
	local notification_type="$2"
	local task_id="$3"

	local notification_file="${COMMUNICATION_DIR}/${agent}_notification.txt"
	local timestamp=$(date +%s)

	echo "${timestamp}|${notification_type}|${task_id}" >>"${notification_file}"

	log_message "INFO" "Notified ${agent}: ${notification_type} (${task_id})"
}

# Process completed tasks and update agent status
process_completed_tasks() {
	# Check for completed task notifications
	for notification_file in "${COMMUNICATION_DIR}"/*_completed.txt; do
		if [[ -f ${notification_file} ]]; then
			local agent_name=$(basename "${notification_file}" "_completed.txt")
			local task_info=$(tail -1 "${notification_file}")

			if [[ -n ${task_info} ]]; then
				local task_id=$(echo "${task_info}" | cut -d'|' -f2)
				local success=$(echo "${task_info}" | cut -d'|' -f3)

				update_task_status "${task_id}" "completed" "${success}"
				update_agent_status "${agent_name}" "available"

				log_message "INFO" "Task ${task_id} completed by ${agent_name} (success: ${success})"
			fi

			# Clear notification
			>"${notification_file}"
		fi
	done
}

# Update task status
update_task_status() {
	local task_id="$1"
	local status="$2"
	local success="$3"

	if command -v jq &>/dev/null; then
		# Move task from tasks to completed/failed
		if [[ ${status} == "completed" ]]; then
			jq --arg task_id "${task_id}" --arg success "${success}" \
				'(.tasks[] | select(.id == $task_id)) as $task | .tasks = (.tasks - [$task]) | .completed += [$task + {"completed_at": now, "success": $success}]' \
				"${TASK_QUEUE_FILE}" >"${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "${TASK_QUEUE_FILE}"
		fi
	fi
}

# Monitor agent health and restart if needed
monitor_agent_health() {
	local current_time=$(date +%s)

	for agent in "${!AGENT_CAPABILITIES[@]}"; do
		if [[ ! -f "$(dirname "$0")/${agent}" ]]; then
			continue
		fi

		local last_seen=$(get_agent_last_seen "${agent}")
		local time_diff=$((current_time - last_seen))

		# If agent hasn't been seen for more than 10 minutes, mark as unresponsive
		if [[ ${time_diff} -gt 600 ]]; then
			update_agent_status "${agent}" "unresponsive"
			log_message "WARNING" "Agent ${agent} is unresponsive (last seen: ${time_diff}s ago)"

			# Attempt to restart agent
			restart_agent "${agent}"
		fi
	done
}

# Get agent's last seen timestamp
get_agent_last_seen() {
	local agent="$1"

	if command -v jq &>/dev/null; then
		jq -r ".agents[\"${agent}\"].last_seen // \"0\"" "${AGENT_STATUS_FILE}"
	else
		echo "0"
	fi
}

# Restart unresponsive agent
restart_agent() {
	local agent="$1"

	log_message "INFO" "Attempting to restart ${agent}"

	# Kill existing process if running
	local pid_file="$(dirname "$0")/${agent}.pid"
	if [[ -f ${pid_file} ]]; then
		local old_pid=$(cat "${pid_file}")
		if kill -0 "${old_pid}" 2>/dev/null; then
			kill "${old_pid}"
			log_message "INFO" "Killed old process ${old_pid} for ${agent}"
		fi
		rm -f "${pid_file}"
	fi

	# Start new instance
	nohup bash "$(dirname "$0")/${agent}" >>"$(dirname "$0")/${agent}.log" 2>&1 &
	local new_pid=$!
	echo "${new_pid}" >"${pid_file}"

	update_agent_status "${agent}" "restarting"
	log_message "INFO" "Restarted ${agent} with PID ${new_pid}"
}

# Distribute tasks to available agents
distribute_tasks() {
	local available_tasks

	if command -v jq &>/dev/null; then
		available_tasks=$(jq -r '.tasks[] | select(.status == "queued") | .id' "${TASK_QUEUE_FILE}")
	else
		available_tasks=$(grep -o '"id": "[^"]*"' "${TASK_QUEUE_FILE}" | cut -d'"' -f4)
	fi

	for task_id in ${available_tasks}; do
		local task_info=$(get_task_info "${task_id}")
		local assigned_agent=$(echo "${task_info}" | cut -d'|' -f1)
		local task_type=$(echo "${task_info}" | cut -d'|' -f2)

		# Check if agent is available
		local agent_status=$(get_agent_status "${assigned_agent}")
		if [[ ${agent_status} == "available" ]]; then
			notify_agent "${assigned_agent}" "execute_task" "${task_id}"
			update_task_status "${task_id}" "assigned" ""
			log_message "INFO" "Assigned task ${task_id} to ${assigned_agent}"
		fi
	done
}

# Get task information
get_task_info() {
	local task_id="$1"

	if command -v jq &>/dev/null; then
		local task_data=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .assigned_agent + \"|\" + .type" "${TASK_QUEUE_FILE}")
		echo "${task_data}"
	else
		echo "unknown|unknown"
	fi
}

# Generate status report
generate_status_report() {
	local report_file="$(dirname "$0")/orchestrator_status_$(date +%Y%m%d_%H%M%S).md"

	{
		echo "# Task Orchestrator Status Report"
		echo "Generated: $(date)"
		echo ""

		echo "## Agent Status"
		echo "| Agent | Status | Last Seen | Tasks Completed |"
		echo "|-------|--------|-----------|-----------------|"

		for agent in "${!AGENT_CAPABILITIES[@]}"; do
			local status=$(get_agent_status "${agent}")
			local last_seen=$(get_agent_last_seen "${agent}")
			local tasks_completed="0"

			if command -v jq &>/dev/null; then
				tasks_completed=$(jq -r ".agents[\"${agent}\"].tasks_completed // \"0\"" "${AGENT_STATUS_FILE}")
			fi

			local last_seen_formatted="Never"
			if [[ ${last_seen} != "0" ]]; then
				last_seen_formatted=$(date -r "${last_seen}" 2>/dev/null || echo "Unknown")
			fi

			echo "| ${agent} | ${status} | ${last_seen_formatted} | ${tasks_completed} |"
		done

		echo ""
		echo "## Task Queue"

		if command -v jq &>/dev/null; then
			local queued_count=$(jq '.tasks | length' "${TASK_QUEUE_FILE}")
			local completed_count=$(jq '.completed | length' "${TASK_QUEUE_FILE}")
			local failed_count=$(jq '.failed | length' "${TASK_QUEUE_FILE}")

			echo "- Queued: ${queued_count}"
			echo "- Completed: ${completed_count}"
			echo "- Failed: ${failed_count}"

			if [[ ${queued_count} -gt 0 ]]; then
				echo ""
				echo "### Queued Tasks"
				echo "| Task ID | Type | Description | Assigned Agent | Priority |"
				echo "|---------|------|-------------|----------------|----------|"

				jq -r '.tasks[] | select(.status == "queued") | "\(.id)|\(.type)|\(.description)|\(.assigned_agent)|\(.priority)"' "${TASK_QUEUE_FILE}" | while IFS='|' read -r id type desc agent priority; do
					echo "| ${id} | ${type} | ${desc} | ${agent} | ${priority} |"
				done
			fi
		fi

	} >"${report_file}"

	log_message "INFO" "Status report generated: ${report_file}"
}

# Main orchestration loop
log_message "INFO" "Task Orchestrator starting..."

while true; do
	# Update orchestrator status
	update_agent_status "task_orchestrator.sh" "active"

	# Process completed tasks
	process_completed_tasks

	# Monitor agent health
	monitor_agent_health

	# Distribute queued tasks
	distribute_tasks

	# Generate periodic status report (every 5 minutes)
	local current_minute=$(date +%M)
	if [[ $((current_minute % 5)) -eq 0 ]]; then
		generate_status_report
	fi

	# Check for new tasks from external sources
	check_external_tasks

	sleep 30 # Check every 30 seconds
done
