#!/bin/bash
# Notification Agent - Smart notifications & alerts

# Source shared functions for task management
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

# Source project configuration
if [[ -f "${SCRIPT_DIR}/../project_config.sh" ]]; then
    source "${SCRIPT_DIR}/../project_config.sh"
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
        local cmd_pid
        cmd_pid=$!

        echo "$cmd_pid" >"$pid_file"

        # Wait for completion or timeout
        local count
        count=0
        while [[ $count -lt $timeout ]] && kill -0 "$cmd_pid" 2>/dev/null; do
            sleep 1
            ((count++))
        done

        # Check if still running
        if kill -0 "$cmd_pid" 2>/dev/null; then
            # Kill the process group
            pkill -TERM -P "$cmd_pid" 2>/dev/null || true
            sleep 1
            pkill -KILL -P "$cmd_pid" 2>/dev/null || true
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
        local mem_percent
        mem_percent=$((mem_usage * 4096 * 100 / (total_mem * 1024 * 1024 / 4096)))
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
ALERT_HISTORY="${SCRIPT_DIR}/.alert_history.json"

# Logging configuration
AGENT_NAME="NotificationAgent"
LOG_FILE="${SCRIPT_DIR}/notification_agent.log"

log_message() {
    local level="$1"
    local message="$2"
    echo "[$(date)] [${AGENT_NAME}] [${level}] ${message}" >>"${LOG_FILE}"
}

process_notification_task() {
    local task="$1"

    log_message "INFO" "Processing notification task: $task"

    case "$task" in
    test_notification_run)
        log_message "INFO" "Running notification system verification..."
        send_notification "info" "Test Notification" "This is a test notification from the Notification Agent" "test_run"
        log_message "SUCCESS" "Notification system operational"
        ;;
    monitor_build_failures)
        log_message "INFO" "Monitoring build failures..."
        monitor_build_failures
        ;;
    monitor_agent_health)
        log_message "INFO" "Monitoring agent health..."
        monitor_agent_health
        ;;
    monitor_disk_space)
        log_message "INFO" "Monitoring disk space..."
        monitor_disk_space
        ;;
    monitor_security_alerts)
        log_message "INFO" "Monitoring security alerts..."
        monitor_security_alerts
        ;;
    check_mcp_alerts)
        log_message "INFO" "Checking MCP alerts..."
        check_mcp_alerts
        ;;
    send_notification)
        log_message "INFO" "Sending notification..."
        # Task data should contain: level|title|message|key
        IFS='|' read -r level title message key <<<"$task"
        send_notification "${level:-info}" "${title:-Notification}" "${message:-Message from agent}" "${key:-manual}"
        ;;
    *)
        log_message "WARN" "Unknown notification task: $task"
        ;;
    esac
}

# Initialize alert history
initialize_alert_history() {
    if [[ ! -f "${ALERT_HISTORY}" ]]; then
        echo '{"alerts":[]}' >"${ALERT_HISTORY}"
    fi
}

# Check if alert was recently sent (deduplication)
is_duplicate_alert() {
    local alert_key="$1"
    local threshold_minutes="${2:-60}"

    python3 <<PYTHON
import json
import time

try:
    with open('${ALERT_HISTORY}', 'r') as f:
        data = json.load(f)

    now = time.time()
    threshold = ${threshold_minutes} * 60

    for alert in data.get('alerts', []):
        if alert['key'] == '${alert_key}':
            if now - alert['timestamp'] < threshold:
                exit(0)  # Duplicate found

    exit(1)  # Not a duplicate
except:
    exit(1)
PYTHON
}

# Record sent alert
record_alert() {
    local alert_key="$1"
    local message="$2"

    python3 <<PYTHON
import json
import time

try:
    with open('${ALERT_HISTORY}', 'r') as f:
        data = json.load(f)

    if 'alerts' not in data:
        data['alerts'] = []

    # Add new alert
    data['alerts'].append({
        'key': '${alert_key}',
        'message': '''${message}''',
        'timestamp': time.time(),
        'date': time.strftime('%Y-%m-%d %H:%M:%S')
    })

    # Keep only last 100 alerts
    data['alerts'] = data['alerts'][-100:]

    with open('${ALERT_HISTORY}', 'w') as f:
        json.dump(data, f, indent=2)
except Exception as e:
    print(f'Error recording alert: {e}')
PYTHON
}

# Send desktop notification (macOS)
send_desktop_notification() {
    local title="$1"
    local message="$2"
    local urgency="${3:-normal}"

    if [[ "$(uname)" == "Darwin" ]]; then
        # macOS notification
        osascript -e "display notification \"${message}\" with title \"${title}\"" 2>/dev/null || true
    elif command -v notify-send &>/dev/null; then
        # Linux notification
        notify-send -u "${urgency}" "${title}" "${message}" 2>/dev/null || true
    fi
}

# Send Slack notification (if configured)
send_slack_notification() {
    local message="$1"
    local channel="${2:-#general}"

    if [[ -z "${SLACK_WEBHOOK_URL:-}" ]]; then
        return 0 # Slack not configured
    fi

    local payload
    payload=$(
        cat <<EOF
{
  "channel": "${channel}",
  "username": "Quantum Agent",
  "text": "${message}",
  "icon_emoji": ":robot_face:"
}
EOF
    )

    if command -v curl &>/dev/null; then
        curl -s -X POST "${SLACK_WEBHOOK_URL}" \
            -H "Content-Type: application/json" \
            -d "${payload}" &>/dev/null || warning "Failed to send Slack notification"
    fi
}

# Send email notification (if configured)
send_email_notification() {
    local subject="$1"
    local body="$2"
    local recipient="${EMAIL_RECIPIENT:-}"

    if [[ -z "${recipient}" ]]; then
        return 0 # Email not configured
    fi

    if command -v mail &>/dev/null; then
        echo "${body}" | mail -s "${subject}" "${recipient}" 2>/dev/null || warning "Failed to send email"
    fi
}

# Send notification via all configured channels
send_notification() {
    local level="$1" # info, warning, error, critical
    local title="$2"
    local message="$3"
    local alert_key="${4:-$(echo "${title}" | tr ' ' '_')}"

    # Check for duplicate
    if is_duplicate_alert "${alert_key}"; then
        log_message "INFO" "Skipping duplicate alert: ${alert_key}"
        return 0
    fi

    log_message "INFO" "Sending ${level} notification: ${title}"

    # Send desktop notification
    local urgency="normal"
    [[ "${level}" == "error" || "${level}" == "critical" ]] && urgency="critical"
    send_desktop_notification "${title}" "${message}" "${urgency}"

    # Send Slack notification for warnings and above
    if [[ "${level}" == "warning" || "${level}" == "error" || "${level}" == "critical" ]]; then
        local slack_message="*${level^^}:* ${title}\n${message}"
        send_slack_notification "${slack_message}"
    fi

    # Send email for critical issues
    if [[ "${level}" == "critical" ]]; then
        send_email_notification "[CRITICAL] ${title}" "${message}"
    fi

    # Record alert
    record_alert "${alert_key}" "${message}"

    log_message "SUCCESS" "Notification sent: ${title}"
}

# Monitor build failures
monitor_build_failures() {
    log_message "INFO" "Checking for build failures..."

    # Check GitHub workflow failures
    if command -v gh &>/dev/null; then
        cd "${WORKSPACE_ROOT}" || return 0

        local failed_runs
        failed_runs=$(gh run list --limit 5 --json status,conclusion,name,createdAt --jq '.[] | select(.conclusion=="failure") | select(.createdAt | fromdateiso8601 > (now - 3600))' 2>/dev/null || echo "")

        if [[ -n "${failed_runs}" ]]; then
            local count
            count=$(echo "${failed_runs}" | jq -s 'length')

            if [[ ${count} -gt 0 ]]; then
                send_notification "error" "Build Failures Detected" "${count} workflow(s) failed in the last hour" "build_failure_hourly"
            fi
        fi

        cd - >/dev/null || return 0
    fi
}

# Monitor agent health
monitor_agent_health() {
    log_message "INFO" "Checking agent health..."

    if [[ ! -f "${STATUS_FILE}" ]]; then
        return 0
    fi

    # Clean up stale agent entries (only count agents that should be actively running)
    cleanup_stale_agents

    # Count unhealthy agents (only count agents that should be actively running)
    local unhealthy
    unhealthy=$(
        python3 <<PYTHON
import json
import time

try:
    with open('${STATUS_FILE}', 'r') as f:
        data = json.load(f)

    now = time.time()
    threshold = 300  # 5 minutes
    unhealthy_count = 0

    for agent, status in data.get('agents', {}).items():
        agent_status = status.get('status', 'unknown')
        # Only count agents that should be actively running
        if agent_status in ['running', 'active', 'busy']:
            last_seen = status.get('last_seen', 0)
            if now - last_seen > threshold:
                unhealthy_count += 1

    print(unhealthy_count)
except:
    print(0)
PYTHON
    )

    if [[ ${unhealthy} -gt 5 ]]; then
        send_notification "warning" "Agent Health Alert" "${unhealthy} agents haven't reported in 5+ minutes" "agent_health_check"
    fi
}

# Clean up stale agent entries
cleanup_stale_agents() {
    if [[ ! -f "${STATUS_FILE}" ]]; then
        return 0
    fi

    log_message "INFO" "Cleaning up stale agent entries..."

    python3 <<PYTHON
import json
import time
import os

try:
    status_file = '${STATUS_FILE}'
    with open(status_file, 'r') as f:
        data = json.load(f)

    now = time.time()
    stale_threshold = 86400  # 24 hours
    agents_to_remove = []

    for agent, status in data.get('agents', {}).items():
        last_seen = status.get('last_seen', 0)
        if now - last_seen > stale_threshold:
            agents_to_remove.append(agent)

    if agents_to_remove:
        for agent in agents_to_remove:
            del data['agents'][agent]
        
        with open(status_file, 'w') as f:
            json.dump(data, f, indent=2)
        
        print(f"Removed {len(agents_to_remove)} stale agent entries: {', '.join(agents_to_remove)}")
    else:
        print("No stale agent entries to remove")

except Exception as e:
    print(f"Error cleaning up stale agents: {e}")
PYTHON
}

# Monitor disk space
monitor_disk_space() {
    log_message "INFO" "Checking disk space..."

    local usage
    usage=$(df -h "${WORKSPACE_ROOT}" | awk 'NR==2 {print $5}' | sed 's/%//')

    if [[ ${usage} -gt 90 ]]; then
        send_notification "critical" "Disk Space Critical" "Disk usage at ${usage}% - cleanup required" "disk_space_critical"
    elif [[ ${usage} -gt 80 ]]; then
        send_notification "warning" "Disk Space Warning" "Disk usage at ${usage}% - consider cleanup" "disk_space_warning"
    fi
}

# Monitor security alerts
monitor_security_alerts() {
    log_message "INFO" "Checking for security alerts..."

    # Check for new security alerts from GitHub
    if command -v gh &>/dev/null; then
        cd "${WORKSPACE_ROOT}" || return 0

        local alerts
        # Note: Replace {owner}/{repo} with actual values or use gh repo view --json owner,name
        local repo_full
        repo_full=$(gh repo view --json nameWithOwner --jq '.nameWithOwner' 2>/dev/null || echo "")

        if [[ -n "${repo_full}" ]]; then
            alerts=$(gh api "/repos/${repo_full}/dependabot/alerts" --jq '.[] | select(.state=="open")' 2>/dev/null || echo "")
        else
            alerts=""
        fi

        if [[ -n "${alerts}" ]]; then
            local count
            count=$(echo "${alerts}" | jq -s 'length')

            if [[ ${count} -gt 0 ]]; then
                send_notification "warning" "Security Alerts" "${count} open Dependabot alert(s) detected" "security_alerts"
            fi
        fi

        cd - >/dev/null || return 0
    fi
}

# Check MCP alerts
check_mcp_alerts() {
    if ! command -v curl &>/dev/null; then
        return 0
    fi

    log_message "INFO" "Checking MCP alerts..."

    local alerts
    alerts=$(curl -s "${MCP_URL}/alerts" 2>/dev/null || echo "[]")

    if [[ "${alerts}" != "[]" ]]; then
        # Process each alert
        echo "${alerts}" | python3 -c "
import json, sys
try:
    alerts = json.load(sys.stdin)
    for alert in alerts:
        level = alert.get('level', 'info')
        message = alert.get('message', 'No message')
        print(f'{level}:{message}')
except:
    pass
" | while IFS=: read -r level message; do
            send_notification "${level}" "MCP Alert" "${message}" "mcp_alert_${level}"
        done
    fi
}

# Main agent loop - standardized task processing
main() {
    log_message "INFO" "Notification Agent starting..."

    # Initialize agent status
    update_agent_status "${AGENT_NAME}" "starting" $$ ""

    # Initialize alert history
    initialize_alert_history

    # Main task processing loop
    while true; do
        # Get next task from shared queue
        local task_data
        task_data=$(get_next_task "${AGENT_NAME}")

        if [[ -n "${task_data}" ]]; then
            # Process the task
            process_notification_task "${task_data}"
        else
            # No tasks available, check for periodic maintenance
            if ensure_within_limits "notification_monitoring" 120; then
                # Run periodic monitoring checks
                monitor_build_failures
                monitor_agent_health
                monitor_disk_space
                monitor_security_alerts
                check_mcp_alerts
            fi
        fi

        # Brief pause to prevent tight looping
        sleep 5
    done
}

# Run main function if script is executed directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    # Handle single run mode for testing
    if [[ "${1:-}" == "SINGLE_RUN" ]]; then
        log_message "INFO" "Running in SINGLE_RUN mode for testing"
        update_agent_status "${AGENT_NAME}" "running" $$ ""

        # Run a quick monitoring cycle
        monitor_build_failures
        monitor_disk_space

        update_agent_status "${AGENT_NAME}" "completed" $$ ""
        log_message "INFO" "SINGLE_RUN completed successfully"
        exit 0
    fi

    # Start the main agent loop
    trap 'update_agent_status "${AGENT_NAME}" "stopped" $$ ""; log_message "INFO" "Notification Agent stopping..."; exit 0' SIGTERM SIGINT
    main "$@"
fi
