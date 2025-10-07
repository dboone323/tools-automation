#!/bin/bash
# Enhanced Quality Assurance Agent: Analyzes and improves code quality with trunk integration

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="quality_agent.sh"
WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
LOG_FILE="${WORKSPACE}/Tools/Automation/agents/quality_agent.log"
NOTIFICATION_FILE="${WORKSPACE}/Tools/Automation/agents/communication/${AGENT_NAME}_notification.txt"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/Tools/Automation/agents/task_queue.json"
REPORTS_DIR="${WORKSPACE}/Tools/Automation/reports"
STATE_DIR="${WORKSPACE}/Tools/Automation/agents/state/${AGENT_NAME%.*}"

# Create reports directory
mkdir -p "${REPORTS_DIR}"
mkdir -p "${STATE_DIR}"

# Logging function
log() {
  echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*" | tee -a "${LOG_FILE}"
}

# Status update function
update_status() {
  local status="$1"
  local now
  now=$(date +%s)
  local STATUS_UTIL="${WORKSPACE}/Tools/Automation/agents/status_utils.py"
  if [[ -f ${STATUS_UTIL} ]]; then
    python3 "${STATUS_UTIL}" update-agent \
      --status-file "${AGENT_STATUS_FILE}" \
      --agent "${AGENT_NAME}" \
      --status "${status}" \
      --last-seen "${now}" >/dev/null 2>&1 || true
  elif command -v jq &>/dev/null; then
    # Fallback: ensure numeric fields are coerced and entry exists
    local tmp="${AGENT_STATUS_FILE}.tmp.$$"
    jq --arg agent "${AGENT_NAME}" --arg status "${status}" --argjson now "${now}" '
        def to_num:
          if type == "string" then
            (gsub("^[\\s]+"; "") | gsub("[\\s]+$"; "") |
              if test("^-?[0-9]+$") then tonumber else . end)
          elif type == "number" then . else . end;
        .agents[$agent] = (.agents[$agent] // {})
        | .agents[$agent].status = $status
        | .agents[$agent].last_seen = $now
        | .agents[$agent] |= (
            to_entries
            | map(if (["pid","last_seen","tasks_completed","restart_count"] | index(.key)) != null
                  then .value = (.value | to_num) else . end)
            | from_entries)
        | .last_update = $now
      ' "${AGENT_STATUS_FILE}" >"${tmp}" 2>/dev/null && mv "${tmp}" "${AGENT_STATUS_FILE}"
  fi
  log "${AGENT_NAME}: Status updated to ${status}"
}

# Process a specific task
process_task() {
  local task_id="$1"
  log "${AGENT_NAME}: Processing task ${task_id}"

  # Get task details
  if command -v jq &>/dev/null; then
    local task_desc
    local task_type

    task_desc=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .description" "${TASK_QUEUE_FILE}")
    task_type=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .type" "${TASK_QUEUE_FILE}")

    log "${AGENT_NAME}: Task description: ${task_desc}"
    log "${AGENT_NAME}: Task type: ${task_type}"

    # Process based on task type
    case "${task_type}" in
    "quality" | "lint" | "metrics")
      run_quality_analysis "${task_desc}"
      ;;
    *)
      echo "[$(date)] ${AGENT_NAME}: Unknown task type: ${task_type}" >>"${LOG_FILE}"
      ;;
    esac

    # Mark task as completed
    update_task_status "${task_id}" "completed"
    echo "[$(date)] ${AGENT_NAME}: Task ${task_id} completed" >>"${LOG_FILE}"
  fi
}

# Update task status
update_task_status() {
  local task_id="$1"
  local status="$2"
  if command -v jq &>/dev/null; then
    jq "(.tasks[] | select(.id == \"${task_id}\") | .status) = \"${status}\"" "${TASK_QUEUE_FILE}" >"${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "${TASK_QUEUE_FILE}"
  fi
}

# Run trunk quality checks
run_trunk_quality_check() {
  local project_name="$1"
  log "${AGENT_NAME}: Running trunk quality checks for ${project_name}"

  # Check if trunk is available
  if ! command -v trunk &>/dev/null; then
    log "${AGENT_NAME}: Trunk not found, skipping quality checks"
    return 0
  fi

  # Run trunk check
  if trunk check --format=json >"${REPORTS_DIR}/trunk_${project_name}_$(date +%Y%m%d_%H%M%S).json" 2>/dev/null; then
    log "${AGENT_NAME}: Trunk checks passed for ${project_name}"
    return 0
  else
    local exit_code=$?
    log "${AGENT_NAME}: Trunk checks found issues in ${project_name} (exit code: ${exit_code})"

    # Attempt auto-fix
    log "${AGENT_NAME}: Attempting auto-fix for ${project_name}"
    if trunk fix 2>/dev/null; then
      log "${AGENT_NAME}: Auto-fix completed for ${project_name}"
    else
      log "${AGENT_NAME}: Auto-fix failed for ${project_name}"
    fi
    return "${exit_code}"
  fi
}

# Generate quality report
generate_quality_report() {
  local project="$1"
  local total_lines="$2"
  local total_files="$3"
  local force_unwraps="$4"
  local todos="$5"
  local prints="$6"
  local quality_score="$7"

  local report_file
  report_file="${REPORTS_DIR}/quality_report_${project}_$(date +%Y%m%d_%H%M%S).md"

  cat >"${report_file}" <<EOF
# Quality Report for ${project}
Generated: $(date)

## Code Metrics
- **Total Lines of Code**: ${total_lines}
- **Total Swift Files**: ${total_files}
- **Average Lines per File**: $((total_lines / (total_files > 0 ? total_files : 1)))

## Code Quality Issues
- **Force Unwraps**: ${force_unwraps} files
- **TODO/FIXME Comments**: ${todos} files
- **Print Statements**: ${prints} files

## Quality Score
**${quality_score}%**

## Recommendations

EOF

  # Add specific recommendations
  if [[ ${force_unwraps} -gt 0 ]]; then
    cat >>"${report_file}" <<EOF
- Replace force unwraps (!) with optional binding or guard statements
- Consider using nil-coalescing operator (??) where appropriate

EOF
  fi

  if [[ ${todos} -gt 0 ]]; then
    cat >>"${report_file}" <<EOF
- Address TODO and FIXME comments
- Convert TODOs to proper issues in project management system

EOF
  fi

  if [[ ${prints} -gt 0 ]]; then
    cat >>"${report_file}" <<EOF
- Remove or replace debug print statements
- Use proper logging framework instead of print statements

EOF
  fi

  log "${AGENT_NAME}: Quality report generated: ${report_file}"
}

# Quality analysis function
run_quality_analysis() {
  local task_desc="$1"
  log "${AGENT_NAME}: Running quality analysis for: ${task_desc}"

  # Extract project name from task description
  local projects=("CodingReviewer" "MomentumFinance" "HabitQuest" "PlannerApp" "AvoidObstaclesGame")

  for project in "${projects[@]}"; do
    local project_path="${WORKSPACE}/Projects/${project}"
    if [[ -d ${project_path} ]]; then
      log "${AGENT_NAME}: Analyzing code quality in ${project}..."
      cd "${project_path}" || {
        log "${AGENT_NAME}: Failed to change to directory: ${project_path}"
        continue
      }

      # Run trunk checks first
      run_trunk_quality_check "${project}"

      # Code quality metrics
      log "${AGENT_NAME}: Calculating quality metrics for ${project}..."

      # Count total lines of code
      local total_lines
      total_lines=$(find . -name "*.swift" -exec wc -l {} \; | awk '{sum += $1} END {print sum}')
      log "${AGENT_NAME}: Total lines of code: ${total_lines}"

      # Count files
      local total_files
      total_files=$(find . -name "*.swift" | wc -l)
      log "${AGENT_NAME}: Total Swift files: ${total_files}"

      # Analyze code quality issues
      log "${AGENT_NAME}: Analyzing code quality issues..."

      # Check for code smells
      local force_unwraps
      local todos
      local prints

      force_unwraps=$(find . -name "*.swift" -exec grep -l "!" {} \; | wc -l)
      todos=$(find . -name "*.swift" -exec grep -l "TODO\|FIXME" {} \; | wc -l)
      prints=$(find . -name "*.swift" -exec grep -l "print\|debugPrint" {} \; | wc -l)

      log "${AGENT_NAME}: Force unwraps found in ${force_unwraps} files"
      log "${AGENT_NAME}: TODO/FIXME found in ${todos} files"
      log "${AGENT_NAME}: Print statements found in ${prints} files"

      # Calculate quality score (simple heuristic)
      local quality_score=$((100 - (force_unwraps * 5) - (todos * 2) - (prints * 1)))
      if [[ ${quality_score} -lt 0 ]]; then
        quality_score=0
      fi

      log "${AGENT_NAME}: Quality score for ${project}: ${quality_score}%"

      # Generate quality report
      generate_quality_report "${project}" "${total_lines}" "${total_files}" "${force_unwraps}" "${todos}" "${prints}" "${quality_score}"
    fi
  done

  log "${AGENT_NAME}: Quality analysis completed"
}

# Main agent loop
log "${AGENT_NAME}: Starting enhanced quality assurance agent..."
update_status "available"

# Track processed tasks to avoid duplicates
processed_tasks_file="${STATE_DIR}/processed_tasks.txt"
touch "${processed_tasks_file}"

while true; do
  # Check for new task notifications
  if [[ -f ${NOTIFICATION_FILE} ]]; then
    while IFS='|' read -r _timestamp action task_id; do
      if [[ ${action} == "execute_task" ]] && ! grep -q "^${task_id}$" "${processed_tasks_file}"; then
        update_status "busy"
        process_task "${task_id}"
        update_status "available"
        echo "${task_id}" >>"${processed_tasks_file}"
        log "${AGENT_NAME}: Marked task ${task_id} as processed"
      fi
    done <"${NOTIFICATION_FILE}"

    # Clear processed notifications to prevent re-processing
    : >"${NOTIFICATION_FILE}"
  fi

  # Update last seen timestamp
  update_status "available"

  sleep 30 # Check every 30 seconds
done
