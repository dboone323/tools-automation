#!/bin/bash
# OA-06: Watchdog Monitor
# Monitors logs for errors, checks system health, and publishes alerts

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
readonly LOG_DIR="${ROOT_DIR}/Tools/Automation"
readonly MCP_SERVER="${MCP_SERVER:-http://localhost:3000}"
readonly OLLAMA_URL="${OLLAMA_URL:-http://localhost:11434}"
readonly DISK_USAGE_THRESHOLD="${DISK_USAGE_THRESHOLD:-85}"
readonly ERROR_THRESHOLD="${ERROR_THRESHOLD:-3}"
readonly TIME_WINDOW_MINUTES="${TIME_WINDOW_MINUTES:-60}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $*"
}

# Check Ollama server health
check_ollama() {
    log_info "Checking Ollama server health..."
    
    if curl -sf --max-time 10 "${OLLAMA_URL}/api/tags" >/dev/null 2>&1; then
        log_info "✓ Ollama server is healthy"
        return 0
    else
        log_error "✗ Ollama server is unavailable"
        publish_alert "critical" "Ollama server is down" "ollama_health" "{\"url\": \"${OLLAMA_URL}\"}"
        return 1
    fi
}

# Check MCP server health
check_mcp() {
    log_info "Checking MCP server health..."
    
    if curl -sf "${MCP_SERVER}/health" >/dev/null 2>&1 || \
       curl -sf "${MCP_SERVER}/alerts" >/dev/null 2>&1; then
        log_info "✓ MCP server is healthy"
        return 0
    else
        log_warning "✗ MCP server is unavailable (may be optional)"
        return 1
    fi
}

# Check disk space usage
check_disk_space() {
    log_info "Checking disk space..."
    
    local usage
    usage=$(df -h "${ROOT_DIR}" | awk 'NR==2 {print $5}' | sed 's/%//')
    
    log_info "Disk usage: ${usage}%"
    
    if [[ $usage -gt 95 ]]; then
        log_error "✗ CRITICAL: Disk usage is ${usage}% (>95%)"
        publish_alert "critical" "Disk usage critical: ${usage}%" "disk_space" "{\"usage_percent\": ${usage}, \"threshold\": 95}"
        return 1
    elif [[ $usage -gt $DISK_USAGE_THRESHOLD ]]; then
        log_warning "✗ WARNING: Disk usage is ${usage}% (>${DISK_USAGE_THRESHOLD}%)"
        publish_alert "warning" "Disk usage high: ${usage}%" "disk_space" "{\"usage_percent\": ${usage}, \"threshold\": ${DISK_USAGE_THRESHOLD}}"
        return 1
    else
        log_info "✓ Disk usage is healthy (${usage}%)"
        return 0
    fi
}

# Scan logs for error patterns
scan_logs_for_errors() {
    log_info "Scanning logs for error patterns..."
    
    local error_count=0
    local recent_errors=()
    
    # Calculate time window in minutes for -mtime (convert to fraction of day)
    local time_window_days
    time_window_days=$(awk "BEGIN {printf \"%.4f\", ${TIME_WINDOW_MINUTES}/1440}")
    
    # Error patterns to search for
    local patterns=(
        "ERROR"
        "FATAL"
        "CRITICAL"
        "Exception"
        "Failed"
    )
    
    # Search recent log files (using time window - files modified within the time window)
    for pattern in "${patterns[@]}"; do
        while IFS= read -r logfile; do
            local count
            count=$(grep -c "$pattern" "$logfile" 2>/dev/null || echo 0)
            
            if [[ $count -gt 0 ]]; then
                error_count=$((error_count + count))
                recent_errors+=("${logfile}: ${count} x ${pattern}")
            fi
        done < <(find "$LOG_DIR" -name "*.log" -type f -mtime -"${time_window_days}" 2>/dev/null)
    done
    
    log_info "Total errors found: ${error_count}"
    
    if [[ $error_count -gt $ERROR_THRESHOLD ]]; then
        log_error "✗ Error threshold exceeded: ${error_count} errors (threshold: ${ERROR_THRESHOLD})"
        
        local details
        details=$(printf '%s\n' "${recent_errors[@]}" | jq -R . | jq -s . | jq -c .)
        publish_alert "error" "Error threshold exceeded: ${error_count} errors" "log_errors" "{\"count\": ${error_count}, \"threshold\": ${ERROR_THRESHOLD}, \"files\": ${details}}"
        return 1
    else
        log_info "✓ Error rate is within acceptable limits"
        return 0
    fi
}

# Check for repeated failures
check_repeated_failures() {
    log_info "Checking for repeated failures..."
    
    local failure_patterns=("FAILED" "FAILURE" "CRITICAL ERROR" "FATAL")
    local total_failures=0
    
    for pattern in "${failure_patterns[@]}"; do
        local count
        count=$(find "$LOG_DIR" -type f -name "*.log" -mtime -1 -exec grep -c "$pattern" {} + 2>/dev/null | awk '{sum+=$1} END {print sum+0}')
        
        if [[ $count -gt 0 ]]; then
            log_warning "Found ${count} occurrence(s) of '${pattern}'"
            total_failures=$((total_failures + count))
        fi
    done
    
    if [[ $total_failures -gt 5 ]]; then
        log_error "✗ High failure rate detected: ${total_failures} failures"
        publish_alert "error" "High failure rate: ${total_failures} failures" "repeated_failures" "{\"count\": ${total_failures}}"
        return 1
    else
        log_info "✓ Failure rate is acceptable"
        return 0
    fi
}

# Publish alert to MCP
publish_alert() {
    local level="$1"
    local message="$2"
    local source="$3"
    local details="${4:-{}}"
    
    local payload
    payload=$(cat <<EOF
{
  "source": "watchdog_${source}",
  "level": "${level}",
  "message": "${message}",
  "details": ${details},
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
}
EOF
)
    
    if curl -sf -X POST "${MCP_SERVER}/alerts" \
        -H "Content-Type: application/json" \
        -d "$payload" >/dev/null 2>&1; then
        log_debug "Published alert to MCP: ${message}"
    else
        log_debug "MCP publish skipped (server offline)"
    fi
}

# Generate health summary
generate_summary() {
    local ollama_status="$1"
    local mcp_status="$2"
    local disk_status="$3"
    local log_status="$4"
    local failure_status="$5"
    
    log_info "================================================"
    log_info "Watchdog Health Summary:"
    log_info "  - Ollama Server: ${ollama_status}"
    log_info "  - MCP Server: ${mcp_status}"
    log_info "  - Disk Space: ${disk_status}"
    log_info "  - Log Errors: ${log_status}"
    log_info "  - Failure Rate: ${failure_status}"
    log_info "================================================"
    
    # Publish overall summary
    local overall_status="healthy"
    [[ "$ollama_status" == "FAIL" ]] && overall_status="degraded"
    [[ "$disk_status" == "FAIL" ]] && overall_status="degraded"
    [[ "$log_status" == "FAIL" ]] && overall_status="warning"
    
    publish_alert "info" "Watchdog health check completed" "summary" "{\"status\": \"${overall_status}\", \"ollama\": \"${ollama_status}\", \"mcp\": \"${mcp_status}\", \"disk\": \"${disk_status}\", \"logs\": \"${log_status}\", \"failures\": \"${failure_status}\"}"
}

# Main monitoring logic
main() {
    log_info "Starting Watchdog Monitor..."
    log_info "Time: $(date)"
    log_info "Thresholds: Disk=${DISK_USAGE_THRESHOLD}%, Errors=${ERROR_THRESHOLD}, Window=${TIME_WINDOW_MINUTES}min"
    echo ""
    
    local ollama_status="OK"
    local mcp_status="OK"
    local disk_status="OK"
    local log_status="OK"
    local failure_status="OK"
    
    # Run health checks
    check_ollama || ollama_status="FAIL"
    echo ""
    
    check_mcp || mcp_status="UNAVAILABLE"
    echo ""
    
    check_disk_space || disk_status="FAIL"
    echo ""
    
    scan_logs_for_errors || log_status="FAIL"
    echo ""
    
    check_repeated_failures || failure_status="FAIL"
    echo ""
    
    # Generate summary
    generate_summary "$ollama_status" "$mcp_status" "$disk_status" "$log_status" "$failure_status"
    
    # Exit with error if critical issues found
    if [[ "$ollama_status" == "FAIL" ]] || [[ "$disk_status" == "FAIL" ]]; then
        log_error "Critical issues detected!"
        exit 1
    fi
    
    log_info "Watchdog check complete!"
    exit 0
}

# Run main function
main "$@"
