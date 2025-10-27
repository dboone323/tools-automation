#!/bin/bash
# Show current alerts and long-running process notifications

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK_QUEUE_FILE="${SCRIPT_DIR}/task_queue.json"
ALERT_LOG="${SCRIPT_DIR}/long_running_alerts.log"

echo "=== CURRENT ALERTS ==="
echo

# Show alert tasks from queue
if [[ -f "$TASK_QUEUE_FILE" ]]; then
    python3 - "$TASK_QUEUE_FILE" <<'PY'
import json, sys
try:
    with open(sys.argv[1], 'r') as f:
        data = json.load(f)
    
    alerts = []
    if 'tasks' in data:
        for task in data['tasks']:
            if task.get('type') == 'alert' and task.get('assigned_agent') == 'user_attention':
                alerts.append(task)
    
    if alerts:
        print(f"Found {len(alerts)} active alerts:")
        print()
        for alert in alerts:
            desc = alert.get('description', 'No description')
            pid = alert.get('process_info', {}).get('pid', 'N/A')
            runtime = alert.get('process_info', {}).get('runtime_minutes', 'N/A')
            cmd = alert.get('process_info', {}).get('command', 'N/A')
            print(f"• ALERT: {desc}")
            print(f"  Process ID: {pid}")
            print(f"  Command: {cmd}")
            print(f"  Runtime: {runtime} minutes")
            print()
    else:
        print("No active alerts found.")
        
except Exception as e:
    print(f"Error reading task queue: {e}")
PY
else
    echo "No task queue file found."
fi

echo
echo "=== RECENT ALERT LOG ==="
echo

# Show recent entries from alert log
if [[ -f "$ALERT_LOG" ]]; then
    echo "Last 10 alert entries:"
    tail -10 "$ALERT_LOG" 2>/dev/null || echo "No recent alerts in log."
else
    echo "No alert log file found."
fi

echo
echo "=== LONG-RUNNING PROCESSES CHECK ==="
echo

# Quick check for currently long-running processes
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

    # Parse etime
    days=0 hours=0 minutes=0
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

    total_minutes=$((days * 1440 + hours * 60 + minutes))

    if ((total_minutes > 5)); then
        echo "⚠️  LONG-RUNNING: PID $pid ($comm) - ${total_minutes} minutes (etime: $etime)"
    fi
done

echo
echo "To clear alerts, run: ./clear_alerts.sh"
