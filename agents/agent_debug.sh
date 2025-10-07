#!/bin/bash

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

# Source project configuration
if [[ -f "${SCRIPT_DIR}/../project_config.sh" ]]; then
  source "${SCRIPT_DIR}/../project_config.sh"
fi

# Set task queue file path
export TASK_QUEUE_FILE="${SCRIPT_DIR}/../task_queue.json"

# Ensure PROJECT_NAME is set for subprocess calls
export PROJECT_NAME="${PROJECT_NAME:-CodingReviewer}"

echo "[$(date)] debug_agent: Script started, PID=$$" >>"/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/debug_agent.log"
# Debug Agent: Runs diagnostics and auto-fix if issues are detected

AGENT_NAME="DebugAgent"
LOG_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/debug_agent.log"
PROJECT="CodingReviewer"

SLEEP_INTERVAL=600 # Start with 10 minutes
MIN_INTERVAL=60
MAX_INTERVAL=1800

STATUS_FILE="$(dirname "$0")/agent_status.json"
TASK_QUEUE="$(dirname "$0")/task_queue.json"
PID=$$
trap 'update_agent_status "agent_debug.sh" "stopped" $$ ""; exit 0' SIGTERM SIGINT
while true; do
  update_agent_status "agent_debug.sh" "running" $$ ""
  echo "[$(date)] ${AGENT_NAME}: Running diagnostics..." >>"${LOG_FILE}"

  # Get next task for this agent
  TASK_ID=$(get_next_task "agent_debug.sh")

  if [[ -n "${TASK_ID}" ]]; then
    echo "[$(date)] ${AGENT_NAME}: Processing task ${TASK_ID}" >>"${LOG_FILE}"

    # Mark task as in progress
    update_task_status "${TASK_ID}" "in_progress"
    update_agent_status "agent_debug.sh" "busy" $$ "${TASK_ID}"

    # Get task details
    TASK_DETAILS=$(get_task_details "${TASK_ID}")
    TASK_TYPE=$(echo "${TASK_DETAILS}" | jq -r '.type // "debug"')
    TASK_DESCRIPTION=$(echo "${TASK_DETAILS}" | jq -r '.description // "Unknown task"')

    echo "[$(date)] ${AGENT_NAME}: Task type: ${TASK_TYPE}, Description: ${TASK_DESCRIPTION}" >>"${LOG_FILE}"

    # Process the task based on type
    TASK_SUCCESS=true

    case "${TASK_TYPE}" in
      "debug")
        # Run debug operations
        /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/automate.sh test >>"${LOG_FILE}" 2>&1
        if grep -q 'error:' "${LOG_FILE}"; then
          echo "[$(date)] ${AGENT_NAME}: Creating backup before auto-fix..." >>"${LOG_FILE}"
          echo "[$(date)] ${AGENT_NAME}: Creating multi-level backup before debug/fix..." >>"${LOG_FILE}"
          /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup CodingReviewer >>"${LOG_FILE}" 2>&1 || true
          echo "[$(date)] ${AGENT_NAME}: Detected errors, running auto-fix..." >>"${LOG_FILE}"
          /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/mcp_workflow.sh autofix CodingReviewer >>"${LOG_FILE}" 2>&1
          echo "[$(date)] ${AGENT_NAME}: Running AI enhancement analysis..." >>"${LOG_FILE}"
          /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_enhancement_system.sh analyze CodingReviewer >>"${LOG_FILE}" 2>&1
          echo "[$(date)] ${AGENT_NAME}: Auto-applying safe AI enhancements..." >>"${LOG_FILE}"
          /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_enhancement_system.sh auto-apply CodingReviewer >>"${LOG_FILE}" 2>&1
          echo "[$(date)] ${AGENT_NAME}: Validating diagnostics, fixes, and enhancements..." >>"${LOG_FILE}"
          /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/intelligent_autofix.sh validate CodingReviewer >>"${LOG_FILE}" 2>&1
          echo "[$(date)] ${AGENT_NAME}: Running automated tests after debug/fix..." >>"${LOG_FILE}"
          /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/automate.sh test >>"${LOG_FILE}" 2>&1

          if tail -40 "${LOG_FILE}" | grep -q 'ROLLBACK'; then
            echo "[$(date)] ${AGENT_NAME}: Rollback detected after validation. Task failed." >>"${LOG_FILE}"
            TASK_SUCCESS=false
            SLEEP_INTERVAL=$((SLEEP_INTERVAL / 2))
            if [[ ${SLEEP_INTERVAL} -lt ${MIN_INTERVAL} ]]; then SLEEP_INTERVAL=${MIN_INTERVAL}; fi
          elif tail -40 "${LOG_FILE}" | grep -q 'error'; then
            echo "[$(date)] ${AGENT_NAME}: Test failure detected, restoring last backup..." >>"${LOG_FILE}"
            /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh restore CodingReviewer >>"${LOG_FILE}" 2>&1
            TASK_SUCCESS=false
            SLEEP_INTERVAL=$((SLEEP_INTERVAL / 2))
            if [[ ${SLEEP_INTERVAL} -lt ${MIN_INTERVAL} ]]; then SLEEP_INTERVAL=${MIN_INTERVAL}; fi
          else
            echo "[$(date)] ${AGENT_NAME}: Debug, fix, validation, and tests completed successfully." >>"${LOG_FILE}"
            SLEEP_INTERVAL=$((SLEEP_INTERVAL + 60))
            if [[ ${SLEEP_INTERVAL} -gt ${MAX_INTERVAL} ]]; then SLEEP_INTERVAL=${MAX_INTERVAL}; fi
          fi
        fi
        ;;
      *)
        echo "[$(date)] ${AGENT_NAME}: Unknown task type: ${TASK_TYPE}" >>"${LOG_FILE}"
        TASK_SUCCESS=false
        ;;
    esac

    # Complete the task
    complete_task "${TASK_ID}" "${TASK_SUCCESS}"
    increment_task_count "agent_debug.sh"

    if [[ "${TASK_SUCCESS}" == "true" ]]; then
      echo "[$(date)] ${AGENT_NAME}: Task ${TASK_ID} completed successfully" >>"${LOG_FILE}"
    else
      echo "[$(date)] ${AGENT_NAME}: Task ${TASK_ID} failed" >>"${LOG_FILE}"
    fi

  else
    update_agent_status "agent_debug.sh" "idle" $$ ""
    echo "[$(date)] ${AGENT_NAME}: No debug tasks found. Sleeping as idle." >>"${LOG_FILE}"
    sleep 60
    continue
  fi
  sleep "${SLEEP_INTERVAL}"
done
