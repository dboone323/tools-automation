#!/bin/bash
# Search Agent: Finds and analyzes information from codebase

AGENT_NAME="search_agent.sh"
LOG_FILE="/Users/danielstevens/Desktop/Code/Tools/Automation/agents/search_agent.log"
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
		"search" | "find" | "locate" | "discover")
			run_search "$task_desc"
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

# Search function
run_search() {
	local task_desc="$1"
	echo "[$(date)] $AGENT_NAME: Running search for: $task_desc" >>"$LOG_FILE"

	# Extract search terms from task description
	local search_terms=""
	if [[ $task_desc =~ deprecated ]]; then
		search_terms="deprecated|DEPRECATED|obsolete|OBSOLETE"
	elif [[ $task_desc =~ API ]]; then
		search_terms="API|api|framework|Framework"
	elif [[ $task_desc =~ TODO|FIXME|BUG ]]; then
		search_terms="TODO|FIXME|BUG|HACK"
	else
		# Extract potential search terms
		search_terms=$(echo "$task_desc" | grep -oE '\b\w+\b' | head -5 | tr '\n' '|')
		search_terms=${search_terms%|} # Remove trailing |
	fi

	echo "[$(date)] $AGENT_NAME: Searching for terms: $search_terms" >>"$LOG_FILE"

	# Search across all projects
	local projects=("CodingReviewer" "MomentumFinance" "HabitQuest" "PlannerApp" "AvoidObstaclesGame")

	for project in "${projects[@]}"; do
		if [[ -d "/Users/danielstevens/Desktop/Code/Projects/$project" ]]; then
			echo "[$(date)] $AGENT_NAME: Searching in $project..." >>"$LOG_FILE"
			cd "/Users/danielstevens/Desktop/Code/Projects/$project"

			# Search for terms in Swift files
			if [[ -n $search_terms ]]; then
				find . -name "*.swift" -exec grep -l "$search_terms" {} \; >>"$LOG_FILE" 2>&1 || true
			fi

			# Look for common issues
			find . -name "*.swift" -exec grep -l "TODO\|FIXME\|BUG\|ERROR\|WARNING" {} \; >>"$LOG_FILE" 2>&1 || true

			# Search for deprecated API usage
			find . -name "*.swift" -exec grep -l "UIWebView\|NSURLConnection\|deprecated" {} \; >>"$LOG_FILE" 2>&1 || true
		fi
	done

	echo "[$(date)] $AGENT_NAME: Search completed" >>"$LOG_FILE"
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
