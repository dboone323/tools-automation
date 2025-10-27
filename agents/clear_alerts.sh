#!/bin/bash
# Clear processed alerts from the task queue

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TASK_QUEUE_FILE="${SCRIPT_DIR}/task_queue.json"
ALERT_LOG="${SCRIPT_DIR}/long_running_alerts.log"

echo "Clearing processed alerts..."

# Remove alert tasks from queue
if [[ -f "$TASK_QUEUE_FILE" ]]; then
    python3 - "$TASK_QUEUE_FILE" <<'PY'
import json, sys, tempfile, os
try:
    with open(sys.argv[1], 'r') as f:
        data = json.load(f)
    
    if 'tasks' in data:
        original_count = len(data['tasks'])
        # Keep only non-alert tasks
        data['tasks'] = [t for t in data['tasks'] if not (t.get('type') == 'alert' and t.get('assigned_agent') == 'user_attention')]
        new_count = len(data['tasks'])
        
        # Write back if changed
        if new_count != original_count:
            with tempfile.NamedTemporaryFile(mode='w', dir=os.path.dirname(sys.argv[1]), delete=False) as temp_file:
                json.dump(data, temp_file, indent=2)
                temp_file.flush()
                os.fsync(temp_file.fileno())
                temp_path = temp_file.name
            os.rename(temp_path, sys.argv[1])
            print(f"Cleared {original_count - new_count} alert tasks from queue.")
        else:
            print("No alert tasks to clear.")
    else:
        print("No tasks in queue.")
        
except Exception as e:
    print(f"Error clearing alerts: {e}")
PY
else
    echo "No task queue file found."
fi

# Optionally archive the alert log
if [[ -f "$ALERT_LOG" ]]; then
    mv "$ALERT_LOG" "${ALERT_LOG}.$(date +%Y%m%d_%H%M%S).bak" 2>/dev/null
    echo "Archived alert log."
fi

echo "Done."
