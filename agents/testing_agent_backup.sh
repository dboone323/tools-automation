#!/bin/bash
# Testing Agent: Manages and improves test coverage and quality

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="testing_agent.sh"
WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
LOG_FILE="${WORKSPACE}/Tools/Automation/agents/testing_agent.log"
NOTIFICATION_FILE="${WORKSPACE}/Tools/Automation/agents/communication/${AGENT_NAME}_notification.txt"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/Tools/Automation/agents/task_queue.json"
OLLAMA_ENDPOINT="http://localhost:11434"

# Logging function
log() {
  echo "[$(date)] ${AGENT_NAME}: $*" >>"${LOG_FILE}"
}

# Ollama Integration Functions
ollama_query() {
  local prompt="$1"
  local model="${2:-codellama}"

  curl -s -X POST "${OLLAMA_ENDPOINT}/api/generate" \
    -H "Content-Type: application/json" \
    -d "{\"model\": \"${model}\", \"prompt\": \"${prompt}\", \"stream\": false}" |
    jq -r '.response // empty'
}

generate_test_with_ollama() {
  local source_file="$1"
  local test_type="$2"

  if [[ ! -f ${source_file} ]]; then
    log "ERROR: Source file not found: ${source_file}"
    return 1
  fi

  local source_content
  source_content=$(cat "${source_file}")

  local prompt="Generate comprehensive unit tests for this Swift code. Include edge cases, error handling, and async tests where appropriate:

${source_content}

Generate tests in the following format:
- Test class structure
- Individual test methods
- Setup and teardown methods
- Mock objects if needed
- Assertions for all scenarios

Focus on ${test_type} testing."

  local generated_tests
  generated_tests=$(ollama_query "${prompt}")

  if [[ -n ${generated_tests} ]]; then
    echo "${generated_tests}"
    return 0
  else
    log "ERROR: Failed to generate tests with Ollama"
    return 1
  fi
}

analyze_test_quality_with_ollama() {
  local test_file="$1"

  if [[ ! -f ${test_file} ]]; then
    log "ERROR: Test file not found: ${test_file}"
    return 1
  fi

  local test_content
  test_content=$(cat "${test_file}")

  local prompt="Analyze the quality of these Swift unit tests. Provide feedback on:
1. Test coverage completeness
2. Edge case coverage
3. Assertion quality
4. Test isolation
5. Naming conventions
6. Setup/teardown usage
7. Mock/stub usage
8. Async testing patterns

Tests to analyze:
${test_content}

Provide specific recommendations for improvement."

  local analysis
  analysis=$(ollama_query "${prompt}")

  if [[ -n ${analysis} ]]; then
    echo "${analysis}"
    return 0
  else
    log "ERROR: Failed to analyze test quality with Ollama"
    return 1
  fi
}

# Update agent status to available when starting
update_status() {
  local status="$1"
  local temp_file="${AGENT_STATUS_FILE}.tmp.$$"

  # Simple atomic update without complex jq operations
  if command -v jq &>/dev/null; then
    # Read current content
    local current_content
    current_content=$(cat "${AGENT_STATUS_FILE}" 2>/dev/null || echo '{"agents":{},"last_update":0}')

    # Update the specific agent status
    local updated_content
    updated_content=$(echo "${current_content}" | jq ".agents[\"${AGENT_NAME}\"] = (.agents[\"${AGENT_NAME}\"] // {}) | .agents[\"${AGENT_NAME}\"].status = \"${status}\" | .agents[\"${AGENT_NAME}\"].last_seen = $(date +%s) | .last_update = $(date +%s)" 2>/dev/null)

    if [[ -n "${updated_content}" ]]; then
      echo "${updated_content}" >"${temp_file}" && mv "${temp_file}" "${AGENT_STATUS_FILE}"
    fi
  fi

  rm -f "${temp_file}"
  echo "[$(date)] ${AGENT_NAME}: Status updated to ${status}" >>"${LOG_FILE}"
}

# Process a specific task
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
    "test" | "testing" | "coverage")
      run_testing_analysis "${task_desc}"
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
  local temp_file="${TASK_QUEUE_FILE}.tmp.$$"

  # Simple atomic update
  if command -v jq &>/dev/null; then
    local current_content
    current_content=$(cat "${TASK_QUEUE_FILE}" 2>/dev/null || echo '{"tasks":[]}')

    local updated_content
    updated_content=$(echo "${current_content}" | jq "(.tasks[] | select(.id == \"${task_id}\") | .status) = \"${status}\"" 2>/dev/null)

    if [[ -n "${updated_content}" ]]; then
      echo "${updated_content}" >"${temp_file}" && mv "${temp_file}" "${TASK_QUEUE_FILE}"
    fi
  fi

  rm -f "${temp_file}"
}

# Testing analysis function
run_testing_analysis() {
  local task_desc="$1"
  echo "[$(date)] ${AGENT_NAME}: Running testing analysis for: ${task_desc}" >>"${LOG_FILE}"

  # Extract project name from task description
  local projects=("CodingReviewer" "MomentumFinance" "HabitQuest" "PlannerApp" "AvoidObstaclesGame")

  for project in "${projects[@]}"; do
    if [[ -d "${WORKSPACE}/Projects/${project}" ]]; then
      echo "[$(date)] ${AGENT_NAME}: Analyzing testing coverage in ${project}..." >>"${LOG_FILE}"
      cd "${WORKSPACE}/Projects/${project}" || return

      # Test coverage metrics
      echo "[$(date)] ${AGENT_NAME}: Calculating testing metrics for ${project}..." >>"${LOG_FILE}"

      # Count test files - use full paths and check for common test directory patterns
      local test_files=0
      local test_dirs=("Tests" "*Tests" "*UITests" "HabitQuestTests" "PlannerAppTests" "AvoidObstaclesGameTests" "CodingReviewerTests" "MomentumFinanceTests")

      for test_dir in "${test_dirs[@]}"; do
        if [[ -d "${test_dir}" ]]; then
          local count
          count=$(find "${test_dir}" -name "*.swift" 2>/dev/null | wc -l)
          test_files=$((test_files + count))
        fi
      done

      # Also count test files in root if no test directories found
      if [[ ${test_files} -eq 0 ]]; then
        test_files=$(find . -name "*Test*.swift" -o -name "*Tests*.swift" 2>/dev/null | wc -l)
      fi

      echo "[$(date)] ${AGENT_NAME}: Test files found: ${test_files}" >>"${LOG_FILE}"

      # Count source files - exclude test files and common non-source directories
      local source_files
      source_files=$(find . -name "*.swift" -not -path "*/Tests/*" -not -path "*/HabitQuestTests/*" -not -path "*/PlannerAppTests/*" -not -path "*/AvoidObstaclesGameTests/*" -not -path "*/CodingReviewerTests/*" -not -path "*/MomentumFinanceTests/*" -not -path "*/UITests/*" -not -path "*/.build/*" -not -path "*/Carthage/*" -not -path "*/Pods/*" 2>/dev/null | wc -l)
      echo "[$(date)] ${AGENT_NAME}: Source files found: ${source_files}" >>"${LOG_FILE}"

      # Calculate test coverage ratio
      local coverage_ratio=0
      if [[ ${source_files} -gt 0 ]]; then
        coverage_ratio=$((test_files * 100 / source_files))
      fi
      echo "[$(date)] ${AGENT_NAME}: Test coverage ratio: ${coverage_ratio}%" >>"${LOG_FILE}"

      # Analyze test quality if test files exist
      echo "[$(date)] ${AGENT_NAME}: Analyzing test quality..." >>"${LOG_FILE}"

      if [[ ${test_files} -gt 0 ]]; then
        # Find actual test files that exist
        local test_file_list
        test_file_list=$(find . -name "*Test*.swift" -o -name "*Tests*.swift" 2>/dev/null | head -10)

        local unit_tests=0
        local ui_tests=0
        local async_tests=0
        local missing_asserts=0

        for test_file in ${test_file_list}; do
          if [[ -f "${test_file}" ]]; then
            # Check for test patterns safely
            if grep -q "func test" "${test_file}" 2>/dev/null; then
              unit_tests=$((unit_tests + 1))
            fi
            if grep -q "UITest\|UI Test" "${test_file}" 2>/dev/null; then
              ui_tests=$((ui_tests + 1))
            fi
            if grep -q "async" "${test_file}" 2>/dev/null; then
              async_tests=$((async_tests + 1))
            fi
            # Check for missing assertions
            if ! grep -q "XCTAssert\|XCTFail" "${test_file}" 2>/dev/null; then
              missing_asserts=$((missing_asserts + 1))
            fi
          fi
        done

        echo "[$(date)] ${AGENT_NAME}: Unit tests: ${unit_tests}" >>"${LOG_FILE}"
        echo "[$(date)] ${AGENT_NAME}: UI tests: ${ui_tests}" >>"${LOG_FILE}"
        echo "[$(date)] ${AGENT_NAME}: Async tests: ${async_tests}" >>"${LOG_FILE}"
        echo "[$(date)] ${AGENT_NAME}: Tests missing assertions: ${missing_asserts}" >>"${LOG_FILE}"

        # Calculate test quality score
        local quality_score=$((100 - (missing_asserts * 10)))
        if [[ ${quality_score} -lt 0 ]]; then
          quality_score=0
        fi
        echo "[$(date)] ${AGENT_NAME}: Test quality score: ${quality_score}%" >>"${LOG_FILE}"
      else
        echo "[$(date)] ${AGENT_NAME}: No test files found - test coverage is 0%" >>"${LOG_FILE}"
      fi

      # Use Ollama for intelligent test analysis and generation
      echo "[$(date)] ${AGENT_NAME}: Using Ollama for intelligent test analysis..." >>"${LOG_FILE}"

      # Find source files that need tests - limit to reasonable number
      local source_files_list
      source_files_list=$(find . -name "*.swift" -not -path "*/Tests/*" -not -path "*/HabitQuestTests/*" -not -path "*/PlannerAppTests/*" -not -path "*/AvoidObstaclesGameTests/*" -not -path "*/CodingReviewerTests/*" -not -path "*/MomentumFinanceTests/*" -not -path "*/UITests/*" 2>/dev/null | head -3)

      for source_file in ${source_files_list}; do
        if [[ -f "${source_file}" ]]; then
          local test_file="${source_file%.swift}Tests.swift"
          if [[ ! -f "${test_file}" ]]; then
            echo "[$(date)] ${AGENT_NAME}: Generating tests for ${source_file} using Ollama..." >>"${LOG_FILE}"
            local generated_tests
            generated_tests=$(generate_test_with_ollama "${source_file}" "unit")
            if [[ -n "${generated_tests}" ]]; then
              echo "[$(date)] ${AGENT_NAME}: Generated tests for ${source_file}" >>"${LOG_FILE}"
              # Could save generated tests to file here
            fi
          else
            # Analyze existing test quality
            local analysis
            analysis=$(analyze_test_quality_with_ollama "${test_file}")
            if [[ -n "${analysis}" ]]; then
              echo "[$(date)] ${AGENT_NAME}: Test quality analysis for ${test_file} completed" >>"${LOG_FILE}"
            fi
          fi
        fi
      done

      if [[ ${test_files} -eq 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Recommendation: Create unit tests for core functionality" >>"${LOG_FILE}"
        echo "[$(date)] ${AGENT_NAME}: Recommendation: Add UI tests for user interactions" >>"${LOG_FILE}"
      fi

      if [[ ${coverage_ratio} -lt 50 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Recommendation: Increase test coverage to at least 50%" >>"${LOG_FILE}"
      fi

      if [[ ${missing_asserts} -gt 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Recommendation: Add proper assertions to all test methods" >>"${LOG_FILE}"
      fi

      if [[ ${async_tests} -eq 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: Recommendation: Add async tests for network and database operations" >>"${LOG_FILE}"
      fi
    fi
  done

  echo "[$(date)] ${AGENT_NAME}: Testing analysis completed" >>"${LOG_FILE}"
}

# Main agent loop
echo "[$(date)] ${AGENT_NAME}: Starting testing agent..." >>"${LOG_FILE}"
update_status "available"

# Track processed tasks to avoid duplicates
PROCESSED_TASKS_FILE="$(dirname "$0")/communication/${AGENT_NAME}_processed_tasks.txt"
touch "${PROCESSED_TASKS_FILE}"

while true; do
  # Check for new task notifications
  if [[ -f ${NOTIFICATION_FILE} ]]; then
    while IFS='|' read -r _ action task_id; do
      if [[ ${action} == "execute_task" && ! $(grep -q "^${task_id}$" "${PROCESSED_TASKS_FILE}" 2>/dev/null) ]]; then
        update_status "busy"
        process_task "${task_id}"
        update_status "available"
        echo "${task_id}" >>"${PROCESSED_TASKS_FILE}"
        echo "[$(date)] ${AGENT_NAME}: Marked task ${task_id} as processed" >>"${LOG_FILE}"
      fi
    done <"${NOTIFICATION_FILE}"

    # Clear processed notifications to prevent re-processing
    true >"${NOTIFICATION_FILE}"
  fi

  # Check for assigned tasks that belong to this agent
  if [[ -f "${TASK_QUEUE_FILE}" ]]; then
    assigned_tasks=$(jq -r ".tasks[] | select(.assigned_agent == \"${AGENT_NAME}\" and .status == \"assigned\") | .id" "${TASK_QUEUE_FILE}" 2>/dev/null)
    for task_id in ${assigned_tasks}; do
      if [[ -n "${task_id}" && ! $(grep -q "^${task_id}$" "${PROCESSED_TASKS_FILE}" 2>/dev/null) ]]; then
        echo "[$(date)] ${AGENT_NAME}: Processing assigned task ${task_id}" >>"${LOG_FILE}"
        update_status "busy"
        process_task "${task_id}"
        update_status "available"
        echo "${task_id}" >>"${PROCESSED_TASKS_FILE}"
        echo "[$(date)] ${AGENT_NAME}: Marked assigned task ${task_id} as processed" >>"${LOG_FILE}"
      fi
    done
  fi

  # Update last seen timestamp
  update_status "available"

  sleep 30 # Check every 30 seconds
done
