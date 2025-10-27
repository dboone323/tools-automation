#!/bin/bash
# Monitor agents and auto-recover if stopped; detect repeated failures and create debug tasks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_FILE="${SCRIPT_DIR}/agent_supervision.log"
STATUS_FILE="${SCRIPT_DIR}/agent_status.json"
TASK_QUEUE_FILE="${SCRIPT_DIR}/task_queue.json"

# Source shared functions so we can add tasks
source "${SCRIPT_DIR}/shared_functions.sh"

AGENTS=(
    "agent_build.sh"
    "agent_debug.sh"
    "agent_codegen.sh"
)

start_agent() {
    local agent_script="$1"
    echo "[$(date)] Supervisor: Starting ${agent_script}..." | tee -a "$LOG_FILE"
    bash "${SCRIPT_DIR}/${agent_script}" &
    echo "[$(date)] Supervisor: ${agent_script} started with PID $!" | tee -a "$LOG_FILE"
}

ensure_agents_running() {
    for a in "${AGENTS[@]}"; do
        if ! pgrep -f "${SCRIPT_DIR}/${a}" >/dev/null 2>&1; then
            echo "[$(date)] Supervisor: ${a} not running. Restarting..." | tee -a "$LOG_FILE"
            start_agent "$a"
            update_agent_status "$a" "running" $$ ""
        fi
    done
}

check_repeated_failures() {
    # Detect patterns in build/debug logs and create a debug task if threshold exceeded
    local threshold=${1:-3}
    local nowts
    nowts=$(date +%s)

    # Build agent consecutive failure pattern
    if [[ -f "${SCRIPT_DIR}/build_agent.log" ]]; then
        local failures
        failures=$(grep -c "Consecutive failures:" "${SCRIPT_DIR}/build_agent.log" 2>/dev/null || echo 0)
        if ((failures >= threshold)); then
            # Create a debug task assigned to the debug agent
            local task_json
            task_json="{\"id\":\"auto_debug_\"${nowts}\"\",\"type\":\"debug\",\"priority\":1,\"description\":\"Supervisor detected repeated build failures\",\"assigned_agent\":\"agent_debug.sh\",\"status\":\"queued\"}"
            add_task_to_queue "$task_json" >/dev/null 2>&1
            echo "[$(date)] Supervisor: Added auto debug task due to repeated build failures ($failures)" | tee -a "$LOG_FILE"
        fi
    fi
}

# Detect and requeue stuck tasks in 'in_progress' older than N minutes
handle_stuck_tasks() {
    local minutes=${1:-10}
    local cutoff
    cutoff=$(
        date -v -"${minutes}"m +%s 2>/dev/null || python3 - <<PY
import time, sys
print(int(time.time()) - int(sys.argv[1])*60)
PY
        ${minutes}
    )

    if [[ ! -f "${TASK_QUEUE_FILE}" ]]; then
        return
    fi

    python3 - "$TASK_QUEUE_FILE" "$cutoff" <<'PY'
import json, sys, os, tempfile, time
path=sys.argv[1]; cutoff=int(sys.argv[2])
try:
  with open(path,'r') as f:
    data=json.load(f)
  tasks=data.get('tasks', [])
  changed=False
  for t in tasks:
    if isinstance(t, dict) and t.get('status')=='in_progress':
      started=t.get('started_at') or t.get('assigned_at') or 0
      if isinstance(started, str):
        try: started=int(started)
        except: started=0
      if started and started < cutoff:
        # Mark as stuck and requeue
        t['status']='queued'
        t['stuck_requeued_at']=int(time.time())
        t['retry_count']=int(t.get('retry_count',0))+1
        # Clear started markers
        t.pop('started_at', None)
        changed=True
  if changed:
    tmp=path+'.tmp'
    with open(tmp,'w') as w:
      json.dump(data, w, indent=2)
    os.replace(tmp, path)
    print(json.dumps({"stuck_requeued": True}))
  else:
    print(json.dumps({"stuck_requeued": False}))
except Exception as e:
  print(json.dumps({"error": str(e)}))
PY
}

# One-shot run (can be placed on a cron or watch task)
ensure_agents_running
check_repeated_failures 3
handle_stuck_tasks 10

# Monitor long-running processes (>5 minutes) and alert
monitor_long_running_processes() {
    local max_minutes=5
    local alert_file="${SCRIPT_DIR}/long_running_alerts.log"

    echo "[$(date)] Checking for processes running longer than ${max_minutes} minutes..." | tee -a "$LOG_FILE"

    # Get processes with elapsed time (etime format: [[dd-]hh:]mm:ss)
    ps -eo pid,comm,etime | tail -n +2 | while read -r pid comm etime; do
        # Skip system processes by PID (low PIDs are system processes)
        if ((pid < 100)); then continue; fi

        # Skip all system paths
        if [[ "$comm" =~ ^/System/ ]] || [[ "$comm" =~ ^/usr/ ]] || [[ "$comm" =~ ^/sbin/ ]] || [[ "$comm" =~ ^/Library/ ]] || [[ "$comm" =~ ^/Applications/ ]] || [[ "$comm" =~ ^/opt/ ]] || [[ "$comm" =~ ^Contents/ ]]; then
            continue
        fi

        # Skip known system processes and background daemons
        if [[ "$comm" =~ ^(launchd|kernel_task|WindowServer|syslogd|systemsound|coreaudiod|bluetoothd|wifid|usbd|powerd|thermald|crond|automountd|mdworker|mds|Spotlight|coreservicesd|cfprefsd|distnoted|autofsd|scutil|cloudphotod|Core)$ ]] || [[ "$comm" =~ ^com\.(apple|macpaw) ]]; then
            continue
        fi

        # Skip common background processes
        [[ "$comm" == "ps" ]] || [[ "$comm" == "bash" ]] || [[ "$comm" == "sh" ]] && continue
        [[ "$comm" == "login" ]] || [[ "$comm" == "Terminal" ]] || [[ "$comm" == "iTerm2" ]] && continue

        # Parse etime: [[dd-]hh:]mm:ss
        local days=0 hours=0 minutes=0
        if [[ "$etime" =~ ([0-9]+)-([0-9]+):([0-9]+):([0-9]+) ]]; then
            # dd-hh:mm:ss
            days=$((10#${BASH_REMATCH[1]}))
            hours=$((10#${BASH_REMATCH[2]}))
            minutes=$((10#${BASH_REMATCH[3]}))
        elif [[ "$etime" =~ ([0-9]+):([0-9]+):([0-9]+) ]]; then
            # hh:mm:ss
            hours=$((10#${BASH_REMATCH[1]}))
            minutes=$((10#${BASH_REMATCH[2]}))
        elif [[ "$etime" =~ ([0-9]+):([0-9]+) ]]; then
            # mm:ss
            minutes=$((10#${BASH_REMATCH[1]}))
        fi

        # Calculate total minutes
        local total_minutes=$((days * 1440 + hours * 60 + minutes))

        if ((total_minutes > max_minutes)); then
            local alert_msg
            alert_msg="[$(date)] ALERT: Process $pid ($comm) has been running for ${total_minutes} minutes (etime: $etime)"
            echo "$alert_msg" | tee -a "$LOG_FILE" -a "$alert_file"

            # Create a notification task for the user
            local task_id
            task_id="long_running_${pid}_$(date +%s)"
            local task_json="{\"id\":\"${task_id}\",\"type\":\"alert\",\"priority\":2,\"description\":\"Process $pid ($comm) running >${max_minutes}min\",\"assigned_agent\":\"user_attention\",\"status\":\"queued\",\"process_info\":{\"pid\":$pid,\"command\":\"$comm\",\"runtime_minutes\":$total_minutes,\"etime\":\"$etime\"}}"
            add_task_to_queue "$task_json" >/dev/null 2>&1
        fi
    done
}

monitor_long_running_processes

# Show quick status summary
if [[ -f "${STATUS_FILE}" ]]; then
    python3 - "${STATUS_FILE}" <<'PY'
import json, sys, os
p=sys.argv[1]
try:
  with open(p,'r') as f:
    data=json.load(f)
  if isinstance(data, dict) and 'agents' in data:
    agents=list(data['agents'].keys())
  elif isinstance(data, list):
    agents=[a.get('id') or a.get('name') for a in data if isinstance(a, dict)]
  else:
    agents=[]
  print(json.dumps({"agents": agents}))
except Exception as e:
  print(json.dumps({"error": str(e)}))
PY
fi
