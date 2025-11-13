#!/bin/bash
# batch_todo_processor.sh - Simple TODO batch processor

set -euo pipefail

echo "Starting TODO Batch Processor"

# Configuration
BATCH_SIZE=10
WORKSPACE_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROGRESS_FILE="${WORKSPACE_ROOT}/todo_batch_progress.json"

echo "Processing TODOs in batches of ${BATCH_SIZE}"

# Check if jq is available
if ! command -v jq >/dev/null 2>&1; then
    echo "Error: jq is required but not installed"
    exit 1
fi

# Check if TODO file exists
TODO_FILE="${WORKSPACE_ROOT}/config/todo-tree-output.json"
if [[ ! -f "${TODO_FILE}" ]]; then
    echo "Error: TODO file not found: ${TODO_FILE}"
    exit 1
fi

# Count total TODOs
TOTAL_TODOS=$(jq '. | length' "${TODO_FILE}")
echo "Found ${TOTAL_TODOS} TODOs to process"

# Initialize progress if needed
if [[ ! -f "${PROGRESS_FILE}" ]]; then
    echo "Initializing progress tracking..."
    cat >"${PROGRESS_FILE}" <<EOF
{
  "total_todos": ${TOTAL_TODOS},
  "processed": 0,
  "successful": 0,
  "failed": 0,
  "batches_completed": 0,
  "current_batch": 0,
  "start_time": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "last_update": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
fi

echo "Batch processor initialized successfully"
echo "Ready to process TODOs"

# Check if assign_agent.sh exists
ASSIGN_SCRIPT="${WORKSPACE_ROOT}/assign_agent.sh"
if [[ ! -f "${ASSIGN_SCRIPT}" ]]; then
    echo "Error: Agent assignment script not found: ${ASSIGN_SCRIPT}"
    exit 1
fi

# Function to update progress
update_progress() {
    local field="$1"
    local value="$2"
    local temp_file="${PROGRESS_FILE}.tmp"

    jq --arg field "$field" --arg value "$value" '.[$field] = ($value | tonumber) | .last_update = "'$(date -u +%Y-%m-%dT%H:%M:%SZ)'"' "${PROGRESS_FILE}" >"$temp_file" && mv "$temp_file" "${PROGRESS_FILE}"
}

# Function to get progress
get_progress() {
    local field="$1"
    jq -r ".${field}" "${PROGRESS_FILE}"
}

# Function to process a batch
process_batch() {
    local batch_num="$1"
    local start_index="$2"
    local end_index="$3"

    echo "Processing batch ${batch_num}: TODOs ${start_index} to ${end_index}"

    # Extract batch
    local batch_file="${WORKSPACE_ROOT}/batch_${batch_num}.json"
    jq ".[${start_index}:${end_index}]" "${TODO_FILE}" >"${batch_file}"

    local batch_size
    batch_size=$(jq '. | length' "${batch_file}")

    if [[ ${batch_size} -eq 0 ]]; then
        echo "Batch ${batch_num} is empty, skipping"
        rm -f "${batch_file}"
        return 0
    fi

    echo "Batch ${batch_num} contains ${batch_size} TODOs"

    local success_count=0
    local fail_count=0

    # Process each TODO
    for i in $(seq 0 $((batch_size - 1))); do
        local todo
        todo=$(jq ".[${i}]" "${batch_file}")

        local file
        file=$(echo "${todo}" | jq -r '.file')
        local line
        line=$(echo "${todo}" | jq -r '.line')
        local text
        text=$(echo "${todo}" | jq -r '.text')

        # Assign agent
        if "${ASSIGN_SCRIPT}" "${file}" "${line}" "${text}" 2>/dev/null; then
            success_count=$((success_count + 1))
        else
            fail_count=$((fail_count + 1))
            echo "Failed to assign agent for ${file}:${line}"
        fi
    done

    # Update progress
    local current_processed
    current_processed=$(get_progress "processed")
    local current_successful
    current_successful=$(get_progress "successful")
    local current_failed
    current_failed=$(get_progress "failed")
    local current_batches
    current_batches=$(get_progress "batches_completed")

    update_progress "processed" $((current_processed + batch_size))
    update_progress "successful" $((current_successful + success_count))
    update_progress "failed" $((current_failed + fail_count))
    update_progress "batches_completed" $((current_batches + 1))
    update_progress "current_batch" "${batch_num}"

    # Clean up
    rm -f "${batch_file}"

    echo "Batch ${batch_num} completed: ${success_count} successful, ${fail_count} failed"
}

# Function to show progress
show_progress() {
    echo "Progress Report"
    echo "==============="

    local total
    total=$(get_progress "total_todos")
    local processed
    processed=$(get_progress "processed")
    local successful
    successful=$(get_progress "successful")
    local failed
    failed=$(get_progress "failed")
    local batches
    batches=$(get_progress "batches_completed")

    echo "Total TODOs: ${total}"
    echo "Processed: ${processed}"
    echo "Successful: ${successful}"
    echo "Failed: ${failed}"
    echo "Batches completed: ${batches}"

    if [[ ${total} -gt 0 ]]; then
        local percent=$((processed * 100 / total))
        echo "Completion: ${percent}%"
    fi
}

# Main processing
echo "Starting batch processing..."

batch_num=1
start_index=0

while [[ ${start_index} -lt ${TOTAL_TODOS} ]]; do
    end_index=$((start_index + BATCH_SIZE))
    if [[ ${end_index} -gt ${TOTAL_TODOS} ]]; then
        end_index=${TOTAL_TODOS}
    fi

    process_batch "${batch_num}" "${start_index}" "${end_index}"

    start_index=${end_index}
    batch_num=$((batch_num + 1))

    # Show progress every 10 batches
    if [[ $((batch_num % 10)) -eq 0 ]]; then
        show_progress
    fi
done

echo "All batches processed!"
show_progress
