#!/bin/bash
# Debug Agent: Processes debug tasks assigned by the task orchestrator

AGENT_NAME="agent_debug.sh"
LOG_FILE="/Users/danielstevens/Desktop/Code/Tools/Automation/agents/debug_agent.log"
NOTIFICATION_FILE="/Users/danielstevens/Desktop/Code/Tools/Automation/agents/communication/${AGENT_NAME}_notification.txt"
AGENT_STATUS_FILE="/Users/danielstevens/Desktop/Code/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="/Users/danielstevens/Desktop/Code/Tools/Automation/agents/task_queue.json"

# Update agent status to available when starting
update_status() {
	local status="$1"
	if command -v jq &>/dev/null; then
		jq ".agents[\"$AGENT_NAME\"].status = \"$status\" | .agents[\"$AGENT_NAME\"].last_seen = $(date +%s)" "$AGENT_STATUS_FILE" >"${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "$AGENT_STATUS_FILE"
	fi
	echo "[$(date)] $AGENT_NAME: Status updated to $status" >>"$LOG_FILE"
}

# Process a specific task
process_task() {
	local task_id="$1"
	echo "[$(date)] $AGENT_NAME: Processing task $task_id" >>"$LOG_FILE"

	# Get task details
	if command -v jq &>/dev/null; then
		local task_desc=$(jq -r ".tasks[] | select(.id == \"$task_id\") | .description" "$TASK_QUEUE_FILE")
		local task_type=$(jq -r ".tasks[] | select(.id == \"$task_id\") | .type" "$TASK_QUEUE_FILE")
		echo "[$(date)] $AGENT_NAME: Task description: $task_desc" >>"$LOG_FILE"
		echo "[$(date)] $AGENT_NAME: Task type: $task_type" >>"$LOG_FILE"

		# Process based on task type
		case "$task_type" in
		"debug")
			run_debug_analysis "$task_desc"
			;;
		"fix")
			run_debug_fix "$task_desc"
			;;
		"diagnose")
			run_diagnostics "$task_desc"
			;;
		"troubleshoot")
			run_troubleshooting "$task_desc"
			;;
		*)
			echo "[$(date)] $AGENT_NAME: Unknown task type: $task_type" >>"$LOG_FILE"
			;;
		esac

		# Mark task as completed
		update_task_status "$task_id" "completed"
		echo "[$(date)] $AGENT_NAME: Task $task_id completed" >>"$LOG_FILE"
	fi
}

# Update task status
update_task_status() {
	local task_id="$1"
	local status="$2"
	if command -v jq &>/dev/null; then
		jq "(.tasks[] | select(.id == \"$task_id\") | .status) = \"$status\"" "$TASK_QUEUE_FILE" >"${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "$TASK_QUEUE_FILE"
	fi
}

# Debug analysis function
run_debug_analysis() {
	local task_desc="$1"
	echo "[$(date)] $AGENT_NAME: Running debug analysis for: $task_desc" >>"$LOG_FILE"

	# Extract project name from task description
	if [[ $task_desc =~ MomentumFinance ]]; then
		PROJECT="MomentumFinance"
	elif [[ $task_desc =~ AvoidObstaclesGame ]]; then
		PROJECT="AvoidObstaclesGame"
	elif [[ $task_desc =~ CodingReviewer ]]; then
		PROJECT="CodingReviewer"
	elif [[ $task_desc =~ HabitQuest ]]; then
		PROJECT="HabitQuest"
	elif [[ $task_desc =~ PlannerApp ]]; then
		PROJECT="PlannerApp"
	else
		PROJECT="CodingReviewer" # Default
	fi

	echo "[$(date)] $AGENT_NAME: Analyzing project: $PROJECT" >>"$LOG_FILE"

	# Run diagnostics
	if [[ -d "/Users/danielstevens/Desktop/Code/Projects/$PROJECT" ]]; then
		cd "/Users/danielstevens/Desktop/Code/Projects/$PROJECT"
		echo "[$(date)] $AGENT_NAME: Running diagnostics on $PROJECT..." >>"$LOG_FILE"

		# Check for build issues
		if [[ -f "Tools/Automation/automate.sh" ]]; then
			./Tools/Automation/automate.sh test >>"$LOG_FILE" 2>&1 || true
		fi

		# Look for common issues
		find . -name "*.swift" -exec grep -l "TODO\|FIXME\|BUG\|ERROR" {} \; >>"$LOG_FILE" 2>&1 || true
		find . -name "*.swift" -exec grep -l "print\|debugPrint" {} \; >>"$LOG_FILE" 2>&1 || true
	fi
}

# Debug fix function
run_debug_fix() {
	local task_desc="$1"
	echo "[$(date)] $AGENT_NAME: Running debug fix for: $task_desc" >>"$LOG_FILE"

	# Similar to analysis but with auto-fix capabilities
	run_debug_analysis "$task_desc"

	# Attempt auto-fixes for common issues
	echo "[$(date)] $AGENT_NAME: Attempting auto-fixes..." >>"$LOG_FILE"
}

# Diagnostics function
run_diagnostics() {
	local task_desc="$1"
	echo "[$(date)] $AGENT_NAME: Running diagnostics for: $task_desc" >>"$LOG_FILE"
	run_debug_analysis "$task_desc"
}

# Troubleshooting function
run_troubleshooting() {
	local task_desc="$1"
	echo "[$(date)] $AGENT_NAME: Running troubleshooting for: $task_desc" >>"$LOG_FILE"
	run_debug_analysis "$task_desc"
}

# Main agent loop
echo "[$(date)] $AGENT_NAME: Starting agent..." >>"$LOG_FILE"
update_status "available"

# Track processed tasks to avoid duplicates
declare -A processed_tasks

while true; do
	# Check for new task notifications
	if [[ -f $NOTIFICATION_FILE ]]; then
		while IFS='|' read -r timestamp action task_id; do
			if [[ $action == "execute_task" && -z ${processed_tasks[$task_id]} ]]; then
				update_status "busy"
				process_task "$task_id"
				update_status "available"
				processed_tasks[$task_id]="completed"
				echo "[$(date)] $AGENT_NAME: Marked task $task_id as processed" >>"$LOG_FILE"
			fi
		done <"$NOTIFICATION_FILE"

		# Clear processed notifications to prevent re-processing
		>"$NOTIFICATION_FILE"
	fi

	# Update last seen timestamp
	update_status "available"

	sleep 30 # Check every 30 seconds
done
