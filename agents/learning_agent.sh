#!/bin/bash
# Learning Agent: Analyzes code patterns and learns from best practices across projects

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="learning_agent.sh"
LOG_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/learning_agent.log"
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
    local task_desc
    task_desc=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .description" "${TASK_QUEUE_FILE}")
    local task_type
    task_type=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .type" "${TASK_QUEUE_FILE}")
    echo "[$(date)] ${AGENT_NAME}: Task description: ${task_desc}" >>"${LOG_FILE}"
    echo "[$(date)] ${AGENT_NAME}: Task type: ${task_type}" >>"${LOG_FILE}"

    # Process based on task type
    case "${task_type}" in
    "learn" | "analyze" | "pattern")
      run_pattern_analysis "${task_desc}"
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

# Pattern analysis function
run_pattern_analysis() {
  local task_desc="$1"
  echo "[$(date)] ${AGENT_NAME}: Running pattern analysis for: ${task_desc}" >>"${LOG_FILE}"

  # Extract project name from task description
  local projects=("CodingReviewer" "MomentumFinance" "HabitQuest" "PlannerApp" "AvoidObstaclesGame")

  for project in "${projects[@]}"; do
    if [[ -d "/Users/danielstevens/Desktop/Code/Projects/${project}" ]]; then
      echo "[$(date)] ${AGENT_NAME}: Analyzing patterns in ${project}..." >>"${LOG_FILE}"
      cd "/Users/danielstevens/Desktop/Quantum-workspace/Projects/${project}" || continue

      # Analyze code patterns
      echo "[$(date)] ${AGENT_NAME}: Finding common patterns in ${project}..." >>"${LOG_FILE}"

      # Look for good patterns
      find . -name "*.swift" -exec grep -l "guard let\|if let\|switch" {} \; >>"${LOG_FILE}" 2>&1 || true
      find . -name "*.swift" -exec grep -l "protocol\|extension\|struct\|enum" {} \; >>"${LOG_FILE}" 2>&1 || true

      # Look for improvement opportunities
      find . -name "*.swift" -exec grep -l "TODO\|FIXME\|print\|debugPrint" {} \; >>"${LOG_FILE}" 2>&1 || true
      find . -name "*.swift" -exec grep -l "force unwrap\|!\|try!" {} \; >>"${LOG_FILE}" 2>&1 || true

      # Analyze code complexity
      find . -name "*.swift" -exec wc -l {} \; | sort -nr | head -10 >>"${LOG_FILE}" 2>&1 || true
    fi
  done

  echo "[$(date)] ${AGENT_NAME}: Pattern analysis completed" >>"${LOG_FILE}"
}

# Main agent loop
echo "[$(date)] ${AGENT_NAME}: Starting learning agent..." >>"${LOG_FILE}"
update_status "available"

# Track processed tasks to avoid duplicates
declare -A processed_tasks

while true; do
  # Check for new task notifications
  if [[ -f ${NOTIFICATION_FILE} ]]; then
    while IFS='|' read -r _ action task_id; do
      if [[ ${action} == "execute_task" && -z ${processed_tasks[${task_id}]} ]]; then
        update_status "busy"
        process_task "${task_id}"
        update_status "available"
        processed_tasks[${task_id}]="completed"
        echo "[$(date)] ${AGENT_NAME}: Marked task ${task_id} as processed" >>"${LOG_FILE}"
      fi
    done <"${NOTIFICATION_FILE}"

    # Clear processed notifications to prevent re-processing
    : >"${NOTIFICATION_FILE}"
  fi

  # Update last seen timestamp
  update_status "available"

  sleep 30 # Check every 30 seconds
done
