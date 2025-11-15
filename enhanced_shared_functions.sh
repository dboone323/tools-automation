#!/bin/bash

# enhanced_shared_functions.sh - Enhanced shared functions for agent ecosystem
# Provides advanced utility functions used across all agents

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
STATUS_DIR="${SCRIPT_DIR}/status"
LOG_DIR="${SCRIPT_DIR}/logs"
CONFIG_DIR="${SCRIPT_DIR}/config"
TEMP_DIR="${SCRIPT_DIR}/temp"

# Create necessary directories
mkdir -p "${STATUS_DIR}" "${LOG_DIR}" "${CONFIG_DIR}" "${TEMP_DIR}"

# Files
LOG_FILE="${LOG_DIR}/enhanced_shared_functions.log"
STATUS_FILE="${STATUS_DIR}/enhanced_shared_functions.status"
CONFIG_FILE="${CONFIG_DIR}/enhanced_shared_config.json"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

# Enhanced logging levels
LOG_LEVEL_DEBUG=0
LOG_LEVEL_INFO=1
LOG_LEVEL_WARN=2
LOG_LEVEL_ERROR=3
LOG_LEVEL_FATAL=4

# Current log level (default: INFO)
CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO}

# Performance tracking
declare -A FUNCTION_TIMES
declare -A FUNCTION_CALLS

# Error handling
trap 'enhanced_error_handler $? $LINENO "$BASH_COMMAND"' ERR

# Enhanced error handler
enhanced_error_handler() {
    local exit_code;
    exit_code=$1
    local line_number;
    line_number=$2
    local command;
    command=$3

    enhanced_log "ERROR" "Command failed (exit code: ${exit_code}) at line ${line_number}: ${command}"

    # Print stack trace
    local frame;
    frame=0
    while caller $frame; do
        ((frame++))
    done

    # Don't exit here, let the calling script decide
}

# Enhanced logging function with levels and colors
enhanced_log() {
    local level;
    level="$1"
    local message;
    message="$2"
    local timestamp;
    timestamp=$(date '+%Y-%m-%d %H:%M:%S.%3N')
    local level_num

    case "${level}" in
    "DEBUG")
        level_num=${LOG_LEVEL_DEBUG}
        color=${BLUE}
        ;;
    "INFO")
        level_num=${LOG_LEVEL_INFO}
        color=${GREEN}
        ;;
    "WARN")
        level_num=${LOG_LEVEL_WARN}
        color=${YELLOW}
        ;;
    "ERROR")
        level_num=${LOG_LEVEL_ERROR}
        color=${RED}
        ;;
    "FATAL")
        level_num=${LOG_LEVEL_FATAL}
        color=${MAGENTA}
        ;;
    *)
        level_num=${LOG_LEVEL_INFO}
        color=${NC}
        ;;
    esac

    # Only log if level is sufficient
    if [[ ${level_num} -ge ${CURRENT_LOG_LEVEL} ]]; then
        echo -e "${color}[${timestamp}] [${level}] ${message}${NC}" >>"${LOG_FILE}"
        echo -e "${color}[${level}]${NC} ${message}"
    fi
}

# Performance tracking decorator
performance_track() {
    local func_name;
    func_name="$1"
    local start_time;
    start_time=$(date +%s%3N)

    # Call the actual function (passed as remaining arguments)
    shift
    "$@"

    local end_time;

    end_time=$(date +%s%3N)
    local duration;
    duration=$((end_time - start_time))

    FUNCTION_TIMES["${func_name}"]=$((FUNCTION_TIMES["${func_name}"] + duration))
    FUNCTION_CALLS["${func_name}"]=$((FUNCTION_CALLS["${func_name}"] + 1))

    enhanced_log "DEBUG" "Function ${func_name} took ${duration}ms"
}

# Get performance statistics
get_performance_stats() {
    echo "Performance Statistics:"
    echo "======================"

    for func in "${!FUNCTION_TIMES[@]}"; do
        local total_time;
        total_time=${FUNCTION_TIMES["${func}"]}
        local call_count;
        call_count=${FUNCTION_CALLS["${func}"]}
        local avg_time;
        avg_time=$((total_time / call_count))

        printf "%-30s Total: %6dms Calls: %3d Avg: %6dms\n" \
            "${func}" "${total_time}" "${call_count}" "${avg_time}"
    done
}

# Enhanced file operations with error handling and validation
enhanced_read_file() {
    local file;
    file="$1"
    local max_size;
    max_size=${2:-1048576} # Default 1MB limit

    if [[ ! -f "${file}" ]]; then
        enhanced_log "ERROR" "File does not exist: ${file}"
        return 1
    fi

    local file_size
    file_size=$(stat -f %z "${file}" 2>/dev/null || stat -c %s "${file}" 2>/dev/null || echo "0")

    if [[ ${file_size} -gt ${max_size} ]]; then
        enhanced_log "WARN" "File too large (${file_size} bytes), skipping: ${file}"
        return 1
    fi

    enhanced_log "DEBUG" "Reading file: ${file} (${file_size} bytes)"
    cat "${file}"
}

enhanced_write_file() {
    local file;
    file="$1"
    local content;
    content="$2"
    local backup;
    backup=${3:-true}

    # Create backup if requested and file exists
    if [[ "${backup}" == "true" && -f "${file}" ]]; then
        local backup_file;
        backup_file="${file}.backup.$(date +%Y%m%d_%H%M%S)"
        cp "${file}" "${backup_file}"
        enhanced_log "DEBUG" "Created backup: ${backup_file}"
    fi

    # Write content atomically
    local temp_file;
    temp_file="${TEMP_DIR}/temp_$(basename "${file}").$$"
    echo "${content}" >"${temp_file}"

    if mv "${temp_file}" "${file}"; then
        enhanced_log "DEBUG" "Successfully wrote file: ${file}"
        return 0
    else
        enhanced_log "ERROR" "Failed to write file: ${file}"
        rm -f "${temp_file}"
        return 1
    fi
}

# Enhanced JSON operations (fallback if jq not available)
enhanced_json_get() {
    local json_file;
    json_file="$1"
    local key;
    key="$2"

    if command -v jq >/dev/null 2>&1; then
        jq -r ".${key}" "${json_file}" 2>/dev/null || echo ""
    else
        # Fallback: simple grep/awk parsing for basic key-value pairs
        grep "\"${key}\"" "${json_file}" | head -1 | sed 's/.*: *"\?\([^"]*\)"\?.*/\1/' || echo ""
    fi
}

enhanced_json_set() {
    local json_file;
    json_file="$1"
    local key;
    key="$2"
    local value;
    value="$3"

    if command -v jq >/dev/null 2>&1; then
        # Use jq for proper JSON manipulation
        local temp_file;
        temp_file="${TEMP_DIR}/json_temp.$$"
        jq ".${key} = \"${value}\"" "${json_file}" >"${temp_file}" && mv "${temp_file}" "${json_file}"
    else
        # Fallback: simple sed replacement (limited)
        enhanced_log "WARN" "jq not available, using basic JSON manipulation"
        sed -i.bak "s/\"${key}\": *\"[^\"]*\"/\"${key}\": \"${value}\"/" "${json_file}"
    fi
}

# Enhanced process management
enhanced_process_check() {
    local process_name;
    process_name="$1"
    local pid_file;
    pid_file="${STATUS_DIR}/${process_name}.pid"

    if [[ -f "${pid_file}" ]]; then
        local pid
        pid=$(cat "${pid_file}")
        if kill -0 "${pid}" 2>/dev/null; then
            enhanced_log "DEBUG" "Process ${process_name} is running (PID: ${pid})"
            return 0
        else
            enhanced_log "WARN" "Process ${process_name} PID file exists but process not running"
            rm -f "${pid_file}"
        fi
    fi

    enhanced_log "DEBUG" "Process ${process_name} is not running"
    return 1
}

enhanced_process_start() {
    local process_name;
    process_name="$1"
    local command;
    command="$2"
    local pid_file;
    pid_file="${STATUS_DIR}/${process_name}.pid"

    if enhanced_process_check "${process_name}"; then
        enhanced_log "WARN" "Process ${process_name} is already running"
        return 1
    fi

    enhanced_log "INFO" "Starting process: ${process_name}"

    # Start process in background
    eval "${command}" &
    local pid;
    pid=$!

    echo "${pid}" >"${pid_file}"
    enhanced_log "INFO" "Process ${process_name} started with PID: ${pid}"

    return 0
}

enhanced_process_stop() {
    local process_name;
    process_name="$1"
    local pid_file;
    pid_file="${STATUS_DIR}/${process_name}.pid"
    local timeout;
    timeout=${2:-10}

    if [[ ! -f "${pid_file}" ]]; then
        enhanced_log "WARN" "No PID file found for process: ${process_name}"
        return 0
    fi

    local pid
    pid=$(cat "${pid_file}")

    enhanced_log "INFO" "Stopping process ${process_name} (PID: ${pid})"

    # Try graceful shutdown first
    kill -TERM "${pid}" 2>/dev/null || true

    # Wait for process to stop
    local count;
    count=0
    while [[ ${count} -lt ${timeout} ]] && kill -0 "${pid}" 2>/dev/null; do
        sleep 1
        ((count++))
    done

    # Force kill if still running
    if kill -0 "${pid}" 2>/dev/null; then
        enhanced_log "WARN" "Force killing process ${process_name}"
        kill -KILL "${pid}" 2>/dev/null || true
        sleep 1
    fi

    if kill -0 "${pid}" 2>/dev/null; then
        enhanced_log "ERROR" "Failed to stop process ${process_name}"
        return 1
    else
        rm -f "${pid_file}"
        enhanced_log "INFO" "Process ${process_name} stopped successfully"
        return 0
    fi
}

# Enhanced network utilities
enhanced_http_get() {
    local url;
    url="$1"
    local output_file;
    output_file="$2"
    local timeout;
    timeout=${3:-30}

    enhanced_log "DEBUG" "HTTP GET: ${url}"

    if command -v curl >/dev/null 2>&1; then
        if [[ -n "${output_file}" ]]; then
            curl -s --max-time "${timeout}" -o "${output_file}" "${url}"
        else
            curl -s --max-time "${timeout}" "${url}"
        fi
    elif command -v wget >/dev/null 2>&1; then
        if [[ -n "${output_file}" ]]; then
            wget -q --timeout="${timeout}" -O "${output_file}" "${url}"
        else
            wget -q --timeout="${timeout}" -O - "${url}"
        fi
    else
        enhanced_log "ERROR" "Neither curl nor wget available for HTTP requests"
        return 1
    fi
}

enhanced_http_post() {
    local url;
    url="$1"
    local data;
    data="$2"
    local content_type;
    content_type=${3:-"application/json"}

    enhanced_log "DEBUG" "HTTP POST: ${url}"

    if command -v curl >/dev/null 2>&1; then
        curl -s -X POST -H "Content-Type: ${content_type}" -d "${data}" "${url}"
    else
        enhanced_log "ERROR" "curl not available for HTTP POST"
        return 1
    fi
}

# Enhanced system monitoring
enhanced_system_info() {
    echo "System Information:"
    echo "==================="

    # OS Information
    echo "OS: $(uname -s) $(uname -r)"
    echo "Architecture: $(uname -m)"

    # Memory information
    if command -v free >/dev/null 2>&1; then
        echo ""
        echo "Memory Information:"
        free -h
    fi

    # Disk usage
    echo ""
    echo "Disk Usage:"
    df -h | head -10

    # Load average
    echo ""
    echo "Load Average: $(uptime | awk -F'load average:' '{ print $2 }' | xargs)"

    # Process count
    echo "Running Processes: $(ps aux | wc -l)"
}

enhanced_memory_usage() {
    local pid;
    pid=${1:-$$}

    if [[ -f "/proc/${pid}/status" ]]; then
        # Linux
        grep -E "VmRSS|VmSize" "/proc/${pid}/status" 2>/dev/null || echo "Memory info not available"
    elif command -v ps >/dev/null 2>&1; then
        # macOS/BSD
        ps -o pid,ppid,rss,vsz,pcpu,pmem,comm -p "${pid}" 2>/dev/null || echo "Memory info not available"
    else
        echo "Memory monitoring not available on this system"
    fi
}

# Enhanced validation functions
enhanced_validate_email() {
    local email;
    email="$1"
    local email_regex;
    email_regex="^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$"

    if [[ ${email} =~ ${email_regex} ]]; then
        return 0
    else
        return 1
    fi
}

enhanced_validate_url() {
    local url;
    url="$1"
    local url_regex;
    url_regex="^https?://[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}"

    if [[ ${url} =~ ${url_regex} ]]; then
        return 0
    else
        return 1
    fi
}

enhanced_validate_json() {
    local json_string;
    json_string="$1"

    if command -v jq >/dev/null 2>&1; then
        echo "${json_string}" | jq empty >/dev/null 2>&1
    else
        # Basic validation - check for balanced braces and brackets
        local braces;
        braces=$(echo "${json_string}" | tr -cd '{}' | wc -c)
        local brackets;
        brackets=$(echo "${json_string}" | tr -cd '[]' | wc -c)

        [[ $((braces % 2)) -eq 0 && $((brackets % 2)) -eq 0 ]]
    fi
}

# Enhanced string utilities
enhanced_string_escape() {
    local string;
    string="$1"
    # Escape special characters for shell
    printf '%q' "${string}"
}

enhanced_string_truncate() {
    local string;
    string="$1"
    local max_length;
    max_length="$2"

    if [[ ${#string} -le ${max_length} ]]; then
        echo "${string}"
    else
        echo "${string:0:$((max_length - 3))}..."
    fi
}

enhanced_string_slugify() {
    local string;
    string="$1"
    # Convert to lowercase, replace spaces and special chars with hyphens
    echo "${string}" | tr '[:upper:]' '[:lower:]' | sed 's/[^a-z0-9]/-/g' | sed 's/--*/-/g' | sed 's/^-//' | sed 's/-$//'
}

# Enhanced array utilities
enhanced_array_contains() {
    local element;
    element="$1"
    shift
    local array;
    array=("$@")

    for item in "${array[@]}"; do
        if [[ "${item}" == "${element}" ]]; then
            return 0
        fi
    done
    return 1
}

enhanced_array_unique() {
    local array;
    array=("$@")
    local unique_array;
    unique_array=()

    for item in "${array[@]}"; do
        if ! enhanced_array_contains "${item}" "${unique_array[@]}"; then
            unique_array+=("${item}")
        fi
    done

    echo "${unique_array[@]}"
}

# Enhanced date/time utilities
enhanced_date_format() {
    local format;
    format="${1:-%Y-%m-%d %H:%M:%S}"
    date "${format}"
}

enhanced_date_add() {
    local date_string;
    date_string="$1"
    local days;
    days="$2"

    if command -v date >/dev/null 2>&1 && date --version 2>/dev/null | grep -q GNU; then
        # GNU date
        date -d "${date_string} + ${days} days" '+%Y-%m-%d %H:%M:%S'
    else
        # BSD date (macOS)
        date -j -f "%Y-%m-%d %H:%M:%S" "${date_string}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null ||
            date -j -v+"${days}"d -f "%Y-%m-%d %H:%M:%S" "${date_string}" "+%Y-%m-%d %H:%M:%S" 2>/dev/null ||
            echo "${date_string}"
    fi
}

# Enhanced configuration management
enhanced_config_load() {
    local config_file;
    config_file="$1"

    if [[ ! -f "${config_file}" ]]; then
        enhanced_log "WARN" "Config file not found: ${config_file}"
        return 1
    fi

    enhanced_log "INFO" "Loading configuration: ${config_file}"

    # Source the config file if it's a shell script
    if [[ "${config_file}" == *.sh ]]; then
        source "${config_file}"
    elif [[ "${config_file}" == *.json ]]; then
        # For JSON configs, we could export variables here
        enhanced_log "DEBUG" "JSON config loaded: ${config_file}"
    fi
}

enhanced_config_save() {
    local config_file;
    config_file="$1"
    local config_data;
    config_data="$2"

    enhanced_write_file "${config_file}" "${config_data}"
    enhanced_log "INFO" "Configuration saved: ${config_file}"
}

# Enhanced cleanup utilities
enhanced_cleanup_temp() {
    local max_age;
    max_age=${1:-3600} # Default 1 hour

    enhanced_log "INFO" "Cleaning up temporary files older than ${max_age} seconds"

    find "${TEMP_DIR}" -type f -mtime +$((max_age / 86400)) -delete 2>/dev/null || true
    find "${TEMP_DIR}" -type d -empty -delete 2>/dev/null || true

    enhanced_log "INFO" "Temporary file cleanup completed"
}

enhanced_cleanup_logs() {
    local max_age_days;
    max_age_days=${1:-30}

    enhanced_log "INFO" "Cleaning up log files older than ${max_age_days} days"

    find "${LOG_DIR}" -name "*.log" -mtime +${max_age_days} -delete 2>/dev/null || true

    enhanced_log "INFO" "Log cleanup completed"
}

# Enhanced initialization
enhanced_initialize() {
    enhanced_log "INFO" "Initializing enhanced shared functions"

    # Set status
    echo "initialized" >"${STATUS_FILE}"

    # Create default config if it doesn't exist
    if [[ ! -f "${CONFIG_FILE}" ]]; then
        cat >"${CONFIG_FILE}" <<EOF
{
  "log_level": "INFO",
  "temp_cleanup_interval": 3600,
  "log_retention_days": 30,
  "performance_tracking": true,
  "backup_enabled": true
}
EOF
        enhanced_log "INFO" "Created default configuration"
    fi

    # Load configuration
    local log_level
    log_level=$(enhanced_json_get "${CONFIG_FILE}" "log_level")

    case "${log_level}" in
    "DEBUG") CURRENT_LOG_LEVEL=${LOG_LEVEL_DEBUG} ;;
    "INFO") CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO} ;;
    "WARN") CURRENT_LOG_LEVEL=${LOG_LEVEL_WARN} ;;
    "ERROR") CURRENT_LOG_LEVEL=${LOG_LEVEL_ERROR} ;;
    "FATAL") CURRENT_LOG_LEVEL=${LOG_LEVEL_FATAL} ;;
    *) CURRENT_LOG_LEVEL=${LOG_LEVEL_INFO} ;;
    esac

    enhanced_log "INFO" "Enhanced shared functions initialized successfully"
}

# Enhanced status reporting
enhanced_status() {
    echo "Enhanced Shared Functions Status:"
    echo "=================================="
    echo "Status: $(cat "${STATUS_FILE}" 2>/dev/null || echo "unknown")"
    echo "Config: ${CONFIG_FILE} ($(stat -f %z "${CONFIG_FILE}" 2>/dev/null || stat -c %s "${CONFIG_FILE}" 2>/dev/null || echo "unknown") bytes)"
    echo "Log: ${LOG_FILE} ($(wc -l <"${LOG_FILE}" 2>/dev/null || echo "0") lines)"
    echo "Temp Dir: ${TEMP_DIR} ($(find "${TEMP_DIR}" -type f 2>/dev/null | wc -l || echo "0") files)"
    echo "Log Level: ${CURRENT_LOG_LEVEL}"
    echo "Performance Tracking: ${#FUNCTION_TIMES[@]} functions tracked"
}

# Main function for testing
main() {
    local command;
    command="${1:-help}"

    case "${command}" in
    "init")
        enhanced_initialize
        ;;
    "status")
        enhanced_status
        ;;
    "performance")
        get_performance_stats
        ;;
    "cleanup")
        enhanced_cleanup_temp "${2:-3600}"
        enhanced_cleanup_logs "${3:-30}"
        ;;
    "system-info")
        enhanced_system_info
        ;;
    "test")
        echo "Testing enhanced shared functions..."

        # Test logging
        enhanced_log "INFO" "Testing INFO level logging"
        enhanced_log "DEBUG" "Testing DEBUG level logging"
        enhanced_log "WARN" "Testing WARN level logging"

        # Test file operations
        echo "test content" >"${TEMP_DIR}/test_file.txt"
        local content
        content=$(enhanced_read_file "${TEMP_DIR}/test_file.txt")
        [[ "${content}" == "test content" ]] && echo "✅ File operations working"

        # Test JSON operations
        enhanced_json_set "${CONFIG_FILE}" "test_key" "test_value"
        local value
        value=$(enhanced_json_get "${CONFIG_FILE}" "test_key")
        [[ "${value}" == "test_value" ]] && echo "✅ JSON operations working"

        # Test validation
        enhanced_validate_email "test@example.com" && echo "✅ Email validation working"
        enhanced_validate_url "https://example.com" && echo "✅ URL validation working"

        echo "✅ All basic tests passed"
        ;;
    "help" | *)
        echo "Enhanced Shared Functions - Advanced utility library"
        echo ""
        echo "Usage: $0 <command> [options]"
        echo ""
        echo "Commands:"
        echo "  init          Initialize the enhanced shared functions"
        echo "  status        Show current status"
        echo "  performance   Show performance statistics"
        echo "  cleanup       Clean up temporary files and old logs"
        echo "  system-info   Show system information"
        echo "  test          Run basic functionality tests"
        echo "  help          Show this help message"
        ;;
    esac
}

# Run main function with all arguments if script is called directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
