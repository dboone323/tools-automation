#!/bin/bash
echo "[$(date)] build_agent: Script started, PID=$$" >>"/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/build_agent.log"
echo "[$(date)] build_agent: Auto-debug task creation enabled (max consecutive failures: ${MAX_CONSECUTIVE_FAILURES})" >>"/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/build_agent.log"
# Build Agent: Watches for changes and triggers builds automatically

AGENT_NAME="BuildAgent"
LOG_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/build_agent.log"
PROJECT="CodingReviewer"

SLEEP_INTERVAL=300 # Start with 5 minutes
MIN_INTERVAL=60
MAX_INTERVAL=1800

STATUS_FILE="$(dirname "$0")/agent_status.json"
TASK_QUEUE="$(dirname "$0")/task_queue.json"
PID=$$
CONSECUTIVE_FAILURES=0
MAX_CONSECUTIVE_FAILURES=3
function update_status() {
  local status="$1"
  echo "[$(date)] build_agent: update_status called with status '${status}'" >>"${LOG_FILE}"
  # Ensure status file exists and is valid JSON
  if [[ ! -s ${STATUS_FILE} ]]; then
    echo '{"agents":{"build_agent":{"status":"unknown","pid":null},"debug_agent":{"status":"unknown","pid":null},"codegen_agent":{"status":"unknown","pid":null}},"last_update":0}' >"${STATUS_FILE}"
  fi
  jq ".agents.build_agent.status = \"${status}\" | .agents.build_agent.pid = ${PID} | .last_update = $(date +%s)" "${STATUS_FILE}" >"${STATUS_FILE}.tmp"
  if [[ $? -eq 0 ]] && [[ -s "${STATUS_FILE}.tmp" ]]; then
    mv "${STATUS_FILE}.tmp" "${STATUS_FILE}"
  else
    echo "[$(date)] ${AGENT_NAME}: Failed to update agent_status.json (jq or mv error)" >>"${LOG_FILE}"
    rm -f "${STATUS_FILE}.tmp"
  fi
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
trap 'update_status stopped; exit 0' SIGTERM SIGINT
while true; do
  update_status running
  echo "[$(date)] ${AGENT_NAME}: Checking for build trigger..." >>"${LOG_FILE}"
  # Check for queued build tasks
  HAS_TASK=$(jq '.tasks[] | select(.assigned_agent=="agent_build.sh" and .status=="queued")' "${TASK_QUEUE}" 2>/dev/null)
  if [[ -n ${HAS_TASK} ]] || grep -q 'ENABLE_AUTO_BUILD=true' "/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/project_config.sh"; then
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
  else
    update_status idle
    echo "[$(date)] ${AGENT_NAME}: No build tasks found. Sleeping as idle." >>"${LOG_FILE}"
    sleep 60
    continue
  fi
  echo "[$(date)] ${AGENT_NAME}: Sleeping for ${SLEEP_INTERVAL} seconds." >>"${LOG_FILE}"
  sleep "${SLEEP_INTERVAL}"
done
