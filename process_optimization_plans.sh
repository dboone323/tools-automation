#!/bin/bash
# Process optimization plans and convert them to agent tasks

WORKSPACE_DIR="/Users/danielstevens/Desktop/Quantum-workspace"
TASK_QUEUE_FILE="${WORKSPACE_DIR}/Tools/Automation/agents/task_queue.json"
LOG_FILE="${WORKSPACE_DIR}/Tools/Automation/process_optimization_plans.log"

log() {
    echo "[$(date)] $*" >>"${LOG_FILE}"
}

log "Starting optimization plan processing"

# Find all optimization plan files
find "${WORKSPACE_DIR}/Projects" -name "*_optimization_plan.md" | while read -r plan_file; do
    log "Processing optimization plan: ${plan_file}"

    project_name=$(basename "${plan_file}" | sed 's/_optimization_plan\.md//')

    # Extract tasks from the optimization plan
    # Look for numbered tasks in the format "1. Task description"
    grep -E "^[0-9]+\." "${plan_file}" | while read -r line; do
        # Extract task number and description
        task_num=$(echo "${line}" | sed 's/^\([0-9]\+\)\..*/\1/')
        task_desc=$(echo "${line}" | sed 's/^[0-9]\+\. //')

        # Skip if empty
        [[ -z "${task_desc}" ]] && continue

        # Determine task type and agent based on content
        if echo "${task_desc}" | grep -qi "test\|testing"; then
            task_type="testing"
            assigned_agent="agent_testing.sh"
            priority=7
        elif echo "${task_desc}" | grep -qi "ui\|ux\|interface\|design"; then
            task_type="ui"
            assigned_agent="uiux_agent.sh"
            priority=6
        elif echo "${task_desc}" | grep -qi "performance\|optimize\|speed"; then
            task_type="performance"
            assigned_agent="agent_performance.sh"
            priority=8
        elif echo "${task_desc}" | grep -qi "security\|vulnerability"; then
            task_type="security"
            assigned_agent="security_agent.sh"
            priority=9
        elif echo "${task_desc}" | grep -qi "documentation\|docs\|readme"; then
            task_type="documentation"
            assigned_agent="documentation_agent.sh"
            priority=4
        elif echo "${task_desc}" | grep -qi "debug\|fix\|error"; then
            task_type="debug"
            assigned_agent="agent_debug.sh"
            priority=8
        elif echo "${task_desc}" | grep -qi "code\|implement\|feature"; then
            task_type="codegen"
            assigned_agent="agent_codegen.sh"
            priority=6
        else
            task_type="debug"
            assigned_agent="agent_debug.sh"
            priority=5
        fi

        # Create unique task ID
        task_id="opt_${project_name}_${task_num}_$(date +%s)"

        # Check if task already exists
        if jq -e ".tasks[] | select(.id == \"${task_id}\")" "${TASK_QUEUE_FILE}" >/dev/null 2>&1; then
            log "Task ${task_id} already exists, skipping"
            continue
        fi

        # Create task entry
        task_json="{\"id\": \"${task_id}\", \"type\": \"${task_type}\", \"description\": \"[${project_name}] ${task_desc}\", \"priority\": ${priority}, \"assigned_agent\": \"${assigned_agent}\", \"status\": \"queued\", \"created\": $(date +%s), \"source_file\": \"${plan_file}\", \"dependencies\": []}"

        # Add task to queue
        jq ".tasks += [${task_json}]" "${TASK_QUEUE_FILE}" >"${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "${TASK_QUEUE_FILE}"

        log "Created optimization task ${task_id} for ${assigned_agent}"
    done
done

log "Optimization plan processing complete"
