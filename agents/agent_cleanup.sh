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

AGENT_NAME="agent_cleanup.sh"
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
# Cleanup Agent: Handles log rotation, cache pruning, temp file cleanup, and workspace maintenance

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

# Source project configuration
if [[ -f "${SCRIPT_DIR}/../project_config.sh" ]]; then
    source "${SCRIPT_DIR}/../project_config.sh"
fi

set -euo pipefail

# Resource limits (matching security agent standards)
MAX_MEMORY_USAGE=80 # 80% of available memory
MAX_CPU_USAGE=90    # 90% CPU usage threshold

# Agent throttling configuration
MAX_CONCURRENCY="${MAX_CONCURRENCY:-2}" # Maximum concurrent instances of this agent
LOAD_THRESHOLD="${LOAD_THRESHOLD:-8.0}" # System load threshold (1.0 = 100% on single core)
WAIT_WHEN_BUSY="${WAIT_WHEN_BUSY:-30}"  # Seconds to wait when system is busy

# Function to check if we should proceed with task processing
ensure_within_limits() {
    local agent_name="agent_cleanup.sh"

    # Check concurrent instances
    local running_count
    running_count=$(pgrep -f "${agent_name}" | wc -l)
    if [[ ${running_count} -gt ${MAX_CONCURRENCY} ]]; then
        log_message "WARN" "Too many concurrent instances (${running_count}/${MAX_CONCURRENCY}). Waiting..."
        return 1
    fi

    # Check system load (macOS compatible)
    local load_avg
    if command -v sysctl >/dev/null 2>&1; then
        # macOS: use sysctl vm.loadavg
        load_avg=$(sysctl -n vm.loadavg | awk '{print $2}')
    else
        # Fallback: use uptime
        load_avg=$(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}' | tr -d ' ')
    fi

    # Compare load as float
    if (($(echo "${load_avg} >= ${LOAD_THRESHOLD}" | bc -l 2>/dev/null || echo "0"))); then
        log_message "WARN" "System load too high (${load_avg} >= ${LOAD_THRESHOLD}). Waiting..."
        return 1
    fi

    return 0
}

# Ensure PROJECT_NAME is set for subprocess calls
export PROJECT_NAME="${PROJECT_NAME:-CodingReviewer}"

AGENT_NAME="CleanupAgent"
LOG_FILE="${SCRIPT_DIR}/cleanup_agent.log"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
AGENTS_DIR="${SCRIPT_DIR}"
CLEANUP_REPORT_DIR="${WORKSPACE_ROOT}/.metrics/cleanup"

# Source AI enhancement modules
ENHANCEMENTS_DIR="${SCRIPT_DIR}/../enhancements"
if [[ -f "${ENHANCEMENTS_DIR}/ai_cleanup_optimizer.sh" ]]; then
    # shellcheck source=../enhancements/ai_cleanup_optimizer.sh
    source "${ENHANCEMENTS_DIR}/ai_cleanup_optimizer.sh"
fi

SLEEP_INTERVAL=86400 # 24 hours for cleanup tasks

mkdir -p "${CLEANUP_REPORT_DIR}"

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

# Function to check resource usage and limits
check_resource_limits() {
    # Check memory usage (macOS compatible)
    local mem_usage
    if command -v vm_stat >/dev/null 2>&1; then
        # macOS: calculate memory usage percentage
        mem_usage=$(vm_stat | awk '/Pages active/ {active=$3} /Pages wired/ {wired=$4} END {total=active+wired; print int(total/2560*100)}' 2>/dev/null || echo "50")
    else
        # Fallback: use ps for memory info
        mem_usage=$(ps -o pmem= -C "${AGENT_NAME}" | awk '{sum+=$1} END {print int(sum)}' 2>/dev/null || echo "10")
    fi

    if [[ ${mem_usage} -gt ${MAX_MEMORY_USAGE} ]]; then
        log_message "WARN" "Memory usage too high (${mem_usage}% > ${MAX_MEMORY_USAGE}%)"
        return 1
    fi

    # Check CPU usage
    local cpu_usage
    cpu_usage=$(ps -o pcpu= -C "${AGENT_NAME}" | awk '{sum+=$1} END {print int(sum)}' 2>/dev/null || echo "5")

    if [[ ${cpu_usage} -gt ${MAX_CPU_USAGE} ]]; then
        log_message "WARN" "CPU usage too high (${cpu_usage}% > ${MAX_CPU_USAGE}%)"
        return 1
    fi

    return 0
}

# Rotate log files
rotate_logs() {
    log_message "INFO" "Rotating log files..."

    local rotated_count=0
    local compressed_count=0

    # Find large log files (>10MB) - add timeout
    local large_logs
    large_logs=$(timeout 30 find "${AGENTS_DIR}" "${WORKSPACE_ROOT}/Projects" -maxdepth 3 -name "*.log" -size +10M 2>/dev/null || echo "")

    if [[ -n "${large_logs}" ]]; then
        while IFS= read -r log_file; do
            [[ -z "${log_file}" ]] && continue

            local timestamp
            timestamp=$(date +%Y%m%d_%H%M%S)
            local rotated_name="${log_file}.${timestamp}"

            log_message "INFO" "Rotating: ${log_file}"

            # Copy and truncate
            cp "${log_file}" "${rotated_name}"
            : >"${log_file}" # Truncate file

            # Compress rotated log
            if command -v gzip &>/dev/null; then
                gzip "${rotated_name}"
                compressed_count=$((compressed_count + 1))
            fi

            rotated_count=$((rotated_count + 1))
        done <<<"${large_logs}"
    fi

    log_message "INFO" "Rotated ${rotated_count} log file(s), compressed ${compressed_count}"
}

# Clean old log files
clean_old_logs() {
    local retention_days="${1:-14}"

    log_message "INFO" "Cleaning logs older than ${retention_days} days..."

    local deleted_count=0
    local space_freed=0

    # Find old compressed logs - add timeout and depth limit
    local old_logs
    old_logs=$(timeout 30 find "${AGENTS_DIR}" "${WORKSPACE_ROOT}/Projects" -maxdepth 3 -name "*.log.*.gz" -mtime "+${retention_days}" 2>/dev/null || echo "")

    if [[ -n "${old_logs}" ]]; then
        while IFS= read -r log_file; do
            [[ -z "${log_file}" ]] && continue

            local size
            size=$(du -k "${log_file}" 2>/dev/null | awk '{print $1}')
            space_freed=$((space_freed + size))

            rm -f "${log_file}"
            deleted_count=$((deleted_count + 1))
        done <<<"${old_logs}"
    fi

    log_message "INFO" "Deleted ${deleted_count} old log(s), freed ${space_freed} KB"
}

# Clean build artifacts
clean_build_artifacts() {
    log_message "INFO" "Cleaning old build artifacts..."

    local deleted_count=0
    local space_freed=0

    # Find old build directories (>7 days)
    local build_dirs=(
        "${WORKSPACE_ROOT}/Projects/*/build"
        "${WORKSPACE_ROOT}/Projects/*/.build"
        "${WORKSPACE_ROOT}/.build"
    )

    for pattern in "${build_dirs[@]}"; do
        local dirs
        dirs=$(find "$(dirname "${pattern}")" -name "$(basename "${pattern}")" -type d -mtime +7 2>/dev/null || echo "")

        if [[ -n "${dirs}" ]]; then
            while IFS= read -r build_dir; do
                [[ -z "${build_dir}" ]] && continue

                local size
                size=$(du -sk "${build_dir}" 2>/dev/null | awk '{print $1}')
                space_freed=$((space_freed + size))

                log_message "INFO" "Removing: ${build_dir}"
                rm -rf "${build_dir}"
                deleted_count=$((deleted_count + 1))
            done <<<"${dirs}"
        fi
    done

    log_message "INFO" "Cleaned ${deleted_count} build director(ies), freed $((space_freed / 1024)) MB"
}

# Clean Xcode DerivedData
clean_derived_data() {
    local derived_data_dir="${HOME}/Library/Developer/Xcode/DerivedData"

    if [[ ! -d "${derived_data_dir}" ]]; then
        return 0
    fi

    log_message "INFO" "Cleaning Xcode DerivedData..."

    # Get size before
    local size_before
    size_before=$(du -sk "${derived_data_dir}" 2>/dev/null | awk '{print $1}')

    # Clean old DerivedData (>7 days)
    find "${derived_data_dir}" -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true

    # Get size after
    local size_after
    size_after=$(du -sk "${derived_data_dir}" 2>/dev/null | awk '{print $1}')

    local space_freed=$((size_before - size_after))

    log_message "INFO" "Freed $((space_freed / 1024)) MB from DerivedData"
}

# Clean temp files
clean_temp_files() {
    log_message "INFO" "Cleaning temporary files..."

    local deleted_count=0
    local space_freed=0

    # Find temp files - limit search depth and add timeout
    local temp_patterns=(
        "*.tmp"
        "*.temp"
        "*~"
        ".DS_Store"
        "*.swp"
        "*.swo"
    )

    for pattern in "${temp_patterns[@]}"; do
        # Use timeout to prevent hanging, limit depth to avoid deep recursion
        local temp_files
        temp_files=$(timeout 30 find "${WORKSPACE_ROOT}" -maxdepth 5 -name "${pattern}" -type f 2>/dev/null || echo "")

        if [[ -n "${temp_files}" ]]; then
            while IFS= read -r temp_file; do
                [[ -z "${temp_file}" ]] && continue

                local size
                size=$(du -k "${temp_file}" 2>/dev/null | awk '{print $1}')
                space_freed=$((space_freed + size))

                rm -f "${temp_file}"
                deleted_count=$((deleted_count + 1))
            done <<<"${temp_files}"
        fi
    done

    log_message "INFO" "Cleaned ${deleted_count} temp file(s), freed ${space_freed} KB"
}

# Clean package manager caches
clean_package_caches() {
    log_message "INFO" "Cleaning package manager caches..."

    local space_freed=0

    # Clean Swift Package Manager cache
    if [[ -d "${HOME}/.swiftpm" ]]; then
        local spm_size
        spm_size=$(du -sk "${HOME}/.swiftpm" 2>/dev/null | awk '{print $1}')

        # Only clean if >1GB
        if [[ ${spm_size} -gt $((1024 * 1024)) ]]; then
            log_message "INFO" "Cleaning SPM cache (${spm_size} KB)..."
            rm -rf "${HOME}/.swiftpm/cache" 2>/dev/null || true

            local spm_after
            spm_after=$(du -sk "${HOME}/.swiftpm" 2>/dev/null | awk '{print $1}')
            space_freed=$((space_freed + spm_size - spm_after))
        fi
    fi

    # Clean npm cache (if exists)
    if command -v npm &>/dev/null && [[ -d "${HOME}/.npm" ]]; then
        local npm_size
        npm_size=$(du -sk "${HOME}/.npm" 2>/dev/null | awk '{print $1}')

        if [[ ${npm_size} -gt $((1024 * 1024)) ]]; then
            log_message "INFO" "Cleaning npm cache..."
            npm cache clean --force &>/dev/null || true

            local npm_after
            npm_after=$(du -sk "${HOME}/.npm" 2>/dev/null | awk '{print $1}')
            space_freed=$((space_freed + npm_size - npm_after))
        fi
    fi

    log_message "INFO" "Freed $((space_freed / 1024)) MB from package caches"
}

# Clean old metrics
clean_old_metrics() {
    local retention_days="${1:-30}"

    log_message "INFO" "Cleaning metrics older than ${retention_days} days..."

    local deleted_count=0

    if [[ -d "${WORKSPACE_ROOT}/.metrics" ]]; then
        local old_metrics
        old_metrics=$(timeout 30 find "${WORKSPACE_ROOT}/.metrics" -maxdepth 2 -name "*.json" -mtime "+${retention_days}" 2>/dev/null || echo "")

        if [[ -n "${old_metrics}" ]]; then
            while IFS= read -r metric_file; do
                [[ -z "${metric_file}" ]] && continue

                rm -f "${metric_file}"
                deleted_count=$((deleted_count + 1))
            done <<<"${old_metrics}"
        fi
    fi

    log_message "INFO" "Cleaned ${deleted_count} old metric file(s)"
}

# Generate cleanup report
generate_cleanup_report() {
    local report_file
    report_file="${CLEANUP_REPORT_DIR}/cleanup_$(date +%Y%m%d_%H%M%S).json"

    log_message "INFO" "Generating cleanup report..."

    # Collect workspace statistics - add timeouts to prevent hanging
    local workspace_size
    workspace_size="$(timeout 30 du -sk "${WORKSPACE_ROOT}" 2>/dev/null | awk '{print $1}' || echo 0)"

    local file_count
    file_count=$(timeout 30 find "${WORKSPACE_ROOT}" -maxdepth 4 -type f 2>/dev/null | wc -l | tr -d ' ' || echo 0)

    local dir_count
    dir_count=$(timeout 30 find "${WORKSPACE_ROOT}" -maxdepth 4 -type d 2>/dev/null | wc -l | tr -d ' ' || echo 0)

    cat >"${report_file}" <<EOF
{
  "timestamp": $(date +%s),
  "date": "$(date -Iseconds)",
  "workspace": {
    "size_kb": ${workspace_size},
    "size_mb": $((workspace_size / 1024)),
    "file_count": ${file_count},
    "directory_count": ${dir_count}
  },
  "cleanup_actions": {
    "logs_rotated": true,
    "old_logs_cleaned": true,
    "build_artifacts_cleaned": true,
    "temp_files_cleaned": true,
    "derived_data_cleaned": true,
    "package_caches_cleaned": true,
    "old_metrics_cleaned": true
  }
}
EOF

    log_message "INFO" "Cleanup report: ${report_file}"
}

# Main cleanup routine
run_full_cleanup() {
    log_message "INFO" "Starting full workspace cleanup..."

    local start_time
    start_time=$(date +%s)

    # Run all cleanup operations
    rotate_logs
    clean_old_logs 14
    clean_build_artifacts
    clean_derived_data
    clean_temp_files
    clean_package_caches
    clean_old_metrics 30

    # Generate report
    generate_cleanup_report

    local end_time
    end_time=$(date +%s)
    local duration=$((end_time - start_time))

    log_message "INFO" "Full cleanup complete in ${duration} seconds"
}

# Process a specific cleanup task
process_cleanup_task() {
    local task_id="$1"
    log_message "INFO" "Processing cleanup task ${task_id}"

    # Mark task as in progress
    update_task_status "${task_id}" "in_progress"
    update_agent_status "agent_cleanup.sh" "busy" $$ "${task_id}"

    # Run full cleanup
    run_full_cleanup

    # Mark task as completed
    update_task_status "${task_id}" "completed"
    increment_task_count "${AGENT_NAME}"
    update_agent_status "agent_cleanup.sh" "available" $$ ""

    log_message "INFO" "Cleanup task ${task_id} completed successfully"
}

# Main agent loop
trap 'update_agent_status "agent_cleanup.sh" "stopped" $$ ""; log_message "INFO" "Cleanup Agent stopping..."; exit 0' SIGTERM SIGINT

while true; do
    # Check if we should proceed (throttling)
    if ! ensure_within_limits; then
        # Wait when busy, with exponential backoff
        wait_time="${WAIT_WHEN_BUSY}"
        attempts=0
        while ! ensure_within_limits && [[ ${attempts} -lt 10 ]]; do
            log_message "INFO" "Waiting ${wait_time}s before retry (attempt $((attempts + 1))/10)"
            sleep "${wait_time}"
            wait_time="$((wait_time * 2))"                        # Exponential backoff
            if [[ ${wait_time} -gt 300 ]]; then wait_time=300; fi # Cap at 5 minutes
            ((attempts++))
        done

        # If still busy after retries, skip this cycle
        if ! ensure_within_limits; then
            log_message "WARN" "System still busy after retries. Skipping cycle."
            sleep 60
            continue
        fi
    fi

    # SINGLE_RUN mode: exit after one cycle for testing
    if [[ "${SINGLE_RUN:-false}" == "true" ]]; then
        log_message "INFO" "SINGLE_RUN mode - exiting after one cycle"
        update_agent_status "agent_cleanup.sh" "stopped" $$ ""
        exit 0
    fi

    # Get next task for this agent
    TASK_ID=$(get_next_task "agent_cleanup.sh")

    if [[ -n "${TASK_ID}" ]]; then
        log_message "INFO" "Found cleanup task: ${TASK_ID}"
        process_cleanup_task "${TASK_ID}"
    else
        # No tasks - run periodic cleanup if enough time has passed
        update_agent_status "agent_cleanup.sh" "idle" $$ ""
        log_message "INFO" "No cleanup tasks found. Sleeping for ${SLEEP_INTERVAL} seconds."
        sleep "${SLEEP_INTERVAL}"
    fi
done
