#!/bin/bash
# Code Review Agent: AI-powered code analysis and improvement suggestions
# Uses Ollama for intelligent code review, automated fixes, and quality assessment

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="code_review_agent.sh"
WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
LOG_FILE="${WORKSPACE}/Tools/Automation/agents/code_review_agent.log"
NOTIFICATION_FILE="${WORKSPACE}/Tools/Automation/agents/communication/${AGENT_NAME}_notification.txt"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/Tools/Automation/agents/task_queue.json"
OLLAMA_ENDPOINT="http://localhost:11434"

# Update agent status
update_status() {
  local status="$1"
  if command -v jq &>/dev/null; then
    jq ".agents[\"${AGENT_NAME}\"].status = \"${status}\" | .agents[\"${AGENT_NAME}\"].last_seen = $(date +%s)" "${AGENT_STATUS_FILE}" >"${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "${AGENT_STATUS_FILE}"
  fi
  echo "[$(date)] ${AGENT_NAME}: Status updated to ${status}" >>"${LOG_FILE}"
}

# Process code review task
process_task() {
  local task_id="$1"
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
    "code_review" | "review" | "analyze")
      run_code_review "${task_desc}"
      ;;
    "fix" | "auto_fix")
      run_automated_fix "${task_desc}"
      ;;
    "quality" | "assessment")
      run_quality_assessment "${task_desc}"
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

# Ollama-powered code review
run_code_review() {
  local task_desc="$1"
  echo "[$(date)] ${AGENT_NAME}: Running Ollama-powered code review for: ${task_desc}" >>"${LOG_FILE}"

  # Check Ollama availability with better error handling
  if ! curl -s -m 5 "${OLLAMA_ENDPOINT}/api/tags" >/dev/null 2>&1; then
    echo "[$(date)] ${AGENT_NAME}: ERROR - Ollama not available. Attempting to start..." >>"${LOG_FILE}"
    if command -v brew &>/dev/null; then
      brew services start ollama >>"${LOG_FILE}" 2>&1
      sleep 10
      if ! curl -s -m 5 "${OLLAMA_ENDPOINT}/api/tags" >/dev/null 2>&1; then
        echo "[$(date)] ${AGENT_NAME}: ERROR - Failed to start Ollama" >>"${LOG_FILE}"
        return 1
      fi
    else
      echo "[$(date)] ${AGENT_NAME}: ERROR - Homebrew not available to start Ollama" >>"${LOG_FILE}"
      return 1
    fi
  fi

  # Verify CodeLlama model availability
  local available_models
  available_models=$(curl -s "${OLLAMA_ENDPOINT}/api/tags" | jq -r '.models[].name' 2>/dev/null)
  if ! echo "${available_models}" | grep -q "codellama"; then
    echo "[$(date)] ${AGENT_NAME}: CodeLlama not available, pulling model..." >>"${LOG_FILE}"
    ollama pull codellama:latest >>"${LOG_FILE}" 2>&1
    sleep 5
  fi

  # Extract project name
  local project="CodingReviewer"
  if [[ ${task_desc} =~ MomentumFinance ]]; then
    project="MomentumFinance"
  elif [[ ${task_desc} =~ HabitQuest ]]; then
    project="HabitQuest"
  elif [[ ${task_desc} =~ PlannerApp ]]; then
    project="PlannerApp"
  elif [[ ${task_desc} =~ AvoidObstaclesGame ]]; then
    project="AvoidObstaclesGame"
  fi

  local project_path="${WORKSPACE}/Projects/${project}"

  if [[ ! -d ${project_path} ]]; then
    echo "[$(date)] ${AGENT_NAME}: ERROR - Project path not found: ${project_path}" >>"${LOG_FILE}"
    return 1
  fi

  # Collect code for review
  local code_sample=""
  cd "${project_path}" || return 1

  # Get recent Swift files (modified in last 24 hours or specified files)
  local swift_files
  if [[ ${task_desc} =~ specific|file ]]; then
    # Extract specific files from task description
    swift_files=$(find . -name "*.swift" | head -5)
  else
    # Get recently modified files
    swift_files=$(find . -name "*.swift" -mtime -1 | head -5)
    if [[ -z ${swift_files} ]]; then
      swift_files=$(find . -name "*.swift" | head -5)
    fi
  fi

  for file in ${swift_files}; do
    if [[ -f ${file} ]]; then
      code_sample+="// File: ${file}\n$(head -30 "${file}")\n\n"
    fi
  done

  if [[ -z ${code_sample} ]]; then
    echo "[$(date)] ${AGENT_NAME}: No code found for review" >>"${LOG_FILE}"
    return 1
  fi

  # Create comprehensive code review prompt
  local review_prompt="Perform a comprehensive code review of this Swift code for iOS development:

${code_sample}

Please provide:
1. CODE QUALITY ASSESSMENT
   - Overall code quality score (1-10 scale)
   - Strengths and weaknesses

2. BUGS AND ISSUES
   - Potential bugs or runtime errors
   - Logic errors or edge cases
   - Memory management issues

3. BEST PRACTICES COMPLIANCE
   - Swift/iOS best practices followed
   - Code style and conventions
   - Error handling patterns

4. PERFORMANCE OPTIMIZATIONS
   - Performance bottlenecks
   - Memory usage optimization
   - Algorithm efficiency suggestions

5. SECURITY CONSIDERATIONS
   - Security vulnerabilities
   - Input validation issues
   - Data protection concerns

6. SPECIFIC IMPROVEMENT SUGGESTIONS
   - Code refactoring recommendations
   - Design pattern improvements
   - Testing recommendations

Format your response with clear sections and actionable recommendations."

  # Get Ollama analysis
  local review_result
  review_result=$(curl -s -X POST "${OLLAMA_ENDPOINT}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"codellama:latest\", \"prompt\": \"${review_prompt}\", \"stream\": false}" | jq -r '.response' 2>/dev/null)

  if [[ $? -eq 0 && -n ${review_result} ]]; then
    # Save review results
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local result_file="${WORKSPACE}/Tools/Automation/results/CodeReview_${project}_${timestamp}.md"

    mkdir -p "${WORKSPACE}/Tools/Automation/results"
    {
      echo "# Ollama Code Review Report"
      echo "**Project:** ${project}"
      echo "**Review Date:** $(date)"
      echo "**Files Reviewed:** ${swift_files}"
      echo "**AI Model:** CodeLlama (Free Ollama Service)"
      echo ""
      echo "## Code Review Results"
      echo ""
      echo "${review_result}"
      echo ""
      echo "---"
      echo "*Generated by Code Review Agent using Ollama*"
    } >"${result_file}"

    echo "[$(date)] ${AGENT_NAME}: Code review completed and saved to ${result_file}" >>"${LOG_FILE}"

    # Generate automated fixes if issues found
    if [[ ${review_result} =~ (bug|error|issue|fix|improve) ]]; then
      echo "[$(date)] ${AGENT_NAME}: Issues detected, generating automated fixes..." >>"${LOG_FILE}"
      generate_automated_fixes "${project}" "${review_result}"
    fi

  else
    echo "[$(date)] ${AGENT_NAME}: Failed to get Ollama code review" >>"${LOG_FILE}"
  fi
}

# Generate automated fixes
generate_automated_fixes() {
  local project="$1"
  local review_result="$2"

  echo "[$(date)] ${AGENT_NAME}: Generating automated fixes for ${project}" >>"${LOG_FILE}"

  local fix_prompt="Based on this code review, generate specific code fixes and improvements:

${review_result}

Please provide:
1. SPECIFIC CODE FIXES with exact changes
2. REFACTORING SUGGESTIONS with before/after examples
3. NEW CODE ADDITIONS for missing functionality
4. CONFIGURATION CHANGES if needed

Format as actionable code changes that can be directly applied."

  local fix_result
  fix_result=$(curl -s -X POST "${OLLAMA_ENDPOINT}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"codellama:latest\", \"prompt\": \"${fix_prompt}\", \"stream\": false}" | jq -r '.response' 2>/dev/null)

  if [[ $? -eq 0 && -n ${fix_result} ]]; then
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local fix_file="${WORKSPACE}/Tools/Automation/results/AutoFix_${project}_${timestamp}.md"

    {
      echo "# Automated Code Fixes"
      echo "**Project:** ${project}"
      echo "**Generated:** $(date)"
      echo "**Based on:** Code Review Analysis"
      echo ""
      echo "## Recommended Fixes"
      echo ""
      echo "${fix_result}"
      echo ""
      echo "---"
      echo "*Generated by Code Review Agent using Ollama*"
    } >"${fix_file}"

    echo "[$(date)] ${AGENT_NAME}: Automated fixes generated and saved to ${fix_file}" >>"${LOG_FILE}"
  fi
}

# Run quality assessment
run_quality_assessment() {
  local task_desc="$1"
  echo "[$(date)] ${AGENT_NAME}: Running quality assessment for: ${task_desc}" >>"${LOG_FILE}"

  # Extract project name
  local project="CodingReviewer"
  if [[ ${task_desc} =~ MomentumFinance ]]; then
    project="MomentumFinance"
  elif [[ ${task_desc} =~ HabitQuest ]]; then
    project="HabitQuest"
  fi

  local project_path="${WORKSPACE}/Projects/${project}"

  if [[ ! -d ${project_path} ]]; then
    echo "[$(date)] ${AGENT_NAME}: ERROR - Project path not found: ${project_path}" >>"${LOG_FILE}"
    return 1
  fi

  cd "${project_path}" || return 1

  # Calculate metrics
  local swift_files
  swift_files=$(find . -name "*.swift" | wc -l)
  local total_lines
  total_lines=$(find . -name "*.swift" -exec wc -l {} \; | awk '{sum += $1} END {print sum}')
  local functions
  functions=$(find . -name "*.swift" -exec grep -c "func " {} \; | awk '{sum += $1} END {print sum}')
  local classes
  classes=$(find . -name "*.swift" -exec grep -c "class " {} \; | awk '{sum += $1} END {print sum}')

  # Quality assessment prompt
  local quality_prompt="Assess the code quality of this Swift project with the following metrics:

Project: ${project}
Swift Files: ${swift_files}
Total Lines: ${total_lines}
Functions: ${functions}
Classes: ${classes}

Provide a comprehensive quality assessment including:
1. Code maintainability score
2. Complexity analysis
3. Test coverage estimation
4. Documentation quality
5. Architecture assessment
6. Recommendations for improvement"

  local quality_result
  quality_result=$(curl -s -X POST "${OLLAMA_ENDPOINT}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"codellama:latest\", \"prompt\": \"${quality_prompt}\", \"stream\": false}" | jq -r '.response' 2>/dev/null)

  if [[ $? -eq 0 && -n ${quality_result} ]]; then
    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local quality_file="${WORKSPACE}/Tools/Automation/results/Quality_${project}_${timestamp}.md"

    {
      echo "# Code Quality Assessment"
      echo "**Project:** ${project}"
      echo "**Assessment Date:** $(date)"
      echo "**Metrics:** ${swift_files} files, ${total_lines} lines, ${functions} functions, ${classes} classes"
      echo ""
      echo "## Quality Assessment Results"
      echo ""
      echo "${quality_result}"
      echo ""
      echo "---"
      echo "*Generated by Code Review Agent using Ollama*"
    } >"${quality_file}"

    echo "[$(date)] ${AGENT_NAME}: Quality assessment saved to ${quality_file}" >>"${LOG_FILE}"
  fi
}

# Main agent loop
echo "[$(date)] ${AGENT_NAME}: Starting Code Review Agent..." >>"${LOG_FILE}"
update_status "available"

# Track processed tasks to avoid duplicates
declare -A processed_tasks

while true; do
  # Check for new task notifications
  if [[ -f ${NOTIFICATION_FILE} ]]; then
    while IFS='|' read -r _timestamp action task_id; do
      if [[ ${action} == "execute_task" && -z ${processed_tasks[${task_id}]} ]]; then
        update_status "busy"
        process_task "${task_id}"
        update_status "available"
        processed_tasks[${task_id}]="completed"
        echo "[$(date)] ${AGENT_NAME}: Marked task ${task_id} as processed" >>"${LOG_FILE}"
      fi
    done <"${NOTIFICATION_FILE}"

    # Clear processed notifications
    true >"${NOTIFICATION_FILE}"
  fi

  # Update last seen timestamp
  update_status "available"

  sleep 30 # Check every 30 seconds
done
