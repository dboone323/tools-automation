#!/bin/bash
# Enhanced shared functions for all agents - includes file locking, retry logic, and monitoring

LOCK_FILE="/tmp/agent_status.lock"
LOCK_TIMEOUT_FILE="/tmp/agent_lock_timeouts.log"
STATUS_FILE="${STATUS_FILE:-$(dirname "$0")/agent_status.json}"
MAX_RETRIES="${MAX_RETRIES:-3}"
RETRY_DELAY="${RETRY_DELAY:-1}"
LOCK_TIMEOUT="${LOCK_TIMEOUT:-10}"

# Initialize monitoring
init_monitoring() {
  mkdir -p "$(dirname "$LOCK_TIMEOUT_FILE")"
  if [[ ! -f "$LOCK_TIMEOUT_FILE" ]]; then
    echo "# Agent Lock Timeout Log - $(date)" >"$LOCK_TIMEOUT_FILE"
  fi
}

# Log lock timeout
log_lock_timeout() {
  local agent_name="$1"
  local timestamp=$(date '+%Y-%m-%d %H:%M:%S')
  echo "[$timestamp] LOCK_TIMEOUT: $agent_name failed to acquire lock within ${LOCK_TIMEOUT}s" >>"$LOCK_TIMEOUT_FILE"
}

# Update agent status with file locking and retry logic
update_agent_status() {
  local agent_name="$1"
  local agent_status="$2"
  local pid="${3:-$$}"
  local task_id="${4:-}"
  local retry_count=0

  while [[ $retry_count -lt $MAX_RETRIES ]]; do
    if _update_agent_status_locked "$agent_name" "$agent_status" "$pid" "$task_id"; then
      return 0
    fi

    retry_count=$((retry_count + 1))
    if [[ $retry_count -lt $MAX_RETRIES ]]; then
      echo "Retry $retry_count/$MAX_RETRIES for $agent_name status update..." >&2
      sleep $RETRY_DELAY
    fi
  done

  echo "ERROR: Failed to update $agent_name status after $MAX_RETRIES attempts" >&2
  return 1
}

# Internal function with file locking
_update_agent_status_locked() {
  local agent_name="$1"
  local agent_status="$2"
  local pid="$3"
  local task_id="$4"

  # Simple file-based locking
  while [[ -f "$LOCK_FILE" ]]; do
    sleep 0.1
  done
  touch "$LOCK_FILE"

  # Ensure JSON file exists
  if [[ ! -f "$STATUS_FILE" ]]; then
    echo '{"agents":{},"last_update":0}' >"$STATUS_FILE"
  fi

  # Use Python for reliable JSON handling with atomic writes
  python3 -c "
import json
import time
import tempfile
import os
import sys

try:
    status = sys.argv[1]
    agent_name = sys.argv[2]
    pid = int(sys.argv[3])
    task_id = sys.argv[4] if len(sys.argv) > 4 else ''
    status_file = '$STATUS_FILE'
    
    # Read existing data
    with open(status_file, 'r') as f:
        data = json.load(f)

    if 'agents' not in data:
        data['agents'] = {}

    agent_data = {
        'status': status,
        'last_seen': int(time.time()),
        'pid': pid
    }

    # Only add tasks_completed if agent already has it
    if agent_name in data['agents'] and 'tasks_completed' in data['agents'][agent_name]:
        agent_data['tasks_completed'] = data['agents'][agent_name]['tasks_completed']

    if task_id:
        agent_data['current_task_id'] = task_id

    data['agents'][agent_name] = agent_data
    data['last_update'] = int(time.time())

    # Write to temporary file first, then atomically move
    with tempfile.NamedTemporaryFile(mode='w', dir=os.path.dirname(status_file), delete=False) as temp_file:
        json.dump(data, temp_file, indent=2)
        temp_file.flush()
        os.fsync(temp_file.fileno())  # Force write to disk
        temp_path = temp_file.name
    
    # Atomic move
    os.rename(temp_path, status_file)

    sys.exit(0)
except Exception as e:
    sys.stderr.write(f'Failed to update status: {e}\n')
    sys.exit(1)
" "$agent_status" "$agent_name" "$pid" "$task_id"

  local result=$?
  rm -f "$LOCK_FILE"
  return $result
}

# Increment task counter for agent
increment_task_count() {
  local agent_name="$1"
  local retry_count=0

  while [[ $retry_count -lt $MAX_RETRIES ]]; do
    if _increment_task_count_locked "$agent_name"; then
      return 0
    fi

    retry_count=$((retry_count + 1))
    if [[ $retry_count -lt $MAX_RETRIES ]]; then
      sleep $RETRY_DELAY
    fi
  done

  return 1
}

_increment_task_count_locked() {
  local agent_name="$1"

  # Simple file-based locking
  while [[ -f "$LOCK_FILE" ]]; do
    sleep 0.1
  done
  touch "$LOCK_FILE"

  python3 -c "
import json
import sys

try:
    agent_name = sys.argv[1]
    status_file = '$STATUS_FILE'
    
    with open(status_file, 'r') as f:
        data = json.load(f)

    if 'agents' in data and agent_name in data['agents']:
        if 'tasks_completed' not in data['agents'][agent_name]:
            data['agents'][agent_name]['tasks_completed'] = 0
        data['agents'][agent_name]['tasks_completed'] += 1

    with open(status_file, 'w') as f:
        json.dump(data, f, indent=2)

    sys.exit(0)
except Exception as e:
    sys.stderr.write(f'Failed to increment task count: {e}\n')
    sys.exit(1)
" "$agent_name"

  local result=$?
  rm -f "$LOCK_FILE"
  return $result
}

# Check if a task exists in the queue
task_exists() {
  local task_id="$1"
  local task_queue_file="${TASK_QUEUE_FILE:-${SCRIPT_DIR}/task_queue.json}"

  if [[ ! -f "${task_queue_file}" ]]; then
    return 1
  fi

  # Check if task exists in tasks array
  local exists
  exists=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .id" "${task_queue_file}" 2>/dev/null | wc -l)

  [[ "$exists" -gt 0 ]]
}

# Add a task to the queue
add_task_to_queue() {
  local task_json="$1"
  local task_queue_file="${TASK_QUEUE_FILE:-${SCRIPT_DIR}/task_queue.json}"

  # Ensure task queue file exists
  if [[ ! -f "${task_queue_file}" ]]; then
    echo '{"tasks":[],"completed":[]}' >"${task_queue_file}"
  fi

  # Add task to tasks array
  jq --argjson task "$task_json" '.tasks += [$task]' "${task_queue_file}" > "${task_queue_file}.tmp" && mv "${task_queue_file}.tmp" "${task_queue_file}"
}

# Check if agent should auto-restart
should_auto_restart() {
  local agent_name="$1"
  local auto_restart_file="$(dirname "$0")/.auto_restart_${agent_name}"

  # Check if auto-restart is enabled for this agent
  [[ -f "$auto_restart_file" ]]
}

# Enable auto-restart for agent
enable_auto_restart() {
  local agent_name="$1"
  local auto_restart_file="$(dirname "$0")/.auto_restart_${agent_name}"
  touch "$auto_restart_file"
}

# Disable auto-restart for agent
disable_auto_restart() {
  local agent_name="$1"
  local auto_restart_file="$(dirname "$0")/.auto_restart_${agent_name}"
  rm -f "$auto_restart_file"
}

# Agent failure handler with auto-restart
handle_agent_failure() {
  local agent_name="$1"
  local agent_script="$2"
  local error_msg="${3:-Unknown error}"

  echo "ERROR: $agent_name failed: $error_msg" >&2
  update_agent_status "$agent_name" "failed" $$ ""

  if should_auto_restart "$agent_name"; then
    echo "Auto-restarting $agent_name..." >&2
    sleep 2
    bash "$agent_script" &
    echo "Restarted $agent_name with PID $!" >&2
  fi
}

# Monitor lock timeouts
get_lock_timeout_count() {
  if [[ -f "$LOCK_TIMEOUT_FILE" ]]; then
    grep -c "LOCK_TIMEOUT:" "$LOCK_TIMEOUT_FILE" 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

# Get recent lock timeouts (last N lines)
get_recent_lock_timeouts() {
  local count="${1:-10}"
  if [[ -f "$LOCK_TIMEOUT_FILE" ]]; then
    tail -n "$count" "$LOCK_TIMEOUT_FILE"
  fi
}

# Clear old lock timeout logs (older than N days)
clear_old_lock_logs() {
  local days="${1:-7}"
  if [[ -f "$LOCK_TIMEOUT_FILE" ]]; then
    local temp_file="${LOCK_TIMEOUT_FILE}.tmp"
    local cutoff_date=$(date -v-${days}d '+%Y-%m-%d' 2>/dev/null || date -d "${days} days ago" '+%Y-%m-%d')

    awk -v cutoff="$cutoff_date" '
            /^\[/ {
                if ($1 >= "[" cutoff) print
                next
            }
            { print }
        ' "$LOCK_TIMEOUT_FILE" >"$temp_file"

    mv "$temp_file" "$LOCK_TIMEOUT_FILE"
  fi
}

# Initialize monitoring on source
init_monitoring

# Task Management Functions
get_next_task() {
  local agent_name="$1"
  local task_queue_file="${TASK_QUEUE_FILE:-${SCRIPT_DIR}/task_queue.json}"

  # Find the first queued task assigned to this agent
  jq -r ".tasks[] | select(.assigned_agent == \"${agent_name}\" and .status == \"queued\") | .id" "${task_queue_file}" 2>/dev/null | head -1
}

update_task_status() {
  local task_id="$1"
  local new_status="$2"
  local task_queue_file="${TASK_QUEUE_FILE:-${SCRIPT_DIR}/task_queue.json}"
  local timestamp
  timestamp=$(date +%s)

  if [[ ! -f "${task_queue_file}" ]]; then
    echo "Task queue file not found: ${task_queue_file}" >&2
    return 1
  fi

  # Update task status and add timestamps
  jq --arg task_id "$task_id" --arg new_status "$new_status" --arg timestamp "$timestamp" '
    .tasks |= map(
      if .id == $task_id then
        .status = $new_status |
        if $new_status == "in_progress" then
          .started_at = ($timestamp | tonumber)
        elif $new_status == "completed" then
          .completed_at = ($timestamp | tonumber)
        elif $new_status == "failed" then
          .failed_at = ($timestamp | tonumber)
        end
      else
        .
      end
    )
  ' "${task_queue_file}" > "${task_queue_file}.tmp" && mv "${task_queue_file}.tmp" "${task_queue_file}"
}

get_task_details() {
  local task_id="$1"
  local task_queue_file="${TASK_QUEUE_FILE:-${SCRIPT_DIR}/task_queue.json}"

  jq -r ".tasks[] | select(.id == \"${task_id}\")" "${task_queue_file}" 2>/dev/null
}

complete_task() {
  local task_id="$1"
  local success="${2:-true}"

  if [[ "$success" == "true" ]]; then
    update_task_status "$task_id" "completed"
    # Move to completed array
    move_task_to_completed "$task_id"
  else
    update_task_status "$task_id" "failed"
  fi
}

move_task_to_completed() {
  local task_id="$1"
  local task_queue_file="${TASK_QUEUE_FILE:-${SCRIPT_DIR}/task_queue.json}"

  # Get the completed task
  local task_data
  task_data=$(jq ".tasks[] | select(.id == \"${task_id}\")" "${task_queue_file}")

  if [[ -n "$task_data" ]]; then
    # Add to completed array
    jq --argjson task "$task_data" '.completed += [$task]' "${task_queue_file}" > "${task_queue_file}.tmp" && mv "${task_queue_file}.tmp" "${task_queue_file}"

    # Remove from tasks array
    jq "del(.tasks[] | select(.id == \"${task_id}\"))" "${task_queue_file}" > "${task_queue_file}.tmp" && mv "${task_queue_file}.tmp" "${task_queue_file}"
  fi
}

# Export functions
export -f update_agent_status
export -f _update_agent_status_locked
export -f increment_task_count
export -f _increment_task_count_locked
export -f task_exists
export -f add_task_to_queue
export -f should_auto_restart
export -f enable_auto_restart
export -f disable_auto_restart
export -f handle_agent_failure
export -f get_lock_timeout_count
export -f get_recent_lock_timeouts
export -f clear_old_lock_logs
export -f log_lock_timeout
export -f init_monitoring
export -f get_next_task
export -f update_task_status
export -f get_task_details
export -f complete_task
export -f move_task_to_completed
