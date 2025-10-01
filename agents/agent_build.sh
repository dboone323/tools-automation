#!/bin/bash
echo "[$(date)] build_agent: Script started, PID=$$" >>"/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/build_agent.log"
echo "[$(date)] build_agent: Auto-debug task creation enabled (max consecutive failures: ${MAX_CONSECUTIVE_FAILURES})" >>"/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/build_agent.log"
# Build Agent: Watches for changes and triggers builds automatically

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
AGENT_NAME="build_agent"
AGENT_LABEL="BuildAgent"
LOG_FILE="${SCRIPT_DIR}/build_agent.log"
COMM_DIR="${SCRIPT_DIR}/communication"
NOTIFICATION_FILE="${COMM_DIR}/agent_build.sh_notification.txt"
COMPLETED_FILE="${COMM_DIR}/agent_build.sh_completed.txt"
PROJECT="CodingReviewer"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/Tools/Automation/agents/task_queue.json"
PROCESSED_TASKS_FILE="${SCRIPT_DIR}/${AGENT_NAME}_processed_tasks.txt"
STATUS_UPDATE_INTERVAL=60

STATUS_UTIL="${SCRIPT_DIR}/status_utils.py"
STATUS_KEYS=("${AGENT_NAME}" "agent_build.sh")

SLEEP_INTERVAL=300 # Start with 5 minutes
MIN_INTERVAL=60
MAX_INTERVAL=1800

CONSECUTIVE_FAILURES=0
MAX_CONSECUTIVE_FAILURES=3

mkdir -p "${COMM_DIR}"
touch "${NOTIFICATION_FILE}" "${COMPLETED_FILE}" "${PROCESSED_TASKS_FILE}"

if [[ ! -f ${AGENT_STATUS_FILE} ]]; then
  echo '{"agents":{},"last_update":0}' >"${AGENT_STATUS_FILE}"
fi

if [[ ! -f ${TASK_QUEUE_FILE} ]]; then
  echo '{"tasks":[]}' >"${TASK_QUEUE_FILE}"
fi

LAST_STATUS_UPDATE=0

log_message() {
  local level
  level="$1"
  local message
  message="$2"
  echo "[$(date)] [${AGENT_LABEL}] [${level}] ${message}" >>"${LOG_FILE}"
}

legacy_update_status() {
  local status="$1"

  if command -v jq &>/dev/null; then
    local current_content
    current_content=$(cat "${AGENT_STATUS_FILE}" 2>/dev/null)
    if [[ -z ${current_content} ]]; then
      current_content='{"agents":{},"last_update":0}'
    fi

    local now
    now=$(date +%s)
    local temp_file
    temp_file="${AGENT_STATUS_FILE}.tmp.$$"
    local key
    for key in "${STATUS_KEYS[@]}"; do
      current_content=$(echo "${current_content}" | jq \
        --arg agent "${key}" \
        --arg status "${status}" \
        --argjson now "${now}" \
        'def to_num:
          if type == "string" then
            (gsub("^[\\s]+"; "") | gsub("[\\s]+$"; "") |
              if test("^-?[0-9]+$") then tonumber else . end)
          elif type == "number" then .
          else . end;
         .agents[$agent] = (.agents[$agent] // {})
         | .agents[$agent].status = $status
         | .agents[$agent].last_seen = $now
         | .agents[$agent] |= (
             to_entries
             | map(if (["pid","last_seen","tasks_completed","restart_count"] | index(.key)) != null
                   then .value = (.value | to_num) else . end)
             | from_entries)
         | .last_update = $now' 2>/dev/null) || return
    done

    if [[ -n ${current_content} ]]; then
      echo "${current_content}" >"${temp_file}" && mv "${temp_file}" "${AGENT_STATUS_FILE}"
    fi
  fi
}

update_status() {
  local status="$1"
  local key
  local now
  now=$(date +%s)

  if [[ -f ${STATUS_UTIL} ]]; then
    local python_ok=true
    for key in "${STATUS_KEYS[@]}"; do
      if ! python3 "${STATUS_UTIL}" update-agent \
        --status-file "${AGENT_STATUS_FILE}" \
        --agent "${key}" \
        --status "${status}" \
        --last-seen "${now}" >/dev/null 2>&1; then
        python_ok=false
        break
      fi
    done

    if [[ ${python_ok} != true ]]; then
      legacy_update_status "${status}"
    fi
  else
    legacy_update_status "${status}"
  fi

  LAST_STATUS_UPDATE=${now}
  log_message "INFO" "Status updated to ${status}"
}

maybe_update_status() {
  local status
  status="$1"
  local now
  now=$(date +%s)
  if ((now - LAST_STATUS_UPDATE >= STATUS_UPDATE_INTERVAL)); then
    update_status "${status}"
  fi
}

update_task_status() {
  local task_id="$1"
  local status="$2"

  [[ -f ${TASK_QUEUE_FILE} ]] || return

  if [[ -f ${STATUS_UTIL} ]]; then
    if python3 "${STATUS_UTIL}" update-task \
      --queue-file "${TASK_QUEUE_FILE}" \
      --task-id "${task_id}" \
      --status "${status}" >/dev/null 2>&1; then
      return
    fi
  fi

  if command -v jq &>/dev/null; then
    local current_content
    current_content=$(cat "${TASK_QUEUE_FILE}" 2>/dev/null)
    if [[ -z ${current_content} ]]; then
      current_content='{"tasks":[]}'
    fi

    local updated_content
    updated_content=$(echo "${current_content}" | jq "(.tasks[] | select(.id == \"${task_id}\") | .status) = \"${status}\"" 2>/dev/null)

    if [[ -n ${updated_content} ]]; then
      local temp_file
      temp_file="${TASK_QUEUE_FILE}.tmp.$$"
      echo "${updated_content}" >"${temp_file}" && mv "${temp_file}" "${TASK_QUEUE_FILE}"
    fi
  fi
}

notify_completion() {
  local task_id
  task_id="$1"
  local success
  success="$2"
  echo "$(date +%s)|${task_id}|${success}" >>"${COMPLETED_FILE}"
}

has_processed_task() {
  local task_id
  task_id="$1"
  [[ -f ${PROCESSED_TASKS_FILE} ]] || return 1
  grep -qx "${task_id}" "${PROCESSED_TASKS_FILE}" 2>/dev/null
}

fetch_task_description() {
  local task_id
  task_id="$1"
  [[ -n ${task_id} ]] || return 1
  command -v jq &>/dev/null || return 1
  [[ -f ${TASK_QUEUE_FILE} ]] || return 1
  jq -r ".tasks[] | select(.id == \"${task_id}\") | .description // \"\"" "${TASK_QUEUE_FILE}" 2>/dev/null
}

# Create debug task for persistent build failures
create_debug_task() {
  local project="$1"
  local failure_description="$2"
  local timestamp
  timestamp=$(date +%s%N | cut -b1-13)
  local task_id="debug_build_failure_${timestamp}"
  local task_description="Investigate persistent build failures in ${project}: ${failure_description}"
  local priority=9
  local task

  echo "[$(date)] ${AGENT_NAME}: Creating debug task for persistent build failures..." >>"${LOG_FILE}"

  # Create task object
  task="{\"id\": \"${task_id}\", \"type\": \"debug\", \"description\": \"${task_description}\", \"priority\": ${priority}, \"assigned_agent\": \"agent_debug.sh\", \"status\": \"queued\", \"created\": $(date +%s), \"dependencies\": []}"

  # Add to task queue
  if command -v jq &>/dev/null; then
    jq --argjson task "${task}" '.tasks += [$task]' "${TASK_QUEUE}" >"${TASK_QUEUE}.tmp" 2>/dev/null
    if [[ $? -eq 0 ]] && [[ -s "${TASK_QUEUE}.tmp" ]]; then
      mv "${TASK_QUEUE}.tmp" "${TASK_QUEUE}"
      echo "[$(date)] ${AGENT_NAME}: Debug task created: ${task_id}" >>"${LOG_FILE}"
      return 0
    else
      echo "[$(date)] ${AGENT_NAME}: Failed to create debug task (jq error)" >>"${LOG_FILE}"
      rm -f "${TASK_QUEUE}.tmp"
      return 1
    fi
  else
    echo "[$(date)] ${AGENT_NAME}: jq not available, cannot create debug task" >>"${LOG_FILE}"
    return 1
  fi
}

process_task() {
  local task_id
  task_id="$1"
  [[ -n ${task_id} ]] || return 1

  if has_processed_task "${task_id}"; then
    log_message "INFO" "Task ${task_id} already processed"
    return 0
  fi

  local task_desc
  task_desc=$(fetch_task_description "${task_id}")
  if [[ ${task_desc} == "null" ]]; then
    task_desc=""
  fi

  log_message "INFO" "Processing task ${task_id}: ${task_desc}"

  local success_flag="true"

  # Process the build task
  echo "[$(date)] ${AGENT_NAME}: Creating multi-level backup before build..." >>"${LOG_FILE}"
  /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup CodingReviewer >>"${LOG_FILE}" 2>&1 || true
  echo "[$(date)] ${AGENT_NAME}: Running build..." >>"${LOG_FILE}"
  /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/automate.sh build >>"${LOG_FILE}" 2>&1
  echo "[$(date)] ${AGENT_NAME}: Running AI enhancement analysis..." >>"${LOG_FILE}"
  /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_enhancement_system.sh analyze CodingReviewer >>"${LOG_FILE}" 2>&1
  echo "[$(date)] ${AGENT_NAME}: Auto-applying safe AI enhancements..." >>"${LOG_FILE}"
  /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_enhancement_system.sh auto-apply CodingReviewer >>"${LOG_FILE}" 2>&1
  echo "[$(date)] ${AGENT_NAME}: Validating build and enhancements..." >>"${LOG_FILE}"
  /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/intelligent_autofix.sh validate CodingReviewer >>"${LOG_FILE}" 2>&1
  echo "[$(date)] ${AGENT_NAME}: Running automated tests after build and enhancements..." >>"${LOG_FILE}"
  /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/automate.sh test >>"${LOG_FILE}" 2>&1

  if tail -40 "${LOG_FILE}" | grep -q 'ROLLBACK'; then
    echo "[$(date)] ${AGENT_NAME}: Rollback detected after validation. Investigate issues." >>"${LOG_FILE}"
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    echo "[$(date)] ${AGENT_NAME}: Consecutive failures: ${CONSECUTIVE_FAILURES}" >>"${LOG_FILE}"
    success_flag="false"
    # Create debug task if failures are persistent
    if [[ ${CONSECUTIVE_FAILURES} -ge ${MAX_CONSECUTIVE_FAILURES} ]]; then
      create_debug_task "${PROJECT}" "Multiple rollbacks detected after validation failures"
      CONSECUTIVE_FAILURES=0 # Reset counter after creating task
    fi
  elif tail -40 "${LOG_FILE}" | grep -q 'error'; then
    echo "[$(date)] ${AGENT_NAME}: Test failure detected, restoring last backup..." >>"${LOG_FILE}"
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh restore CodingReviewer >>"${LOG_FILE}" 2>&1
    CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
    echo "[$(date)] ${AGENT_NAME}: Consecutive failures: ${CONSECUTIVE_FAILURES}" >>"${LOG_FILE}"
    success_flag="false"
    # Create debug task if failures are persistent
    if [[ ${CONSECUTIVE_FAILURES} -ge ${MAX_CONSECUTIVE_FAILURES} ]]; then
      create_debug_task "${PROJECT}" "Persistent test failures detected after multiple build attempts"
      CONSECUTIVE_FAILURES=0 # Reset counter after creating task
    fi
  else
    echo "[$(date)] ${AGENT_NAME}: Build, AI enhancement, validation, and tests completed successfully." >>"${LOG_FILE}"
    if [[ ${CONSECUTIVE_FAILURES} -gt 0 ]]; then
      echo "[$(date)] ${AGENT_NAME}: Reset consecutive failures counter (was: ${CONSECUTIVE_FAILURES})" >>"${LOG_FILE}"
    fi
    CONSECUTIVE_FAILURES=0 # Reset counter on success
  fi

  if [[ ${success_flag} == "true" ]]; then
    update_task_status "${task_id}" "completed"
    echo "${task_id}" >>"${PROCESSED_TASKS_FILE}"
  else
    update_task_status "${task_id}" "failed"
  fi

  notify_completion "${task_id}" "${success_flag}"
  log_message "INFO" "Task ${task_id} completed with success=${success_flag}"

  [[ ${success_flag} == "true" ]]
}

process_assigned_tasks() {
  [[ -f ${TASK_QUEUE_FILE} ]] || return
  command -v jq &>/dev/null || return

  local assigned_tasks
  assigned_tasks=$(jq -r ".tasks[] | select(.assigned_agent == \"agent_build.sh\" and (.status == \"assigned\" or .status == \"queued\" or .status == \"in_progress\")) | .id" "${TASK_QUEUE_FILE}" 2>/dev/null)

  for task_id in ${assigned_tasks}; do
    [[ -n ${task_id} ]] || continue
    if has_processed_task "${task_id}"; then
      continue
    fi

    update_status "busy"
    update_task_status "${task_id}" "in_progress"
    process_task "${task_id}" || log_message "ERROR" "Task ${task_id} failed"
    update_status "available"
  done
}

process_notifications() {
  if [[ -f ${NOTIFICATION_FILE} ]]; then
    while IFS='|' read -r _timestamp notification_type task_id; do
      case "${notification_type}" in
      "execute_task")
        if [[ -n ${task_id} ]] && ! has_processed_task "${task_id}"; then
          update_status "busy"
          update_task_status "${task_id}" "in_progress"
          process_task "${task_id}" || log_message "ERROR" "Notification task ${task_id} failed"
          update_status "available"
        fi
        ;;
      "build_now")
        update_status "busy"
        log_message "INFO" "Manual build triggered"
        # Run build logic here
        update_status "available"
        ;;
      esac
    done <"${NOTIFICATION_FILE}"

    # Clear processed notifications
    : >"${NOTIFICATION_FILE}"
  fi
}

trap 'update_status stopped; exit 0' SIGTERM SIGINT
while true; do
  maybe_update_status "available"

  process_notifications
  process_assigned_tasks

  # Legacy check for queued build tasks (fallback)
  HAS_TASK=$(jq '.tasks[] | select(.assigned_agent=="agent_build.sh" and .status=="queued")' "${TASK_QUEUE_FILE}" 2>/dev/null)
  if [[ -n ${HAS_TASK} ]] || grep -q 'ENABLE_AUTO_BUILD=true' "/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/project_config.sh" 2>/dev/null; then
    update_status "busy"
    echo "[$(date)] ${AGENT_NAME}: Creating multi-level backup before build..." >>"${LOG_FILE}"
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup CodingReviewer >>"${LOG_FILE}" 2>&1 || true
    echo "[$(date)] ${AGENT_NAME}: Running build..." >>"${LOG_FILE}"
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/automate.sh build >>"${LOG_FILE}" 2>&1
    echo "[$(date)] ${AGENT_NAME}: Running AI enhancement analysis..." >>"${LOG_FILE}"
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_enhancement_system.sh analyze CodingReviewer >>"${LOG_FILE}" 2>&1
    echo "[$(date)] ${AGENT_NAME}: Auto-applying safe AI enhancements..." >>"${LOG_FILE}"
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_enhancement_system.sh auto-apply CodingReviewer >>"${LOG_FILE}" 2>&1
    echo "[$(date)] ${AGENT_NAME}: Validating build and enhancements..." >>"${LOG_FILE}"
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/intelligent_autofix.sh validate CodingReviewer >>"${LOG_FILE}" 2>&1
    echo "[$(date)] ${AGENT_NAME}: Running automated tests after build and enhancements..." >>"${LOG_FILE}"
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/automate.sh test >>"${LOG_FILE}" 2>&1
    if tail -40 "${LOG_FILE}" | grep -q 'ROLLBACK'; then
      echo "[$(date)] ${AGENT_NAME}: Rollback detected after validation. Investigate issues." >>"${LOG_FILE}"
      CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
      echo "[$(date)] ${AGENT_NAME}: Consecutive failures: ${CONSECUTIVE_FAILURES}" >>"${LOG_FILE}"
      SLEEP_INTERVAL=$((SLEEP_INTERVAL / 2))
      if [[ ${SLEEP_INTERVAL} -lt ${MIN_INTERVAL} ]]; then SLEEP_INTERVAL=${MIN_INTERVAL}; fi

      # Create debug task if failures are persistent
      if [[ ${CONSECUTIVE_FAILURES} -ge ${MAX_CONSECUTIVE_FAILURES} ]]; then
        create_debug_task "${PROJECT}" "Multiple rollbacks detected after validation failures"
        CONSECUTIVE_FAILURES=0 # Reset counter after creating task
      fi
    elif tail -40 "${LOG_FILE}" | grep -q 'error'; then
      echo "[$(date)] ${AGENT_NAME}: Test failure detected, restoring last backup..." >>"${LOG_FILE}"
      /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh restore CodingReviewer >>"${LOG_FILE}" 2>&1
      CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
      echo "[$(date)] ${AGENT_NAME}: Consecutive failures: ${CONSECUTIVE_FAILURES}" >>"${LOG_FILE}"
      SLEEP_INTERVAL=$((SLEEP_INTERVAL / 2))
      if [[ ${SLEEP_INTERVAL} -lt ${MIN_INTERVAL} ]]; then SLEEP_INTERVAL=${MIN_INTERVAL}; fi

      # Create debug task if failures are persistent
      if [[ ${CONSECUTIVE_FAILURES} -ge ${MAX_CONSECUTIVE_FAILURES} ]]; then
        create_debug_task "${PROJECT}" "Persistent test failures detected after multiple build attempts"
        CONSECUTIVE_FAILURES=0 # Reset counter after creating task
      fi
    else
      echo "[$(date)] ${AGENT_NAME}: Build, AI enhancement, validation, and tests completed successfully." >>"${LOG_FILE}"
      if [[ ${CONSECUTIVE_FAILURES} -gt 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Reset consecutive failures counter (was: ${CONSECUTIVE_FAILURES})" >>"${LOG_FILE}"
      fi
      CONSECUTIVE_FAILURES=0 # Reset counter on success
      SLEEP_INTERVAL=$((SLEEP_INTERVAL + 60))
      if [[ ${SLEEP_INTERVAL} -gt ${MAX_INTERVAL} ]]; then SLEEP_INTERVAL=${MAX_INTERVAL}; fi
    fi
    update_status "available"
  else
    update_status "idle"
    echo "[$(date)] ${AGENT_NAME}: No build tasks found. Sleeping as idle." >>"${LOG_FILE}"
    sleep 60
    continue
  fi
  echo "[$(date)] ${AGENT_NAME}: Sleeping for ${SLEEP_INTERVAL} seconds." >>"${LOG_FILE}"
  sleep "${SLEEP_INTERVAL}"
done
