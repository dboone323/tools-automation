#!/bin/bash
# UI/UX Agent: Analyzes and suggests improvements for user interface and experience

AGENT_NAME="uiux_agent.sh"
WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
LOG_FILE="${WORKSPACE}/Tools/Automation/agents/uiux_agent.log"
NOTIFICATION_FILE="${WORKSPACE}/Tools/Automation/agents/communication/${AGENT_NAME}_notification.txt"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/Tools/Automation/agents/task_queue.json"

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
		"ui" | "ux" | "interface" | "design" | "user_experience")
			run_uiux_analysis "$task_desc"
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

# UI/UX analysis function with Ollama integration
run_uiux_analysis() {
	local task_desc="$1"
	echo "[$(date)] $AGENT_NAME: Running UI/UX analysis for: $task_desc" >>"$LOG_FILE"

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

	echo "[$(date)] $AGENT_NAME: Analyzing project: $PROJECT" >>"$LOG_FILE"

	# Run Ollama-powered UI/UX analysis
	run_ollama_uiux_analysis "$task_desc" "$PROJECT"

	# Run traditional file-based analysis as backup
	run_traditional_uiux_analysis "$PROJECT"
}

# Ollama-powered UI/UX analysis
run_ollama_uiux_analysis() {
	local task_desc="$1"
	local project="$2"

	echo "[$(date)] $AGENT_NAME: Running Ollama-powered UI/UX analysis..." >>"$LOG_FILE"

	# Check if Ollama is available
	if ! curl -s -m 5 http://localhost:11434/api/tags >/dev/null 2>&1; then
		echo "[$(date)] $AGENT_NAME: Ollama not available, skipping AI analysis" >>"$LOG_FILE"
		return 1
	fi

	# Collect UI-related code for analysis
	local ui_code=""
	if [[ -d "${WORKSPACE}/Projects/$project" ]]; then
		cd "${WORKSPACE}/Projects/$project" || return 1

		# Find SwiftUI and UI-related files
		while IFS= read -r -d '' file; do
			if [[ -f $file ]]; then
				ui_code+="// File: $file\n$(cat "$file")\n\n"
			fi
		done < <(find . -name "*.swift" -exec grep -l "SwiftUI\|UIKit\|View\|Controller\|Storyboard" {} \; -print0 2>/dev/null)
	fi

	if [[ -z $ui_code ]]; then
		echo "[$(date)] $AGENT_NAME: No UI code found for Ollama analysis" >>"$LOG_FILE"
		return 1
	fi

	# Create analysis prompt for Ollama
	local analysis_prompt="Analyze this Swift UI/UX code and provide suggestions for improvement:

${ui_code}

Please provide:
1. UI/UX issues found
2. Accessibility improvements needed
3. Design pattern recommendations
4. Performance optimization suggestions
5. Best practices compliance

Focus on SwiftUI and iOS development best practices."

	# Call Ollama API
	local ollama_response
	ollama_response=$(curl -s -X POST http://localhost:11434/api/generate \
		-H "Content-Type: application/json" \
		-d "{\"model\": \"llama2\", \"prompt\": \"$analysis_prompt\", \"stream\": false}" 2>/dev/null)

	if [[ $? -eq 0 && -n $ollama_response ]]; then
		local analysis_result
		analysis_result=$(echo "$ollama_response" | jq -r '.response' 2>/dev/null || echo "$ollama_response")

		# Save Ollama analysis results
		local timestamp
		timestamp=$(date +%Y%m%d_%H%M%S)
		mkdir -p "${WORKSPACE}/Tools/Automation/results"
		local result_file="${WORKSPACE}/Tools/Automation/results/UIUX_Analysis_${project}_${timestamp}.txt"

		{
			echo "Ollama-Powered UI/UX Analysis for: $task_desc"
			echo "Project: $project"
			echo "Analysis Type: AI-Powered UI/UX Review"
			echo "Timestamp: $(date)"
			echo "========================================"
			echo ""
			echo "AI Analysis Results:"
			echo "$analysis_result"
			echo ""
			echo "========================================"
		} >"$result_file"

		echo "[$(date)] $AGENT_NAME: Ollama UI/UX analysis saved to $result_file" >>"$LOG_FILE"
	else
		echo "[$(date)] $AGENT_NAME: Failed to get Ollama analysis" >>"$LOG_FILE"
	fi
}

# Traditional file-based UI/UX analysis
run_traditional_uiux_analysis() {
	local project="$1"

	# Run UI/UX analysis
	if [[ -d "${WORKSPACE}/Projects/$project" ]]; then
		cd "${WORKSPACE}/Projects/$project" || {
			echo "[$(date)] $AGENT_NAME: ERROR - Could not cd to ${WORKSPACE}/Projects/$project" >>"$LOG_FILE"
			return 1
		}
		echo "[$(date)] $AGENT_NAME: Running traditional UI/UX analysis on $project..." >>"$LOG_FILE"

		# Analyze SwiftUI and interface files
		find . -name "*.swift" -exec grep -l "SwiftUI\|UIKit\|View\|Controller" {} \; >>"$LOG_FILE" 2>&1 || true

		# Look for accessibility issues
		find . -name "*.swift" -exec grep -l "accessibilityLabel\|accessibilityHint\|accessibilityIdentifier" {} \; >>"$LOG_FILE" 2>&1 || true

		# Check for UI best practices
		find . -name "*.swift" -exec grep -l "TODO.*UI\|FIXME.*UX\|Color\|Font\|Image" {} \; >>"$LOG_FILE" 2>&1 || true
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
		while IFS='|' read -r _timestamp action task_id; do
			if [[ $action == "execute_task" && -z ${processed_tasks[$task_id]} ]]; then
				update_status "busy"
				process_task "$task_id"
				update_status "available"
				processed_tasks[$task_id]="completed"
				echo "[$(date)] $AGENT_NAME: Marked task $task_id as processed" >>"$LOG_FILE"
			fi
		done <"$NOTIFICATION_FILE"

		# Clear processed notifications to prevent re-processing
		true >"$NOTIFICATION_FILE"
	fi

	# Update last seen timestamp
	update_status "available"

	sleep 30 # Check every 30 seconds
done
