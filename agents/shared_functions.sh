#!/bin/bash
# Simplified shared functions for agent coordination and task management

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_FILE="${SCRIPT_DIR}/agent_status.json"
TASK_QUEUE_FILE="${SCRIPT_DIR}/task_queue.json"

# Initialize monitoring
init_monitoring() {
    echo "DEBUG: shared_functions.sh sourced" >&2
}

# Update agent status
update_agent_status() {
    local agent_name="$1"
    local agent_status="$2"
    local pid="${3:-$$}"
    local task_id="${4:-}"

    # Use the dedicated Python script for reliable status updates
    echo "DEBUG: update_agent_status called for $agent_name with status=$agent_status, pid=$pid, task_id=$task_id" >&2
    echo "DEBUG: Using update_status.py script" >&2
    echo "DEBUG: About to call update_status.py" >&2
    STATUS_FILE="$STATUS_FILE" python3 "${SCRIPT_DIR}/update_status.py" "$agent_status" "$agent_name" "$pid" "$task_id" 2>&1
    return $?
}

# Get next task for agent
get_next_task() {
    local agent_name="$1"

    # Get next task using Python
    python3 -c "
import json
import sys
import tempfile
import os
import time

try:
    agent_name = sys.argv[1]
    task_queue_file = '${TASK_QUEUE_FILE}'

    with open(task_queue_file, 'r') as f:
        data = json.load(f)

    # Build acceptable name aliases
    aliases = {agent_name}
    base = agent_name
    if base.endswith('.sh'):
        base = base[:-3]
    if base.startswith('agent_'):
        short = base[len('agent_'):]
        aliases.add(f'{short}_agent')
        aliases.add(base)
    else:
        aliases.add(f'agent_{base}')
        aliases.add(f'{base}_agent')

    if 'tasks' in data:
        for task in data['tasks']:
            assigned = task.get('assigned_agent') or task.get('assigned_to')
            status = task.get('status')
            if (assigned in aliases and status in ('queued', 'assigned')):
                print(json.dumps(task))
                sys.exit(0)

    # No task found
    sys.exit(1)
except Exception as e:
    sys.exit(1)
" "$agent_name"
}

# Update task status
update_task_status() {
    local task_id="$1"
    local new_status="$2"

    # Update task status using Python
    python3 -c "
import json
import sys
import tempfile
import os
import time

try:
    task_id = sys.argv[1]
    new_status = sys.argv[2]
    task_queue_file = '${TASK_QUEUE_FILE}'
    timestamp = int(time.time())
    
    with open(task_queue_file, 'r') as f:
        data = json.load(f)
    
    if 'tasks' in data:
        for task in data['tasks']:
            if task.get('id') == task_id:
                task['status'] = new_status
                if new_status == 'in_progress':
                    task['started_at'] = timestamp
                elif new_status == 'completed':
                    task['completed_at'] = timestamp
                elif new_status == 'failed':
                    task['failed_at'] = timestamp
                break
    
    # Write to temporary file first, then atomically move
    with tempfile.NamedTemporaryFile(mode='w', dir=os.path.dirname(task_queue_file), delete=False) as temp_file:
        json.dump(data, temp_file, indent=2)
        temp_file.flush()
        os.fsync(temp_file.fileno())
        temp_path = temp_file.name
    
    os.rename(temp_path, task_queue_file)
    print('Task status updated successfully')
except Exception as e:
    print(f'Failed to update task status: {e}', file=sys.stderr)
    sys.exit(1)
" "$task_id" "$new_status"
}

# Add task to queue
add_task_to_queue() {
    local task_json="$1"

    # Add task using Python
    python3 -c "
import json
import sys
import tempfile
import os
import time

try:
    task_json_str = sys.argv[1]
    task_queue_file = '${TASK_QUEUE_FILE}'
    
    # Parse the task JSON
    task = json.loads(task_json_str)
    
    # Read existing queue
    if os.path.exists(task_queue_file):
        with open(task_queue_file, 'r') as f:
            data = json.load(f)
    else:
        data = {'tasks': []}
    
    # Add timestamp if not present
    if 'created_at' not in task:
        task['created_at'] = int(time.time())
    
    # Add to tasks list
    if 'tasks' not in data:
        data['tasks'] = []
    data['tasks'].append(task)
    
    # Write to temporary file first, then atomically move
    with tempfile.NamedTemporaryFile(mode='w', dir=os.path.dirname(task_queue_file), delete=False) as temp_file:
        json.dump(data, temp_file, indent=2)
        temp_file.flush()
        os.fsync(temp_file.fileno())
        temp_path = temp_file.name
    
    os.rename(temp_path, task_queue_file)
    print('Task added to queue successfully')
except Exception as e:
    print(f'Failed to add task to queue: {e}', file=sys.stderr)
    sys.exit(1)
" "$task_json"
}

# Set resource limits to prevent system overload
set_resource_limits() {
    local cpu_seconds="${1:-300}"  # Default 5 minutes CPU time
    local memory_kb="${2:-524288}" # Default 512MB memory
    local max_processes="${3:-50}" # Default max processes

    echo "DEBUG: Setting resource limits - CPU: ${cpu_seconds}s, Memory: ${memory_kb}KB, Processes: ${max_processes}" >&2

    # Set CPU time limit (seconds)
    ulimit -t "$cpu_seconds" 2>/dev/null || echo "WARNING: Could not set CPU time limit" >&2

    # Set memory limit (kilobytes)
    ulimit -v "$memory_kb" 2>/dev/null || echo "WARNING: Could not set memory limit" >&2

    # Set max user processes
    ulimit -u "$max_processes" 2>/dev/null || echo "WARNING: Could not set process limit" >&2

    # Set file size limit to prevent runaway log files (100MB)
    ulimit -f 102400 2>/dev/null || echo "WARNING: Could not set file size limit" >&2
}

# Execute command with resource limits
with_resource_limits() {
    local cpu_seconds="${1:-300}"
    local memory_kb="${2:-524288}"
    local max_processes="${3:-50}"
    shift 3
    local command="$*"

    echo "DEBUG: Executing with resource limits: $command" >&2

    # Use bash with limits to execute the command
    bash -c "
        ulimit -t $cpu_seconds 2>/dev/null
        ulimit -v $memory_kb 2>/dev/null
        ulimit -u $max_processes 2>/dev/null
        ulimit -f 102400 2>/dev/null
        exec $command
    "
}

# Export functions
export -f update_agent_status
export -f get_next_task
export -f update_task_status
export -f add_task_to_queue
export -f init_monitoring
export -f set_resource_limits
export -f with_resource_limits

# Initialize on source
init_monitoring
