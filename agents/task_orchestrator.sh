#!/bin/bash
# Task Orchestrator Agent: Central coordinator for all agents with intelligent task distribution

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="TaskOrchestrator"
SCRIPT_DIR="$(dirname "$0")"
LOG_FILE="${SCRIPT_DIR}/task_orchestrator.log"
TASK_QUEUE_FILE="${SCRIPT_DIR}/task_queue.json"
AGENT_STATUS_FILE="${SCRIPT_DIR}/agent_status.json"
COMMUNICATION_DIR="${SCRIPT_DIR}/communication"
LOOP_INTERVAL="${LOOP_INTERVAL:-30}" # Configurable main loop sleep

# Agent capabilities and priorities
declare -A AGENT_CAPABILITIES
AGENT_CAPABILITIES=(
  ["agent_build.sh"]="build,test,compile,xcode"
  ["agent_debug.sh"]="debug,fix,diagnose,troubleshoot"
  ["agent_codegen.sh"]="generate,code,create,implement"
  ["uiux_agent.sh"]="ui,ux,interface,design,user_experience"
  ["apple_pro_agent.sh"]="ios,swift,apple,frameworks"
  ["collab_agent.sh"]="coordinate,plan,organize,collaborate"
  ["updater_agent.sh"]="update,upgrade,modernize,enhance"
  ["search_agent.sh"]="search,find,locate,discover"
  ["pull_request_agent.sh"]="pr,pull_request,merge,review"
  ["public_api_agent.sh"]="api,public,external,service"
  ["security_agent.sh"]="security,scan,audit,vulnerability"
  ["performance_agent.sh"]="performance,optimize,monitor,metrics"
  ["auto_update_agent.sh"]="auto_update,enhancement,best_practices"
  ["knowledge_base_agent.sh"]="knowledge,learn,share,best_practices"
  ["documentation_agent.sh"]="documentation,docs,readme,guide,manual"
  ["quality_agent.sh"]="quality,lint,format,style,standards"
  ["testing_agent.sh"]="testing,test,unit,integration,validation"
)

# Agent priority levels (higher number = higher priority)
declare -A AGENT_PRIORITY
AGENT_PRIORITY=(
  ["agent_build.sh"]="8"
  ["agent_debug.sh"]="9"
  ["pull_request_agent.sh"]="7"
  ["public_api_agent.sh"]="7"
  ["security_agent.sh"]="8"
  ["performance_agent.sh"]="7"
  ["auto_update_agent.sh"]="6"
  ["agent_codegen.sh"]="5"
  ["uiux_agent.sh"]="4"
  ["apple_pro_agent.sh"]="4"
  ["collab_agent.sh"]="3"
  ["updater_agent.sh"]="3"
  ["search_agent.sh"]="2"
  ["knowledge_base_agent.sh"]="1"
  ["documentation_agent.sh"]="6"
  ["quality_agent.sh"]="7"
  ["testing_agent.sh"]="8"
)

# Task types and their requirements
declare -A TASK_REQUIREMENTS
TASK_REQUIREMENTS=(
  ["build"]="agent_build.sh"
  ["test"]="agent_build.sh"
  ["debug"]="agent_debug.sh"
  ["fix"]="agent_debug.sh"
  ["generate"]="agent_codegen.sh"
  ["create"]="agent_codegen.sh"
  ["ui"]="uiux_agent.sh"
  ["ux"]="uiux_agent.sh"
  ["ios"]="apple_pro_agent.sh"
  ["swift"]="apple_pro_agent.sh"
  ["coordinate"]="collab_agent.sh"
  ["plan"]="collab_agent.sh"
  ["update"]="updater_agent.sh"
  ["search"]="search_agent.sh"
  ["pr"]="pull_request_agent.sh"
  ["pull_request"]="pull_request_agent.sh"
  ["api"]="public_api_agent.sh"
  ["review"]="code_review_agent.sh"
  ["security"]="security_agent.sh"
  ["performance"]="performance_agent.sh"
  ["auto_update"]="auto_update_agent.sh"
  ["knowledge"]="knowledge_base_agent.sh"
  ["documentation"]="documentation_agent.sh"
  ["docs"]="documentation_agent.sh"
  ["quality"]="quality_agent.sh"
  ["lint"]="quality_agent.sh"
  ["testing"]="testing_agent.sh"
  ["validation"]="testing_agent.sh"
)

# Initialize directories and files
mkdir -p "${COMMUNICATION_DIR}"

# Initialize task queue if it doesn't exist
if [[ ! -f ${TASK_QUEUE_FILE} ]]; then
  echo '{"tasks": [], "completed": [], "failed": []}' >"${TASK_QUEUE_FILE}"
fi

# Initialize agent status if it doesn't exist
if [[ ! -f ${AGENT_STATUS_FILE} ]]; then
  echo '{"agents": {}}' >"${AGENT_STATUS_FILE}"
fi

# Ensure status file is valid JSON; if corrupt, back it up and recreate.
ensure_status_file_valid() {
  if [[ -f ${AGENT_STATUS_FILE} ]] && command -v jq &>/dev/null; then
    if ! jq empty "${AGENT_STATUS_FILE}" >/dev/null 2>&1; then
      local ts
      ts=$(date +%Y%m%d_%H%M%S)
      cp "${AGENT_STATUS_FILE}" "${AGENT_STATUS_FILE}.corrupt_${ts}" 2>/dev/null || true
      echo '{"agents": {}}' >"${AGENT_STATUS_FILE}"
      log_message "WARNING" "agent_status.json was corrupt; backed up and recreated clean (${AGENT_STATUS_FILE}.corrupt_${ts})"
    fi
  fi
}

log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date)] [${AGENT_NAME}] [${level}] ${message}" >>"${LOG_FILE}"
}

# Normalize agent key between variants with/without .sh for status lookups
normalize_agent_key() {
  local agent="$1"
  # no-op placeholder removed; key not used
  # Prefer exact key if present
  if command -v jq &>/dev/null && [[ -f ${AGENT_STATUS_FILE} ]]; then
    if jq -e --arg a "${agent}" '.agents[$a]' "${AGENT_STATUS_FILE}" >/dev/null 2>&1; then
      echo "${agent}"
      return 0
    fi
  fi
  # Try without .sh
  local nosh="${agent%.sh}"
  if [[ -n ${nosh} && ${nosh} != "${agent}" ]]; then
    if command -v jq &>/dev/null && [[ -f ${AGENT_STATUS_FILE} ]]; then
      if jq -e --arg a "${nosh}" '.agents[$a]' "${AGENT_STATUS_FILE}" >/dev/null 2>&1; then
        echo "${nosh}"
        return 0
      fi
    fi
  fi
  # Try with .sh if missing
  if [[ ${agent} != *.sh ]]; then
    local withsh="${agent}.sh"
    if command -v jq &>/dev/null && [[ -f ${AGENT_STATUS_FILE} ]]; then
      if jq -e --arg a "${withsh}" '.agents[$a]' "${AGENT_STATUS_FILE}" >/dev/null 2>&1; then
        echo "${withsh}"
        return 0
      fi
    fi
  fi
  # Fallback to original
  echo "${agent}"
}

# Update agent status
update_agent_status() {
  local agent="$1"
  local status="$2"
  local last_seen
  last_seen=$(date +%s)
  local status_key
  status_key=$(normalize_agent_key "${agent}")

  # Read current status
  local current_status
  if [[ -f ${AGENT_STATUS_FILE} ]]; then
    current_status=$(cat "${AGENT_STATUS_FILE}")
  else
    current_status='{"agents": {}}'
  fi

  # Update agent status using jq if available, otherwise use sed
  if command -v jq &>/dev/null; then
    echo "${current_status}" | jq --arg agent "${status_key}" --arg status "${status}" --argjson last_seen "${last_seen}" \
      '.agents[$agent] = {"status": $status, "last_seen": $last_seen, "tasks_completed": (.agents[$agent].tasks_completed // 0)}' >"${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "${AGENT_STATUS_FILE}"
  else
    # Fallback to basic JSON manipulation
    sed -i.bak "s/\"${agent}\": {[^}]*}/\"${agent}\": {\"status\": \"${status}\", \"last_seen\": \"${last_seen}\", \"tasks_completed\": 0}/g" "${AGENT_STATUS_FILE}"
    rm -f "${AGENT_STATUS_FILE}.bak"
  fi

  log_message "INFO" "Updated status for ${agent} (${status_key}): ${status}"
}

# Update orchestrator's own status in agent_status.json
update_orchestrator_status() {
  ensure_status_file_valid
  local status="${1:-available}"
  local last_seen
  last_seen=$(date +%s)
  local pid=$$

  # Count tasks by status
  local tasks_queued=0
  local tasks_in_progress=0
  local tasks_completed=0

  if [[ -f ${TASK_QUEUE_FILE} ]]; then
    if command -v jq &>/dev/null; then
      tasks_queued=$(jq '[.tasks[] | select(.status == "queued")] | length' "${TASK_QUEUE_FILE}" 2>/dev/null || echo 0)
      tasks_in_progress=$(jq '[.tasks[] | select(.status == "in_progress")] | length' "${TASK_QUEUE_FILE}" 2>/dev/null || echo 0)
      tasks_completed=$(jq '[.tasks[] | select(.status == "completed")] | length' "${TASK_QUEUE_FILE}" 2>/dev/null || echo 0)
    fi
  fi

  # Read current status file
  local current_status
  if [[ -f ${AGENT_STATUS_FILE} ]]; then
    current_status=$(cat "${AGENT_STATUS_FILE}")
  else
    current_status='{"agents": {}}'
  fi

  # Update orchestrator status (atomic)
  if command -v jq &>/dev/null; then
    if echo "${current_status}" | jq \
      --arg status "${status}" \
      --argjson last_seen "${last_seen}" \
      --argjson pid "${pid}" \
      --argjson queued "${tasks_queued}" \
      --argjson in_progress "${tasks_in_progress}" \
      --argjson completed "${tasks_completed}" \
      '.orchestrator = {
        "status": $status,
        "last_seen": $last_seen,
        "pid": $pid,
        "is_running": true,
        "tasks_queued": $queued,
        "tasks_in_progress": $in_progress,
        "tasks_completed": $completed
      }
      | .agents["task_orchestrator.sh"] = {
         "status": $status,
         "last_seen": $last_seen,
         "pid": $pid,
         "is_running": true,
         "tasks_queued": $queued,
         "tasks_in_progress": $in_progress,
         "tasks_completed": $completed
      }
      | .last_update = $last_seen' >"${AGENT_STATUS_FILE}.tmp"; then
      mv "${AGENT_STATUS_FILE}.tmp" "${AGENT_STATUS_FILE}"
    else
      log_message "ERROR" "Failed to write orchestrator status (jq pipeline failed)"
    fi
  else
    log_message "WARNING" "jq not available; cannot update orchestrator status"
  fi
}

# One-shot mode for scripted status update without starting loop
if [[ "${TASK_ORCHESTRATOR_MODE}" == "oneshot" ]]; then
  update_orchestrator_status "available"
  exit 0
fi

# Add task to queue
add_task() {
  local task_type="$1"
  local task_description="$2"
  local priority="${3:-5}"
  local assigned_agent=""
  local task_id
  task_id=$(date +%s%N | cut -b1-13)

  # Determine best agent for task
  assigned_agent=$(select_best_agent "${task_type}")

  if [[ -z ${assigned_agent} ]]; then
    log_message "WARNING" "No suitable agent found for task type: ${task_type}"
    return 1
  fi

  # Create task object
  local task
  task="{\"id\": \"${task_id}\", \"type\": \"${task_type}\", \"description\": \"${task_description}\", \"priority\": ${priority}, \"assigned_agent\": \"${assigned_agent}\", \"status\": \"queued\", \"created\": $(date +%s), \"dependencies\": []}"

  # Add to queue using jq if available
  if command -v jq &>/dev/null; then
    jq --argjson task "${task}" '.tasks += [$task]' "${TASK_QUEUE_FILE}" >"${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "${TASK_QUEUE_FILE}"
  else
    # Fallback: append to tasks array manually
    sed -i.bak 's/"tasks": \[/&'"${task}"', /' "${TASK_QUEUE_FILE}"
    rm -f "${TASK_QUEUE_FILE}.bak"
  fi

  log_message "INFO" "Added task ${task_id} (${task_type}) assigned to ${assigned_agent}"

  # Notify assigned agent
  notify_agent "${assigned_agent}" "new_task" "${task_id}"
}

# Select best agent for task based on capabilities and current load
select_best_agent() {
  local task_type="$1"
  local best_agent=""
  local best_score=0

  # Check if task type has specific requirement
  if [[ -n ${TASK_REQUIREMENTS[${task_type}]} ]]; then
    best_agent="${TASK_REQUIREMENTS[${task_type}]}"
    if [[ -f "$(dirname "$0")/${best_agent}" ]]; then
      echo "${best_agent}"
      return 0
    fi
  fi

  # Score agents based on capabilities and priority
  for agent in "${!AGENT_CAPABILITIES[@]}"; do
    if [[ ! -f "$(dirname "$0")/${agent}" ]]; then
      continue
    fi

    local score=0
    local capabilities="${AGENT_CAPABILITIES[${agent}]}"
    local priority="${AGENT_PRIORITY[${agent}]}"

    # Check if agent has relevant capabilities
    if [[ ${capabilities} == *"${task_type}"* ]]; then
      score=$((score + 10))
    fi

    # Add priority score
    score=$((score + priority))

    # Check agent status (prefer available agents)
    local agent_status
    agent_status=$(get_agent_status "${agent}")
    if [[ ${agent_status} == "available" ]]; then
      score=$((score + 5))
    elif [[ ${agent_status} == "busy" ]]; then
      score=$((score - 3))
    fi

    if [[ ${score} -gt ${best_score} ]]; then
      best_score=${score}
      best_agent="${agent}"
    fi
  done

  echo "${best_agent}"
}

# Get agent status
get_agent_status() {
  local agent="$1"
  local status_key
  status_key=$(normalize_agent_key "${agent}")

  if [[ ! -f ${AGENT_STATUS_FILE} ]]; then
    echo "unknown"
    return
  fi

  if command -v jq &>/dev/null; then
    jq -r ".agents[\"${status_key}\"].status // \"unknown\"" "${AGENT_STATUS_FILE}"
  else
    grep -o "\"${status_key}\": {\"status\": \"[^\"]*\"" "${AGENT_STATUS_FILE}" | grep -o '"status": "[^"]*"' | cut -d'"' -f4 || echo "unknown"
  fi
}

# Notify agent of new task or status change
notify_agent() {
  local agent="$1"
  local notification_type="$2"
  local task_id="$3"

  local notification_file="${COMMUNICATION_DIR}/${agent}_notification.txt"
  local timestamp
  timestamp=$(date +%s)

  echo "${timestamp}|${notification_type}|${task_id}" >>"${notification_file}"

  log_message "INFO" "Notified ${agent}: ${notification_type} (${task_id})"
}

# Process completed tasks and update agent status
process_completed_tasks() {
  # Check for completed task notifications
  for notification_file in "${COMMUNICATION_DIR}"/*_completed.txt; do
    if [[ -f ${notification_file} ]]; then
      local agent_name
      agent_name=$(basename "${notification_file}" "_completed.txt")
      local task_info
      task_info=$(tail -1 "${notification_file}")

      if [[ -n ${task_info} ]]; then
        local task_id
        task_id=$(echo "${task_info}" | cut -d'|' -f2)
        local success
        success=$(echo "${task_info}" | cut -d'|' -f3)

        update_task_status "${task_id}" "completed" "${success}"
        update_agent_status "${agent_name}" "available"

        log_message "INFO" "Task ${task_id} completed by ${agent_name} (success: ${success})"
      fi

      # Clear notification
      true >"${notification_file}"
    fi
  done
}

# Update task status
update_task_status() {
  local task_id="$1"
  local status="$2"
  local success="$3"

  if command -v jq &>/dev/null; then
    # Move task from tasks to completed/failed
    if [[ ${status} == "completed" ]]; then
      local tq_tmp="${TASK_QUEUE_FILE}.tmp$$"
      jq --arg task_id "${task_id}" --arg success "${success}" '(.tasks[] | select(.id==$task_id)) |= (.status="completed" | .completed_at=now | .success=$success | (if .assigned_agent==null and .assigned_to!=null then .assigned_agent=.assigned_to else . end)) | (.completed += [.tasks[] | select(.id==$task_id)])' "${TASK_QUEUE_FILE}" >"${tq_tmp}" 2>/dev/null && mv "${tq_tmp}" "${TASK_QUEUE_FILE}"
      if [[ -f ${AGENT_STATUS_FILE} ]]; then
        local agent
        agent=$(jq -r --arg id "${task_id}" '.tasks[]? | select(.id==$id) | (.assigned_agent // .assigned_to // "")' "${TASK_QUEUE_FILE}" 2>/dev/null)
        if [[ -n ${agent} ]]; then
          local as_tmp="${AGENT_STATUS_FILE}.tmp$$"
          jq --arg a "${agent}" '(.agents[$a].current_task_id=null) | (.agents[$a].status="available") | (.agents[$a].tasks_completed = ((.agents[$a].tasks_completed // 0)+1))' "${AGENT_STATUS_FILE}" >"${as_tmp}" 2>/dev/null && mv "${as_tmp}" "${AGENT_STATUS_FILE}"
        fi
      fi
    fi
  fi
}

# Release stale busy agents without a current_task_id so they can take work again
release_stale_busy_agents() {
  if ! command -v jq &>/dev/null || [[ ! -f ${AGENT_STATUS_FILE} ]]; then return; fi
  local tmp="${AGENT_STATUS_FILE}.tmp$$"
  local released_count=0

  # Count agents that will be released for logging
  released_count=$(jq -r '.agents | to_entries | map(select(.value.status=="busy" and (.value.current_task_id==null or .value.current_task_id==""))) | length' "${AGENT_STATUS_FILE}" 2>/dev/null || echo 0)

  jq '(.agents |= with_entries( if (.value.status=="busy" and (.value.current_task_id==null or .value.current_task_id=="")) then .value.status="available" else . end ))' "${AGENT_STATUS_FILE}" >"${tmp}" 2>/dev/null && mv "${tmp}" "${AGENT_STATUS_FILE}"

  if [[ ${released_count} -gt 0 ]]; then
    log_message "INFO" "Released ${released_count} stale busy agents to available status"
  fi
}

# Monitor agent health and restart if needed
monitor_agent_health() {
  local current_time
  current_time=$(date +%s)

  for agent in "${!AGENT_CAPABILITIES[@]}"; do
    if [[ ! -f "$(dirname "$0")/${agent}" ]]; then
      continue
    fi

    local last_seen
    last_seen=$(get_agent_last_seen "${agent}")
    local time_diff=$((current_time - last_seen))

    # If agent hasn't been seen for more than 10 minutes, mark as unresponsive
    if [[ ${time_diff} -gt 600 ]]; then
      update_agent_status "${agent}" "unresponsive"
      log_message "WARNING" "Agent ${agent} is unresponsive (last seen: ${time_diff}s ago)"

      # Attempt to restart agent
      restart_agent "${agent}"
    fi
  done
}

# Get agent's last seen timestamp
get_agent_last_seen() {
  local agent="$1"
  local status_key
  status_key=$(normalize_agent_key "${agent}")

  if command -v jq &>/dev/null; then
    jq -r ".agents[\"${status_key}\"].last_seen // \"0\"" "${AGENT_STATUS_FILE}"
  else
    echo "0"
  fi
}

# Restart unresponsive agent
restart_agent() {
  local agent="$1"

  log_message "INFO" "Attempting to restart ${agent}"

  # Kill existing process if running
  local pid_file
  pid_file="$(dirname "$0")/${agent}.pid"
  if [[ -f ${pid_file} ]]; then
    local old_pid
    old_pid=$(cat "${pid_file}")
    if kill -0 "${old_pid}" 2>/dev/null; then
      kill "${old_pid}"
      log_message "INFO" "Killed old process ${old_pid} for ${agent}"
    fi
    rm -f "${pid_file}"
  fi

  # Start new instance
  nohup bash "$(dirname "$0")/${agent}" >>"$(dirname "$0")/${agent}.log" 2>&1 &
  local new_pid=$!
  echo "${new_pid}" >"${pid_file}"

  update_agent_status "${agent}" "restarting"
  log_message "INFO" "Restarted ${agent} with PID ${new_pid}"
}

# Distribute tasks to available agents
distribute_tasks() {
  local available_tasks

  if command -v jq &>/dev/null; then
    available_tasks=$(jq -r '.tasks[] | select(.status == "queued") | .id' "${TASK_QUEUE_FILE}")
  else
    available_tasks=$(grep -o '"id": "[^"]*"' "${TASK_QUEUE_FILE}" | cut -d'"' -f4)
  fi

  for task_id in ${available_tasks}; do
    local task_info
    task_info=$(get_task_info "${task_id}")
    local assigned_agent
    assigned_agent=$(echo "${task_info}" | cut -d'|' -f1)
    local task_type
    task_type=$(echo "${task_info}" | cut -d'|' -f2)

    if [[ -z ${task_type} || ${task_type} == "unknown" ]]; then
      continue
    fi

    if [[ -z ${assigned_agent} ]]; then
      assigned_agent=$(select_best_agent "${task_type}")
      [[ -z ${assigned_agent} ]] && continue
    fi

    local agent_status
    agent_status=$(get_agent_status "${assigned_agent}")
    if [[ ${agent_status} == "available" || ${agent_status} == "idle" ]]; then
      notify_agent "${assigned_agent}" "execute_task" "${task_id}"
      mark_task_assigned "${task_id}" "${assigned_agent}"
      log_message "INFO" "Assigned (dynamic) task ${task_id} -> ${assigned_agent} (status: ${agent_status})"
    else
      log_message "DEBUG" "Agent ${assigned_agent} not available for task ${task_id} (status: ${agent_status})"
    fi
  done
}

# Mark task as assigned (transition to in_progress soon)
mark_task_assigned() {
  local task_id="$1"
  local agent="$2"
  if command -v jq &>/dev/null; then
    tmp_file="${TASK_QUEUE_FILE}.tmp$$"
    if jq --arg id "${task_id}" --arg agent "${agent}" '(.tasks[] | select(.id==$id)) |= (.status="assigned" | .assigned_at=(now|floor) | .assigned_to=$agent | .assigned_agent=$agent)' "${TASK_QUEUE_FILE}" >"${tmp_file}" 2>/dev/null; then
      mv "${tmp_file}" "${TASK_QUEUE_FILE}"
      update_agent_status "${agent}" "busy"
      if [[ -f ${AGENT_STATUS_FILE} ]]; then
        local a_tmp="${AGENT_STATUS_FILE}.tmp$$"
        jq --arg a "${agent}" --arg t "${task_id}" '(.agents[$a].current_task_id=$t)' "${AGENT_STATUS_FILE}" >"${a_tmp}" 2>/dev/null && mv "${a_tmp}" "${AGENT_STATUS_FILE}"
      fi
    fi
  fi
}

# Advance assigned/in_progress tasks automatically for demo metrics
advance_task_progress() {
  local now
  now=$(date +%s)
  if ! command -v jq &>/dev/null; then return; fi
  # 1) Move tasks from assigned -> in_progress after 3s (faster demo)
  tmp_file="${TASK_QUEUE_FILE}.tmp$$"
  if jq '(.tasks[] | select(.status=="assigned" and ((now - (.assigned_at // now)) > 3))) |= (.status="in_progress" | .started_at=now)' "${TASK_QUEUE_FILE}" >"${tmp_file}" 2>/dev/null; then
    mv "${tmp_file}" "${TASK_QUEUE_FILE}"
  fi
  # 2) Complete tasks in_progress after 5s from started_at (faster demo)
  local to_complete
  to_complete=$(jq -r '.tasks[] | select(.status=="in_progress" and ((now - (.started_at // now)) > 5)) | .id' "${TASK_QUEUE_FILE}" 2>/dev/null)
  for tid in ${to_complete}; do
    update_task_status "${tid}" "completed" "true"
  done
}

# Refresh agent heartbeats: mark idle if busy without tasks > 120s; bump last_seen
refresh_agent_heartbeats() {
  local now
  now=$(date +%s)
  if ! command -v jq &>/dev/null; then return; fi
  # For each agent, if status busy but no active task recorded in queue and last_seen >120s mark available
  local tmp_file="${AGENT_STATUS_FILE}.tmp$$"
  if jq --argjson now "${now}" '(.agents |= with_entries(
      if (.value.status=="busy" and (.value.last_seen // 0) < ($now-120)) then
        .value.status="available" | .value.last_seen=$now
      elif (.value.status=="available" and (.value.last_seen // 0) < ($now-180)) then
        .value.status="idle" | .value.last_seen=$now
      else . end))' "${AGENT_STATUS_FILE}" >"${tmp_file}" 2>/dev/null; then
    mv "${tmp_file}" "${AGENT_STATUS_FILE}"
  fi
}

# Get task information
get_task_info() {
  local task_id="$1"

  if command -v jq &>/dev/null; then
    local task_data
    task_data=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | (.assigned_agent // .assigned_to // \"\") + \"|\" + .type" "${TASK_QUEUE_FILE}")
    echo "${task_data}"
  else
    echo "unknown|unknown"
  fi
}

# Generate status report
generate_status_report() {
  local report_file
  report_file="$(dirname "$0")/orchestrator_status_$(date +%Y%m%d_%H%M%S).md"

  {
    echo "# Task Orchestrator Status Report"
    echo "Generated: $(date)"
    echo ""

    echo "## Agent Status"
    echo "| Agent | Status | Last Seen | Tasks Completed |"
    echo "|-------|--------|-----------|-----------------|"

    for agent in "${!AGENT_CAPABILITIES[@]}"; do
      local status
      status=$(get_agent_status "${agent}")
      local last_seen
      last_seen=$(get_agent_last_seen "${agent}")
      local tasks_completed="0"

      if command -v jq &>/dev/null; then
        tasks_completed=$(jq -r ".agents[\"${agent}\"].tasks_completed // \"0\"" "${AGENT_STATUS_FILE}")
      fi

      local last_seen_formatted="Never"
      if [[ ${last_seen} != "0" ]]; then
        last_seen_formatted=$(date -r "${last_seen}" 2>/dev/null || echo "Unknown")
      fi

      echo "| ${agent} | ${status} | ${last_seen_formatted} | ${tasks_completed} |"
    done

    echo ""
    echo "## Task Queue"

    if command -v jq &>/dev/null; then
      local queued_count
      queued_count=$(jq '.tasks | length' "${TASK_QUEUE_FILE}")
      local completed_count
      completed_count=$(jq '.completed | length' "${TASK_QUEUE_FILE}")
      local failed_count
      failed_count=$(jq '.failed | length' "${TASK_QUEUE_FILE}")

      echo "- Queued: ${queued_count}"
      echo "- Completed: ${completed_count}"
      echo "- Failed: ${failed_count}"

      if [[ ${queued_count} -gt 0 ]]; then
        echo ""
        echo "### Queued Tasks"
        echo "| Task ID | Type | Description | Assigned Agent | Priority |"
        echo "|---------|------|-------------|----------------|----------|"

        jq -r '.tasks[] | select(.status == "queued") | "\(.id)|\(.type)|\(.description)|\(.assigned_agent)|\(.priority)"' "${TASK_QUEUE_FILE}" | while IFS='|' read -r id type desc agent priority; do
          echo "| ${id} | ${type} | ${desc} | ${agent} | ${priority} |"
        done
      fi
    fi

  } >"${report_file}"

  log_message "INFO" "Status report generated: ${report_file}"
}

# Ingest external tasks and bridge assignments
check_external_tasks() {
  # 1) Bridge agent assignments into this queue
  local bridge_script="${SCRIPT_DIR%/agents}/bridge_assignments_to_tasks.sh"
  if [[ -x "${bridge_script}" ]]; then
    "${bridge_script}" || log_message "WARNING" "bridge_assignments_to_tasks.sh returned non-zero"
  fi

  # 2) Merge tasks from Tools/agents/task_queue.json into this queue
  local external_queue="${SCRIPT_DIR%/Automation/agents}/agents/task_queue.json"
  if [[ -f "${external_queue}" ]] && command -v jq &>/dev/null; then
    local new_tasks
    new_tasks=$(jq -c '.tasks[] | select(.status == "queued")' "${external_queue}" 2>/dev/null)
    if [[ -n ${new_tasks} ]]; then
      while IFS= read -r task; do
        # Skip if task with same id already exists
        if jq -e --arg id "$(echo "${task}" | jq -r '.id')" '.tasks[] | select(.id == $id)' "${TASK_QUEUE_FILE}" >/dev/null 2>&1; then
          continue
        fi
        # Append task
        tmp_file="${TASK_QUEUE_FILE}.tmp$$"
        if jq --argjson t "${task}" '.tasks += [$t]' "${TASK_QUEUE_FILE}" >"${tmp_file}" 2>/dev/null; then
          mv "${tmp_file}" "${TASK_QUEUE_FILE}"
          log_message "INFO" "Imported external task $(echo "${task}" | jq -r '.id')"
        else
          rm -f "${tmp_file}"
        fi
      done < <(echo "${new_tasks}")
    fi
  fi
}

# Main orchestration loop
log_message "INFO" "Task Orchestrator starting..."

while true; do
  # Update orchestrator status
  update_orchestrator_status "available"
  update_agent_status "task_orchestrator.sh" "active"

  # Advance synthetic task progress (demo metrics) & refresh heartbeats
  advance_task_progress
  refresh_agent_heartbeats
  release_stale_busy_agents

  # Process completed tasks
  process_completed_tasks

  # Monitor agent health
  monitor_agent_health

  # Distribute queued tasks
  distribute_tasks

  # Generate periodic status report (every 5 minutes)
  current_minute=$(date +%M)
  if [[ $((current_minute % 5)) -eq 0 ]]; then
    generate_status_report
  fi

  # Check for new tasks from external sources
  check_external_tasks

  sleep "${LOOP_INTERVAL}" # Configurable interval
done
