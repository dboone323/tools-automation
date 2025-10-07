#!/bin/bash
# Agent Notification - Smart notifications & alerts
# Sends notifications for build failures, PR updates, security alerts, and more

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
AGENTS_DIR="${SCRIPT_DIR}"
AGENT_NAME="agent_notification"
MCP_URL="${MCP_URL:-http://127.0.0.1:5005}"
LOG_FILE="${AGENTS_DIR}/${AGENT_NAME}.log"
STATUS_FILE="${AGENTS_DIR}/agent_status.json"
ALERT_HISTORY="${AGENTS_DIR}/.alert_history.json"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() { echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] $*" | tee -a "${LOG_FILE}"; }
error() { echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ❌ $*${NC}" | tee -a "${LOG_FILE}"; }
success() { echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ✅ $*${NC}" | tee -a "${LOG_FILE}"; }
warning() { echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ⚠️  $*${NC}" | tee -a "${LOG_FILE}"; }
info() { echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ℹ️  $*${NC}" | tee -a "${LOG_FILE}"; }


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
    info "Skipping duplicate alert: ${alert_key}"
    return 0
  fi

  log "Sending ${level} notification: ${title}"

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

  success "Notification sent: ${title}"
}

# Monitor build failures
monitor_build_failures() {
  info "Checking for build failures..."

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
  info "Checking agent health..."

  if [[ ! -f "${STATUS_FILE}" ]]; then
    return 0
  fi

  # Count unhealthy agents
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
        last_seen = status.get('last_seen', 0)
        if now - last_seen > threshold:
            unhealthy_count += 1

    print(unhealthy_count)
except:
    print(0)
PYTHON
  )

  if [[ ${unhealthy} -gt 3 ]]; then
    send_notification "warning" "Agent Health Alert" "${unhealthy} agents haven't reported in 5+ minutes" "agent_health_check"
  fi
}

# Monitor disk space
monitor_disk_space() {
  info "Checking disk space..."

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
  info "Checking for security alerts..."

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

  info "Checking MCP alerts..."

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

# Main monitoring loop
main() {
  log "Notification Agent starting..."
  update_agent_status "agent_notification.sh" "starting" $$ ""

  initialize_alert_history

  echo $$ >"${AGENTS_DIR}/${AGENT_NAME}.pid"

  # Register with MCP
  if command -v curl &>/dev/null; then
    curl -s -X POST "${MCP_URL}/register" \
      -H "Content-Type: application/json" \
      -d "{\"agent\": \"${AGENT_NAME}\", \"capabilities\": [\"notifications\", \"alerts\", \"monitoring\"]}" \
      &>/dev/null || warning "Failed to register with MCP"
  fi

  update_agent_status "agent_notification.sh" "available" $$ ""
  success "Notification Agent ready"

  # Send startup notification
  send_notification "info" "Notification Agent Started" "Agent is now monitoring for alerts" "agent_startup"

  # Main loop - check every 2 minutes
  while true; do
    update_agent_status "agent_notification.sh" "running" $$ ""

    # Run all monitors
    monitor_build_failures
    monitor_agent_health
    monitor_disk_space
    monitor_security_alerts
    check_mcp_alerts

    update_agent_status "agent_notification.sh" "available" $$ ""
    info "Monitoring cycle complete. Next check in 2 minutes."

    # Heartbeat
    if command -v curl &>/dev/null; then
      curl -s -X POST "${MCP_URL}/heartbeat" \
        -H "Content-Type: application/json" \
        -d "{\"agent\": \"${AGENT_NAME}\"}" &>/dev/null || true
    fi

    sleep 120 # 2 minutes
  done
}

# Handle CLI commands
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-daemon}" in
  test)
    send_notification "info" "Test Notification" "This is a test notification from the Notification Agent"
    ;;
  send)
    send_notification "${2:-info}" "${3:-Test}" "${4:-Test message}"
    ;;
  history)
    if [[ -f "${ALERT_HISTORY}" ]]; then
      cat "${ALERT_HISTORY}" | python3 -m json.tool
    fi
    ;;
  daemon)
    trap 'update_agent_status "agent_notification.sh" "stopped" $$ ""; log "Notification Agent stopping..."; exit 0' SIGTERM SIGINT
    main "$@"
    ;;
  *)
    echo "Usage: $0 {test|send|history|daemon}"
    echo ""
    echo "Commands:"
    echo "  test                           - Send test notification"
    echo "  send <level> <title> <message> - Send custom notification"
    echo "  history                        - Show alert history"
    echo "  daemon                         - Run as daemon (default)"
    echo ""
    echo "Environment Variables:"
    echo "  SLACK_WEBHOOK_URL    - Slack webhook for notifications"
    echo "  EMAIL_RECIPIENT      - Email address for critical alerts"
    exit 1
    ;;
  esac
fi
