#!/usr/bin/env bash
# Auto-injected health & reliability shim
# Adds: standardized --health handler, strict mode, and a graceful shutdown trap

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

# Enable strict mode for safer scripts
set -euo pipefail

# Default agent logging vars if not present
AGENT_NAME="agent_analytics.sh"
LOG_FILE="${LOG_FILE:-$DIR/${AGENT_NAME}.log}"
PID=$$

# Ensure we update status on termination if helper available
if type update_agent_status >/dev/null 2>&1; then
  trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; exit 0' SIGTERM SIGINT
else
  trap 'exit 0' SIGTERM SIGINT
fi

# Health handler
if [[ "${1-}" == "--health" || "${1-}" == "health" || "${1-}" == "-h" ]]; then
  if type agent_health_check >/dev/null 2>&1; then
    agent_health_check
    exit $?
  fi
  # Best-effort lightweight checks
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
# Agent Analytics - Project metrics collection & analysis
# Tracks code complexity, build times, test coverage, and agent performance

# Source shared functions for file locking and monitoring
# shellcheck source=./shared_functions.sh
# shellcheck disable=SC1091
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"
if [[ -f "${SCRIPT_DIR}/agent_loop_utils.sh" ]]; then
    # shellcheck source=./agent_loop_utils.sh
    # shellcheck disable=SC1091
    source "${SCRIPT_DIR}/agent_loop_utils.sh"
fi

set -euo pipefail

# Portable run_with_timeout: run a command and kill it if it exceeds timeout (seconds)
# Usage: run_with_timeout <seconds> <cmd> [args...]
run_with_timeout() {
    local timeout="$1"
    shift
    local cmd="$*"

    # Use timeout command if available (Linux), otherwise implement with background process
    if command -v timeout >/dev/null 2>&1; then
        timeout --kill-after=5s "${timeout}s" bash -c "$cmd"
    else
        # macOS/BSD implementation using background process
        local pid_file
        pid_file=$(mktemp)
        local exit_file
        exit_file=$(mktemp)

        # Run command in background
        (
            if bash -c "$cmd"; then
                echo 0 >"$exit_file"
            else
                echo $? >"$exit_file"
            fi
        ) &
        local cmd_pid=$!

        echo $cmd_pid >"$pid_file"

        # Wait for completion or timeout
        local count=0
        while [[ $count -lt $timeout ]] && kill -0 $cmd_pid 2>/dev/null; do
            sleep 1
            ((count++))
        done

        # Check if still running
        if kill -0 $cmd_pid 2>/dev/null; then
            # Kill the process group
            pkill -TERM -P $cmd_pid 2>/dev/null || true
            sleep 1
            pkill -KILL -P $cmd_pid 2>/dev/null || true
            rm -f "$pid_file" "$exit_file"
            log_message "ERROR" "Command timed out after ${timeout}s: $cmd"
            return 124
        else
            # Command completed, get exit code
            local exit_code
            if [[ -f "$exit_file" ]]; then
                exit_code=$(cat "$exit_file")
                rm -f "$pid_file" "$exit_file"
                return "$exit_code"
            else
                rm -f "$pid_file" "$exit_file"
                return 0
            fi
        fi
    fi
}

# Check resource limits before operations
check_resource_limits() {
    # Check file count limit (1000 files max)
    local file_count
    file_count=$(find "${WORKSPACE_ROOT:-/Users/danielstevens/Desktop/Quantum-workspace}" -type f 2>/dev/null | wc -l | tr -d ' ')
    if [[ $file_count -gt 1000 ]]; then
        log_message "ERROR" "File count limit exceeded: $file_count files (max: 1000)"
        return 1
    fi

    # Check memory usage (80% max)
    if command -v vm_stat >/dev/null 2>&1; then
        # macOS memory check
        local mem_usage
        mem_usage=$(vm_stat | grep "Pages active" | awk '{print $3}' | tr -d '.')
        local total_mem
        total_mem=$(echo "$(sysctl -n hw.memsize) / 1024 / 1024" | bc 2>/dev/null || echo "8192")
        local mem_percent=$((mem_usage * 4096 * 100 / (total_mem * 1024 * 1024 / 4096)))
        if [[ $mem_percent -gt 80 ]]; then
            log_message "ERROR" "Memory usage too high: ${mem_percent}% (max: 80%)"
            return 1
        fi
    fi

    # Check CPU usage (90% max)
    if command -v ps >/dev/null 2>&1; then
        local cpu_usage
        cpu_usage=$(ps -A -o %cpu | awk '{s+=$1} END {print s}')
        if [[ $(echo "$cpu_usage > 90" | bc 2>/dev/null) -eq 1 ]]; then
            log_message "ERROR" "CPU usage too high: ${cpu_usage}% (max: 90%)"
            return 1
        fi
    fi

    return 0
}

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
AGENTS_DIR="${SCRIPT_DIR}"
AGENT_NAME="agent_analytics"
LOG_FILE="${AGENTS_DIR}/${AGENT_NAME}.log"
STATUS_FILE="${AGENTS_DIR}/../config/agent_status.json"
METRICS_DIR="${WORKSPACE_ROOT}/.metrics"
ANALYTICS_DATA="${METRICS_DIR}/analytics_$(date +%Y%m).json"

# Logging function
log_message() {
    echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] $*" | tee -a "${LOG_FILE}"
}

# Throttling and load management
ensure_within_limits() {
    local max_concurrency=${MAX_CONCURRENCY:-3}
    local load_threshold=${LOAD_THRESHOLD:-8.0}
    local wait_time=${THROTTLE_WAIT_TIME:-30}

    # Check concurrent agent instances
    local running_agents
    running_agents="$(pgrep -f "agent_.*\.sh" | wc -l)"

    if [[ $running_agents -gt $max_concurrency ]]; then
        log_message "WARNING: Too many agents running ($running_agents > $max_concurrency). Waiting..."
        sleep "$wait_time"
        return 1
    fi

    # Check system load
    local current_load
    if command -v sysctl &>/dev/null; then
        # macOS load average
        current_load="$(sysctl -n vm.loadavg | awk '{print $2}')"
    else
        # Linux fallback
        current_load="$(uptime | awk -F'load average:' '{print $2}' | awk '{print $1}' | sed 's/,//')"
    fi

    # Compare as floats
    if (($(echo "$current_load >= $load_threshold" | bc -l 2>/dev/null || echo "0"))); then
        log_message "WARNING: System load too high ($current_load >= $load_threshold). Waiting..."
        sleep "$wait_time"
        return 1
    fi

    return 0
}

# Initialize metrics directory
mkdir -p "${METRICS_DIR}"
mkdir -p "${METRICS_DIR}/history"
mkdir -p "${METRICS_DIR}/reports"

# Update agent status
update_agent_status() {
    local agent_script="$1"
    local status="$2"
    local pid="$3"
    local task="$4"

    if [[ ! -f "${STATUS_FILE}" ]]; then
        echo "{}" >"${STATUS_FILE}"
    fi

    python3 -c "
import json
import time
try:
    with open('${STATUS_FILE}', 'r') as f:
        data = json.load(f)
except:
    data = {}

if 'agents' not in data:
    data['agents'] = {}

data['agents']['${agent_script}'] = {
    'status': '${status}',
    'pid': ${pid},
    'last_seen': int(time.time()),
    'task': '${task}',
    'capabilities': ['analytics', 'metrics', 'reporting', 'quantum-analysis']
}

with open('${STATUS_FILE}', 'w') as f:
    json.dump(data, f, indent=2)
" 2>/dev/null || true
}

# Collect code metrics for a project
collect_code_metrics() {
    local project_path="$1"
    local project_name
    project_name=$(basename "${project_path}")

    local swift_files=0
    local total_lines=0
    local code_lines=0
    local comment_lines=0
    local blank_lines=0

    # Count Swift files
    if [[ -d "${project_path}" ]]; then
        swift_files=$(find "${project_path}" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')

        # Analyze file content
        while IFS= read -r file; do
            [[ ! -f "$file" ]] && continue

            local lines
            lines=$(wc -l <"$file" 2>/dev/null | tr -d ' \n')
            total_lines=$((total_lines + lines))

            # Count comment and blank lines
            local comments
            comments=$(grep -c '^\s*//' "$file" 2>/dev/null | tr -d '\n' || echo 0)
            local blanks
            blanks=$(grep -c '^\s*$' "$file" 2>/dev/null | tr -d '\n' || echo 0)

            comment_lines=$((comment_lines + comments))
            blank_lines=$((blank_lines + blanks))
        done < <(find "${project_path}" -name "*.swift" 2>/dev/null)

        code_lines=$((total_lines - comment_lines - blank_lines))
    fi

    # Return JSON
    cat <<EOF
{
  "project": "${project_name}",
  "swift_files": ${swift_files},
  "total_lines": ${total_lines},
  "code_lines": ${code_lines},
  "comment_lines": ${comment_lines},
  "blank_lines": ${blank_lines},
  "comment_ratio": $(awk "BEGIN {if (${code_lines} > 0) print ${comment_lines}/${code_lines}; else print 0}")
}
EOF
}

# Collect build metrics
collect_build_metrics() {

    local build_logs=()
    local avg_build_time=0
    local total_builds=0

    # Find recent build logs
    while IFS= read -r log; do
        build_logs+=("$log")
    done < <(find "${WORKSPACE_ROOT}" -name "*build*.log" -mtime -7 2>/dev/null | head -20)

    # Analyze build times (simplified - would need actual timing data)
    total_builds=${#build_logs[@]}

    cat <<EOF
{
  "total_builds_7d": ${total_builds},
  "avg_build_time_seconds": ${avg_build_time},
  "last_build": "$(date -Iseconds)"
}
EOF
}

# Collect test coverage metrics
collect_coverage_metrics() {
    local project_path="$1"
    local project_name
    project_name=$(basename "${project_path}")

    # Look for coverage reports
    local coverage_file="${project_path}/.build/debug/codecov/*.json"
    local coverage_pct=0

    if compgen -G "${coverage_file}" >/dev/null 2>&1; then
        # Parse coverage from file (simplified)
        coverage_pct=$(grep -o '"coverage":[0-9.]*' "${coverage_file}" 2>/dev/null | head -1 | cut -d: -f2 || echo 0)
    fi

    cat <<EOF
{
  "project": "${project_name}",
  "coverage_percent": ${coverage_pct},
  "has_tests": $([ -d "${project_path}/Tests" ] && echo "true" || echo "false")
}
EOF
}

# Collect agent performance metrics
collect_agent_metrics() {

    local agent_count=0
    local active_agents=0
    local tasks_completed=0

    if [[ -f "${STATUS_FILE}" ]]; then
        agent_count=$(python3 -c "
import json
try:
    with open('${STATUS_FILE}', 'r') as f:
        data = json.load(f)
    print(len(data.get('agents', {})))
except:
    print(0)
" 2>/dev/null || echo 0)

        active_agents=$(python3 -c "
import json, time
try:
    with open('${STATUS_FILE}', 'r') as f:
        data = json.load(f)
    active = sum(1 for a in data.get('agents', {}).values()
                if a.get('status') in ['available', 'running', 'busy']
                and time.time() - a.get('last_seen', 0) < 300)
    print(active)
except:
    print(0)
" 2>/dev/null || echo 0)

        tasks_completed=$(python3 -c "
import json
try:
    with open('${STATUS_FILE}', 'r') as f:
        data = json.load(f)
    total = sum(a.get('tasks_completed', 0) for a in data.get('agents', {}).values())
    print(total)
except:
    print(0)
" 2>/dev/null || echo 0)
    fi

    cat <<EOF
{
  "total_agents": ${agent_count},
  "active_agents": ${active_agents},
  "tasks_completed_all_time": ${tasks_completed},
  "agent_availability": $(awk "BEGIN {if (${agent_count} > 0) print ${active_agents}/${agent_count}; else print 0}")
}
EOF
}

# Collect complexity metrics
collect_complexity_metrics() {
    local project_path="$1"
    local project_name
    project_name=$(basename "${project_path}")

    # Use SwiftLint if available
    local complexity_violations=0
    local avg_file_complexity=0

    if command -v swiftlint &>/dev/null && [[ -d "${project_path}" ]]; then
        # Count complexity warnings
        complexity_violations=$(cd "${project_path}" && swiftlint lint --quiet 2>/dev/null | grep -c "Cyclomatic Complexity" | tr -d '\n' || echo 0)
    fi

    cat <<EOF
{
  "project": "${project_name}",
  "complexity_violations": ${complexity_violations},
  "avg_complexity": ${avg_file_complexity}
}
EOF
}

# Generate analytics report
generate_report() {
    log_message "INFO: Generating analytics report..."

    local timestamp
    timestamp=$(date +%s)
    local report_file
    report_file="${METRICS_DIR}/reports/analytics_$(date +%Y%m%d_%H%M%S).json"

    # Collect metrics for the first valid project found
    local projects=("${WORKSPACE_ROOT}/Projects/"*)
    local code_metrics="{}"
    local coverage_metrics="{}"
    local complexity_metrics="{}"

    for project in "${projects[@]}"; do
        [[ ! -d "$project" ]] && continue

        local pname
        pname=$(basename "$project")
        [[ "$pname" == "Tools" || "$pname" == "scripts" || "$pname" == "Config" ]] && continue

        # Collect metrics for this project
        code_metrics=$(collect_code_metrics "$project")
        coverage_metrics=$(collect_coverage_metrics "$project")
        complexity_metrics=$(collect_complexity_metrics "$project")
        break # Just use the first valid project for now
    done

    # Collect other metrics
    local build_metrics
    build_metrics=$(collect_build_metrics)
    local agent_metrics
    agent_metrics=$(collect_agent_metrics)

    # Build full report
    cat >"${report_file}" <<EOF
{
  "timestamp": ${timestamp},
  "date": "$(date -Iseconds)",
  "workspace": "${WORKSPACE_ROOT}",
  "code_metrics": ${code_metrics},
  "build_metrics": ${build_metrics},
  "coverage_metrics": ${coverage_metrics},
  "complexity_metrics": ${complexity_metrics},
  "agent_metrics": ${agent_metrics}
}
EOF

    log_message "SUCCESS: Report generated: ${report_file}"

    # Save to monthly analytics
    cp "${report_file}" "${ANALYTICS_DATA}"

    echo "${report_file}"
}

# Generate dashboard-friendly summary
generate_dashboard_summary() {
    local report_file="$1"

    if [[ ! -f "${report_file}" ]]; then
        log_message "ERROR: Report file not found: ${report_file}"
        return 1
    fi

    log_message "INFO: Generating dashboard summary..."

    # Extract key metrics for dashboard
    python3 <<PYTHON
import json
import sys

try:
    with open('${report_file}', 'r') as f:
        data = json.load(f)

    summary = {
        "timestamp": data.get("timestamp"),
        "date": data.get("date"),
        "overview": {
            "total_agents": data.get("agent_metrics", {}).get("total_agents", 0),
            "active_agents": data.get("agent_metrics", {}).get("active_agents", 0),
            "total_builds": data.get("build_metrics", {}).get("total_builds_7d", 0),
            "agent_health": "healthy" if data.get("agent_metrics", {}).get("agent_availability", 0) > 0.8 else "degraded"
        },
        "code_quality": {
            "swift_files": data.get("code_metrics", {}).get("swift_files", 0),
            "total_lines": data.get("code_metrics", {}).get("total_lines", 0),
            "comment_ratio": round(data.get("code_metrics", {}).get("comment_ratio", 0), 2),
            "complexity_violations": data.get("complexity_metrics", {}).get("complexity_violations", 0)
        },
        "testing": {
            "coverage_percent": data.get("coverage_metrics", {}).get("coverage_percent", 0),
            "has_tests": data.get("coverage_metrics", {}).get("has_tests", False)
        }
    }

    with open('${METRICS_DIR}/dashboard_summary.json', 'w') as f:
        json.dump(summary, f, indent=2)

    print(json.dumps(summary, indent=2))

except Exception as e:
    print(f"Error: {e}", file=sys.stderr)
    exit(1)
PYTHON

    log_message "SUCCESS: Dashboard summary generated: ${METRICS_DIR}/dashboard_summary.json"
}

# Process analytics task
process_analytics_task() {
    local task="$1"

    log_message "Processing analytics task: $task"

    # Generate full analytics report
    local report_file
    report_file=$(generate_report)

    # Generate dashboard summary
    if [[ -f "${report_file}" ]]; then
        generate_dashboard_summary "${report_file}"
    fi

    # Archive old reports (keep last 30 days)
    find "${METRICS_DIR}/reports" -name "analytics_*.json" -mtime +30 -delete 2>/dev/null || true

    log_message "Analytics task completed successfully"
}

# Main agent loop
main() {
    log_message "Analytics Agent starting..."

    # Check for single run mode (for testing)
    if [[ "${SINGLE_RUN:-false}" == "true" ]]; then
        log_message "Running in SINGLE_RUN mode for testing"
        process_analytics_task "test_analytics_run"
        log_message "Single run analytics complete"
        return 0
    fi

    # Standardize timing/backoff and support pipeline quick-exit
    agent_init_backoff
    if agent_detect_pipe_and_quick_exit "${AGENT_NAME}"; then
        return 0
    fi

    # Exit early if in test mode
    if [[ "${TEST_MODE}" == "true" ]]; then
        log_message "Test mode detected, exiting before main loop"
        return 0 2>/dev/null || exit 0
    fi

    while true; do
        # Ensure we're within system limits
        if ! ensure_within_limits; then
            log_message "System limits exceeded, waiting before retry..."
            agent_sleep_with_backoff
            continue
        fi

        # Get next task for this agent
        local task
        task=$(get_next_task "agent_analytics")

        if [[ -n "$task" ]]; then
            # Mark task as in progress
            update_task_status "$task" "in_progress" "agent_analytics"

            # Process the task
            if process_analytics_task "$task"; then
                update_task_status "$task" "completed" "agent_analytics"
    increment_task_count "${AGENT_NAME}"
                log_message "Task $task completed successfully"
            else
                update_task_status "$task" "failed" "agent_analytics"
                log_message "Task $task failed"
            fi
        else
            # No tasks available, wait before checking again
            agent_sleep_with_backoff
        fi
    done
}

# Run main loop
main "$@"
