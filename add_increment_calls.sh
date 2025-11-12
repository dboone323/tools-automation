#!/bin/bash
# Script to add increment_task_count calls to all agents that complete tasks

set -e

# Get all agent files that complete tasks
agent_files=$(grep -l "update_task_status.*completed" agents/*.sh)

for file in $agent_files; do
    echo "Processing $file..."

    # Check if increment_task_count is already called
    if grep -q "increment_task_count" "$file"; then
        echo "  Already has increment_task_count call"
        continue
    fi

    # Find the line with update_task_status.*completed and add increment_task_count before it
    # We need to be careful about the agent name variable
    if grep -q 'AGENT_NAME=' "$file"; then
        # Use AGENT_NAME variable
        sed -i '' '/update_task_status.*completed/a\
    increment_task_count "${AGENT_NAME}"' "$file"
    else
        # Extract agent name from filename
        agent_name=$(basename "$file" .sh)
        sed -i '' "/update_task_status.*completed/a\\
    increment_task_count \"${agent_name}\"" "$file"
    fi

    echo "  Added increment_task_count call"
done

echo "Done processing all agent files"
