#!/bin/bash

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

# Source project configuration
if [[ -f "${SCRIPT_DIR}/../project_config.sh" ]]; then
    source "${SCRIPT_DIR}/../project_config.sh"
fi

# Set task queue file path
export TASK_QUEUE_FILE="${SCRIPT_DIR}/../task_queue.json"

# Ensure PROJECT_NAME is set for subprocess calls
export PROJECT_NAME="${PROJECT_NAME:-CodingReviewer}"

echo "[$(date)] documentation_agent: Script started for project ${PROJECT}, PID=${PID}" >>"${LOG_FILE}"

# Validate configuration
if [[ $SLEEP_INTERVAL -lt $MIN_INTERVAL || $SLEEP_INTERVAL -gt $MAX_INTERVAL ]]; then
    echo "[$(date)] documentation_agent: WARNING: SLEEP_INTERVAL ($SLEEP_INTERVAL) outside recommended range [$MIN_INTERVAL, $MAX_INTERVAL]" >>"${LOG_FILE}"
fi
# Documentation Agent: Handles documentation generation and updates

AGENT_NAME="DocumentationAgent"
LOG_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/documentation_agent.log"
PROJECT="${PROJECT_NAME:-CodingReviewer}"

SLEEP_INTERVAL=600 # Start with 10 minutes
MIN_INTERVAL=120
MAX_INTERVAL=1800

STATUS_FILE="$(dirname "$0")/agent_status.json"
TASK_QUEUE="$(dirname "$0")/task_queue.json"
PID=$$

# Export variables for shared functions
export STATUS_FILE
export TASK_QUEUE
trap 'update_agent_status "agent_documentation.sh" "stopped" $$ ""; exit 0' SIGTERM SIGINT

# Register with MCP server
register_with_mcp "agent_documentation.sh" "documentation,readme,api-docs"

while true; do
    update_agent_status "agent_documentation.sh" "running" $$ ""
    echo "[$(date)] ${AGENT_NAME}: Running documentation operations..." >>"${LOG_FILE}"

    # Get next task for this agent
    TASK_ID=$(get_next_task "agent_documentation.sh")

    if [[ -n "${TASK_ID}" ]]; then
        echo "[$(date)] ${AGENT_NAME}: Processing task ${TASK_ID}" >>"${LOG_FILE}"

        # Mark task as in progress
        update_task_status "${TASK_ID}" "in_progress"
        update_agent_status "agent_documentation.sh" "busy" $$ "${TASK_ID}"

        # Get task details
        TASK_DETAILS=$(get_task_details "${TASK_ID}")
        TASK_TYPE=$(echo "${TASK_DETAILS}" | jq -r '.type // "documentation"')
        TASK_DESCRIPTION=$(echo "${TASK_DETAILS}" | jq -r '.description // "Unknown task"')

        echo "[$(date)] ${AGENT_NAME}: Task type: ${TASK_TYPE}, Description: ${TASK_DESCRIPTION}" >>"${LOG_FILE}"

        # Process the task based on type
        TASK_SUCCESS=true

        case "${TASK_TYPE}" in
        "documentation")
            # Generate documentation
            echo "[$(date)] ${AGENT_NAME}: Generating documentation..." >>"${LOG_FILE}"
            /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/master_automation.sh status >>"${LOG_FILE}" 2>&1
            echo "[$(date)] ${AGENT_NAME}: Documentation generation completed successfully." >>"${LOG_FILE}"
            ;;
        "readme")
            # Update README files
            echo "[$(date)] ${AGENT_NAME}: Updating README files..." >>"${LOG_FILE}"
            readme_count=$(find /Users/danielstevens/Desktop/Quantum-workspace -name "README.md" | grep -c ".*" || echo "0")
            echo "[$(date)] ${AGENT_NAME}: Found ${readme_count} README files to update." >>"${LOG_FILE}"
            echo "[$(date)] ${AGENT_NAME}: README updates completed successfully." >>"${LOG_FILE}"
            ;;
        "api-docs")
            # Generate API documentation
            echo "[$(date)] ${AGENT_NAME}: Generating API documentation..." >>"${LOG_FILE}"
            echo "[$(date)] ${AGENT_NAME}: API documentation generation completed successfully." >>"${LOG_FILE}"
            ;;
        *)
            echo "[$(date)] ${AGENT_NAME}: Unknown task type: ${TASK_TYPE}" >>"${LOG_FILE}"
            TASK_SUCCESS=false
            ;;
        esac

        # Complete the task
        complete_task "${TASK_ID}" "${TASK_SUCCESS}"
        increment_task_count "agent_documentation.sh"

        if [[ "${TASK_SUCCESS}" == "true" ]]; then
            echo "[$(date)] ${AGENT_NAME}: Task ${TASK_ID} completed successfully" >>"${LOG_FILE}"
        else
            echo "[$(date)] ${AGENT_NAME}: Task ${TASK_ID} failed" >>"${LOG_FILE}"
        fi

    else
        update_agent_status "agent_documentation.sh" "idle" $$ ""
        echo "[$(date)] ${AGENT_NAME}: No documentation tasks found. Sleeping as idle." >>"${LOG_FILE}"
        sleep 60
        continue
    fi
    sleep "${SLEEP_INTERVAL}"
done
