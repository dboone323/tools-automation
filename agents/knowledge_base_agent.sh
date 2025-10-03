#!/bin/bash
# Knowledge Base Agent: Maintains and shares best practices across all agents

AGENT_NAME="KnowledgeBaseAgent"
LOG_FILE="$(dirname "$0")/knowledge_base_agent.log"
NOTIFICATION_FILE="$(dirname "$0")/communication/${AGENT_NAME}_notification.txt"
COMPLETED_FILE="$(dirname "$0")/communication/${AGENT_NAME}_completed.txt"
KNOWLEDGE_BASE_FILE="$(dirname "$0")/knowledge_base.json"
LEARNING_HISTORY_FILE="$(dirname "$0")/learning_history.json"

# Knowledge categories
# shellcheck disable=SC2034
declare -a KNOWLEDGE_CATEGORIES=(
  "swift_best_practices"
  "ios_development"
  "testing_strategies"
  "performance_optimization"
  "security_practices"
  "code_quality"
  "ci_cd_practices"
  "architecture_patterns"
)

# Learning sources
# shellcheck disable=SC2034
declare -a LEARNING_SOURCES=(
  "agent_logs"
  "project_analysis"
  "external_apis"
  "community_best_practices"
  "performance_metrics"
  "error_patterns"
)

# Initialize files
mkdir -p "$(dirname "$0")/communication" "$(dirname "$0")/knowledge_exports"
touch "${NOTIFICATION_FILE}"
touch "${COMPLETED_FILE}"

if [[ ! -f ${KNOWLEDGE_BASE_FILE} ]]; then
  cat >"${KNOWLEDGE_BASE_FILE}" <<'EOF'
{
  "metadata": {
    "version": "1.0",
    "last_updated": "",
    "total_entries": 0
  },
  "categories": {},
  "patterns": {},
  "recommendations": {},
  "metrics": {}
}
EOF
fi

if [[ ! -f ${LEARNING_HISTORY_FILE} ]]; then
  echo '{"learning_sessions": [], "insights": [], "improvements": []}' >"${LEARNING_HISTORY_FILE}"
fi

log_message() {
  local level
  level="$1"
  local message
  message="$2"
  echo "[$(date)] [${level}] ${message}" >>"${LOG_FILE}"
}

# Notify orchestrator of task completion
notify_completion() {
  local task_id
  task_id="$1"
  local success
  success="$2"
  echo "$(date +%s)|${task_id}|${success}" >>"${COMPLETED_FILE}"
}

# Learn from agent logs
learn_from_agent_logs() {
  log_message "INFO" "Learning from agent logs..."

  local insights_found
  insights_found=0

  local log_dir
  log_dir="$(dirname "$0")"

  # Analyze all agent logs
  for log_file in "${log_dir}"/*.log; do
    if [[ ! -f ${log_file} || ${log_file} == "${LOG_FILE}" ]]; then
      continue
    fi

    local agent_name
    agent_name=$(basename "${log_file}" .log)

    # Extract error patterns
    local error_patterns
    error_patterns=$(grep -i "error\|failed\|exception" "${log_file}" | tail -10)
    if [[ -n ${error_patterns} ]]; then
      extract_error_patterns "${agent_name}" "${error_patterns}"
      ((insights_found++))
    fi

    # Extract success patterns
    local success_patterns
    success_patterns=$(grep -i "success\|completed\|✅" "${log_file}" | tail -10)
    if [[ -n ${success_patterns} ]]; then
      extract_success_patterns "${agent_name}" "${success_patterns}"
      ((insights_found++))
    fi

    # Extract performance insights
    local perf_patterns
    perf_patterns=$(grep -i "performance\|duration\|optimization" "${log_file}" | tail -5)
    if [[ -n ${perf_patterns} ]]; then
      extract_performance_insights "${agent_name}" "${perf_patterns}"
      ((insights_found++))
    fi
  done

  log_message "INFO" "Found ${insights_found} insights from agent logs"
}

# Extract error patterns and create prevention strategies
extract_error_patterns() {
  local agent_name
  agent_name="$1"
  local error_patterns
  error_patterns="$2"

  # Analyze common error types
  if echo "${error_patterns}" | grep -qi "timeout\|connection"; then
    add_knowledge_entry "error_prevention" "network_timeout" "Implement retry mechanisms for network operations" "high"
  fi

  if echo "${error_patterns}" | grep -qi "permission\|access"; then
    add_knowledge_entry "error_prevention" "permission_denied" "Validate file permissions before operations" "medium"
  fi

  if echo "${error_patterns}" | grep -qi "memory\|out_of_memory"; then
    add_knowledge_entry "performance_optimization" "memory_management" "Implement memory monitoring and cleanup routines" "high"
  fi
}

# Extract success patterns and create best practices
extract_success_patterns() {
  local agent_name
  agent_name="$1"
  local success_patterns
  success_patterns="$2"

  # Analyze successful strategies
  if echo "${success_patterns}" | grep -qi "parallel\|concurrent"; then
    add_knowledge_entry "performance_optimization" "parallel_processing" "Use parallel processing for independent operations" "medium"
  fi

  if echo "${success_patterns}" | grep -qi "cache\|cached"; then
    add_knowledge_entry "performance_optimization" "caching_strategy" "Implement intelligent caching for frequently accessed data" "medium"
  fi
}

# Extract performance insights
extract_performance_insights() {
  local agent_name
  agent_name="$1"
  local perf_patterns
  perf_patterns="$2"

  # Analyze performance data
  local avg_duration
  avg_duration=$(echo "${perf_patterns}" | grep -o '[0-9]\+\.[0-9]\+s\|[0-9]\+s' | sed 's/s//' | awk '{sum+=$1; count++} END {if(count>0) print sum/count; else print 0}')

  if [[ $(echo "${avg_duration} > 300" | bc -l 2>/dev/null) -eq 1 ]]; then
    add_knowledge_entry "performance_optimization" "long_running_tasks" "Optimize tasks taking longer than 5 minutes" "high"
  fi
}

# Learn from project analysis
learn_from_project_analysis() {
  log_message "INFO" "Learning from project analysis..."

  # Analyze project structure and patterns
  local project_count
  local projects_root="/Users/danielstevens/Desktop/Quantum-workspace/Projects"
  project_count=$(find "${projects_root}" -maxdepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
  local swift_files
  swift_files=$(find "${projects_root}" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')

  # Extract architectural patterns
  if [[ ${project_count} -gt 5 ]]; then
    add_knowledge_entry "architecture_patterns" "multi_project_setup" "Maintain consistent structure across ${project_count} projects" "medium"
  fi

  # Analyze code quality patterns
  local avg_files_per_project=0
  if [[ ${project_count} -gt 0 ]]; then
    avg_files_per_project=$((swift_files / project_count))
  fi
  if [[ ${avg_files_per_project} -gt 50 ]]; then
    add_knowledge_entry "architecture_patterns" "large_codebase" "Implement modular architecture for large codebases" "high"
  fi
}

# Learn from external APIs and best practices
learn_from_external_sources() {
  log_message "INFO" "Learning from external sources..."

  # Check for Swift evolution proposals (simplified)
  local swift_version
  swift_version=$(swift --version 2>/dev/null | grep -o 'Swift version [0-9]\+\.[0-9]\+' | head -1)
  if [[ -n ${swift_version} ]]; then
    add_knowledge_entry "swift_best_practices" "swift_version" "Current Swift version: ${swift_version} - stay updated with latest features" "low"
  fi

  # iOS development best practices
  add_knowledge_entry "ios_development" "deployment_target" "Target iOS 15.0+ for modern features and security" "medium"
  add_knowledge_entry "ios_development" "architecture" "Use MVVM or Clean Architecture for scalable iOS apps" "high"

  # Testing strategies
  add_knowledge_entry "testing_strategies" "test_coverage" "Maintain 80%+ test coverage for critical components" "high"
  add_knowledge_entry "testing_strategies" "ui_testing" "Implement UI tests for critical user flows" "medium"
}

# Add knowledge entry to database
add_knowledge_entry() {
  local category
  category="$1"
  local key
  key="$2"
  local value
  value="$3"
  local priority
  priority="$4"
  local entry_id
  entry_id="${category}_${key}_$(date +%s)"

  if command -v jq &>/dev/null; then
    # Check if entry already exists
    local existing
    existing=$(jq -r ".categories.\"${category}\".\"${key}\" // empty" "${KNOWLEDGE_BASE_FILE}")

    if [[ -z ${existing} ]]; then
      # Add new entry
      jq --arg category "${category}" --arg key "${key}" --arg value "${value}" --arg priority "${priority}" --arg entry_id "${entry_id}" \
        '.categories[$category] = (.categories[$category] // {}) | .categories[$category][$key] = {"value": $value, "priority": $priority, "id": $entry_id, "created": now, "usage_count": 0}' \
        "${KNOWLEDGE_BASE_FILE}" >"${KNOWLEDGE_BASE_FILE}.tmp" && mv "${KNOWLEDGE_BASE_FILE}.tmp" "${KNOWLEDGE_BASE_FILE}"

      log_message "INFO" "Added knowledge entry: ${category}/${key}"
    else
      # Update existing entry usage
      jq --arg category "${category}" --arg key "${key}" \
        '.categories[$category][$key].usage_count = (.categories[$category][$key].usage_count // 0) + 1' \
        "${KNOWLEDGE_BASE_FILE}" >"${KNOWLEDGE_BASE_FILE}.tmp" && mv "${KNOWLEDGE_BASE_FILE}.tmp" "${KNOWLEDGE_BASE_FILE}"
    fi
  fi
}

# Share knowledge with other agents
share_knowledge() {
  log_message "INFO" "Sharing knowledge with other agents..."

  local shared_count

  shared_count=0

  # Create knowledge summary for each agent
  for agent_script in "$(dirname "$0")"/agent_*.sh; do
    if [[ -f ${agent_script} ]]; then
      local agent_name
      agent_name=$(basename "${agent_script}" .sh)
      local agent_capabilities
      # shellcheck disable=SC2153
      if declare -p AGENT_CAPABILITIES >/dev/null 2>&1; then
        agent_capabilities="${AGENT_CAPABILITIES[${agent_script}]}"
      else
        agent_capabilities="general"
      fi

      # Generate personalized knowledge for this agent
      generate_agent_knowledge "${agent_name}" "${agent_capabilities}"
      ((shared_count++))
    fi
  done

  # Share with specialized agents
  for agent_script in "$(dirname "$0")"/{pull_request,auto_update}_agent.sh; do
    if [[ -f ${agent_script} ]]; then
      local agent_name
      agent_name=$(basename "${agent_script}" .sh)
      generate_agent_knowledge "${agent_name}" "specialized"
      ((shared_count++))
    fi
  done

  log_message "INFO" "Shared knowledge with ${shared_count} agents"
}

# Generate personalized knowledge for specific agent
generate_agent_knowledge() {
  local agent_name
  agent_name="$1"
  local capabilities
  capabilities="$2"

  local knowledge_file

  knowledge_file="$(dirname "$0")/knowledge_exports/${agent_name}_knowledge.json"

  if command -v jq &>/dev/null; then
    # Extract relevant knowledge based on agent capabilities
    jq --arg capabilities "${capabilities}" '{
            relevant_practices: .categories | to_entries[] | select(.key | contains($capabilities)) | .value,
            recommendations: .recommendations | to_entries[] | select(.key | contains($capabilities)) | .value,
            patterns: .patterns | to_entries[] | select(.key | contains($capabilities)) | .value
        }' "${KNOWLEDGE_BASE_FILE}" >"${knowledge_file}"

    log_message "INFO" "Generated knowledge file for ${agent_name}: ${knowledge_file}"
  fi
}

# Analyze learning effectiveness
analyze_learning_effectiveness() {
  log_message "INFO" "Analyzing learning effectiveness..."

  if ! command -v jq &>/dev/null; then
    return
  fi

  # Calculate knowledge growth
  local total_entries
  total_entries=$(jq '.categories | map(length) | add' "${KNOWLEDGE_BASE_FILE}")
  local high_priority_entries
  high_priority_entries=$(jq '.categories | map(to_entries[] | select(.value.priority == "high")) | flatten | length' "${KNOWLEDGE_BASE_FILE}")

  # Analyze usage patterns
  local most_used
  most_used=$(jq -r '.categories | to_entries[] | .value | to_entries[] | select(.value.usage_count > 0) | "\(.key): \(.value.usage_count)"' "${KNOWLEDGE_BASE_FILE}" | sort -t: -k2 -nr | head -5)

  # Generate learning insights
  local insight
  insight="Knowledge base contains ${total_entries} entries with ${high_priority_entries} high-priority items"

  if [[ -n ${most_used} ]]; then
    insight="${insight}. Most used practices: ${most_used}"
  fi

  # Record learning session
  record_learning_session "effectiveness_analysis" "${insight}"

  log_message "INFO" "Learning analysis: ${insight}"
}

# Record learning session
record_learning_session() {
  local session_type
  session_type="$1"
  local insights
  insights="$2"

  if command -v jq &>/dev/null; then
    local session_data
    session_data="{\"type\": \"${session_type}\", \"insights\": \"${insights}\", \"timestamp\": $(date +%s)}"
    jq --argjson session "${session_data}" '.learning_sessions += [$session]' "${LEARNING_HISTORY_FILE}" >"${LEARNING_HISTORY_FILE}.tmp" && mv "${LEARNING_HISTORY_FILE}.tmp" "${LEARNING_HISTORY_FILE}"
  fi
}

# Generate knowledge base report
generate_knowledge_report() {
  local report_file
  report_file="$(dirname "$0")/knowledge_reports/knowledge_report_$(date +%Y%m%d_%H%M%S).md"
  mkdir -p "$(dirname "${report_file}")"

  {
    echo "# Knowledge Base Report"
    echo "Generated: $(date)"
    echo ""

    if command -v jq &>/dev/null; then
      local total_entries
      total_entries=$(jq '.categories | map(length) | add' "${KNOWLEDGE_BASE_FILE}")
      local categories_count
      categories_count=$(jq '.categories | length' "${KNOWLEDGE_BASE_FILE}")

      echo "## Knowledge Base Overview"
      echo "- Total Knowledge Entries: ${total_entries}"
      echo "- Categories: ${categories_count}"
      echo "- Last Updated: $(jq -r '.metadata.last_updated // "Never"' "${KNOWLEDGE_BASE_FILE}")"
      echo ""

      echo "## Categories"
      jq -r '.categories | to_entries[] | "- **\(.key)**: \(.value | length) entries"' "${KNOWLEDGE_BASE_FILE}"
      echo ""

      echo "## High Priority Items"
      jq -r '.categories | to_entries[] | .value | to_entries[] | select(.value.priority == "high") | "- \(.key): \(.value.value)"' "${KNOWLEDGE_BASE_FILE}" | head -10
      echo ""

      echo "## Most Used Practices"
      jq -r '.categories | to_entries[] | .value | to_entries[] | select(.value.usage_count > 0) | "\(.key): \(.value.usage_count) uses"' "${KNOWLEDGE_BASE_FILE}" | sort -t: -k2 -nr | head -5
      echo ""

      echo "## Recent Learning Sessions"
      jq -r '.learning_sessions[-3:][] | "- **\(.type)** (\(strftime("%Y-%m-%d %H:%M") as $date | $date)): \(.insights)"' "${LEARNING_HISTORY_FILE}" 2>/dev/null || echo "No recent learning sessions"
    fi

  } >"${report_file}"

  log_message "INFO" "Knowledge report generated: ${report_file}"
}

# Update knowledge base metadata
update_metadata() {
  if command -v jq &>/dev/null; then
    local total_entries
    total_entries=$(jq '.categories | map(length) | add' "${KNOWLEDGE_BASE_FILE}")
    jq --arg total_entries "${total_entries}" '.metadata.last_updated = now | .metadata.total_entries = ($total_entries | tonumber)' "${KNOWLEDGE_BASE_FILE}" >"${KNOWLEDGE_BASE_FILE}.tmp" && mv "${KNOWLEDGE_BASE_FILE}.tmp" "${KNOWLEDGE_BASE_FILE}"
  fi
}

# Process notifications from orchestrator
process_notifications() {
  if [[ -f ${NOTIFICATION_FILE} ]]; then
    while IFS='|' read -r _timestamp notification_type task_id; do
      case "${notification_type}" in
      "new_task")
        log_message "INFO" "Received new task: ${task_id}"
        ;;
      "execute_task")
        log_message "INFO" "Executing task: ${task_id}"
        ;;
      "share_knowledge")
        log_message "INFO" "Knowledge sharing requested"
        share_knowledge
        ;;
      "analyze_learning")
        log_message "INFO" "Learning analysis requested"
        analyze_learning_effectiveness
        ;;
      esac
    done <"${NOTIFICATION_FILE}"

    # Clear processed notifications
    : >"${NOTIFICATION_FILE}"
  fi
}

# Main learning and knowledge sharing loop
log_message "INFO" "Knowledge Base Agent starting..."

while true; do
  # Process notifications from orchestrator
  process_notifications

  # Learn from various sources
  learn_from_agent_logs
  learn_from_project_analysis
  learn_from_external_sources

  # Share knowledge with other agents
  share_knowledge

  # Analyze learning effectiveness
  analyze_learning_effectiveness

  # Update metadata
  update_metadata

  # Generate periodic report (every 2 hours)
  current_minute=$(date +%M)
  if [[ $((current_minute % 120)) -eq 0 ]]; then
    generate_knowledge_report
  fi

  sleep 1800 # Learn and share every 30 minutes
done
