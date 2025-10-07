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
  local status="$2"
  local pid="${3:-$$}"
  local task_id="${4:-}"
  local retry_count=0

  while [[ $retry_count -lt $MAX_RETRIES ]]; do
    if _update_agent_status_locked "$agent_name" "$status" "$pid" "$task_id"; then
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
  local status="$2"
  local pid="$3"
  local task_id="$4"

  # Use flock with timeout (200 is arbitrary file descriptor)
  (
    # Try to acquire lock with timeout
    if ! flock -x -w "$LOCK_TIMEOUT" 200; then
      log_lock_timeout "$agent_name"
      echo "Failed to acquire lock within ${LOCK_TIMEOUT}s" >&2
      return 1
    fi

    # Ensure JSON file exists
    if [[ ! -f "$STATUS_FILE" ]]; then
      echo '{"agents":{},"last_update":0}' >"$STATUS_FILE"
    fi

    # Update status using Python for reliable JSON handling
    python3 <<PYEOF
import json
import time
import sys

try:
    with open("$STATUS_FILE", "r") as f:
        data = json.load(f)

    if "agents" not in data:
        data["agents"] = {}

    agent_data = {
        "status": "$status",
        "last_seen": int(time.time()),
        "pid": $pid
    }

    # Only add tasks_completed if agent already has it
    if "$agent_name" in data["agents"] and "tasks_completed" in data["agents"]["$agent_name"]:
        agent_data["tasks_completed"] = data["agents"]["$agent_name"]["tasks_completed"]

    if "$task_id":
        agent_data["current_task_id"] = "$task_id"

    data["agents"]["$agent_name"] = agent_data
    data["last_update"] = int(time.time())

    with open("$STATUS_FILE", "w") as f:
        json.dump(data, f, indent=2)

    sys.exit(0)
except Exception as e:
    sys.stderr.write(f"Failed to update status: {e}\\n")
    sys.exit(1)
PYEOF

    return $?

  ) 200>"$LOCK_FILE"
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

  (
    if ! flock -x -w "$LOCK_TIMEOUT" 200; then
      log_lock_timeout "$agent_name"
      return 1
    fi

    python3 <<PYEOF
import json
import sys

try:
    with open("$STATUS_FILE", "r") as f:
        data = json.load(f)

    if "agents" in data and "$agent_name" in data["agents"]:
        if "tasks_completed" not in data["agents"]["$agent_name"]:
            data["agents"]["$agent_name"]["tasks_completed"] = 0
        data["agents"]["$agent_name"]["tasks_completed"] += 1

    with open("$STATUS_FILE", "w") as f:
        json.dump(data, f, indent=2)

    sys.exit(0)
except Exception as e:
    sys.stderr.write(f"Failed to increment task count: {e}\\n")
    sys.exit(1)
PYEOF

    return $?

  ) 200>"$LOCK_FILE"
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

# Export functions
export -f update_agent_status
export -f _update_agent_status_locked
export -f increment_task_count
export -f _increment_task_count_locked
export -f should_auto_restart
export -f enable_auto_restart
export -f disable_auto_restart
export -f handle_agent_failure
export -f get_lock_timeout_count
export -f get_recent_lock_timeouts
export -f clear_old_lock_logs
export -f log_lock_timeout
export -f init_monitoring
