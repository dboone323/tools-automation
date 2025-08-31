#!/bin/bash
# CodeGen Agent: Generates code and creates automated tests

AGENT_NAME="agent_codegen.sh"
LOG_FILE="/Users/danielstevens/Desktop/Code/Tools/Automation/agents/codegen_agent.log"
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
		"generate" | "create" | "code")
			run_codegen "$task_desc"
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

# Code generation function
run_codegen() {
	local task_desc="$1"
	echo "[$(date)] $AGENT_NAME: Running code generation for: $task_desc" >>"$LOG_FILE"

	# Extract project name from task description
	if [[ $task_desc =~ CodingReviewer ]]; then
		PROJECT="CodingReviewer"
	elif [[ $task_desc =~ MomentumFinance ]]; then
		PROJECT="MomentumFinance"
	elif [[ $task_desc =~ HabitQuest ]]; then
		PROJECT="HabitQuest"
	elif [[ $task_desc =~ PlannerApp ]]; then
		PROJECT="PlannerApp"
	elif [[ $task_desc =~ AvoidObstaclesGame ]]; then
		PROJECT="AvoidObstaclesGame"
	else
		PROJECT="CodingReviewer" # Default
	fi

	echo "[$(date)] $AGENT_NAME: Generating code for project: $PROJECT" >>"$LOG_FILE"

	# Run code generation
	if [[ -d "/Users/danielstevens/Desktop/Code/Projects/$PROJECT" ]]; then
		cd "/Users/danielstevens/Desktop/Code/Projects/$PROJECT"
		echo "[$(date)] $AGENT_NAME: Running codegen on $PROJECT..." >>"$LOG_FILE"

		# Create backup before codegen
		echo "[$(date)] $AGENT_NAME: Creating backup before codegen..." >>"$LOG_FILE"
		/Users/danielstevens/Desktop/Code/Tools/Automation/agents/backup_manager.sh backup "$PROJECT" >>"$LOG_FILE" 2>&1 || true

		# Run AI enhancement analysis
		echo "[$(date)] $AGENT_NAME: Running AI enhancement analysis..." >>"$LOG_FILE"
		/Users/danielstevens/Desktop/Code/Projects/CodingReviewer/Tools/Automation/ai_enhancement_system.sh analyze "$PROJECT" >>"$LOG_FILE" 2>&1 || true

		# Auto-apply safe enhancements
		echo "[$(date)] $AGENT_NAME: Auto-applying safe AI enhancements..." >>"$LOG_FILE"
		/Users/danielstevens/Desktop/Code/Projects/CodingReviewer/Tools/Automation/ai_enhancement_system.sh auto-apply "$PROJECT" >>"$LOG_FILE" 2>&1 || true

		# Validate changes
		echo "[$(date)] $AGENT_NAME: Validating codegen and enhancements..." >>"$LOG_FILE"
		/Users/danielstevens/Desktop/Code/Tools/Automation/intelligent_autofix.sh validate "$PROJECT" >>"$LOG_FILE" 2>&1 || true

		# Run tests
		echo "[$(date)] $AGENT_NAME: Running automated tests after codegen..." >>"$LOG_FILE"
		/Users/danielstevens/Desktop/Code/Projects/CodingReviewer/Tools/Automation/automate.sh test >>"$LOG_FILE" 2>&1 || true
	fi
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
