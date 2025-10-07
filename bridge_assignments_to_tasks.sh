#!/bin/bash
# Bridge script to convert agent assignments to task queue entries

WORKSPACE_DIR="/Users/danielstevens/Desktop/Quantum-workspace"
ASSIGNMENTS_FILE="${WORKSPACE_DIR}/Tools/Automation/agent_assignments.json"
TASK_QUEUE_FILE="${WORKSPACE_DIR}/Tools/Automation/agents/task_queue.json"
LOG_FILE="${WORKSPACE_DIR}/Tools/Automation/bridge_assignments.log"

log() {
  echo "[$(date)] $*" >>"${LOG_FILE}"
}

log "Starting assignment to task bridge process"

if [[ ! -f ${ASSIGNMENTS_FILE} ]]; then
  log "No assignments file found"
  exit 0
fi

# Read assignments and create tasks
jq -c '.[]' "${ASSIGNMENTS_FILE}" | while read -r assignment; do
  id=$(echo "${assignment}" | jq -r '.id')
  file=$(echo "${assignment}" | jq -r '.file')
  line=$(echo "${assignment}" | jq -r '.line')
  text=$(echo "${assignment}" | jq -r '.text')
  agent=$(echo "${assignment}" | jq -r '.agent')

  # Convert agent name to task type
  case "${agent}" in
  "performance_agent.sh")
    task_type="performance"
    ;;
  "testing_agent.sh")
    task_type="testing"
    ;;
  "uiux_agent.sh")
    task_type="ui"
    ;;
  "apple_pro_agent.sh")
    task_type="swift"
    ;;
  "code_review_agent.sh")
    task_type="review"
    ;;
  "agent_debug.sh")
    task_type="debug"
    ;;
  "public_api_agent.sh")
    task_type="api"
    ;;
  "documentation_agent.sh")
    task_type="documentation"
    ;;
  "security_agent.sh")
    task_type="security"
    ;;
  "pull_request_agent.sh")
    task_type="pull_request"
    ;;
  *)
    task_type="debug"
    ;;
  esac

  # Create task entry
  task_id="todo_${id}"
  task_description="${text} (File: ${file}:${line})"

  # Check if task already exists
  if jq -e ".tasks[] | select(.id == \"${task_id}\")" "${TASK_QUEUE_FILE}" >/dev/null 2>&1; then
    log "Task ${task_id} already exists, skipping"
    continue
  fi

  # Add task to queue
  task_json="{\"id\": \"${task_id}\", \"type\": \"${task_type}\", \"description\": \"${task_description}\", \"priority\": 5, \"assigned_agent\": \"${agent}\", \"status\": \"queued\", \"created\": $(date +%s), \"dependencies\": []}"

  jq ".tasks += [${task_json}]" "${TASK_QUEUE_FILE}" >"${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "${TASK_QUEUE_FILE}"

  log "Created task ${task_id} for agent ${agent}"
done

log "Assignment to task bridge process complete"
