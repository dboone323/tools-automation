#!/bin/bash
# AI-Powered Cleanup Optimization Module
# Provides intelligent cleanup prioritization, predictive disk analysis, and smart cache management

# Check if Ollama is available
check_ollama() {
  if command -v ollama &>/dev/null && ollama list &>/dev/null 2>&1; then
    return 0
  fi
  return 1
}

# AI-powered cleanup prioritization
ai_prioritize_cleanup() {
  local disk_usage_data="$1"

  if ! check_ollama; then
    echo "logs,cache,temp" # Safe default priority
    return
  fi

  local prompt="Analyze this disk usage data and prioritize what to clean first:
${disk_usage_data}

Consider:
- Space savings potential
- Safety of deletion
- System performance impact
- Data recovery difficulty

Return comma-separated priorities: logs, cache, temp, artifacts, derived_data"

  local priorities
  priorities=$(ollama run llama2 "${prompt}" 2>/dev/null | tr -d '[:space:]' | tr '[:upper:]' '[:lower:]')

  # Validate response contains expected keywords
  if echo "${priorities}" | grep -qE '(logs|cache|temp|artifacts|derived)'; then
    echo "${priorities}"
  else
    echo "logs,cache,temp,artifacts,derived_data" # Safe default
  fi
}

# Predictive disk usage analysis
ai_predict_disk_usage() {
  local historical_usage="$1"
  local days_ahead="${2:-7}"

  if ! check_ollama; then
    echo "0"
    return
  fi

  local prompt="Based on this historical disk usage data, predict usage in ${days_ahead} days (in GB):
${historical_usage}

Analyze trends and provide a single number (GB)."

  local prediction
  prediction=$(ollama run llama2 "${prompt}" 2>/dev/null | grep -oE '[0-9]+' | head -1)

  echo "${prediction:-0}"
}

# Intelligent cache management
ai_recommend_cache_policy() {
  local cache_stats="$1"

  if ! check_ollama; then
    echo "7" # Default: 7 days
    return
  fi

  local prompt="Based on these cache statistics, recommend optimal cache retention (days):
${cache_stats}

Consider:
- Cache hit rates
- Build performance impact
- Disk space constraints
- Cache regeneration cost

Respond with just the number of days (1-30)."

  local days
  days=$(ollama run llama2 "${prompt}" 2>/dev/null | grep -oE '[0-9]+' | head -1)

  # Ensure reasonable bounds: 1-30 days
  if [[ -n "${days}" ]]; then
    if [[ ${days} -lt 1 ]]; then
      echo "1"
    elif [[ ${days} -gt 30 ]]; then
      echo "30"
    else
      echo "${days}"
    fi
  else
    echo "7" # Safe default
  fi
}

# Smart log rotation recommendations
ai_optimize_log_rotation() {
  local log_stats="$1"

  if ! check_ollama; then
    echo "10" # Default: 10MB
    return
  fi

  local prompt="Based on these log file statistics, recommend optimal log rotation threshold (MB):
${log_stats}

Consider:
- Log growth rate
- Disk space availability
- Log analysis requirements
- Performance impact

Respond with just the number in MB (5-100)."

  local threshold
  threshold=$(ollama run llama2 "${prompt}" 2>/dev/null | grep -oE '[0-9]+' | head -1)

  # Ensure reasonable bounds: 5-100 MB
  if [[ -n "${threshold}" ]]; then
    if [[ ${threshold} -lt 5 ]]; then
      echo "5"
    elif [[ ${threshold} -gt 100 ]]; then
      echo "100"
    else
      echo "${threshold}"
    fi
  else
    echo "10" # Safe default
  fi
}

# AI-powered cleanup risk assessment
ai_assess_cleanup_risk() {
  local target_path="$1"
  local file_age_days="$2"

  if ! check_ollama; then
    return 0 # Proceed with caution
  fi

  local prompt="Assess the risk of deleting these files:
Path: ${target_path}
Age: ${file_age_days} days

Consider:
- Path patterns that indicate importance
- Age as risk indicator
- Common temporary vs permanent patterns

Respond with: LOW, MEDIUM, or HIGH risk."

  local risk
  risk=$(ollama run llama2 "${prompt}" 2>/dev/null | grep -oiE '(LOW|MEDIUM|HIGH)' | head -1 | tr '[:lower:]' '[:upper:]')

  case "${risk}" in
  HIGH)
    return 2 # High risk - abort
    ;;
  MEDIUM)
    return 1 # Medium risk - warn
    ;;
  LOW | *)
    return 0 # Low/unknown risk - proceed
    ;;
  esac
}

# Generate cleanup insights
ai_generate_cleanup_insights() {
  local cleanup_history="$1"
  local output_file="$2"

  if ! check_ollama; then
    echo "AI insights unavailable (Ollama not installed)" >"${output_file}"
    return
  fi

  local prompt="Analyze this cleanup history and provide actionable insights:
${cleanup_history}

Generate a report covering:
1. Space savings trends
2. Cleanup efficiency opportunities
3. Risk patterns identified
4. Automated cleanup recommendations

Format as markdown."

  ollama run llama2 "${prompt}" 2>/dev/null >"${output_file}"
}

# Smart artifact cleanup
ai_identify_safe_artifacts() {
  local artifact_list="$1"

  if ! check_ollama; then
    echo "${artifact_list}" # Return all as potentially safe
    return
  fi

  local prompt="From this list of build artifacts, identify which are safe to delete:
${artifact_list}

Safe deletion criteria:
- Derived data (can be regenerated)
- Old build outputs
- Temporary compilation artifacts
- Cached dependencies (if recent build exists)

Return only the safe-to-delete items, one per line."

  ollama run llama2 "${prompt}" 2>/dev/null | grep -v "^$" || echo "${artifact_list}"
}

# Export functions for sourcing
export -f check_ollama
export -f ai_prioritize_cleanup
export -f ai_predict_disk_usage
export -f ai_recommend_cache_policy
export -f ai_optimize_log_rotation
export -f ai_assess_cleanup_risk
export -f ai_generate_cleanup_insights
export -f ai_identify_safe_artifacts
