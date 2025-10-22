#!/bin/bash

# Task Discovery Script
# Automatically finds TODOs in the codebase and converts them to queued tasks

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck disable=SC1091  # Expected for sourcing shared functions
source "${SCRIPT_DIR}/agents/shared_functions.sh"

# Source project configuration
if [[ -f "${SCRIPT_DIR}/project_config.sh" ]]; then
    # shellcheck disable=SC1091  # Expected for sourcing project configuration
    source "${SCRIPT_DIR}/project_config.sh"
fi

# Ensure PROJECT_NAME is set
export PROJECT_NAME="${PROJECT_NAME:-CodingReviewer}"

WORKSPACE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
TASK_QUEUE_FILE="${SCRIPT_DIR}/task_queue.json"
LOG_FILE="${SCRIPT_DIR}/task_discovery.log"

echo "[$(date)] Task Discovery: Starting scan for TODOs..." >>"${LOG_FILE}"

# Function to extract TODO information from a file
extract_todos_from_file() {
    local file_path="$1"
    local relative_path="${file_path#"${WORKSPACE_DIR}"/}"

    # Skip certain directories and files
    if [[ "$relative_path" =~ ^(\.git|node_modules|build|\.build|DerivedData|\.swiftpm) ]]; then
        return
    fi

    # Skip binary files and certain extensions
    if [[ "$file_path" =~ \.(png|jpg|jpeg|gif|ico|svg|pdf|zip|tar|gz|xcodeproj|xcworkspace|json)$ ]] || [[ "$file_path" =~ todo-tree-output\.json ]]; then
        echo "[$(date)] Task Discovery: Skipping ${relative_path} (excluded file)" >>"${LOG_FILE}"
        return
    fi

    echo "[$(date)] Task Discovery: Scanning ${relative_path}" >>"${LOG_FILE}"

    # Look for TODO comments with various patterns
    grep -n -i "TODO\|FIXME\|XXX\|HACK" "$file_path" 2>/dev/null | while IFS=: read -r line_number content; do
        # Clean up the content
        content=$(echo "$content" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')

        # Skip if it's just a generic TODO without context
        if [[ "$content" =~ ^(TODO|FIXME|XXX|HACK)[[:space:]]*$ ]]; then
            continue
        fi

        # Extract the actual TODO text
        # shellcheck disable=SC2001  # sed is more appropriate for complex regex text extraction
        todo_text=$(echo "$content" | sed 's/.*\(TODO\|FIXME\|XXX\|HACK\)[[:space:]]*//i')

        # Skip very short or generic TODOs
        if [[ ${#todo_text} -lt 10 ]]; then
            continue
        fi

        # Skip descriptive comments that just explain what code does
        # These often start with verbs like "Check", "Process", "Handle", "Create", etc.
        # and are typically just documenting existing functionality
        if [[ "$todo_text" =~ ^(Check|Process|Handle|Create|Update|Validate|Parse|Convert|Format|Display|Show|Print|Log|Save|Load|Read|Write|Execute|Run|Start|Stop|Initialize|Setup|Configure|Clean|Build|Compile|Test|Verify|Calculate|Compute|Generate|Send|Receive|Connect|Disconnect|Open|Close|Begin|End|Finish|Complete)[[:space:]] ]]; then
            echo "[$(date)] Task Discovery: Skipping descriptive comment - ${todo_text}" >>"${LOG_FILE}"
            continue
        fi

        # Skip TODOs that appear to be just code comments (start with # and describe functionality)
        if [[ "$content" =~ ^#[[:space:]]*(Check|Process|Handle|Create|Update|Validate|Parse|Convert|Format|Display|Show|Print|Log|Save|Load|Read|Write|Execute|Run|Start|Stop|Initialize|Setup|Configure|Clean|Build|Compile|Test|Verify|Calculate|Compute|Generate|Send|Receive|Connect|Disconnect|Open|Close|Begin|End|Finish|Complete) ]]; then
            echo "[$(date)] Task Discovery: Skipping code documentation comment - ${todo_text}" >>"${LOG_FILE}"
            continue
        fi

        # Create a unique task ID
        timestamp=$(date +%s%N | cut -b1-13)
        task_id="todo_${timestamp}_${line_number}"

        # Determine task type and priority based on content
        task_type="codegen" # Default
        priority=5          # Default medium priority

        if [[ "$content" =~ [Ff][Ii][Xx][Mm][Ee] ]]; then
            task_type="debug"
            priority=8 # High priority for fixes
        elif [[ "$content" =~ [Hh][Aa][Cc][Kk] ]]; then
            task_type="debug"
            priority=7 # High priority for hacks
        elif [[ "$content" =~ [Aa][Dd][Dd]|[Ii][Mm][Pp][Ll][Ee][Mm][Ee][Nn][Tt] ]]; then
            task_type="codegen"
            priority=6 # Medium-high for new features
        fi

        # Determine appropriate agent
        assigned_agent="agent_codegen.sh"
        if [[ "$task_type" == "debug" ]]; then
            assigned_agent="agent_debug.sh"
        fi

        # Create task description
        task_description="TODO in ${relative_path}:${line_number} - ${todo_text}"

        # Create the task JSON using jq for proper escaping
        task_json=$(jq -n \
            --arg id "$task_id" \
            --arg type "$task_type" \
            --arg desc "$task_description" \
            --arg agent "$assigned_agent" \
            --arg status "queued" \
            --arg source_file "$relative_path" \
            --argjson priority "$priority" \
            --argjson created "$(date +%s)" \
            --argjson source_line "$line_number" \
            '{
        id: $id,
        type: $type,
        description: $desc,
        priority: $priority,
        assigned_agent: $agent,
        status: $status,
        created: $created,
        source_file: $source_file,
        source_line: $source_line,
        dependencies: []
      }')

        echo "[$(date)] Task Discovery: Found TODO - ${task_description}" >>"${LOG_FILE}"

        # Add task to queue if it doesn't already exist
        if ! task_exists "$task_id"; then
            add_task_to_queue "$task_json"
            echo "[$(date)] Task Discovery: Added task ${task_id} to queue" >>"${LOG_FILE}"
        else
            echo "[$(date)] Task Discovery: Task ${task_id} already exists, skipping" >>"${LOG_FILE}"
        fi
    done
}

# Function to scan directory recursively
scan_directory() {
    local dir_path="$1"

    # Use find to get all files, then process each one
    find "$dir_path" -type f -not -path '*/\.*' -not -path '*/node_modules/*' -not -path '*/build/*' -not -path '*/.build/*' -not -path '*/DerivedData/*' -not -path '*/.swiftpm/*' | while read -r file; do
        extract_todos_from_file "$file"
    done
}

# Main execution
echo "[$(date)] Task Discovery: Scanning workspace for TODOs..." >>"${LOG_FILE}"

# Scan the main projects directory
scan_directory "${WORKSPACE_DIR}/Projects"

# Scan the Shared directory
scan_directory "${WORKSPACE_DIR}/Shared"

# Scan Tools directory (excluding automation logs and temp files)
scan_directory "${WORKSPACE_DIR}/Tools"

echo "[$(date)] Task Discovery: Scan completed" >>"${LOG_FILE}"

# Show summary
task_count=$(jq '.tasks | length' "$TASK_QUEUE_FILE" 2>/dev/null || echo "0")
echo "[$(date)] Task Discovery: Total tasks in queue: ${task_count}" >>"${LOG_FILE}"
