#!/bin/bash

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

# Source project configuration
if [[ -f "${SCRIPT_DIR}/../project_config.sh" ]]; then
  source "${SCRIPT_DIR}/../project_config.sh"
fi

# Ensure PROJECT_NAME is set for subprocess calls
export PROJECT_NAME="${PROJECT_NAME:-CodingReviewer}"

echo "[$(date)] codegen_agent: Script started, PID=$$" >>"/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/codegen_agent.log"
# CodeGen/Fix Agent: Triggers code generation and auto-fix routines

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Source AI enhancement modules
ENHANCEMENTS_DIR="${SCRIPT_DIR}/../enhancements"
if [[ -f "${ENHANCEMENTS_DIR}/ai_codegen_optimizer.sh" ]]; then
  # shellcheck source=../enhancements/ai_codegen_optimizer.sh
  source "${ENHANCEMENTS_DIR}/ai_codegen_optimizer.sh"
fi

AGENT_NAME="codegen_agent"
AGENT_LABEL="CodeGenAgent"
LOG_FILE="${SCRIPT_DIR}/codegen_agent.log"
COMM_DIR="${SCRIPT_DIR}/communication"
NOTIFICATION_FILE="${COMM_DIR}/agent_codegen.sh_notification.txt"
COMPLETED_FILE="${COMM_DIR}/agent_codegen.sh_completed.txt"
PROJECT="CodingReviewer"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/Tools/Automation/agents/task_queue.json"
PROCESSED_TASKS_FILE="${SCRIPT_DIR}/${AGENT_NAME}_processed_tasks.txt"
STATUS_UPDATE_INTERVAL=60

STATUS_UTIL="${SCRIPT_DIR}/status_utils.py"
STATUS_KEYS=("${AGENT_NAME}" "agent_codegen.sh")

PROJECT="${PROJECT:-CodingReviewer}"
PROJECT_CONFIG_FILES=(
  "${WORKSPACE}/Tools/Automation/project_config.sh"
  "${WORKSPACE}/Projects/${PROJECT}/Tools/Automation/project_config.sh"
)

AUTOMATE_BIN="${WORKSPACE}/Tools/Automation/automate.sh"
MCP_WORKFLOW_BIN="${WORKSPACE}/Tools/Automation/mcp_workflow.sh"
AI_ENHANCEMENT_BIN="${WORKSPACE}/Tools/Automation/ai_enhancement_system.sh"
AUTO_FIX_VALIDATOR="${WORKSPACE}/Tools/Automation/intelligent_autofix.sh"
BACKUP_MANAGER="${SCRIPT_DIR}/backup_manager.sh"

SLEEP_INTERVAL=900 # Start with 15 minutes
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

initialize_project_context() {
  local config_loaded=false
  local config
  for config in "${PROJECT_CONFIG_FILES[@]}"; do
    if [[ -f ${config} ]]; then
      # shellcheck disable=SC1090
      source "${config}"
      config_loaded=true
    fi
  done

  PROJECT_NAME="${PROJECT_NAME:-${PROJECT}}"
  PROJECT_DIR="${PROJECT_DIR:-${WORKSPACE}/Projects/${PROJECT_NAME}}"

  export PROJECT_NAME PROJECT_DIR

  if [[ ${config_loaded} != true ]]; then
    log_message "WARN" "No project configuration found for ${PROJECT_NAME}; using defaults."
  else
    log_message "INFO" "Project configuration loaded for ${PROJECT_NAME}."
  fi

  if [[ ! -d ${PROJECT_DIR} ]]; then
    log_message "ERROR" "Project directory not found: ${PROJECT_DIR}"
    return 1
  fi

  return 0
}

if ! initialize_project_context; then
  log_message "ERROR" "Unable to initialize project context; exiting."
  exit 1
fi

run_step() {
  local allow_failure
  allow_failure="$1"
  shift
  local description
  description="$1"
  shift

  echo "[$(date)] ${AGENT_NAME}: ${description}" >>"${LOG_FILE}"

  if "$@" >>"${LOG_FILE}" 2>&1; then
    return 0
  fi

  log_message "ERROR" "${description} failed"
  if [[ ${allow_failure} == "true" ]]; then
    return 0
  fi

  return 1
}

record_task_success() {
  [[ -f ${STATUS_UTIL} ]] || return

  local key
  for key in "${STATUS_KEYS[@]}"; do
    python3 "${STATUS_UTIL}" update-agent \
      --status-file "${AGENT_STATUS_FILE}" \
      --agent "${key}" \
      --increment-field tasks_completed >/dev/null 2>&1 || true
  done
}

log_message() {
  local level
  level="$1"
  local message
  message="$2"
  echo "[$(date)] [${AGENT_LABEL}] [${level}] ${message}" >>"${LOG_FILE}"
}


maybe_update_status() {
  local status
  status="$1"
  local now
  now=$(date +%s)
  if ((now - LAST_STATUS_UPDATE >= STATUS_UPDATE_INTERVAL)); then
    update_agent_status "agent_codegen.sh" "${status}" $$ ""
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

run_codegen_pipeline() {
  local success_flag="true"

  if ! run_step true "Creating backup before codegen/fix..." "${BACKUP_MANAGER}" backup "${PROJECT_NAME}"; then
    success_flag="false"
  fi

  if ! run_step false "Running AI automation pipeline" "${AUTOMATE_BIN}" ai; then
    success_flag="false"
  fi

  if ! run_step false "Executing MCP autofix workflow" "${MCP_WORKFLOW_BIN}" autofix "${PROJECT_NAME}"; then
    success_flag="false"
  fi

  if ! run_step false "Running AI enhancement analysis" "${AI_ENHANCEMENT_BIN}" analyze "${PROJECT_NAME}"; then
    success_flag="false"
  fi

  if ! run_step true "Auto-applying safe AI enhancements" "${AI_ENHANCEMENT_BIN}" auto-apply "${PROJECT_NAME}"; then
    success_flag="false"
  fi

  if ! run_step false "Validating codegen, fixes, and enhancements" "${AUTO_FIX_VALIDATOR}" validate "${PROJECT_NAME}"; then
    success_flag="false"
  fi

  if ! run_step false "Running automated tests after codegen/enhancement" "${AUTOMATE_BIN}" test; then
    success_flag="false"
  fi

  if [[ ${success_flag} == "true" ]]; then
    if tail -40 "${LOG_FILE}" | grep -q 'ROLLBACK'; then
      echo "[$(date)] ${AGENT_NAME}: Rollback detected after validation. Investigate issues." >>"${LOG_FILE}"
      CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
      echo "[$(date)] ${AGENT_NAME}: Consecutive failures: ${CONSECUTIVE_FAILURES}" >>"${LOG_FILE}"
      success_flag="false"
    elif tail -40 "${LOG_FILE}" | grep -iq 'error'; then
      echo "[$(date)] ${AGENT_NAME}: Errors detected during validation or tests; restoring last backup." >>"${LOG_FILE}"
      run_step true "Restoring last backup" "${BACKUP_MANAGER}" restore "${PROJECT_NAME}" || true
      CONSECUTIVE_FAILURES=$((CONSECUTIVE_FAILURES + 1))
      echo "[$(date)] ${AGENT_NAME}: Consecutive failures: ${CONSECUTIVE_FAILURES}" >>"${LOG_FILE}"
      success_flag="false"
    else
      echo "[$(date)] ${AGENT_NAME}: Codegen, enhancement, validation, and tests completed successfully." >>"${LOG_FILE}"
      if [[ ${CONSECUTIVE_FAILURES} -gt 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Reset consecutive failures counter (was: ${CONSECUTIVE_FAILURES})" >>"${LOG_FILE}"
      fi
      CONSECUTIVE_FAILURES=0
    fi
  fi

  [[ ${success_flag} == "true" ]]
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
  if ! run_codegen_pipeline; then
    success_flag="false"
  fi

  if [[ ${success_flag} == "true" ]]; then
    update_task_status "${task_id}" "completed"
    echo "${task_id}" >>"${PROCESSED_TASKS_FILE}"
    record_task_success
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
  assigned_tasks=$(jq -r ".tasks[] | select(.assigned_agent == \"${AGENT_NAME}\" or .assigned_agent == \"agent_codegen.sh\" and (.status == \"assigned\" or .status == \"queued\" or .status == \"in_progress\")) | .id" "${TASK_QUEUE_FILE}" 2>/dev/null)

  for task_id in ${assigned_tasks}; do
    [[ -n ${task_id} ]] || continue
    if has_processed_task "${task_id}"; then
      continue
    fi

    update_agent_status "agent_codegen.sh" "busy" $$ ""
    update_task_status "${task_id}" "in_progress"
    process_task "${task_id}" || log_message "ERROR" "Task ${task_id} failed"
    update_agent_status "agent_codegen.sh" "available" $$ ""
  done
}

process_notifications() {
  if [[ -f ${NOTIFICATION_FILE} ]]; then
    while IFS='|' read -r _timestamp notification_type task_id; do
      case "${notification_type}" in
      "execute_task")
        if [[ -n ${task_id} ]] && ! has_processed_task "${task_id}"; then
          update_agent_status "agent_codegen.sh" "busy" $$ ""
          update_task_status "${task_id}" "in_progress"
          process_task "${task_id}" || log_message "ERROR" "Notification task ${task_id} failed"
          update_agent_status "agent_codegen.sh" "available" $$ ""
        fi
        ;;
      "codegen_now")
        update_agent_status "agent_codegen.sh" "busy" $$ ""
        log_message "INFO" "Manual codegen triggered"
        # Run codegen logic here
        update_agent_status "agent_codegen.sh" "available" $$ ""
        ;;
      esac
    done <"${NOTIFICATION_FILE}"

    # Clear processed notifications
    : >"${NOTIFICATION_FILE}"
  fi
}
trap 'update_agent_status "agent_codegen.sh" "stopped" $$ ""; exit 0' SIGTERM SIGINT
while true; do
  maybe_update_status "available"

  process_notifications

  # Get next task for this agent
  TASK_ID=$(get_next_task "agent_codegen.sh")

  if [[ -n "${TASK_ID}" ]]; then
    echo "[$(date)] ${AGENT_NAME}: Processing task ${TASK_ID}" >>"${LOG_FILE}"

    # Mark task as in progress
    update_task_status "${TASK_ID}" "in_progress"
    update_agent_status "agent_codegen.sh" "busy" $$ "${TASK_ID}"

    # Get task details
    TASK_DETAILS=$(get_task_details "${TASK_ID}")
    TASK_TYPE=$(echo "${TASK_DETAILS}" | jq -r '.type // "codegen"')
    TASK_DESCRIPTION=$(echo "${TASK_DETAILS}" | jq -r '.description // "Unknown task"')

    echo "[$(date)] ${AGENT_NAME}: Task type: ${TASK_TYPE}, Description: ${TASK_DESCRIPTION}" >>"${LOG_FILE}"

    # Process the task based on type
    TASK_SUCCESS=true

    case "${TASK_TYPE}" in
      "codegen")
        # Run codegen operations
        if ! run_codegen_pipeline; then
          TASK_SUCCESS=false
        fi
        ;;
      *)
        echo "[$(date)] ${AGENT_NAME}: Unknown task type: ${TASK_TYPE}" >>"${LOG_FILE}"
        TASK_SUCCESS=false
        ;;
    esac

    # Complete the task
    complete_task "${TASK_ID}" "${TASK_SUCCESS}"
    increment_task_count "agent_codegen.sh"

    if [[ "${TASK_SUCCESS}" == "true" ]]; then
      echo "[$(date)] ${AGENT_NAME}: Task ${TASK_ID} completed successfully" >>"${LOG_FILE}"
      SLEEP_INTERVAL=$((SLEEP_INTERVAL + 60))
      if [[ ${SLEEP_INTERVAL} -gt ${MAX_INTERVAL} ]]; then SLEEP_INTERVAL=${MAX_INTERVAL}; fi
    else
      echo "[$(date)] ${AGENT_NAME}: Task ${TASK_ID} failed" >>"${LOG_FILE}"
      SLEEP_INTERVAL=$((SLEEP_INTERVAL / 2))
      if [[ ${SLEEP_INTERVAL} -lt ${MIN_INTERVAL} ]]; then SLEEP_INTERVAL=${MIN_INTERVAL}; fi
    fi

  fi
    # Legacy check for queued codegen tasks (fallback)
    HAS_TASK=$(jq ".tasks[] | select((.assigned_agent==\"${AGENT_NAME}\" or .assigned_agent==\"agent_codegen.sh\") and .status==\"queued\")" "${TASK_QUEUE_FILE}" 2>/dev/null)
    if [[ -n ${HAS_TASK} ]]; then
    update_agent_status "agent_codegen.sh" "busy" $$ ""
    echo "[$(date)] ${AGENT_NAME}: Running codegen pipeline for queued work..." >>"${LOG_FILE}"
    if run_codegen_pipeline; then
      SLEEP_INTERVAL=$((SLEEP_INTERVAL + 60))
      if [[ ${SLEEP_INTERVAL} -gt ${MAX_INTERVAL} ]]; then SLEEP_INTERVAL=${MAX_INTERVAL}; fi
    else
      SLEEP_INTERVAL=$((SLEEP_INTERVAL + 60))
      if [[ ${SLEEP_INTERVAL} -gt ${MAX_INTERVAL} ]]; then SLEEP_INTERVAL=${MAX_INTERVAL}; fi
    fi
    update_agent_status "agent_codegen.sh" "available" $$ ""
  else
    update_agent_status "agent_codegen.sh" "idle" $$ ""
    echo "[$(date)] ${AGENT_NAME}: No codegen tasks found. Sleeping as idle." >>"${LOG_FILE}"
    sleep 60
    continue
  fi
  echo "[$(date)] ${AGENT_NAME}: Sleeping for ${SLEEP_INTERVAL} seconds." >>"${LOG_FILE}"
  sleep "${SLEEP_INTERVAL}"
done
