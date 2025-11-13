#!/bin/bash
# Convert agent assignments to task queue

ASSIGNMENTS_FILE="agent_assignments.json"
TASK_QUEUE_FILE="task_queue.json"

# Initialize empty task queue if it doesn't exist
if [[ ! -f "$TASK_QUEUE_FILE" ]]; then
    echo '{"tasks":[]}' > "$TASK_QUEUE_FILE"
fi

# Process each assignment
jq -c '.[]' "$ASSIGNMENTS_FILE" | while read -r assignment; do
    id=$(echo "$assignment" | jq -r '.id')
    file=$(echo "$assignment" | jq -r '.file')
    line=$(echo "$assignment" | jq -r '.line')
    text=$(echo "$assignment" | jq -r '.text')
    agent=$(echo "$assignment" | jq -r '.agent')
    
    # Convert agent to task type
    case "$agent" in
        "testing_agent.sh") task_type="testing" ;;
        "uiux_agent.sh") task_type="ui" ;;
        "agent_debug.sh") task_type="debug" ;;
        "documentation_agent.sh") task_type="documentation" ;;
        "security_agent.sh") task_type="security" ;;
        "pull_request_agent.sh") task_type="pull_request" ;;
        "code_review_agent.sh") task_type="review" ;;
        *) task_type="debug" ;;
    esac
    
    # Create task
    task_id="todo_${id}"
    task_description="$text (File: $file:$line)"
    
    # Check if task exists
    if jq -e ".tasks[] | select(.id == \"$task_id\")" "$TASK_QUEUE_FILE" >/dev/null 2>&1; then
        echo "Task $task_id already exists"
        continue
    fi
    
    # Add task
    task_json=$(cat <<TASK_JSON
{
  "id": "$task_id",
  "type": "$task_type", 
  "description": "$task_description",
  "priority": 5,
  "assigned_agent": "$agent",
  "status": "queued",
  "created": $(date +%s),
  "dependencies": []
}
TASK_JSON
)
    
    jq ".tasks += [$task_json]" "$TASK_QUEUE_FILE" > "${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "$TASK_QUEUE_FILE"
    echo "Added task $task_id for agent $agent"
done

echo "Conversion complete"
