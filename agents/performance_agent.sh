#!/bin/bash
# Performance Agent: Analyzes and optimizes code performance

AGENT_NAME="performance_agent.sh"
LOG_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/performance_agent.log"
NOTIFICATION_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/communication/${AGENT_NAME}_notification.txt"
AGENT_STATUS_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/task_queue.json"

# Update agent status to available when starting
update_status() {
	local status="$1"
	if command -v jq &>/dev/null; then
		jq ".agents[\"${AGENT_NAME}\"].status = \"${status}\" | .agents[\"${AGENT_NAME}\"].last_seen = $(date +%s)" "${AGENT_STATUS_FILE}" >"${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "${AGENT_STATUS_FILE}"
	fi
	echo "[$(date)] ${AGENT_NAME}: Status updated to ${status}" >>"${LOG_FILE}"
}

# Process a specific task
process_task() {
	local task_id="$1"
	echo "[$(date)] ${AGENT_NAME}: Processing task ${task_id}" >>"${LOG_FILE}"

	# Get task details
	if command -v jq &>/dev/null; then
		local task_desc=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .description" "${TASK_QUEUE_FILE}")
		local task_type=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .type" "${TASK_QUEUE_FILE}")
		echo "[$(date)] ${AGENT_NAME}: Task description: ${task_desc}" >>"${LOG_FILE}"
		echo "[$(date)] ${AGENT_NAME}: Task type: ${task_type}" >>"${LOG_FILE}"

		# Process based on task type
		case "${task_type}" in
		"perf" | "performance" | "optimization")
			run_performance_analysis "${task_desc}"
			;;
		*)
			echo "[$(date)] ${AGENT_NAME}: Unknown task type: ${task_type}" >>"${LOG_FILE}"
			;;
		esac

		# Mark task as completed
		update_task_status "${task_id}" "completed"
		echo "[$(date)] ${AGENT_NAME}: Task ${task_id} completed" >>"${LOG_FILE}"
	fi
}

# Update task status
update_task_status() {
	local task_id="$1"
	local status="$2"
	if command -v jq &>/dev/null; then
		jq "(.tasks[] | select(.id == \"${task_id}\") | .status) = \"${status}\"" "${TASK_QUEUE_FILE}" >"${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "${TASK_QUEUE_FILE}"
	fi
}

# Performance analysis function
run_performance_analysis() {
	local task_desc="$1"
	echo "[$(date)] ${AGENT_NAME}: Running performance analysis for: ${task_desc}" >>"${LOG_FILE}"

	# Extract project name from task description
	local projects=("CodingReviewer" "MomentumFinance" "HabitQuest" "PlannerApp" "AvoidObstaclesGame")

	for project in "${projects[@]}"; do
		if [[ -d "/Users/danielstevens/Desktop/Quantum-workspace/Projects/${project}" ]]; then
			echo "[$(date)] ${AGENT_NAME}: Analyzing performance in ${project}..." >>"${LOG_FILE}"
			cd "/Users/danielstevens/Desktop/Quantum-workspace/Projects/${project}" || continue

			# Performance metrics
			echo "[$(date)] ${AGENT_NAME}: Calculating performance metrics for ${project}..." >>"${LOG_FILE}"

			# Count Swift files
			local swift_files=$(find . -name "*.swift" | wc -l)
			echo "[$(date)] ${AGENT_NAME}: Total Swift files: ${swift_files}" >>"${LOG_FILE}"

			# Analyze performance issues
			echo "[$(date)] ${AGENT_NAME}: Analyzing performance bottlenecks..." >>"${LOG_FILE}"

			# Check for performance anti-patterns
			local force_casts=$(find . -name "*.swift" -exec grep -l "as!" {} \; | wc -l)
			local array_operations=$(find . -name "*.swift" -exec grep -l "append\|insert\|remove" {} \; | wc -l)
			local string_concat=$(find . -name "*.swift" -exec grep -l "+=" {} \; | wc -l)
			local nested_loops=$(find . -name "*.swift" -exec grep -A 5 -B 5 "for.*in" {} \; | grep -c "for.*in")
			local large_objects=$(find . -name "*.swift" -exec grep -l "class.*{" {} \; | xargs grep -l "var.*:.*Array\|var.*:.*Dictionary" | wc -l)

			echo "[$(date)] ${AGENT_NAME}: Force casts found in ${force_casts} files" >>"${LOG_FILE}"
			echo "[$(date)] ${AGENT_NAME}: Array operations found in ${array_operations} files" >>"${LOG_FILE}"
			echo "[$(date)] ${AGENT_NAME}: String concatenation found in ${string_concat} files" >>"${LOG_FILE}"
			echo "[$(date)] ${AGENT_NAME}: Nested loops found in ${nested_loops} files" >>"${LOG_FILE}"
			echo "[$(date)] ${AGENT_NAME}: Large objects found in ${large_objects} files" >>"${LOG_FILE}"

			# Check for memory management issues
			local retain_cycles=$(find . -name "*.swift" -exec grep -l "\[weak self\]\|\[unowned self\]" {} \; | wc -l)
			local strong_refs=$(find . -name "*.swift" -exec grep -l "self\." {} \; | wc -l)
			local memory_issues=$((strong_refs - retain_cycles))

			echo "[$(date)] ${AGENT_NAME}: Potential retain cycles: ${memory_issues}" >>"${LOG_FILE}"

			# Check for async/await usage
			local async_funcs=$(find . -name "*.swift" -exec grep -l "async func" {} \; | wc -l)
			local await_calls=$(find . -name "*.swift" -exec grep -l "await" {} \; | wc -l)

			echo "[$(date)] ${AGENT_NAME}: Async functions: ${async_funcs}" >>"${LOG_FILE}"
			echo "[$(date)] ${AGENT_NAME}: Await calls: ${await_calls}" >>"${LOG_FILE}"

			# Calculate performance score (simple heuristic)
			local perf_score=$((100 - (force_casts * 5) - (string_concat * 3) - (nested_loops * 2) - (memory_issues * 4)))
			if [[ ${perf_score} -lt 0 ]]; then
				perf_score=0
			fi

			echo "[$(date)] ${AGENT_NAME}: Performance score for ${project}: ${perf_score}%" >>"${LOG_FILE}"

			# Generate performance recommendations
			echo "[$(date)] ${AGENT_NAME}: Generating performance recommendations..." >>"${LOG_FILE}"

			if [[ ${force_casts} -gt 0 ]]; then
				echo "[$(date)] ${AGENT_NAME}: Recommendation: Replace force casts with safe optional casting" >>"${LOG_FILE}"
			fi

			if [[ ${string_concat} -gt 0 ]]; then
				echo "[$(date)] ${AGENT_NAME}: Recommendation: Use StringBuilder or array joining for string concatenation" >>"${LOG_FILE}"
			fi

			if [[ ${nested_loops} -gt 0 ]]; then
				echo "[$(date)] ${AGENT_NAME}: Recommendation: Review nested loops for optimization opportunities" >>"${LOG_FILE}"
			fi

			if [[ ${memory_issues} -gt 0 ]]; then
				echo "[$(date)] ${AGENT_NAME}: Recommendation: Use weak/unowned references to prevent retain cycles" >>"${LOG_FILE}"
			fi

			if [[ ${async_funcs} -eq 0 ]]; then
				echo "[$(date)] ${AGENT_NAME}: Recommendation: Consider using async/await for I/O operations" >>"${LOG_FILE}"
			fi

			if [[ ${array_operations} -gt 0 ]]; then
				echo "[$(date)] ${AGENT_NAME}: Recommendation: Review array operations for potential optimizations" >>"${LOG_FILE}"
			fi
		fi
	done

	echo "[$(date)] ${AGENT_NAME}: Performance analysis completed" >>"${LOG_FILE}"
}

# Main agent loop
echo "[$(date)] ${AGENT_NAME}: Starting performance agent..." >>"${LOG_FILE}"
update_status "available"

# Track processed tasks to avoid duplicates
declare -A processed_tasks

while true; do
	# Check for new task notifications
	if [[ -f ${NOTIFICATION_FILE} ]]; then
		while IFS='|' read -r timestamp action task_id; do
			if [[ ${action} == "execute_task" && -z ${processed_tasks[${task_id}]} ]]; then
				update_status "busy"
				process_task "${task_id}"
				update_status "available"
				processed_tasks[${task_id}]="completed"
				echo "[$(date)] ${AGENT_NAME}: Marked task ${task_id} as processed" >>"${LOG_FILE}"
			fi
		done <"${NOTIFICATION_FILE}"

		# Clear processed notifications to prevent re-processing
		>"${NOTIFICATION_FILE}"
	fi

	# Update last seen timestamp
	update_status "available"

	sleep 30 # Check every 30 seconds
done
