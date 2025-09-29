#!/bin/bash
# CodeGen/Fix Agent: Triggers code generation and auto-fix routines

AGENT_NAME="CodeGenAgent"
LOG_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/codegen_agent.log"
PROJECT="CodingReviewer"

SLEEP_INTERVAL=900 # Start with 15 minutes
MIN_INTERVAL=60
MAX_INTERVAL=1800

STATUS_FILE="$(dirname "$0")/agent_status.json"
TASK_QUEUE="$(dirname "$0")/task_queue.json"
PID=$$
function update_status() {
  local status="$1"
  # Ensure status file exists and is valid JSON
  if [[ ! -s ${STATUS_FILE} ]]; then
    echo '{"agents":{"build_agent":{"status":"unknown","pid":null},"debug_agent":{"status":"unknown","pid":null},"codegen_agent":{"status":"unknown","pid":null}},"last_update":0}' >"${STATUS_FILE}"
  fi
  jq ".agents.codegen_agent.status = \"${status}\" | .agents.codegen_agent.pid = ${PID} | .last_update = $(date +%s)" "${STATUS_FILE}" >"${STATUS_FILE}.tmp"
  if [[ $? -eq 0 ]] && [[ -s "${STATUS_FILE}.tmp" ]]; then
    mv "${STATUS_FILE}.tmp" "${STATUS_FILE}"
  else
    echo "[$(date)] ${AGENT_NAME}: Failed to update agent_status.json (jq or mv error)" >>"${LOG_FILE}"
    rm -f "${STATUS_FILE}.tmp"
  fi
}
trap 'update_status stopped; exit 0' SIGTERM SIGINT
while true; do
  update_status running
  echo "[$(date)] ${AGENT_NAME}: Running codegen and fix routines..." >>"${LOG_FILE}"
  # Check for queued codegen tasks
  HAS_TASK=$(jq '.tasks[] | select(.assigned_agent=="agent_codegen.sh" and .status=="queued")' "${TASK_QUEUE}" 2>/dev/null)
  if [[ -n ${HAS_TASK} ]]; then
    echo "[$(date)] ${AGENT_NAME}: Creating backup before codegen/fix..." >>"${LOG_FILE}"
    echo "[$(date)] ${AGENT_NAME}: Creating multi-level backup before codegen/enhancement..." >>"${LOG_FILE}"
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup CodingReviewer >>"${LOG_FILE}" 2>&1 || true
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/automate.sh ai >>"${LOG_FILE}" 2>&1
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/mcp_workflow.sh autofix CodingReviewer >>"${LOG_FILE}" 2>&1
    echo "[$(date)] ${AGENT_NAME}: Running AI enhancement analysis..." >>"${LOG_FILE}"
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_enhancement_system.sh analyze CodingReviewer >>"${LOG_FILE}" 2>&1
    echo "[$(date)] ${AGENT_NAME}: Auto-applying safe AI enhancements..." >>"${LOG_FILE}"
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/ai_enhancement_system.sh auto-apply CodingReviewer >>"${LOG_FILE}" 2>&1
    echo "[$(date)] ${AGENT_NAME}: Validating codegen, fixes, and enhancements..." >>"${LOG_FILE}"
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/intelligent_autofix.sh validate CodingReviewer >>"${LOG_FILE}" 2>&1
    echo "[$(date)] ${AGENT_NAME}: Running automated tests after codegen/enhancement..." >>"${LOG_FILE}"
    /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/automate.sh test >>"${LOG_FILE}" 2>&1
    if tail -40 "${LOG_FILE}" | grep -q 'ROLLBACK'; then
      echo "[$(date)] ${AGENT_NAME}: Rollback detected after validation. Investigate issues." >>"${LOG_FILE}"
      SLEEP_INTERVAL=$((SLEEP_INTERVAL / 2))
      if [[ ${SLEEP_INTERVAL} -lt ${MIN_INTERVAL} ]]; then SLEEP_INTERVAL=${MIN_INTERVAL}; fi
    elif tail -40 "${LOG_FILE}" | grep -q 'error'; then
      echo "[$(date)] ${AGENT_NAME}: Test failure detected, restoring last backup..." >>"${LOG_FILE}"
      /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh restore CodingReviewer >>"${LOG_FILE}" 2>&1
      SLEEP_INTERVAL=$((SLEEP_INTERVAL / 2))
      if [[ ${SLEEP_INTERVAL} -lt ${MIN_INTERVAL} ]]; then SLEEP_INTERVAL=${MIN_INTERVAL}; fi
    else
      echo "[$(date)] ${AGENT_NAME}: Codegen, enhancement, validation, and tests completed successfully." >>"${LOG_FILE}"
      SLEEP_INTERVAL=$((SLEEP_INTERVAL + 60))
      if [[ ${SLEEP_INTERVAL} -gt ${MAX_INTERVAL} ]]; then SLEEP_INTERVAL=${MAX_INTERVAL}; fi
    fi
  else
    update_status idle
    echo "[$(date)] ${AGENT_NAME}: No codegen tasks found. Sleeping as idle." >>"${LOG_FILE}"
    sleep 60
    continue
  fi
  sleep "${SLEEP_INTERVAL}"
done
