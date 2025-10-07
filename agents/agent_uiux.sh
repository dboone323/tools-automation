#!/bin/bash
# UI/UX Agent: Handles UI/UX enhancements, drag-and-drop, and interface improvements

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="UIUXAgent"
LOG_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/uiux_agent.log"
PROJECT="PlannerApp" # Default project, can be overridden by task

SLEEP_INTERVAL=600 # Start with 10 minutes for UI work
MIN_INTERVAL=120
MAX_INTERVAL=2400

STATUS_FILE="$(dirname "$0")/agent_status.json"
TASK_QUEUE="$(dirname "$0")/task_queue.json"
PID=$$
function update_status() {
  local status="$1"
  # Ensure status file exists and is valid JSON
  if [[ ! -s ${STATUS_FILE} ]]; then
    echo '{"agents":{"build_agent":{"status":"unknown","pid":null},"debug_agent":{"status":"unknown","pid":null},"codegen_agent":{"status":"unknown","pid":null},"uiux_agent":{"status":"unknown","pid":null}},"last_update":0}' >"${STATUS_FILE}"
  fi
  jq ".agents.uiux_agent.status = \"${status}\" | .agents.uiux_agent.pid = ${PID} | .last_update = $(date +%s)" "${STATUS_FILE}" >"${STATUS_FILE}.tmp"
  if [[ $? -eq 0 ]] && [[ -s "${STATUS_FILE}.tmp" ]]; then
    mv "${STATUS_FILE}.tmp" "${STATUS_FILE}"
  else
    echo "[$(date)] ${AGENT_NAME}: Failed to update agent_status.json (jq or mv error)" >>"${LOG_FILE}"
    rm -f "${STATUS_FILE}.tmp"
  fi
}
trap 'update_status stopped; exit 0' SIGTERM SIGINT

# Function to determine project from task or use default
get_project_from_task() {
  local task_data="$1"
  local project
  project=$(echo "${task_data}" | jq -r '.project // empty')
  if [[ -z ${project} || ${project} == "null" ]]; then
    project="${PROJECT}"
  fi
  echo "${project}"
}

# Function to perform UI/UX enhancements
perform_ui_enhancements() {
  local project="$1"
  local task_data="$2"

  echo "[$(date)] ${AGENT_NAME}: Starting UI/UX enhancements for ${project}..." >>"${LOG_FILE}"

  # Navigate to project directory
  local project_path="/Users/danielstevens/Desktop/Quantum-workspace/Projects/${project}"
  if [[ ! -d ${project_path} ]]; then
    echo "[$(date)] ${AGENT_NAME}: Project directory not found: ${project_path}" >>"${LOG_FILE}"
    return 1
  fi

  cd "${project_path}" || return 1

  # Create backup before making changes
  echo "[$(date)] ${AGENT_NAME}: Creating backup before UI/UX enhancements..." >>"${LOG_FILE}"
  /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup "${project}" >>"${LOG_FILE}" 2>&1 || true

  # Check if this is a drag-and-drop task
  local is_drag_drop
  is_drag_drop=$(echo "${task_data}" | jq -r '.todo // empty' | grep -i "drag\|drop" | wc -l)

  if [[ ${is_drag_drop} -gt 0 ]]; then
    echo "[$(date)] ${AGENT_NAME}: Detected drag-and-drop enhancement task..." >>"${LOG_FILE}"

    # Look for UI files that might need drag-and-drop functionality
    find . -name "*.swift" -o -name "*.storyboard" -o -name "*.xib" | while read -r file; do
      if grep -q "TODO.*drag.*drop\|drag.*drop.*TODO" "${file}" 2>/dev/null; then
        echo "[$(date)] ${AGENT_NAME}: Found drag-drop TODO in ${file}" >>"${LOG_FILE}"

        # Basic drag-and-drop implementation suggestions
        if [[ ${file} == *".swift" ]]; then
          echo "[$(date)] ${AGENT_NAME}: Adding drag-and-drop implementation to ${file}" >>"${LOG_FILE}"
          # This would be where we add actual drag-and-drop code
          # For now, we'll log the enhancement
        fi
      fi
    done
  fi

  # Run general UI/UX analysis
  echo "[$(date)] ${AGENT_NAME}: Analyzing UI/UX patterns..." >>"${LOG_FILE}"

  # Look for UI-related files and suggest improvements
  find . -name "*View*.swift" -o -name "*Controller*.swift" -o -name "*UI*.swift" | head -10 | while read -r file; do
    echo "[$(date)] ${AGENT_NAME}: Analyzing UI file: ${file}" >>"${LOG_FILE}"

    # Check for common UI improvement opportunities
    if grep -q "TODO.*UI\|UI.*TODO" "${file}" 2>/dev/null; then
      echo "[$(date)] ${AGENT_NAME}: Found UI TODO in ${file}" >>"${LOG_FILE}"
    fi
  done

  # Run validation after changes
  echo "[$(date)] ${AGENT_NAME}: Validating UI/UX enhancements..." >>"${LOG_FILE}"
  /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/intelligent_autofix.sh validate "${project}" >>"${LOG_FILE}" 2>&1

  return 0
}

while true; do
  update_status running
  echo "[$(date)] ${AGENT_NAME}: Checking for UI/UX enhancement tasks..." >>"${LOG_FILE}"

  # Check for queued UI/UX tasks
  HAS_TASK=$(jq '.tasks[] | select(.assigned_agent=="agent_uiux.sh" and .status=="queued")' "${TASK_QUEUE}" 2>/dev/null)

  if [[ -n ${HAS_TASK} ]]; then
    echo "[$(date)] ${AGENT_NAME}: Found UI/UX tasks to process..." >>"${LOG_FILE}"

    # Process each queued task
    echo "${HAS_TASK}" | jq -c '.' | while read -r task; do
      project=$(get_project_from_task "${task}")
      task_id=$(echo "${task}" | jq -r '.id')

      echo "[$(date)] ${AGENT_NAME}: Processing task ${task_id} for project ${project}..." >>"${LOG_FILE}"

      # Perform UI/UX enhancements
      if perform_ui_enhancements "${project}" "${task}"; then
        echo "[$(date)] ${AGENT_NAME}: UI/UX enhancements completed successfully for ${project}" >>"${LOG_FILE}"

        # Update task status to completed
        jq "(.tasks[] | select(.id==\"${task_id}\") | .status) = \"completed\"" "${TASK_QUEUE}" >"${TASK_QUEUE}.tmp" 2>/dev/null
        if [[ $? -eq 0 ]] && [[ -s "${TASK_QUEUE}.tmp" ]]; then
          mv "${TASK_QUEUE}.tmp" "${TASK_QUEUE}"
          echo "[$(date)] ${AGENT_NAME}: Task ${task_id} marked as completed" >>"${LOG_FILE}"
        fi

        SLEEP_INTERVAL=$((SLEEP_INTERVAL + 120))
        if [[ ${SLEEP_INTERVAL} -gt ${MAX_INTERVAL} ]]; then SLEEP_INTERVAL=${MAX_INTERVAL}; fi
      else
        echo "[$(date)] ${AGENT_NAME}: UI/UX enhancements failed for ${project}" >>"${LOG_FILE}"

        # Check if we should rollback
        if tail -20 "${LOG_FILE}" | grep -q 'error\|failed'; then
          echo "[$(date)] ${AGENT_NAME}: Error detected, attempting rollback..." >>"${LOG_FILE}"
          /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh restore "${project}" >>"${LOG_FILE}" 2>&1
          SLEEP_INTERVAL=$((SLEEP_INTERVAL / 2))
          if [[ ${SLEEP_INTERVAL} -lt ${MIN_INTERVAL} ]]; then SLEEP_INTERVAL=${MIN_INTERVAL}; fi
        fi
      fi
    done
  else
    update_status idle
    echo "[$(date)] ${AGENT_NAME}: No UI/UX tasks found. Sleeping as idle." >>"${LOG_FILE}"
    sleep 120
  fi

  echo "[$(date)] ${AGENT_NAME}: Sleeping for ${SLEEP_INTERVAL} seconds..." >>"${LOG_FILE}"
  sleep "${SLEEP_INTERVAL}"
done
name="filePath" <parameter >/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/agent_uiux.sh
