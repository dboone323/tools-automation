#!/bin/bash
# Public API Integration Agent: Manages API calls and avoids rate limits

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

AGENT_NAME="PublicApiAgent"
LOG_FILE="$(dirname "$0")/public_api_agent.log"
NOTIFICATION_FILE="$(dirname "$0")/communication/${AGENT_NAME}_notification.txt"
COMPLETED_FILE="$(dirname "$0")/communication/${AGENT_NAME}_completed.txt"
API_CACHE_FILE="$(dirname "$0")/api_cache.json"
RATE_LIMIT_FILE="$(dirname "$0")/rate_limits.json"

# Public APIs configuration (no authentication required)
declare -A PUBLIC_APIS
PUBLIC_APIS=(
  ["github_api"]="https://api.github.com"
  ["swift_evolution"]="https://data.swift.org/swift-evolution"
  ["apple_developer"]="https://developer.apple.com"
  ["cocoapods_specs"]="https://cdn.cocoapods.org"
  ["swift_package_index"]="https://swiftpackageindex.com"
  ["ios_dev_docs"]="https://developer.apple.com/documentation"
)

# Rate limiting configuration
declare -A RATE_LIMITS
RATE_LIMITS=(
  ["github_api"]="60|3600"          # 60 requests per hour
  ["swift_evolution"]="100|3600"    # 100 requests per hour
  ["apple_developer"]="30|3600"     # 30 requests per hour
  ["cocoapods_specs"]="200|3600"    # 200 requests per hour
  ["swift_package_index"]="50|3600" # 50 requests per hour
  ["ios_dev_docs"]="100|3600"       # 100 requests per hour
)

# Cache configuration
CACHE_DURATION=3600 # 1 hour cache
MAX_CACHE_SIZE=100  # Maximum cached responses

# Initialize files
mkdir -p "$(dirname "$0")/communication" "$(dirname "$0")/api_cache"
touch "${NOTIFICATION_FILE}"
touch "${COMPLETED_FILE}"

if [[ ! -f ${API_CACHE_FILE} ]]; then
  echo '{"cache": {}, "metadata": {"created": "", "last_cleanup": ""}}' >"${API_CACHE_FILE}"
fi

if [[ ! -f ${RATE_LIMIT_FILE} ]]; then
  echo '{"limits": {}}' >"${RATE_LIMIT_FILE}"
fi

log_message() {
  local level="$1"
  local message="$2"
  echo "[$(date)] [${level}] ${message}" >>"${LOG_FILE}"
}

# Notify orchestrator of task completion
notify_completion() {
  local task_id="$1"
  local success="$2"
  echo "$(date +%s)|${task_id}|${success}" >>"${COMPLETED_FILE}"
}

# Make API request with rate limiting and caching
make_api_request() {
  local api_name="$1"
  local endpoint="$2"
  local method="${3:-GET}"
  local data="${4-}"

  local api_base="${PUBLIC_APIS[${api_name}]}"
  if [[ -z ${api_base} ]]; then
    log_message "ERROR" "Unknown API: ${api_name}"
    return 1
  fi

  local full_url="${api_base}${endpoint}"
  local cache_key
  cache_key=$(echo "${method}|${full_url}|${data}" | md5)

  # Check cache first
  local cached_response
  cached_response=$(get_cached_response "${cache_key}")
  if [[ -n ${cached_response} ]]; then
    log_message "INFO" "Cache hit for ${api_name}: ${endpoint}"
    echo "${cached_response}"
    return 0
  fi

  # Check rate limits
  if ! check_rate_limit "${api_name}"; then
    log_message "WARNING" "Rate limit exceeded for ${api_name}"
    return 1
  fi

  # Make the actual request
  local response
  local http_code

  case "${method}" in
  "GET")
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" "${full_url}" 2>/dev/null)
    ;;
  "POST")
    response=$(curl -s -w "HTTPSTATUS:%{http_code}" -X POST -H "Content-Type: application/json" -d "${data}" "${full_url}" 2>/dev/null)
    ;;
  *)
    log_message "ERROR" "Unsupported HTTP method: ${method}"
    return 1
    ;;
  esac

  # Extract HTTP status code
  http_code="${response##*HTTPSTATUS:}"
  http_code=${http_code//$'\n'/}
  response="${response%HTTPSTATUS:*}"

  # Check for successful response
  if [[ ${http_code} -ge 200 && ${http_code} -lt 300 ]]; then
    # Cache successful response
    cache_response "${cache_key}" "${response}"

    # Update rate limit tracking
    update_rate_limit "${api_name}"

    log_message "INFO" "API request successful: ${api_name} ${endpoint} (HTTP ${http_code})"
    echo "${response}"
    return 0
  else
    log_message "ERROR" "API request failed: ${api_name} ${endpoint} (HTTP ${http_code})"
    return 1
  fi
}

# Check if request is within rate limits
check_rate_limit() {
  local api_name="$1"

  local limit_config="${RATE_LIMITS[${api_name}]}"
  if [[ -z ${limit_config} ]]; then
    return 0 # No rate limit configured
  fi

  local requests_per_window
  requests_per_window=$(echo "${limit_config}" | cut -d'|' -f1)
  local window_seconds
  window_seconds=$(echo "${limit_config}" | cut -d'|' -f2)

  # Get current usage
  local current_usage
  current_usage=$(get_current_usage "${api_name}" "${window_seconds}")

  if [[ ${current_usage} -ge ${requests_per_window} ]]; then
    return 1 # Rate limit exceeded
  fi

  return 0 # Within limits
}

# Get current API usage within time window
get_current_usage() {
  local api_name="$1"
  local window_seconds="$2"
  local cutoff_time
  cutoff_time=$(($(date +%s) - window_seconds))

  if command -v jq &>/dev/null; then
    jq -r ".limits.\"${api_name}\" // [] | map(select(.timestamp > ${cutoff_time})) | length" "${RATE_LIMIT_FILE}" 2>/dev/null || echo "0"
  else
    echo "0"
  fi
}

# Update rate limit tracking
update_rate_limit() {
  local api_name="$1"
  local timestamp
  timestamp=$(date +%s)

  if command -v jq &>/dev/null; then
    # Add new request to tracking
    jq --arg api_name "${api_name}" --arg timestamp "${timestamp}" \
      '.limits[$api_name] = (.limits[$api_name] // [] | . + [{"timestamp": ($timestamp | tonumber)}])' \
      "${RATE_LIMIT_FILE}" >"${RATE_LIMIT_FILE}.tmp" && mv "${RATE_LIMIT_FILE}.tmp" "${RATE_LIMIT_FILE}"
  fi
}

# Get cached response
get_cached_response() {
  local cache_key="$1"

  if command -v jq &>/dev/null; then
    local cached_data
    cached_data=$(jq -r ".cache.\"${cache_key}\" // empty" "${API_CACHE_FILE}")
    if [[ -n ${cached_data} && ${cached_data} != "null" ]]; then
      local cache_time
      cache_time=$(echo "${cached_data}" | jq -r '.timestamp // 0')
      local current_time
      current_time=$(date +%s)

      # Check if cache is still valid
      if [[ $((current_time - cache_time)) -lt ${CACHE_DURATION} ]]; then
        echo "${cached_data}" | jq -r '.response // empty'
        return 0
      else
        # Remove expired cache entry
        jq "del(.cache.\"${cache_key}\")" "${API_CACHE_FILE}" >"${API_CACHE_FILE}.tmp" && mv "${API_CACHE_FILE}.tmp" "${API_CACHE_FILE}"
      fi
    fi
  fi

  return 1
}

# Cache API response
cache_response() {
  local cache_key="$1"
  local response="$2"
  local timestamp
  timestamp=$(date +%s)

  if command -v jq &>/dev/null; then
    # Clean up old cache entries if needed
    cleanup_cache

    # Add new cache entry
    jq --arg cache_key "${cache_key}" --arg response "${response}" --arg timestamp "${timestamp}" \
      '.cache[$cache_key] = {"response": $response, "timestamp": ($timestamp | tonumber)}' \
      "${API_CACHE_FILE}" >"${API_CACHE_FILE}.tmp" && mv "${API_CACHE_FILE}.tmp" "${API_CACHE_FILE}"

    log_message "INFO" "Cached response for key: ${cache_key}"
  fi
}

# Clean up expired cache entries
cleanup_cache() {
  local current_time
  current_time=$(date +%s)
  local cutoff_time
  cutoff_time=$((current_time - CACHE_DURATION))

  if command -v jq &>/dev/null; then
    local cache_size
    cache_size=$(jq '.cache | length' "${API_CACHE_FILE}")

    if [[ ${cache_size} -gt ${MAX_CACHE_SIZE} ]]; then
      # Remove expired entries and keep only recent ones
      jq --arg cutoff_time "${cutoff_time}" \
        '.cache = (.cache | to_entries | map(select(.value.timestamp > ($cutoff_time | tonumber))) | from_entries)' \
        "${API_CACHE_FILE}" >"${API_CACHE_FILE}.tmp" && mv "${API_CACHE_FILE}.tmp" "${API_CACHE_FILE}"

      log_message "INFO" "Cleaned up cache (was ${cache_size} entries)"
    fi
  fi
}

# GitHub API integration
github_api_call() {
  local endpoint="$1"
  local method="${2:-GET}"
  local data="${3-}"

  make_api_request "github_api" "${endpoint}" "${method}" "${data}"
}

# Get latest Swift version information
get_swift_version_info() {
  log_message "INFO" "Fetching Swift version information..."

  local response
  if ! response=$(github_api_call "/repos/apple/swift/releases/latest"); then
    return 1
  fi

  if [[ -z ${response} ]]; then
    return 1
  fi

  local version
  version=$(echo "${response}" | jq -r '.tag_name // empty' 2>/dev/null | sed 's/swift-//')
  local release_notes
  release_notes=$(echo "${response}" | jq -r '.body // empty' 2>/dev/null | head -5)

  if [[ -n ${version} ]]; then
    echo "{\"version\": \"${version}\", \"release_notes\": \"${release_notes}\"}"
    return 0
  fi

  return 1
}

# Get iOS development documentation
get_ios_docs() {
  local topic="$1"

  log_message "INFO" "Fetching iOS documentation for: ${topic}"

  # This is a simplified example - in reality, you'd need to parse Apple's documentation API

  make_api_request "ios_dev_docs" "/${topic}"
}

# Get CocoaPods specifications
get_cocoapods_specs() {
  local pod_name="$1"

  log_message "INFO" "Fetching CocoaPods specs for: ${pod_name}"

  make_api_request "cocoapods_specs" "/Specs/0/3/5/${pod_name}.json"
}

# Get Swift Package Index information
get_swift_package_info() {
  local package_name="$1"

  log_message "INFO" "Fetching Swift Package Index info for: ${package_name}"

  # Note: This would need actual API endpoints from Swift Package Index
  make_api_request "swift_package_index" "/api/packages/${package_name}"
}

# Batch API requests to optimize rate limit usage
batch_api_requests() {
  local requests_file="$1"

  log_message "INFO" "Processing batch API requests..."

  local processed=0
  local failed=0

  while IFS='|' read -r api_name endpoint method data; do
    if make_api_request "${api_name}" "${endpoint}" "${method}" "${data}"; then
      ((processed++))
    else
      ((failed++))
    fi

    # Small delay between requests to be respectful
    sleep 0.1
  done <"${requests_file}"

  log_message "INFO" "Batch processing complete: ${processed} successful, ${failed} failed"

  echo "{\"processed\": ${processed}, \"failed\": ${failed}}"
}

# Generate API usage report
generate_api_report() {
  local report_dir
  report_dir="$(dirname "$0")/api_reports"
  mkdir -p "${report_dir}"

  local report_file
  report_file="${report_dir}/api_usage_$(date +%Y%m%d_%H%M%S).md"

  {
    echo "# API Usage Report"
    echo "Generated: $(date)"
    echo ""

    echo "## Rate Limit Status"
    echo "| API | Current Usage | Limit | Window | Status |"
    echo "|-----|---------------|-------|--------|--------|"

    for api_name in "${!RATE_LIMITS[@]}"; do
      local limit_config="${RATE_LIMITS[${api_name}]}"
      local requests_per_window
      requests_per_window=$(echo "${limit_config}" | cut -d'|' -f1)
      local window_seconds
      window_seconds=$(echo "${limit_config}" | cut -d'|' -f2)

      local current_usage
      current_usage=$(get_current_usage "${api_name}" "${window_seconds}")
      local status="✅ OK"

      if [[ ${current_usage} -ge ${requests_per_window} ]]; then
        status="❌ Limited"
      elif [[ ${current_usage} -gt $((requests_per_window * 80 / 100)) ]]; then
        status="⚠️  Near Limit"
      fi

      echo "| ${api_name} | ${current_usage} | ${requests_per_window} | ${window_seconds}s | ${status} |"
    done
    echo ""

    echo "## Cache Statistics"
    if command -v jq &>/dev/null; then
      local cache_entries
      cache_entries=$(jq '.cache | length' "${API_CACHE_FILE}")
      local cache_size
      cache_size=$(stat -f%z "${API_CACHE_FILE}" 2>/dev/null || echo "0")
      echo "- **Cached Responses**: ${cache_entries}"
      echo "- **Cache File Size**: ${cache_size} bytes"
      echo "- **Cache Duration**: ${CACHE_DURATION} seconds"
    fi
    echo ""

    echo "## Recent API Calls"
    tail -10 "${LOG_FILE}" | grep "API request" | while read -r line; do
      echo "- ${line}"
    done

  } >"${report_file}"

  log_message "INFO" "API usage report generated: ${report_file}"
}

# Process notifications from orchestrator
process_notifications() {
  if [[ -f ${NOTIFICATION_FILE} ]]; then
    while IFS='|' read -r _timestamp notification_type task_id; do
      case "${notification_type}" in
      "api_request")
        log_message "INFO" "Processing API request: ${task_id}"
        # Parse and execute API request
        ;;
      "batch_requests")
        log_message "INFO" "Processing batch requests: ${task_id}"
        # Process batch file
        ;;
      "clear_cache")
        log_message "INFO" "Clearing API cache"
        echo '{"cache": {}, "metadata": {"created": "", "last_cleanup": ""}}' >"${API_CACHE_FILE}"
        ;;
      "get_report")
        log_message "INFO" "Generating API report"
        generate_api_report
        ;;
      esac
    done <"${NOTIFICATION_FILE}"

    # Clear processed notifications
    : >"${NOTIFICATION_FILE}"
  fi
}

# Main API management loop
log_message "INFO" "Public API Integration Agent starting..."

while true; do
  # Process notifications from orchestrator
  process_notifications

  # Clean up expired cache entries
  cleanup_cache

  # Generate periodic API report (every 30 minutes)
  current_minute=$(date +%M)
  if [[ $((current_minute % 30)) -eq 0 ]]; then
    generate_api_report
  fi

  # Check for rate limit resets (simplified)
  current_hour=$(date +%H)
  if [[ ${current_hour} -eq 0 ]]; then
    # Reset hourly rate limits at midnight
    if command -v jq &>/dev/null; then
      jq '.limits = {}' "${RATE_LIMIT_FILE}" >"${RATE_LIMIT_FILE}.tmp" && mv "${RATE_LIMIT_FILE}.tmp" "${RATE_LIMIT_FILE}"
      log_message "INFO" "Reset hourly rate limits"
    fi
  fi

  sleep 300 # Check every 5 minutes
done
