#!/bin/bash
# Performance Agent: Analyzes and optimizes code performance

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="performance_agent.sh"
LOG_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/performance_agent.log"
NOTIFICATION_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/communication/${AGENT_NAME}_notification.txt"
AGENT_STATUS_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="/Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/task_queue.json"

# Update agent status to available when starting
update_status() {
  local status
  status="$1"
  if command -v jq &>/dev/null; then
    jq ".agents[\"${AGENT_NAME}\"].status = \"${status}\" | .agents[\"${AGENT_NAME}\"].last_seen = $(date +%s)" "${AGENT_STATUS_FILE}" >"${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "${AGENT_STATUS_FILE}"
  fi
  echo "[$(date)] ${AGENT_NAME}: Status updated to ${status}" >>"${LOG_FILE}"
}

# Process a specific task
process_task() {
  local task_id
  task_id="$1"
  echo "[$(date)] ${AGENT_NAME}: Processing task ${task_id}" >>"${LOG_FILE}"

  # Get task details
  if command -v jq &>/dev/null; then
    local task_desc
    task_desc=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .description" "${TASK_QUEUE_FILE}")
    local task_type
    task_type=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .type" "${TASK_QUEUE_FILE}")
    echo "[$(date)] ${AGENT_NAME}: Task description: ${task_desc}" >>"${LOG_FILE}"
    echo "[$(date)] ${AGENT_NAME}: Task type: ${task_type}" >>"${LOG_FILE}"

    # Process based on task type
    case "${task_type}" in
    "perf" | "performance" | "optimization")
      run_performance_analysis "${task_desc}"
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
  local task_id
  task_id="$1"
  local status
  status="$2"
  if command -v jq &>/dev/null; then
    jq "(.tasks[] | select(.id == \"${task_id}\") | .status) = \"${status}\"" "${TASK_QUEUE_FILE}" >"${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "${TASK_QUEUE_FILE}"
  fi
}

count_matching_files() {
  local pattern
  pattern="$1"
  shift
  local files=("$@")
  local count=0

  for file in "${files[@]}"; do
    if [[ -f ${file} ]] && grep -qE "${pattern}" "${file}" 2>/dev/null; then
      ((count++))
    fi
  done

  echo "${count}"
}

count_pattern_occurrences() {
  local pattern
  pattern="$1"
  shift
  local files=("$@")
  local total=0

  for file in "${files[@]}"; do
    if [[ -f ${file} ]]; then
      local occurrences
      occurrences=$(grep -cE "${pattern}" "${file}" 2>/dev/null || true)
      total=$((total + occurrences))
    fi
  done

  echo "${total}"
}

count_large_objects() {
  local files=("$@")
  local count=0

  for file in "${files[@]}"; do
    if [[ -f ${file} ]] &&
      grep -qE 'class[[:space:]].*{' "${file}" 2>/dev/null &&
      grep -qE 'var.*:.*(Array|Dictionary)' "${file}" 2>/dev/null; then
      ((count++))
    fi
  done

  echo "${count}"
}

# Performance analysis function
run_performance_analysis() {
  local task_desc
  task_desc="$1"
  echo "[$(date)] ${AGENT_NAME}: Running performance analysis for: ${task_desc}" >>"${LOG_FILE}"

  # Extract project name from task description
  local projects
  projects=("CodingReviewer" "MomentumFinance" "HabitQuest" "PlannerApp" "AvoidObstaclesGame")

  for project in "${projects[@]}"; do
    if [[ -d "/Users/danielstevens/Desktop/Quantum-workspace/Projects/${project}" ]]; then
      echo "[$(date)] ${AGENT_NAME}: Analyzing performance in ${project}..." >>"${LOG_FILE}"
      cd "/Users/danielstevens/Desktop/Quantum-workspace/Projects/${project}" || continue

      # Performance metrics
      echo "[$(date)] ${AGENT_NAME}: Calculating performance metrics for ${project}..." >>"${LOG_FILE}"

      local swift_files_list=()
      while IFS='' read -r -d '' swift_file; do
        swift_files_list+=("${swift_file}")
      done < <(find . -name "*.swift" -print0 2>/dev/null)

      local swift_files
      swift_files=${#swift_files_list[@]}

      {
        echo "[$(date)] ${AGENT_NAME}: Total Swift files: ${swift_files}"
        echo "[$(date)] ${AGENT_NAME}: Analyzing performance bottlenecks..."
      } >>"${LOG_FILE}"

      local force_casts
      force_casts=$(count_matching_files 'as!' "${swift_files_list[@]}")
      local array_operations
      array_operations=$(count_matching_files 'append|insert|remove' "${swift_files_list[@]}")
      local string_concat
      string_concat=$(count_matching_files '\\+=' "${swift_files_list[@]}")
      local nested_loops
      nested_loops=$(count_pattern_occurrences 'for[[:space:]].*in' "${swift_files_list[@]}")
      local large_objects
      large_objects=$(count_large_objects "${swift_files_list[@]}")

      {
        echo "[$(date)] ${AGENT_NAME}: Force casts found in ${force_casts} files"
        echo "[$(date)] ${AGENT_NAME}: Array operations found in ${array_operations} files"
        echo "[$(date)] ${AGENT_NAME}: String concatenation found in ${string_concat} files"
        echo "[$(date)] ${AGENT_NAME}: Nested loops found in ${nested_loops} occurrences"
        echo "[$(date)] ${AGENT_NAME}: Large objects found in ${large_objects} files"
      } >>"${LOG_FILE}"

      local retain_cycles
      retain_cycles=$(count_matching_files '\\[weak self\\]|\\[unowned self\\]' "${swift_files_list[@]}")
      local strong_refs
      strong_refs=$(count_matching_files 'self\\.' "${swift_files_list[@]}")
      local memory_issues
      memory_issues=$((strong_refs - retain_cycles))

      local async_funcs
      async_funcs=$(count_matching_files 'async func' "${swift_files_list[@]}")
      local await_calls
      await_calls=$(count_matching_files 'await' "${swift_files_list[@]}")

      {
        echo "[$(date)] ${AGENT_NAME}: Potential retain cycles: ${memory_issues}"
        echo "[$(date)] ${AGENT_NAME}: Async functions: ${async_funcs}"
        echo "[$(date)] ${AGENT_NAME}: Await calls: ${await_calls}"
      } >>"${LOG_FILE}"

      # Calculate performance score (simple heuristic)
      local perf_score
      perf_score=$((100 - (force_casts * 5) - (string_concat * 3) - (nested_loops * 2) - (memory_issues * 4)))
      if [[ ${perf_score} -lt 0 ]]; then
        perf_score=0
      fi

      echo "[$(date)] ${AGENT_NAME}: Performance score for ${project}: ${perf_score}%" >>"${LOG_FILE}"

      # Generate performance recommendations
      echo "[$(date)] ${AGENT_NAME}: Generating performance recommendations..." >>"${LOG_FILE}"

      if [[ ${force_casts} -gt 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Recommendation: Replace force casts with safe optional casting" >>"${LOG_FILE}"
      fi

      if [[ ${string_concat} -gt 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Recommendation: Use StringBuilder or array joining for string concatenation" >>"${LOG_FILE}"
      fi

      if [[ ${nested_loops} -gt 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Recommendation: Review nested loops for optimization opportunities" >>"${LOG_FILE}"
      fi

      if [[ ${memory_issues} -gt 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Recommendation: Use weak/unowned references to prevent retain cycles" >>"${LOG_FILE}"
      fi

      if [[ ${async_funcs} -eq 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Recommendation: Consider using async/await for I/O operations" >>"${LOG_FILE}"
      fi

      if [[ ${array_operations} -gt 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Recommendation: Review array operations for potential optimizations" >>"${LOG_FILE}"
      fi
    fi
  done

  echo "[$(date)] ${AGENT_NAME}: Performance analysis completed" >>"${LOG_FILE}"
}

# Main agent loop
echo "[$(date)] ${AGENT_NAME}: Starting performance agent..." >>"${LOG_FILE}"
update_status "available"

# Track processed tasks to avoid duplicates using a simple array approach
processed_tasks=()

while true; do
  # Check for new task notifications
  if [[ -f ${NOTIFICATION_FILE} ]]; then
    while IFS='|' read -r _timestamp action task_id; do
      # Check if task has already been processed
      already_processed=false
      for processed_id in "${processed_tasks[@]}"; do
        if [[ ${processed_id} == "${task_id}" ]]; then
          already_processed=true
          break
        fi
      done

      if [[ ${action} == "execute_task" && ${already_processed} == false ]]; then
        update_status "busy"
        process_task "${task_id}"
        update_status "available"
        processed_tasks+=("${task_id}")
        echo "[$(date)] ${AGENT_NAME}: Marked task ${task_id} as processed" >>"${LOG_FILE}"
      fi
    done <"${NOTIFICATION_FILE}"

    # Clear processed notifications to prevent re-processing
    : >"${NOTIFICATION_FILE}"
  fi

  # Update last seen timestamp
  update_status "available"

  sleep 30 # Check every 30 seconds
done
