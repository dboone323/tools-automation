#!/usr/bin/env bash
# TODO Processing Agent: Reads TODOs and delegates to appropriate agents

AGENTS_DIR="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents"
TODO_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Projects/todo-tree-output.json"
LOG_FILE="${AGENTS_DIR}/todo_agent.log"
MCP_URL="http://127.0.0.1:5005"

# Ensure running in bash
if [[ -z ${BASH_VERSION} ]]; then
  echo "This script must be run with bash."
  exec bash "$0" "$@"
  exit 1
fi

# Logging function
log() {
  echo "[$(date)] TODO Agent: $1" >>"${LOG_FILE}"
  echo "[$(date)] TODO Agent: $1"
}

# Function to read TODOs from JSON file
read_todos() {
  if [[ ! -f ${TODO_FILE} ]]; then
    log "TODO file not found: ${TODO_FILE}"
    return 1
  fi

  # Use python to parse JSON and extract TODOs
  python3 -c "
import json
import sys

try:
    with open('${TODO_FILE}', 'r') as f:
        todos = json.load(f)

    for i, todo in enumerate(todos):
        print(f'{i}|{todo[\"file\"]}|{todo[\"line\"]}|{todo[\"text\"]}')
except Exception as e:
    print(f'ERROR: {e}', file=sys.stderr)
    sys.exit(1)
"
}

# Function to determine which agent should handle a TODO
delegate_todo() {
  local file="$1"
  local line="$2"
  local text="$3"

  # Extract the actual TODO text (remove "TODO: " prefix)
  local todo_text="${text#TODO: }"

  # Determine project from file path
  local project=""
  if [[ ${file} == AvoidObstaclesGame/* ]]; then
    project="AvoidObstaclesGame"
  elif [[ ${file} == CodingReviewer/* ]]; then
    project="CodingReviewer"
  elif [[ ${file} == HabitQuest/* ]]; then
    project="HabitQuest"
  elif [[ ${file} == MomentumFinance/* ]]; then
    project="MomentumFinance"
  elif [[ ${file} == PlannerApp/* ]]; then
    project="PlannerApp"
  fi

  # Smart delegation based on TODO content
  local agent=""
  local command=""

  if [[ ${todo_text} == *"collision"* || ${todo_text} == *"performance"* ]]; then
    agent="debug"
    command="optimize-performance"
  elif [[ ${todo_text} == *"code review"* || ${todo_text} == *"language"* ]]; then
    agent="codegen"
    command="enhance-review-engine"
  elif [[ ${todo_text} == *"streak"* || ${todo_text} == *"feature"* ]]; then
    agent="codegen"
    command="implement-feature"
  elif [[ ${todo_text} == *"API"* || ${todo_text} == *"integrate"* ]]; then
    agent="build"
    command="integrate-api"
  elif [[ ${todo_text} == *"drag"* || ${todo_text} == *"UI"* ]]; then
    agent="uiux"
    command="enhance-ui"
  else
    agent="codegen"
    command="implement-todo"
  fi

  echo "${agent}|${command}|${project}|${file}|${line}|${todo_text}"
}

# Function to submit task to MCP server
submit_task() {
  local agent="$1"
  local command="$2"
  local project="$3"
  local file="$4"
  local line="$5"
  local todo_text="$6"

  log "Delegating TODO to ${agent} agent: ${todo_text}"

  # Submit task to MCP server
  local response
  response=$(curl -s -X POST "${MCP_URL}/run" \
    -H "Content-Type: application/json" \
    -d "{\"agent\": \"${agent}\", \"command\": \"${command}\", \"project\": \"${project}\", \"file\": \"${file}\", \"line\": \"${line}\", \"todo\": \"${todo_text}\", \"execute\": true}")

  if [[ $? -eq 0 ]] && [[ ${response} == *"\"ok\": true"* ]]; then
    log "Successfully delegated TODO to ${agent} agent"
    return 0
  else
    log "Failed to delegate TODO: ${response}"
    return 1
  fi
}

# Function to check if TODO has been completed
check_todo_completion() {
  local file="$1"
  local line="$2"
  local todo_text="$3"

  # Check if the TODO comment still exists in the file
  if [[ -f ${file} ]]; then
    if grep -n "TODO.*${todo_text}" "${file}" >/dev/null 2>&1; then
      return 1 # TODO still exists
    else
      return 0 # TODO completed
    fi
  fi

  return 1 # File not found or error
}

# Main processing loop
log "Starting TODO Processing Agent"

while true; do
  log "Checking for new TODOs..."

  # Read current TODOs
  todos=$(read_todos 2>>"${LOG_FILE}")

  if [[ $? -ne 0 ]]; then
    log "Error reading TODOs: ${todos}"
    sleep 60
    continue
  fi

  # Process each TODO
  echo "${todos}" | while IFS='|' read -r index file line text; do
    if [[ ${index} == "ERROR:"* ]]; then
      log "JSON parsing error: ${index}"
      continue
    fi

    log "Processing TODO: ${text} in ${file}:${line}"

    # Check if TODO is already being processed
    if [[ -f "${AGENTS_DIR}/todo_${index}.processing" ]]; then
      log "TODO ${index} already being processed, skipping"
      continue
    fi

    # Check if TODO has been completed
    if check_todo_completion "${file}" "${line}" "${text}"; then
      log "TODO ${index} appears to be completed, removing marker"
      rm -f "${AGENTS_DIR}/todo_${index}.processing"
      continue
    fi

    # Mark as being processed
    touch "${AGENTS_DIR}/todo_${index}.processing"

    # Delegate to appropriate agent
    delegation=$(delegate_todo "${file}" "${line}" "${text}")

    if [[ -n ${delegation} ]]; then
      IFS='|' read -r agent command project todo_file todo_line todo_text <<<"${delegation}"
      submit_task "${agent}" "${command}" "${project}" "${todo_file}" "${todo_line}" "${todo_text}"
    else
      log "Could not determine delegation for TODO: ${text}"
    fi
  done

  log "TODO processing cycle completed, sleeping for 300 seconds"
  sleep 300 # Check every 5 minutes
done
