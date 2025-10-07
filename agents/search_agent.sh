#!/bin/bash
# Search Agent: Finds and summarizes information from codebase, docs, or the web as needed

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
WORKSPACE="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
AGENT_NAME="search_agent"
AGENT_LABEL="SearchAgent"
LOG_FILE="${SCRIPT_DIR}/search_agent.log"
COMM_DIR="${SCRIPT_DIR}/communication"
NOTIFICATION_FILE="${COMM_DIR}/${AGENT_NAME}_notification.txt"
COMPLETED_FILE="${COMM_DIR}/${AGENT_NAME}_completed.txt"
RESULTS_DIR="${SCRIPT_DIR}/search_results"
QUERY_DIR="${SCRIPT_DIR}/queries"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/Tools/Automation/agents/task_queue.json"
PROCESSED_TASKS_FILE="${SCRIPT_DIR}/${AGENT_NAME}_processed_tasks.txt"
STATUS_UPDATE_INTERVAL=60
STATUS_UTIL="${SCRIPT_DIR}/status_utils.py"
STATUS_KEYS=("${AGENT_NAME}" "search_agent.sh")
BASE_SLEEP_INTERVAL=300
MIN_SLEEP_INTERVAL=60
MAX_SLEEP_INTERVAL=1800
CONTEXT_LINES=3
TMP_ROOT="${TMPDIR:-/tmp}"

mkdir -p "${COMM_DIR}" "${RESULTS_DIR}" "${QUERY_DIR}"
touch "${NOTIFICATION_FILE}" "${COMPLETED_FILE}" "${PROCESSED_TASKS_FILE}"

if [[ ! -f ${AGENT_STATUS_FILE} ]]; then
  echo '{"agents":{},"last_update":0}' >"${AGENT_STATUS_FILE}"
fi

if [[ ! -f ${TASK_QUEUE_FILE} ]]; then
  echo '{"tasks":[]}' >"${TASK_QUEUE_FILE}"
fi

log_message() {
  local level
  level="$1"
  local message
  message="$2"
  echo "[$(date)] [${AGENT_LABEL}] [${level}] ${message}" >>"${LOG_FILE}"
}

LAST_STATUS_UPDATE=0

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
    temp_file=$(mktemp "${TMP_ROOT}/search_agent_status.XXXXXX") || return
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
          elif type == "number" then . else . end;
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
      if printf '%s' "${current_content}" >"${temp_file}" && mv "${temp_file}" "${AGENT_STATUS_FILE}"; then
        return
      fi
    fi
    rm -f "${temp_file}"
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

update_agent_pid() {
  local pid_value
  pid_value="$1"
  [[ -n ${pid_value} ]] || return

  if [[ -f ${STATUS_UTIL} ]]; then
    local python_ok=true
    local key
    for key in "${STATUS_KEYS[@]}"; do
      if ! python3 "${STATUS_UTIL}" update-agent \
        --status-file "${AGENT_STATUS_FILE}" \
        --agent "${key}" \
        --pid "${pid_value}" >/dev/null 2>&1; then
        python_ok=false
        break
      fi
    done
    if [[ ${python_ok} == true ]]; then
      log_message "INFO" "Registered PID ${pid_value}"
      return
    fi
  fi

  if command -v jq &>/dev/null; then
    local current_content
    current_content=$(cat "${AGENT_STATUS_FILE}" 2>/dev/null)
    if [[ -z ${current_content} ]]; then
      current_content='{"agents":{},"last_update":0}'
    fi
    local now
    now=$(date +%s)
    local key
    for key in "${STATUS_KEYS[@]}"; do
      current_content=$(echo "${current_content}" | jq \
        --arg agent "${key}" \
        --argjson pid ${pid_value} \
        --argjson now "${now}" \
        '.agents[$agent] = (.agents[$agent] // {})
         | .agents[$agent].pid = $pid
         | .agents[$agent].last_seen = $now
         | .last_update = $now' 2>/dev/null) || return
    done
    local temp_file
    temp_file=$(mktemp "${TMP_ROOT}/search_agent_pid.XXXXXX") || return
    if printf '%s' "${current_content}" >"${temp_file}" && mv "${temp_file}" "${AGENT_STATUS_FILE}"; then
      log_message "INFO" "Registered PID ${pid_value} (jq fallback)"
    else
      rm -f "${temp_file}"
    fi
  fi
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

fetch_task_payload_value() {
  local task_id
  task_id="$1"
  local key
  key="$2"
  [[ -n ${task_id} ]] || return 1
  [[ -n ${key} ]] || return 1
  command -v jq &>/dev/null || return 1
  [[ -f ${TASK_QUEUE_FILE} ]] || return 1
  jq -r ".tasks[] | select(.id == \"${task_id}\") | .payload.${key} // \"\"" "${TASK_QUEUE_FILE}" 2>/dev/null
}

extract_query_from_task() {
  local task_id
  task_id="$1"
  local query
  query=$(fetch_task_payload_value "${task_id}" "query")
  if [[ -z ${query} || ${query} == "null" ]]; then
    query=$(fetch_task_description "${task_id}")
  fi
  echo "${query}"
}

safely_trim_output() {
  local max_lines
  max_lines="$1"
  if [[ -n ${max_lines} ]]; then
    head -n "${max_lines}"
  else
    cat
  fi
}

perform_local_search() {
  local query
  query="$1"
  local target_dir
  target_dir="$2"
  local max_hits
  max_hits="$3"

  [[ -n ${query} ]] || return 1
  [[ -d ${target_dir} ]] || return 0

  local matcher_output

  if command -v rg &>/dev/null; then
    matcher_output=$(rg --no-heading --line-number --context "${CONTEXT_LINES}" --max-count "${max_hits}" --fixed-strings "${query}" "${target_dir}" 2>/dev/null)
  else
    matcher_output=$(grep -R -n -C "${CONTEXT_LINES}" -F --binary-files=without-match --exclude-dir=".git" -m "${max_hits}" -- "${query}" "${target_dir}" 2>/dev/null)
  fi

  if [[ -z ${matcher_output} ]]; then
    echo "No matches found in ${target_dir}."
  else
    echo "Matches found in ${target_dir}:"
    echo "${matcher_output}" | safely_trim_output 200
  fi
}

summarize_results() {
  local result_file
  result_file="$1"
  if command -v python3 &>/dev/null; then
    python3 - "${result_file}" <<'PYCODE'
import sys
from pathlib import Path

result_path = Path(sys.argv[1])
text = result_path.read_text(encoding="utf-8", errors="ignore")
lines = [line.strip() for line in text.splitlines() if line.strip()]
summary_lines = []
for line in lines[:20]:
    summary_lines.append(f"- {line[:200]}")
if not summary_lines:
    summary_lines.append("- No significant matches captured")
summary = "\n".join(summary_lines)
summary_path = result_path.with_suffix(".summary.md")
summary_path.write_text("# Search Summary\n" + summary + "\n", encoding="utf-8")
print(summary_path)
PYCODE
  fi
}

generate_search_report() {
  local task_id
  task_id="$1"
  local query
  query="$2"
  local scope
  scope="$3"

  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local report_file
  report_file="${RESULTS_DIR}/search_${timestamp}_${task_id}.md"

  {
    echo "# Search Report"
    echo "Generated: $(date)"
    echo "Task ID: ${task_id}"
    echo "Query: ${query}"
    echo "Scope: ${scope:-auto}"
    echo
  } >"${report_file}"

  local max_hits
  max_hits=50

  local effective_scope
  effective_scope=${scope:-auto}

  if [[ ${effective_scope} == "docs" || ${effective_scope} == "auto" ]]; then
    echo "## Documentation" >>"${report_file}"
    perform_local_search "${query}" "${WORKSPACE}/Documentation" "${max_hits}" >>"${report_file}"
    echo >>"${report_file}"
  fi

  if [[ ${effective_scope} == "code" || ${effective_scope} == "auto" ]]; then
    echo "## Codebase" >>"${report_file}"
    perform_local_search "${query}" "${WORKSPACE}/Projects" "${max_hits}" >>"${report_file}"
    echo >>"${report_file}"

    echo "## Shared Components" >>"${report_file}"
    perform_local_search "${query}" "${WORKSPACE}/Shared" "${max_hits}" >>"${report_file}"
    echo >>"${report_file}"
  fi

  if [[ ${effective_scope} == "automation" || ${effective_scope} == "auto" ]]; then
    echo "## Automation" >>"${report_file}"
    perform_local_search "${query}" "${WORKSPACE}/Tools" "${max_hits}" >>"${report_file}"
    echo >>"${report_file}"
  fi

  log_message "INFO" "Search report created: ${report_file}"

  local summary_path
  summary_path=$(summarize_results "${report_file}" 2>/dev/null)
  if [[ -n ${summary_path} ]]; then
    log_message "INFO" "Search summary created: ${summary_path}"
  fi

  echo "${report_file}"
}

process_search_task() {
  local task_id
  task_id="$1"
  local query
  query="$2"
  local scope
  scope="$3"

  if [[ -z ${query} ]]; then
    log_message "WARN" "Task ${task_id} missing query"
    return 1
  fi

  log_message "INFO" "Running search for task ${task_id}: ${query}"

  local report_path
  report_path=$(generate_search_report "${task_id}" "${query}" "${scope}")
  if [[ -n ${report_path} ]]; then
    log_message "INFO" "Search results stored at ${report_path}"
    return 0
  fi

  return 1
}

process_task() {
  local task_id
  task_id="$1"
  [[ -n ${task_id} ]] || return 1

  if has_processed_task "${task_id}"; then
    log_message "INFO" "Task ${task_id} already processed"
    return 0
  fi

  local query
  query=$(extract_query_from_task "${task_id}")
  if [[ ${query} == "null" ]]; then
    query=""
  fi

  local scope
  scope=$(fetch_task_payload_value "${task_id}" "scope")
  if [[ ${scope} == "null" ]]; then
    scope=""
  fi

  local success="true"
  if ! process_search_task "${task_id}" "${query}" "${scope}"; then
    success="false"
  fi

  if [[ ${success} == "true" ]]; then
    update_task_status "${task_id}" "completed"
    echo "${task_id}" >>"${PROCESSED_TASKS_FILE}"
  else
    update_task_status "${task_id}" "failed"
  fi

  notify_completion "${task_id}" "${success}"
  log_message "INFO" "Task ${task_id} finished with success=${success}"

  [[ ${success} == "true" ]]
}

process_assigned_tasks() {
  [[ -f ${TASK_QUEUE_FILE} ]] || return 1
  command -v jq &>/dev/null || return 1

  local assigned_tasks
  assigned_tasks=$(jq -r ".tasks[] | select(.assigned_agent == \"${AGENT_NAME}\" and (.status == \"assigned\" or .status == \"queued\" or .status == \"in_progress\")) | .id" "${TASK_QUEUE_FILE}" 2>/dev/null)

  local handled=1

  for task_id in ${assigned_tasks}; do
    [[ -n ${task_id} ]] || continue
    if has_processed_task "${task_id}"; then
      continue
    fi

    update_status "busy"
    update_task_status "${task_id}" "in_progress"
    if process_task "${task_id}"; then
      handled=0
    else
      log_message "ERROR" "Task ${task_id} failed"
      handled=0
    fi
    update_status "available"
  done

  return ${handled}
}

process_notification_query() {
  local query
  query="$1"
  local scope
  scope="$2"

  if [[ -z ${query} ]]; then
    log_message "WARN" "Notification search missing query"
    return 1
  fi

  local synthetic_task_id
  synthetic_task_id="notif_$(date +%s)"
  update_status "busy"
  if process_search_task "${synthetic_task_id}" "${query}" "${scope}"; then
    log_message "INFO" "Notification-triggered search completed"
    update_status "available"
    return 0
  else
    log_message "ERROR" "Notification-triggered search failed for query ${query}"
    update_status "available"
    return 1
  fi
}

process_notifications() {
  [[ -f ${NOTIFICATION_FILE} ]] || return 1

  local handled=false
  while IFS='|' read -r _timestamp notification_type payload; do
    case "${notification_type}" in
    "search")
      local query scope
      query=$(echo "${payload}" | cut -d ';' -f 1)
      scope=$(echo "${payload}" | cut -d ';' -f 2)
      if process_notification_query "${query}" "${scope}"; then
        handled=true
      fi
      ;;
    "refresh")
      log_message "INFO" "Refresh signal received"
      update_status "busy"
      run_discovery_cycle
      update_status "available"
      handled=true
      ;;
    "execute_task")
      local task_id
      task_id="${payload}"
      if [[ -n ${task_id} ]] && ! has_processed_task "${task_id}"; then
        update_status "busy"
        update_task_status "${task_id}" "in_progress"
        if process_task "${task_id}"; then
          handled=true
        else
          log_message "ERROR" "Notification task ${task_id} failed"
          handled=true
        fi
        update_status "available"
      fi
      ;;
    esac
  done <"${NOTIFICATION_FILE}"

  : >"${NOTIFICATION_FILE}"
  if [[ ${handled} == true ]]; then
    return 0
  fi
  return 1
}

run_discovery_cycle() {
  local processed=false

  shopt -s nullglob
  local -a query_paths=("${QUERY_DIR}"/*.query)
  shopt -u nullglob

  if ((${#query_paths[@]} == 0)); then
    return 1
  fi

  log_message "INFO" "Running discovery cycle"

  local query_file
  for query_file in "${query_paths[@]}"; do
    processed=true
    local query
    query=$(<"${query_file}")
    log_message "INFO" "Processing legacy query: ${query}"
    process_notification_query "${query}" "auto" || true
    rm -f "${query_file}"
  done

  if [[ ${processed} == true ]]; then
    return 0
  fi
  return 1
}

log_message "INFO" "Search agent starting..."
update_status "starting"
update_agent_pid "$$"
run_discovery_cycle
update_status "available"

sleep_interval=${BASE_SLEEP_INTERVAL}

while true; do
  maybe_update_status "available"

  work_performed=false

  process_notifications && work_performed=true
  process_assigned_tasks && work_performed=true
  run_discovery_cycle && work_performed=true

  if [[ ${work_performed} == true ]]; then
    sleep_interval=${MIN_SLEEP_INTERVAL}
  else
    sleep_interval=$((sleep_interval + 60))
    if ((sleep_interval > MAX_SLEEP_INTERVAL)); then
      sleep_interval=${MAX_SLEEP_INTERVAL}
    fi
  fi

  maybe_update_status "available"
  log_message "INFO" "Sleeping for ${sleep_interval} seconds"
  sleep "${sleep_interval}"
done
