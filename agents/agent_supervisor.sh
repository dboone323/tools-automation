#!/usr/bin/env bash
# Agent Supervisor: Starts and monitors all agents

AGENTS_DIR="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents"
LOG_FILE="${AGENTS_DIR}/supervisor.log"

# Ensure running in bash
if [[ -z ${BASH_VERSION} ]]; then
  echo "This script must be run with bash."
  exec bash "$0" "$@"
  exit 1
fi

AGENT_PIDS_FILE="$(dirname "$0")/agent_pids.txt"
AGENT_LOGS_FILE="$(dirname "$0")/agent_logs.txt"
AGENT_RESTART_COUNT_FILE="$(dirname "$0")/agent_restart_count.txt"
AGENT_LAST_RESTART_FILE="$(dirname "$0")/agent_last_restart.txt"
SUPERVISOR_PID_FILE="$(dirname "$0")/agent_supervisor.pid"
STATUS_FILE="${AGENTS_DIR}/agent_status.json"
STATUS_UTIL="${AGENTS_DIR}/status_utils.py"

MANAGED_AGENTS=(
  "agent_build.sh"
  "agent_debug.sh"
  "agent_codegen.sh"
  "agent_todo.sh"
  "testing_agent.sh"
  "uiux_agent.sh"
  "apple_pro_agent.sh"
  "collab_agent.sh"
  "updater_agent.sh"
  "search_agent.sh"
  "pull_request_agent.sh"
  "auto_update_agent.sh"
  "knowledge_base_agent.sh"
  "code_review_agent.sh"
  "documentation_agent.sh"
  "public_api_agent.sh"
  "security_agent.sh"
  "agent_security.sh"
  "performance_agent.sh"
  "agent_performance_monitor.sh"
  "monitoring_agent.sh"
  "quality_agent.sh"
  "learning_agent.sh"
  "deployment_agent.sh"
  "agent_uiux.sh"
  "agent_testing.sh"
  "task_orchestrator.sh"
  "unified_dashboard_agent.sh"
)

declare -A STATUS_ALIAS_MAP=(
  ["agent_build.sh"]="build_agent"
  ["agent_debug.sh"]="debug_agent"
  ["agent_codegen.sh"]="codegen_agent"
  ["public_api_agent.sh"]="public_api_agent"
  ["search_agent.sh"]="search_agent"
  ["security_agent.sh"]="security_agent"
  ["uiux_agent.sh"]="uiux_agent"
  ["testing_agent.sh"]="testing_agent"
  ["performance_agent.sh"]="performance_monitor"
  ["task_orchestrator.sh"]="task_orchestrator"
)

if [[ ! -f ${STATUS_FILE} ]]; then
  echo '{"agents":{},"last_update":0}' >"${STATUS_FILE}"
fi

# --- Utility functions ---
# Return 1 if the string is an integer (optionally negative), else 0
is_int() {
  local v="$1"
  [[ ${v} =~ ^-?[0-9]+$ ]]
}

# Sanitize a value to an integer or default to 0
sanitize_int() {
  local v="$1"
  if is_int "${v}"; then
    echo "${v}"
  else
    echo 0
  fi
}

# Read exact key value (key:val format) from a KV file; prints first match
kv_read_value() {
  local file="$1" key="$2"
  [[ -f ${file} ]] || return 1
  awk -F: -v a="${key}" '($1==a){print $2; exit}' "${file}"
}

# Delete exact key (key:val) lines from a KV file in-place (portable on macOS/Linux)
kv_delete_key() {
  local file="$1" key="$2"
  [[ -f ${file} ]] || {
    : >"${file}"
    return 0
  }
  local tmp="${file}.tmp.$$"
  awk -F: -v a="${key}" '($1!=a){print $0}' "${file}" >"${tmp}" && mv "${tmp}" "${file}"
}

status_keys_for() {
  local agent_script="$1"
  local -a keys
  keys=("${agent_script}")
  if [[ -n ${STATUS_ALIAS_MAP["${agent_script}"]+x} ]]; then
    keys+=("${STATUS_ALIAS_MAP["${agent_script}"]}")
  fi
  printf '%s\n' "${keys[@]}"
}

legacy_set_agent_status() {
  local agent_script="$1"
  local status="$2"

  [[ -f ${STATUS_FILE} ]] || return

  local now
  now=$(date +%s)
  local content
  content=$(cat "${STATUS_FILE}" 2>/dev/null)
  if [[ -z ${content} ]]; then
    content='{"agents":{},"last_update":0}'
  fi

  local temp_file
  temp_file="${STATUS_FILE}.tmp.$$"
  local key
  while IFS= read -r key; do
    [[ -n ${key} ]] || continue
    content=$(echo "${content}" | jq \
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
           | map(if (["pid","last_seen","tasks_completed","restart_count"]
                     | index(.key)) != null
                 then .value = (.value | to_num) else . end)
           | from_entries)
       | .last_update = $now' 2>/dev/null) || return
  done < <(status_keys_for "${agent_script}")

  echo "${content}" >"${temp_file}" && mv "${temp_file}" "${STATUS_FILE}"
}

update_agent_entry_python() {
  local agent_script="$1"
  shift
  [[ -f ${STATUS_UTIL} ]] || return 1

  local key
  local result=0
  while IFS= read -r key; do
    [[ -n ${key} ]] || continue
    if ! python3 "${STATUS_UTIL}" update-agent \
      --status-file "${STATUS_FILE}" \
      --agent "${key}" "$@" >/dev/null 2>&1; then
      result=1
    fi
  done < <(status_keys_for "${agent_script}")

  return ${result}
}

# Initialize agent logs (static mapping)
cat >"${AGENT_LOGS_FILE}" <<EOF
agent_build.sh:${AGENTS_DIR}/build_agent.log
agent_debug.sh:${AGENTS_DIR}/debug_agent.log
agent_codegen.sh:${AGENTS_DIR}/codegen_agent.log
agent_todo.sh:${AGENTS_DIR}/todo_agent.log
testing_agent.sh:${AGENTS_DIR}/testing_agent.log
uiux_agent.sh:${AGENTS_DIR}/uiux_agent.log
apple_pro_agent.sh:${AGENTS_DIR}/apple_pro_agent.log
collab_agent.sh:${AGENTS_DIR}/collab_agent.log
updater_agent.sh:${AGENTS_DIR}/updater_agent.log
search_agent.sh:${AGENTS_DIR}/search_agent.log
pull_request_agent.sh:${AGENTS_DIR}/pull_request_agent.log
auto_update_agent.sh:${AGENTS_DIR}/auto_update_agent.log
knowledge_base_agent.sh:${AGENTS_DIR}/knowledge_base_agent.log
code_review_agent.sh:${AGENTS_DIR}/code_review_agent.log
documentation_agent.sh:${AGENTS_DIR}/documentation_agent.log
public_api_agent.sh:${AGENTS_DIR}/public_api_agent.log
security_agent.sh:${AGENTS_DIR}/security_agent.log
performance_agent.sh:${AGENTS_DIR}/performance_agent.log
monitoring_agent.sh:${AGENTS_DIR}/monitoring_agent.log
agent_performance_monitor.sh:${AGENTS_DIR}/performance_monitor.log
learning_agent.sh:${AGENTS_DIR}/learning_agent.log
quality_agent.sh:${AGENTS_DIR}/quality_agent.log
deployment_agent.sh:${AGENTS_DIR}/deployment_agent.log
agent_security.sh:${AGENTS_DIR}/agent_security.log
agent_uiux.sh:${AGENTS_DIR}/agent_uiux.log
agent_testing.sh:${AGENTS_DIR}/agent_testing.log
task_orchestrator.sh:${AGENTS_DIR}/task_orchestrator.log
unified_dashboard_agent.sh:${AGENTS_DIR}/unified_dashboard_agent.log
EOF

# Initialize empty files if they don't exist
touch "${AGENT_PIDS_FILE}"
touch "${AGENT_RESTART_COUNT_FILE}"
touch "${AGENT_LAST_RESTART_FILE}"
RESTART_LIMIT=5
RESTART_THROTTLE=60 # 1 minute between restarts

# Ensure a value is a non-negative integer; otherwise fallback to 0
to_int_or_zero() {
  local v="$1"
  if [[ "$v" =~ ^-?[0-9]+$ ]]; then
    echo "$v"
  else
    echo 0
  fi
}

# Log rotation function (keep logs <10MB)
rotate_log() {
  local log_file="$1"
  local max_size=10485760 # 10MB
  if [[ -f ${log_file} ]]; then
    local size
    size=$(stat -f%z "${log_file}")
    if ((size > max_size)); then
      mv "${log_file}" "${log_file}.old"
      echo "[$(date)] Log rotated: ${log_file}" >"${log_file}"
    fi
  fi
}

get_existing_agent_pids() {
  local agent_script
  agent_script="$1"
  local alt_agents_dir
  alt_agents_dir="${AGENTS_DIR%/Automation/agents}/agents"
  {
    pgrep -f "${AGENTS_DIR}/${agent_script}" 2>/dev/null
    pgrep -f "${alt_agents_dir}/${agent_script}" 2>/dev/null
    pgrep -f "[[:space:]]${agent_script}" 2>/dev/null
  } | sort -u
}

is_agent_running() {
  local agent_script pids
  agent_script="$1"
  pids=$(get_existing_agent_pids "${agent_script}")
  [[ -n ${pids} ]]
}

record_agent_pid() {
  local agent_script pid
  agent_script="$1"
  pid="$2"
  kv_delete_key "${AGENT_PIDS_FILE}" "${agent_script}"
  echo "${agent_script}:${pid}" >>"${AGENT_PIDS_FILE}"

  if ! update_agent_entry_python "${agent_script}" --set-field "pid=${pid}" >/dev/null 2>&1; then
    if command -v jq &>/dev/null; then
      local temp_file="${STATUS_FILE}.tmp.$$"
      local content
      content=$(cat "${STATUS_FILE}" 2>/dev/null)
      if [[ -z ${content} ]]; then
        content='{"agents":{},"last_update":0}'
      fi
      local key
      while IFS= read -r key; do
        [[ -n ${key} ]] || continue
        content=$(echo "${content}" | jq --arg agent "${key}" --arg pid "${pid}" '
          def to_clean_pid:
            if (test("^\\s*-?[0-9]+\\s*$")) then (gsub("^\\s+|\\s+$"; "") | tonumber) else 0 end;
          .agents[$agent] = (.agents[$agent] // {})
          | .agents[$agent].pid = ($pid | to_clean_pid)
        ' 2>/dev/null) || break
      done < <(status_keys_for "${agent_script}")
      if [[ -n ${content} ]]; then
        echo "${content}" >"${temp_file}" && mv "${temp_file}" "${STATUS_FILE}"
      fi
    fi
  fi
}

set_agent_status() {
  local agent_script="$1"
  local status="$2"

  if ! update_agent_entry_python "${agent_script}" --status "${status}" >/dev/null 2>&1; then
    legacy_set_agent_status "${agent_script}" "${status}"
  fi
}

start_agent() {
  local agent_script primary_pid
  local -a existing_pids duplicates
  agent_script="$1"

  # Normalize any already-running processes so we do not spawn duplicates.
  while IFS= read -r pid; do
    [[ -n ${pid} ]] && existing_pids+=("${pid}")
  done < <(get_existing_agent_pids "${agent_script}")

  if ((${#existing_pids[@]} > 0)); then
    primary_pid="${existing_pids[0]}"
    record_agent_pid "${agent_script}" "${primary_pid}"
    set_agent_status "${agent_script}" "available"
    if ((${#existing_pids[@]} > 1)); then
      duplicates=("${existing_pids[@]:1}")
      for duplicate_pid in "${duplicates[@]}"; do
        if [[ "${duplicate_pid}" != "${primary_pid}" ]]; then
          kill "${duplicate_pid}" 2>/dev/null
          echo "${agent_script} duplicate PID ${duplicate_pid} terminated" >>"${LOG_FILE}"
        fi
      done
    fi
    echo "${agent_script} already running (PID ${primary_pid})" >>"${LOG_FILE}"
    return
  fi

  # Special-case unified_dashboard_agent: Also treat Tools/agents instance as the source of truth
  if [[ "${agent_script}" == "unified_dashboard_agent.sh" ]]; then
    local ext_pid
    ext_pid=$(pgrep -f "${AGENTS_DIR%/Automation/agents}/agents/${agent_script}" 2>/dev/null | head -n1 || true)
    if [[ -n "${ext_pid}" ]]; then
      record_agent_pid "${agent_script}" "${ext_pid}"
      set_agent_status "${agent_script}" "available"
      echo "${agent_script} external instance detected (PID ${ext_pid}); not spawning duplicate." >>"${LOG_FILE}"
      return
    fi
  fi

  set_agent_status "${agent_script}" "starting"
  nohup bash "${AGENTS_DIR}/${agent_script}" >>"${LOG_FILE}" 2>&1 &
  local pid=$!
  record_agent_pid "${agent_script}" "${pid}"
  echo "${agent_script} started with PID ${pid}" >>"${LOG_FILE}"
  sleep 1
  if is_agent_running "${agent_script}"; then
    set_agent_status "${agent_script}" "available"
  fi
}

stop_agent() {
  local agent_script="$1"
  local -a pids
  while IFS= read -r pid; do
    [[ -n ${pid} ]] && pids+=("${pid}")
  done < <(get_existing_agent_pids "${agent_script}")

  if ((${#pids[@]} == 0)); then
    # Nothing running; still mark as stopped and clear pid
    update_agent_entry_python "${agent_script}" --status stopped --clear-pid >/dev/null 2>&1 || legacy_set_agent_status "${agent_script}" stopped
    return 0
  fi

  for pid in "${pids[@]}"; do
    kill "${pid}" 2>/dev/null || true
  done
  sleep 1
  # Force kill if still alive
  for pid in "${pids[@]}"; do
    if kill -0 "${pid}" 2>/dev/null; then
      kill -9 "${pid}" 2>/dev/null || true
    fi
  done
  update_agent_entry_python "${agent_script}" --status stopped --clear-pid >/dev/null 2>&1 || legacy_set_agent_status "${agent_script}" stopped
  # Remove from PIDs file
  kv_delete_key "${AGENT_PIDS_FILE}" "${agent_script}"
}

start_all_agents() {
  echo "[$(date)] Supervisor: Starting managed agents..." >>"${LOG_FILE}"
  for agent in "${MANAGED_AGENTS[@]}"; do
    start_agent "${agent}"
  done
  echo "[$(date)] Supervisor: Agent launch sequence complete." >>"${LOG_FILE}"
}

stop_all_agents() {
  echo "[$(date)] Supervisor: Stopping managed agents..." >>"${LOG_FILE}"
  for agent in "${MANAGED_AGENTS[@]}"; do
    stop_agent "${agent}" || true
  done
  echo "[$(date)] Supervisor: Stop sequence complete." >>"${LOG_FILE}"
}

restart_agent() {
  local agent_script="$1"
  local pid
  pid=$(kv_read_value "${AGENT_PIDS_FILE}" "${agent_script}")
  if [[ -n ${pid} ]]; then
    kill "${pid}" 2>/dev/null || true
    echo "${agent_script} (PID ${pid}) killed for restart." >>"${LOG_FILE}"
    kv_delete_key "${AGENT_PIDS_FILE}" "${agent_script}"
  fi
  set_agent_status "${agent_script}" "restarting"
  # Throttle and limit restarts
  local now last_restart count
  now=$(date +%s)
  last_restart=$(sanitize_int "$(kv_read_value "${AGENT_LAST_RESTART_FILE}" "${agent_script}" || echo 0)")
  count=$(sanitize_int "$(kv_read_value "${AGENT_RESTART_COUNT_FILE}" "${agent_script}" || echo 0)")

  if ((now - last_restart < RESTART_THROTTLE)); then
    echo "[$(date)] Supervisor: Throttling restart of ${agent_script} (too soon)." >>"${LOG_FILE}"
    return
  fi
  if ((count >= RESTART_LIMIT)); then
    echo "[$(date)] Supervisor: Restart limit reached for ${agent_script}. Not restarting." >>"${LOG_FILE}"
    return
  fi

  # Proceed restart
  start_agent "${agent_script}"
  # Update restart tracking
  kv_delete_key "${AGENT_LAST_RESTART_FILE}" "${agent_script}"
  echo "${agent_script}:${now}" >>"${AGENT_LAST_RESTART_FILE}"
  local new_count=$((count + 1))
  kv_delete_key "${AGENT_RESTART_COUNT_FILE}" "${agent_script}"
  echo "${agent_script}:${new_count}" >>"${AGENT_RESTART_COUNT_FILE}"
  echo "${agent_script} restarted." >>"${LOG_FILE}"
}

cleanup_task_queue() {
  local queue_file="${AGENTS_DIR}/task_queue.json"
  [[ -f ${queue_file} ]] || return 0
  
  # Use Python to clean old tasks (keep only recent/active)
  python3 - <<'PYCLEAN' >"${LOG_FILE}" 2>&1
import json
from datetime import datetime, timedelta

try:
    with open('${AGENTS_DIR}/task_queue.json') as f:
        data = json.load(f)
    
    original_count = len(data.get("tasks", []))
    if original_count < 1000:  # Skip if not bloated
        exit(0)
    
    now = datetime.now()
    cutoff_queued = now - timedelta(hours=24)
    cutoff_completed = now - timedelta(hours=6)
    
    kept_tasks = []
    for task in data.get("tasks", []):
        status = task.get("status", "unknown")
        try:
            task_time = datetime.fromtimestamp(float(task.get("created_at", 0)))
        except:
            task_time = datetime.min
        
        if status == "in_progress":
            kept_tasks.append(task)
        elif status == "queued" and task_time > cutoff_queued:
            kept_tasks.append(task)
        elif status in ["completed", "failed"] and task_time > cutoff_completed:
            kept_tasks.append(task)
    
    data["tasks"] = kept_tasks
    
    with open('${AGENTS_DIR}/task_queue.json', 'w') as f:
        json.dump(data, f, indent=2)
    
    print(f"[{datetime.now()}] Cleaned task_queue: {original_count} -> {len(kept_tasks)} tasks")
except Exception as e:
    print(f"[{datetime.now()}] Task queue cleanup failed: {e}")
PYCLEAN
  echo "[$(date)] Supervisor: Task queue cleanup completed." >>"${LOG_FILE}"
}

run_supervisor_loop() {
  echo "$$" >"${SUPERVISOR_PID_FILE}"
  # Supervisor main loop: monitor logs and restart agents on error/rollback
  while true; do
    for agent in "${MANAGED_AGENTS[@]}"; do
      if ! is_agent_running "${agent}"; then
        echo "[$(date)] Supervisor: ${agent} not running, restarting." >>"${LOG_FILE}"
        set_agent_status "${agent}" "stopped"
        start_agent "${agent}"
        continue
      fi

      log_file=$(grep "^${agent}:" "${AGENT_LOGS_FILE}" | cut -d: -f2)
      [[ -n ${log_file} ]] || continue
      rotate_log "${log_file}"
      if [[ -f ${log_file} ]]; then
        if tail -40 "${log_file}" | grep -q -E 'ROLLBACK|error|❌'; then
          echo "[$(date)] Supervisor: Detected error/rollback in ${agent}. Restarting..." >>"${LOG_FILE}"
          restart_agent "${agent}"
          continue
        fi
        if tail -40 "${log_file}" | grep -q 'multi-level backup'; then
          echo "[$(date)] Supervisor: Backup event detected in ${agent}." >>"${LOG_FILE}"
        fi
        if tail -40 "${log_file}" | grep -q 'restoring last backup'; then
          echo "[$(date)] Supervisor: Restore event detected in ${agent}." >>"${LOG_FILE}"
        fi
      fi
    done
    rotate_log "${LOG_FILE}"

    # Periodically run AI log analyzer and report findings
    now_epoch=$(date +%s)
    if ((now_epoch % 300 < 5)); then # every ~5 minutes
      ANALYZER="$(dirname "$0")/ai_log_analyzer.py"
      if [[ -x ${ANALYZER} || -f ${ANALYZER} ]]; then
        python3 "${ANALYZER}" >>"${LOG_FILE}" 2>&1
        if [[ -f "$(dirname "$0")/ai_log_analysis.txt" ]]; then
          tail -20 "$(dirname "$0")/ai_log_analysis.txt" | while read -r line; do
            echo "[$(date)] Supervisor: AI Log Analyzer: ${line}" >>"${LOG_FILE}"
          done
        fi
      fi
    fi
    
    # Periodically clean task queue to prevent bloat
    if ((now_epoch % 3600 < 5)); then # every ~1 hour
      cleanup_task_queue
    fi
    
    sleep 120 # Check every 2 minutes
  done
}

start_dashboard() {
  local pidfile="${AGENTS_DIR}/dashboard_server.pid"
  local script="${AGENTS_DIR}/dashboard_api_server.py"
  if [[ -f ${pidfile} ]] && kill -0 "$(cat "${pidfile}")" 2>/dev/null; then
    echo "Dashboard already running (PID $(cat "${pidfile}"))" >>"${LOG_FILE}"
    return 0
  fi
  if [[ -f ${script} ]]; then
    nohup python3 "${script}" >>"${LOG_FILE}" 2>&1 &
    echo $! >"${pidfile}"
    echo "Dashboard started (PID $(cat "${pidfile}"))" >>"${LOG_FILE}"
    return 0
  fi
  return 1
}

stop_dashboard() {
  local pidfile="${AGENTS_DIR}/dashboard_server.pid"
  if [[ -f ${pidfile} ]]; then
    local pid
    pid=$(cat "${pidfile}" 2>/dev/null)
    if [[ -n ${pid} ]]; then
      kill "${pid}" 2>/dev/null || true
      sleep 1
      kill -9 "${pid}" 2>/dev/null || true
    fi
    rm -f "${pidfile}"
    echo "Dashboard stopped" >>"${LOG_FILE}"
  fi
}

# Command dispatch
cmd=${1:-start}
case "${cmd}" in
start)
  start_all_agents
  start_dashboard || true
  run_supervisor_loop
  ;;
stop)
  stop_dashboard || true
  stop_all_agents || true
  # Stop supervisor loop if running
  if [[ -f ${SUPERVISOR_PID_FILE} ]]; then
    sup_pid=$(cat "${SUPERVISOR_PID_FILE}" 2>/dev/null)
    if [[ -n ${sup_pid} ]]; then
      kill "${sup_pid}" 2>/dev/null || true
    fi
    rm -f "${SUPERVISOR_PID_FILE}"
  fi
  exit 0
  ;;
restart)
  stop_dashboard || true
  stop_all_agents || true
  start_all_agents
  start_dashboard || true
  run_supervisor_loop
  ;;
status)
  echo "Managed agents: ${#MANAGED_AGENTS[@]}"
  for agent in "${MANAGED_AGENTS[@]}"; do
    if is_agent_running "${agent}"; then
      echo "${agent}: running"
    else
      echo "${agent}: stopped"
    fi
  done
  exit 0
  ;;
*)
  echo "Usage: $0 {start|stop|restart|status}"
  exit 1
  ;;
esac
