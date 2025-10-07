#!/bin/bash
# Security Agent: Analyzes and improves code security

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="security_agent.sh"
WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
LOG_FILE="${WORKSPACE}/Tools/Automation/agents/security_agent.log"
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

analyze_security_vulnerabilities() {
  local code_content="$1"
  local file_path="$2"

  local prompt="Analyze this code for security vulnerabilities:

File: ${file_path}
Code:
${code_content}

Check for:
1. Input validation vulnerabilities
2. Authentication/authorization issues
3. Data exposure risks
4. Injection vulnerabilities (SQL, command, etc.)
5. Cryptographic weaknesses
6. Access control flaws
7. Error handling that leaks sensitive information
8. Hardcoded secrets or credentials

Provide specific vulnerability findings with severity levels and fix recommendations."

  local analysis
  analysis=$(ollama_query "${prompt}")

  if [[ -n ${analysis} ]]; then
    echo "${analysis}"
    return 0
  else
    log "ERROR: Failed to analyze security vulnerabilities with Ollama"
    return 1
  fi
}

# Update agent status to available when starting
update_status() {
  local status="$1"
  if command -v jq &>/dev/null; then
    jq ".agents[\"${AGENT_NAME}\"].status = \"${status}\" | .agents[\"${AGENT_NAME}\"].last_seen = $(date +%s)" "${AGENT_STATUS_FILE}" >"${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "${AGENT_STATUS_FILE}"
  fi
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
    "sec" | "security" | "vulnerability")
      run_security_analysis "${task_desc}"
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

# Security analysis function
run_security_analysis() {
  local task_desc="$1"
  echo "[$(date)] ${AGENT_NAME}: Running security analysis for: ${task_desc}" >>"${LOG_FILE}"

  # Extract project name from task description
  local projects=("CodingReviewer" "MomentumFinance" "HabitQuest" "PlannerApp" "AvoidObstaclesGame")

  for project in "${projects[@]}"; do
    if [[ -d "${WORKSPACE}/Projects/${project}" ]]; then
      log "Analyzing security in ${project}..."
      cd "${WORKSPACE}/Projects/${project}" || return

      # Security metrics
      echo "[$(date)] ${AGENT_NAME}: Calculating security metrics for ${project}..." >>"${LOG_FILE}"

      # Count Swift files
      local swift_files
      swift_files=$(find . -name "*.swift" | wc -l)
      log "Total Swift files: ${swift_files}"

      # Analyze security vulnerabilities
      log "Analyzing security vulnerabilities..."

      # Check for common security issues
      local hard_coded_secrets
      hard_coded_secrets=$(find . -name "*.swift" -exec grep -l "password\|secret\|key.*=.*\"" {} \; | wc -l)
      local sql_injection
      sql_injection=$(find . -name "*.swift" -exec grep -l "SELECT.*+.*\|INSERT.*+.*\|UPDATE.*+.*" {} \; | wc -l)
      local weak_crypto
      weak_crypto=$(find . -name "*.swift" -exec grep -l "MD5\|SHA1" {} \; | wc -l)
      local unsafe_urls
      unsafe_urls=$(find . -name "*.swift" -exec grep -l "http://" {} \; | wc -l)
      local exposed_data
      exposed_data=$(find . -name "*.swift" -exec grep -l "UserDefaults\|Keychain" {} \; | wc -l)
      local input_validation
      input_validation=$(find . -name "*.swift" -exec grep -l "guard.*let\|if.*nil" {} \; | wc -l)

      {
        echo "[$(date)] ${AGENT_NAME}: Hard-coded secrets found in ${hard_coded_secrets} files"
        echo "[$(date)] ${AGENT_NAME}: SQL injection risks found in ${sql_injection} files"
        echo "[$(date)] ${AGENT_NAME}: Weak cryptography found in ${weak_crypto} files"
        echo "[$(date)] ${AGENT_NAME}: Unsafe URLs found in ${unsafe_urls} files"
        echo "[$(date)] ${AGENT_NAME}: Data exposure risks found in ${exposed_data} files"
        echo "[$(date)] ${AGENT_NAME}: Input validation found in ${input_validation} files"
      } >>"${LOG_FILE}"

      # Check for authentication and authorization
      local auth_usage
      auth_usage=$(find . -name "*.swift" -exec grep -l "authenticate\|login\|session" {} \; | wc -l)
      local permission_checks
      permission_checks=$(find . -name "*.swift" -exec grep -l "canRead\|canWrite\|hasPermission" {} \; | wc -l)

      {
        echo "[$(date)] ${AGENT_NAME}: Authentication usage: ${auth_usage} files"
        echo "[$(date)] ${AGENT_NAME}: Permission checks: ${permission_checks} files"
      } >>"${LOG_FILE}"

      # Calculate security score (simple heuristic)
      local security_score=$((100 - (hard_coded_secrets * 20) - (sql_injection * 15) - (weak_crypto * 10) - (unsafe_urls * 5)))
      if [[ ${security_score} -lt 0 ]]; then
        security_score=0
      fi

      echo "[$(date)] ${AGENT_NAME}: Security score for ${project}: ${security_score}%" >>"${LOG_FILE}"

      # Use Ollama for intelligent security analysis
      log "Using Ollama for intelligent security analysis..."

      # Find files with potential security issues for deep analysis
      local suspicious_files
      suspicious_files=$(find . -name "*.swift" -exec grep -l "password\|secret\|SELECT.*+\|INSERT.*+\|MD5\|SHA1\|http://" {} \; | head -3)

      for file in ${suspicious_files}; do
        if [[ -f ${file} ]]; then
          log "Deep security analysis of ${file} using Ollama..."
          local content
          content=$(cat "${file}")
          local ollama_analysis
          ollama_analysis=$(analyze_security_vulnerabilities "${content}" "${file}")
          if [[ -n ${ollama_analysis} ]]; then
            log "Ollama security analysis completed for ${file}"
          fi
        fi
      done

      if [[ ${hard_coded_secrets} -gt 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: CRITICAL: Remove hard-coded secrets and use secure storage" >>"${LOG_FILE}"
      fi

      if [[ ${sql_injection} -gt 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: CRITICAL: Use parameterized queries to prevent SQL injection" >>"${LOG_FILE}"
      fi

      if [[ ${weak_crypto} -gt 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: HIGH: Replace weak cryptography with strong algorithms (SHA256, AES)" >>"${LOG_FILE}"
      fi

      if [[ ${unsafe_urls} -gt 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: MEDIUM: Use HTTPS instead of HTTP for all network requests" >>"${LOG_FILE}"
      fi

      if [[ ${exposed_data} -gt 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: MEDIUM: Review data storage practices and use encryption" >>"${LOG_FILE}"
      fi

      if [[ ${input_validation} -eq 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: MEDIUM: Add input validation for all user inputs" >>"${LOG_FILE}"
      fi

      if [[ ${auth_usage} -eq 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: HIGH: Implement proper authentication mechanisms" >>"${LOG_FILE}"
      fi

      if [[ ${permission_checks} -eq 0 ]]; then
        echo "[$(date)] ${AGENT_NAME}: MEDIUM: Add authorization checks for sensitive operations" >>"${LOG_FILE}"
      fi
    fi
  done

  echo "[$(date)] ${AGENT_NAME}: Security analysis completed" >>"${LOG_FILE}"
}

# Main agent loop
echo "[$(date)] ${AGENT_NAME}: Starting security agent..." >>"${LOG_FILE}"
update_status "available"

# Track processed tasks to avoid duplicates
declare -A processed_tasks

while true; do
  # Check for new task notifications
  if [[ -f ${NOTIFICATION_FILE} ]]; then
    while IFS='|' read -r _ action task_id; do
      if [[ ${action} == "execute_task" && -z ${processed_tasks[${task_id}]} ]]; then
        update_status "busy"
        process_task "${task_id}"
        update_status "available"
        processed_tasks[${task_id}]="completed"
        echo "[$(date)] ${AGENT_NAME}: Marked task ${task_id} as processed" >>"${LOG_FILE}"
      fi
    done <"${NOTIFICATION_FILE}"

    # Clear processed notifications to prevent re-processing
    true >"${NOTIFICATION_FILE}"
  fi

  # Update last seen timestamp
  update_status "available"

  sleep 30 # Check every 30 seconds
done
