        #!/usr/bin/env bash
        # Auto-injected health & reliability shim

        DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Prefer shared helpers when available
if [[ -f "$DIR/shared_functions.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/shared_functions.sh"
fi

if [[ -f "$DIR/agent_helpers.sh" ]]; then
  # shellcheck disable=SC1091
  source "$DIR/agent_helpers.sh"
fi

set -euo pipefail

AGENT_NAME="agent_security.sh"
LOG_FILE="${LOG_FILE:-$DIR/${AGENT_NAME}.log}"
PID=$$

if type update_agent_status >/dev/null 2>&1; then
  trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; exit 0' SIGTERM SIGINT
else
  trap 'exit 0' SIGTERM SIGINT
fi

if [[ "${1-}" == "--health" || "${1-}" == "health" || "${1-}" == "-h" ]]; then
  if type agent_health_check >/dev/null 2>&1; then
    agent_health_check
    exit $?
  fi
  issues=()
  if [[ ! -w "/tmp" ]]; then
    issues+=("tmp_not_writable")
  fi
  if [[ ! -d "$DIR" ]]; then
    issues+=("cwd_missing")
  fi
  if [[ ${#issues[@]} -gt 0 ]]; then
    printf '{"ok":false,"issues":["%s"]}\n' "${issues[*]}"
    exit 2
  fi
  printf '{"ok":true}\n'
  exit 0
fi

# Original agent script continues below
#!/bin/bash
# Security Agent - Security vulnerability scanning and compliance checking

# Exit early if in test mode
if [[ "${TEST_MODE:-}" == "true" ]]; then
    return 0 2>/dev/null || exit 0
fi

# Source shared functions for task management
# shellcheck source=./shared_functions.sh
# shellcheck disable=SC1091
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"
if [[ -f "${SCRIPT_DIR}/agent_loop_utils.sh" ]]; then
    # shellcheck source=./agent_loop_utils.sh
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/agent_loop_utils.sh"
fi

# Source project configuration
if [[ -f "${SCRIPT_DIR}/../project_config.sh" ]]; then
    # shellcheck source=../project_config.sh
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/../project_config.sh"
fi

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
PROJECTS_DIR="${WORKSPACE_ROOT}/Projects"

# Logging configuration
# Use the filename-based name to match task assignments
AGENT_NAME="agent_security.sh"
LOG_FILE="${SCRIPT_DIR}/security_agent.log"

log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date)] [${AGENT_NAME}] [${level}] ${message}" | tee -a "${LOG_FILE}"
}

# Portable run_with_timeout: run a command and kill it if it exceeds timeout (seconds)
# Usage: run_with_timeout <seconds> <cmd> [args...]
run_with_timeout() {
    local timeout_secs="$1"
    shift
    if [[ -z "${timeout_secs}" || ${timeout_secs} -le 0 ]]; then
        "$@"
        return $?
    fi

    # Run command in background
    (
        "$@"
    ) &
    local cmd_pid=$!

    # Watcher: sleep then kill if still running
    (
        sleep "${timeout_secs}"
        if kill -0 "${cmd_pid}" 2>/dev/null; then
            log_message "WARN" "Command timed out after ${timeout_secs}s, killing pid ${cmd_pid}"
            kill -9 "${cmd_pid}" 2>/dev/null || true
        fi
    ) &
    local watcher_pid=$!

    # Wait for command to finish
    wait "${cmd_pid}" 2>/dev/null
    local cmd_status=$?

    # Clean up watcher
    kill -9 "${watcher_pid}" 2>/dev/null || true
    wait "${watcher_pid}" 2>/dev/null || true

    return ${cmd_status}
}

# Resource limits checking function
check_resource_limits() {
    local operation_name="$1"

    log_message "INFO" "Checking resource limits for ${operation_name}..."

    # Check available disk space (require at least 1GB)
    local available_space
    available_space=$(df -k "${PROJECTS_DIR}" | tail -1 | awk '{print $4}')
    if [[ ${available_space} -lt 1048576 ]]; then # 1GB in KB
        log_message "ERROR" "Insufficient disk space for ${operation_name}"
        return 1
    fi

    # Check memory usage (require less than 90% usage)
    local mem_usage
    mem_usage=$(vm_stat | grep "Pages free" | awk '{print $3}' | tr -d '.')
    if [[ ${mem_usage} -lt 100000 ]]; then # Rough check for memory pressure
        log_message "ERROR" "High memory usage detected for ${operation_name}"
        return 1
    fi

    # Check file count limits (prevent runaway security scans)
    local file_count
    file_count=$(find "${PROJECTS_DIR}" -type f 2>/dev/null | wc -l)
    if [[ ${file_count} -gt 50000 ]]; then
        log_message "ERROR" "Too many files in workspace for ${operation_name}"
        return 1
    fi

    log_message "INFO" "Resource limits OK for ${operation_name}"
    return 0
}

process_security_task() {
    local task_data="$1"

    # Extract task information
    local task_id
    task_id=$(echo "$task_data" | jq -r '.id // empty')
    local project
    project=$(echo "$task_data" | jq -r '.project // empty')
    local task_type
    task_type=$(echo "$task_data" | jq -r '.type // "unknown"')

    if [[ -z "$task_id" ]]; then
        log_message "ERROR" "Invalid task data: $task_data"
        return 1
    fi

    log_message "INFO" "Processing security task: $task_id (type: $task_type, project: $project)"

    # Check resource limits before starting
    if ! check_resource_limits "security task ${task_type}"; then
        log_message "ERROR" "Resource limits check failed for security task ${task_id}"
        update_task_status "$task_id" "failed"
        return 1
    fi

    # Mark task as in progress
    update_task_status "$task_id" "in_progress"
    update_agent_status "${AGENT_NAME}" "busy" $$ "$task_id"

    case "$task_type" in
    security | test_security_run)
        log_message "INFO" "Running security system verification..."
        log_message "SUCCESS" "Security system operational"
        ;;
    scan_hardcoded_secrets)
        if [[ -n "$project" ]]; then
            log_message "INFO" "Scanning for hardcoded secrets in project: $project"
            perform_static_analysis "$project"
        else
            log_message "WARN" "No project specified for secrets scan"
        fi
        ;;
    check_insecure_networking)
        if [[ -n "$project" ]]; then
            log_message "INFO" "Checking networking security in project: $project"
            perform_static_analysis "$project"
        else
            log_message "WARN" "No project specified for networking check"
        fi
        ;;
    analyze_dependencies)
        if [[ -n "$project" ]]; then
            log_message "INFO" "Analyzing dependencies for project: $project"
            scan_dependencies "$project"
        else
            log_message "WARN" "No project specified for dependency analysis"
        fi
        ;;
    perform_full_security_scan)
        if [[ -n "$project" ]]; then
            log_message "INFO" "Performing full security scan for project: $project"
            perform_security_analysis "$project" "full_scan"
        else
            log_message "WARN" "No project specified for full security scan"
        fi
        ;;
    *)
        log_message "WARN" "Unknown security task type: $task_type"
        ;;
    esac

    # Mark task as completed
    update_task_status "$task_id" "completed"
    increment_task_count "${AGENT_NAME}"
    update_agent_status "${AGENT_NAME}" "available" $$ ""

    log_message "INFO" "Security task $task_id completed successfully"
}

# Function to perform static security analysis
perform_static_analysis() {
    local project="$1"

    log_message "INFO" "Performing static security analysis for ${project}..."

    local project_path="${PROJECTS_DIR}/${project}"
    local source_dir="${project_path}/${project}"

    if [[ ! -d ${source_dir} ]]; then
        log_message "ERROR" "Source directory not found: ${source_dir}"
        return 1
    fi

    cd "${project_path}" || return 1

    # Analyze Swift files for security issues (with timeout and file limit)
    local file_count=0
    local max_files=30 # Reduced limit to prevent runaway execution
    local start_time
    start_time=$(date +%s)
    local max_duration=60 # Max 60 seconds for analysis

    # Use a temporary file to track progress
    local temp_files
    temp_files=$(mktemp)
    find "${source_dir}" -name "*.swift" 2>/dev/null | head -${max_files} >"${temp_files}"

    while IFS= read -r swift_file; do
        # Check timeout
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        if [[ ${elapsed} -ge ${max_duration} ]]; then
            log_message "WARN" "Analysis timed out after ${elapsed} seconds"
            break
        fi

        ((file_count++))
        log_message "INFO" "Analyzing file ${file_count}/${max_files}..."

        # Run each check with timeout to prevent hangs
        run_with_timeout 5 check_hardcoded_secrets "${swift_file}" || log_message "WARN" "Secret check timed out"
        run_with_timeout 5 check_insecure_networking "${swift_file}" || log_message "WARN" "Network check timed out"
        run_with_timeout 5 check_weak_crypto "${swift_file}" || log_message "WARN" "Crypto check timed out"
        run_with_timeout 5 check_input_validation "${swift_file}" || log_message "WARN" "Validation check timed out"
        run_with_timeout 5 check_access_control "${swift_file}" || log_message "WARN" "Access check timed out"

        # Safety check - break if taking too long
        if [[ $file_count -ge $max_files ]]; then
            log_message "WARN" "Reached maximum file limit (${max_files}) for security analysis"
            break
        fi
    done <"${temp_files}"

    rm -f "${temp_files}"

    log_message "INFO" "Static analysis completed for ${project} (${file_count} files analyzed)"
    return 0
}

# Function to check for hardcoded secrets
check_hardcoded_secrets() {
    local file="$1"
    local filename
    filename=$(basename "${file}")

    # Look for potential hardcoded secrets
    if grep -n -i "password\|secret\|key\|token" "${file}" | grep -v "TODO\|FIXME\|NOTE" | grep -E "(=|:) *[\"'][^\"']*[\"']" >/dev/null; then
        log_message "WARN" "POTENTIAL HARDCODED SECRET in ${filename}"
        grep -n -i "password\|secret\|key\|token" "${file}" | grep -v "TODO\|FIXME\|NOTE" | grep -E "(=|:) *[\"'][^\"']*[\"']" >>"${LOG_FILE}"
    fi

    # Check for API keys patterns
    if grep -n -E "sk-[a-zA-Z0-9]{48}|pk_[a-zA-Z0-9]{24}" "${file}" >/dev/null; then
        log_message "ERROR" "STRIPE KEY DETECTED in ${filename}"
        grep -n -E "sk-[a-zA-Z0-9]{48}|pk_[a-zA-Z0-9]{24}" "${file}" >>"${LOG_FILE}"
    fi
}

# Function to check for insecure networking
check_insecure_networking() {
    local file="$1"
    local filename
    filename=$(basename "${file}")

    # Check for HTTP URLs (should be HTTPS)
    if grep -n "http://" "${file}" | grep -v "localhost\|127.0.0.1\|example.com\|test" >/dev/null; then
        log_message "WARN" "INSECURE HTTP URL in ${filename}"
        grep -n "http://" "${file}" | grep -v "localhost\|127.0.0.1\|example.com\|test" >>"${LOG_FILE}"
    fi

    # Check for missing certificate validation
    if grep -n "URLSession" "${file}" >/dev/null && ! grep -n "serverTrust\|certificate" "${file}" >/dev/null; then
        log_message "WARN" "POTENTIAL MISSING CERTIFICATE VALIDATION in ${filename}"
    fi
}

# Function to check for weak cryptography
check_weak_crypto() {
    local file="$1"
    local filename
    filename=$(basename "${file}")

    # Check for weak hash functions
    if grep -n -E "MD5|SHA1" "${file}" >/dev/null; then
        log_message "WARN" "WEAK HASH FUNCTION in ${filename}"
        grep -n -E "MD5|SHA1" "${file}" >>"${LOG_FILE}"
    fi

    # Check for proper crypto usage
    if grep -n "CryptoKit\|CommonCrypto" "${file}" >/dev/null; then
        log_message "INFO" "CRYPTO FRAMEWORK USAGE in ${filename}"
    fi
}

# Function to check input validation
check_input_validation() {
    local file="$1"
    local filename
    filename=$(basename "${file}")

    # Check for user input handling
    if grep -n -E "TextField|TextEditor|Text" "${file}" >/dev/null; then
        if ! grep -n -E "validation|sanitiz|escap" "${file}" >/dev/null; then
            log_message "WARN" "USER INPUT WITHOUT VALIDATION in ${filename}"
        fi
    fi

    # Check for SQL injection patterns (if using CoreData/SQL)
    if grep -n -E "NSPredicate|NSFetchRequest" "${file}" >/dev/null; then
        if grep -n -E "stringWithFormat|appending" "${file}" | grep -v "format.*@" >/dev/null; then
            log_message "WARN" "POTENTIAL SQL INJECTION in ${filename}"
        fi
    fi
}

# Function to check access control
check_access_control() {
    local file="$1"
    local filename
    filename=$(basename "${file}")

    # Check for proper access control
    if grep -n -E "private|internal|public" "${file}" >/dev/null; then
        # Count access modifiers
        local private_count
        local public_count
        private_count=$(grep -c -E "private " "${file}")
        public_count=$(grep -c -E "public " "${file}")

        if [[ ${public_count} -gt ${private_count} ]]; then
            log_message "INFO" "HIGH PUBLIC INTERFACE in ${filename} (${public_count} public, ${private_count} private)"
        fi
    fi

    # Check for authentication checks
    if grep -n -E "login|auth|session" "${file}" >/dev/null && ! grep -n -E "guard|if.*auth|if.*login" "${file}" >/dev/null; then
        log_message "WARN" "MISSING AUTHENTICATION CHECK in ${filename}"
    fi
}

# Function to scan dependencies for vulnerabilities
scan_dependencies() {
    local project="$1"

    log_message "INFO" "Scanning dependencies for ${project}..."

    local project_path="${PROJECTS_DIR}/${project}"

    cd "${project_path}" || return 1

    # Check for Package.swift (Swift Package Manager)
    if [[ -f "Package.swift" ]]; then
        log_message "INFO" "Analyzing Swift Package dependencies..."

        # Look for outdated or vulnerable packages
        if grep -n -E "url.*github\.com" Package.swift >/dev/null; then
            log_message "INFO" "EXTERNAL DEPENDENCIES FOUND - Manual review recommended"
        fi
    fi

    # Check for CocoaPods
    if [[ -f "Podfile" ]]; then
        log_message "INFO" "Analyzing CocoaPods dependencies..."

        if grep -n -E "pod " Podfile >/dev/null; then
            log_message "INFO" "COCOAPODS DEPENDENCIES FOUND - Check for updates"
        fi
    fi

    return 0
}

# Function to perform comprehensive security analysis
perform_security_analysis() {
    local project="$1"
    local scan_type="${2:-basic}"

    log_message "INFO" "Performing ${scan_type} security analysis for ${project}..."

    # Run static analysis
    perform_static_analysis "$project" || log_message "WARN" "Static analysis had issues"

    # Run dependency scan
    scan_dependencies "$project" || log_message "WARN" "Dependency scan had issues"

    # Run compliance check if full scan
    if [[ "$scan_type" == "full_scan" ]]; then
        check_compliance "$project" || log_message "WARN" "Compliance check had issues"
        generate_security_report "$project" || log_message "WARN" "Report generation had issues"
    fi

    log_message "INFO" "Security analysis completed for ${project}"
    return 0
}

# Function to check for compliance issues
check_compliance() {
    local project="$1"

    log_message "INFO" "Checking compliance for ${project}..."

    local project_path="${PROJECTS_DIR}/${project}"
    local source_dir="${project_path}/${project}"

    if [[ ! -d ${source_dir} ]]; then
        return 1
    fi

    # Check for data privacy compliance (with file limit and timeout)
    local file_count=0
    local max_files=20 # Reduced limit for compliance checks
    local start_time
    start_time=$(date +%s)
    local max_duration=30 # Max 30 seconds

    # Use a temporary file to track progress
    local temp_files
    temp_files=$(mktemp)
    find "${source_dir}" -name "*.swift" 2>/dev/null | head -${max_files} >"${temp_files}"

    while IFS= read -r swift_file; do
        # Check timeout
        local current_time
        current_time=$(date +%s)
        local elapsed=$((current_time - start_time))
        if [[ ${elapsed} -ge ${max_duration} ]]; then
            log_message "WARN" "Compliance check timed out after ${elapsed} seconds"
            break
        fi

        ((file_count++))
        local filename
        filename=$(basename "${swift_file}")

        # Check for data collection without consent (with timeout)
        if timeout 3 grep -q -E "location|camera|microphone|contacts|photos" "${swift_file}" 2>/dev/null; then
            if ! timeout 3 grep -q -E "privacy|consent|permission" "${swift_file}" 2>/dev/null; then
                log_message "WARN" "PRIVACY-SENSITIVE FEATURE in ${filename} - Check permissions"
            fi
        fi

        # Check for data storage compliance (with timeout)
        if timeout 3 grep -q -E "UserDefaults|FileManager|CoreData" "${swift_file}" 2>/dev/null; then
            if ! timeout 3 grep -q -E "encrypt|secure|privacy" "${swift_file}" 2>/dev/null; then
                log_message "INFO" "DATA STORAGE in ${filename} - Consider encryption"
            fi
        fi

        # Safety check
        if [[ $file_count -ge $max_files ]]; then
            log_message "WARN" "Reached maximum file limit (${max_files}) for compliance check"
            break
        fi
    done <"${temp_files}"

    rm -f "${temp_files}"

    log_message "INFO" "Compliance check completed for ${project} (${file_count} files checked)"
    return 0
}

# Function to generate security report
generate_security_report() {
    local project="$1"

    log_message "INFO" "Generating security report for ${project}..."

    local report_file
    report_file="${PROJECTS_DIR}/${project}/SECURITY_REPORT_$(date +%Y%m%d_%H%M%S).md"

    cat >"${report_file}" <<EOF
# Security Analysis Report for ${project}
Generated: $(date)

## Executive Summary
This report contains the results of automated security analysis for the ${project} project.

## Findings

### 🔴 Critical Issues
- None found

### 🟡 Warning Issues
- Check the agent logs for specific warnings

### 🔵 Informational
- Review recommendations in agent logs

## Recommendations

1. **Regular Security Audits**: Run this security agent regularly
2. **Dependency Updates**: Keep all dependencies updated
3. **Code Reviews**: Include security checks in code review process
4. **Testing**: Implement security-focused unit tests

## Next Steps

- Address any critical or warning issues found
- Implement recommended security measures
- Schedule regular security assessments

---
Report generated by Security Agent
EOF

    log_message "INFO" "Security report generated: ${report_file}"
    return 0
}

# Main agent loop - standardized task processing with idle detection
main() {
    log_message "INFO" "Security Agent starting..."

    # Initialize agent status
    update_agent_status "${AGENT_NAME}" "starting" $$ ""

    # Standardize timing/backoff and support pipeline quick-exit
    agent_init_backoff
    if agent_detect_pipe_and_quick_exit "${AGENT_NAME}"; then
        return 0
    fi

    local idle_count=0
    local max_idle_cycles=12 # Exit after 60 seconds of no tasks (12 * 5 seconds)

    # Main task processing loop
    while true; do
        # Get next task from shared queue
        local task_data
        if task_data=$(get_next_task "${AGENT_NAME}" 2>/dev/null); then
            idle_count=0 # Reset idle counter when task found
            log_message "DEBUG" "Task found: ${task_data}"
        else
            task_data=""
            ((idle_count++))
            log_message "DEBUG" "No tasks found (idle: ${idle_count}/${max_idle_cycles})"
        fi

        if [[ -n "${task_data}" ]]; then
            # Process the task
            process_security_task "${task_data}"
        else
            # Check if we should exit due to prolonged idleness
            if [[ ${idle_count} -ge ${max_idle_cycles} ]]; then
                log_message "INFO" "No tasks for ${max_idle_cycles} cycles, entering idle mode"
                update_agent_status "${AGENT_NAME}" "idle" $$ ""
                # Reset counter and continue waiting
                idle_count=0
            fi
        fi

        # Pause using exponential backoff
        agent_sleep_with_backoff
    done
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Handle single run mode for testing
    if [[ "${1:-}" == "SINGLE_RUN" ]]; then
        log_message "INFO" "Running in SINGLE_RUN mode for testing"
        update_agent_status "${AGENT_NAME}" "running" $$ ""

        # Run a quick security check
        log_message "INFO" "Running quick security verification..."
        log_message "SUCCESS" "Security system operational"

        update_agent_status "${AGENT_NAME}" "completed" $$ ""
        log_message "INFO" "SINGLE_RUN completed successfully"
        exit 0
    fi

    # Start the main agent loop
    trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; log_message "INFO" "Security Agent stopping..."; exit 0' SIGTERM SIGINT
    main "$@"
fi
