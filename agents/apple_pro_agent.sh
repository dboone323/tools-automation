#!/bin/bash
# Apple Pro Engineer Agent: Ensures code and project follow Apple best practices and advanced engineering standards

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="AppleProAgent"
LOG_FILE="$(dirname "$0")/apple_pro_agent.log"
PROJECT="CodingReviewer" # Default project, can be overridden by task

SLEEP_INTERVAL=3600 # 1 hour for Apple standards checks
MIN_INTERVAL=600
MAX_INTERVAL=7200

# Function to determine project from task or use default
get_project_from_task() {
    local task_data="$1"
    local project
    project=$(echo "${task_data}" | jq -r '.project // empty')
    if [[ -z ${project} || ${project} == "null" ]]; then
        project="${PROJECT}"
    fi
    echo "${project}"
}

# Function to run Apple Pro engineering checks
run_apple_pro_checks() {
    local project="$1"
    local task_data="$2"

    echo "[$(date)] ${AGENT_NAME}: Running Apple Pro engineering checks for ${project}..." >>"${LOG_FILE}"

    # Navigate to project directory
    local project_path="/Users/danielstevens/Desktop/Quantum-workspace/Projects/${project}"
    if [[ ! -d ${project_path} ]]; then
        echo "[$(date)] ${AGENT_NAME}: Project directory not found: ${project_path}" >>"${LOG_FILE}"
        return 1
    fi

    cd "${project_path}" || return 1

    # Check if SwiftLint is available and run it
    if command -v swiftlint >/dev/null 2>&1; then
        echo "[$(date)] ${AGENT_NAME}: Running SwiftLint checks..." >>"${LOG_FILE}"
        nice -n 19 swiftlint --strict >>"${LOG_FILE}" 2>&1
    else
        echo "[$(date)] ${AGENT_NAME}: SwiftLint not available, skipping lint checks" >>"${LOG_FILE}"
    fi

    # Check if SwiftFormat is available and run it
    if command -v swiftformat >/dev/null 2>&1; then
        echo "[$(date)] ${AGENT_NAME}: Running SwiftFormat checks..." >>"${LOG_FILE}"
        nice -n 19 swiftformat --lint . >>"${LOG_FILE}" 2>&1
    else
        echo "[$(date)] ${AGENT_NAME}: SwiftFormat not available, skipping format checks" >>"${LOG_FILE}"
    fi

    # Check for Apple-specific best practices
    echo "[$(date)] ${AGENT_NAME}: Checking Apple best practices..." >>"${LOG_FILE}"

    # Look for potential issues in Swift files
    find . -name "*.swift" | while read -r file; do
        # Check for force unwrapping
        if grep -n "!" "${file}" | grep -v "if let\|guard let\|case let" | head -5; then
            echo "[$(date)] ${AGENT_NAME}: Found force unwrapping in ${file}" >>"${LOG_FILE}"
        fi

        # Check for large functions (Apple recommends < 200 lines)
        local line_count
        line_count=$(wc -l <"${file}")
        if [[ ${line_count} -gt 200 ]]; then
            echo "[$(date)] ${AGENT_NAME}: Large function detected in ${file} (${line_count} lines)" >>"${LOG_FILE}"
        fi

        # Check for proper error handling
        if ! grep -q "throws\|Error\|Result<" "${file}"; then
            echo "[$(date)] ${AGENT_NAME}: No error handling found in ${file}" >>"${LOG_FILE}"
        fi
    done

    # Check for proper project structure
    if [[ ! -f "${project}.xcodeproj/project.pbxproj" ]]; then
        echo "[$(date)] ${AGENT_NAME}: Xcode project file not found" >>"${LOG_FILE}"
    fi

    return 0
}

# Function to suggest and apply Apple best practices
apply_apple_best_practices() {
    local project="$1"
    local task_data="$2"

    echo "[$(date)] ${AGENT_NAME}: Applying Apple best practices for ${project}..." >>"${LOG_FILE}"

    # Navigate to project directory
    local project_path="/Users/danielstevens/Desktop/Quantum-workspace/Projects/${project}"
    if [[ ! -d ${project_path} ]]; then
        echo "[$(date)] ${AGENT_NAME}: Project directory not found: ${project_path}" >>"${LOG_FILE}"
        return 1
    fi

    cd "${project_path}" || return 1

    # Create backup before making changes
    echo "[$(date)] ${AGENT_NAME}: Creating backup before applying best practices..." >>"${LOG_FILE}"
    nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup_if_needed "${project}" >>"${LOG_FILE}" 2>&1 || true

    # Apply SwiftFormat if available
    if command -v swiftformat >/dev/null 2>&1; then
        echo "[$(date)] ${AGENT_NAME}: Applying SwiftFormat..." >>"${LOG_FILE}"
        nice -n 19 swiftformat . >>"${LOG_FILE}" 2>&1
    fi

    # Run validation after changes
    echo "[$(date)] ${AGENT_NAME}: Validating Apple best practices..." >>"${LOG_FILE}"
    nice -n 19 /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/intelligent_autofix.sh validate "${project}" >>"${LOG_FILE}" 2>&1

    return 0
}

# Function to run a step with nice priority
run_step() {
    local step_name="$1"
    local command="$2"

    echo "[$(date)] ${AGENT_NAME}: Running ${step_name}..." >>"${LOG_FILE}"
    nice -n 19 bash -c "${command}" >>"${LOG_FILE}" 2>&1
    local exit_code=$?
    if [[ ${exit_code} -eq 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: ${step_name} completed successfully" >>"${LOG_FILE}"
    else
        echo "[$(date)] ${AGENT_NAME}: ${step_name} failed with exit code ${exit_code}" >>"${LOG_FILE}"
    fi
    return ${exit_code}
}

# Function to process assigned tasks
process_assigned_tasks() {
    local task
    task=$(get_next_task "apple_pro_agent.sh")
    if [[ -z ${task} ]]; then
        return 0
    fi

    local task_id
    task_id=$(echo "${task}" | jq -r '.id')
    local project
    project=$(get_project_from_task "${task}")

    echo "[$(date)] ${AGENT_NAME}: Processing task ${task_id} for project ${project}..." >>"${LOG_FILE}"

    # Update task status to in_progress
    update_task_status "${task_id}" "in_progress"

    # Determine task type and execute appropriate action
    local task_type
    task_type=$(echo "${task}" | jq -r '.type // "check"')

    case "${task_type}" in
    "check")
        if run_apple_pro_checks "${project}" "${task}"; then
            echo "[$(date)] ${AGENT_NAME}: Apple Pro checks completed successfully for ${project}" >>"${LOG_FILE}"
            update_task_status "${task_id}" "completed"
            update_agent_status "${AGENT_NAME}" "idle"
            return 0
        else
            echo "[$(date)] ${AGENT_NAME}: Apple Pro checks failed for ${project}" >>"${LOG_FILE}"
            update_task_status "${task_id}" "failed"
            update_agent_status "${AGENT_NAME}" "error"
            return 1
        fi
        ;;
    "apply")
        if apply_apple_best_practices "${project}" "${task}"; then
            echo "[$(date)] ${AGENT_NAME}: Apple best practices applied successfully for ${project}" >>"${LOG_FILE}"
            update_task_status "${task_id}" "completed"
            update_agent_status "${AGENT_NAME}" "idle"
            return 0
        else
            echo "[$(date)] ${AGENT_NAME}: Failed to apply Apple best practices for ${project}" >>"${LOG_FILE}"
            update_task_status "${task_id}" "failed"
            update_agent_status "${AGENT_NAME}" "error"
            return 1
        fi
        ;;
    *)
        echo "[$(date)] ${AGENT_NAME}: Unknown task type: ${task_type}" >>"${LOG_FILE}"
        update_task_status "${task_id}" "failed"
        update_agent_status "${AGENT_NAME}" "error"
        return 1
        ;;
    esac
}

# Main agent loop
while true; do
    update_agent_status "${AGENT_NAME}" "running"

    if process_assigned_tasks; then
        # Success - sleep longer
        SLEEP_INTERVAL=$((SLEEP_INTERVAL + 600))
        if [[ ${SLEEP_INTERVAL} -gt ${MAX_INTERVAL} ]]; then
            SLEEP_INTERVAL=${MAX_INTERVAL}
        fi
    else
        # Failure or no tasks - sleep shorter
        SLEEP_INTERVAL=$((SLEEP_INTERVAL / 2))
        if [[ ${SLEEP_INTERVAL} -lt ${MIN_INTERVAL} ]]; then
            SLEEP_INTERVAL=${MIN_INTERVAL}
        fi
    fi

    update_agent_status "${AGENT_NAME}" "idle"
    echo "[$(date)] ${AGENT_NAME}: Sleeping for ${SLEEP_INTERVAL} seconds..." >>"${LOG_FILE}"
    sleep "${SLEEP_INTERVAL}"
done
