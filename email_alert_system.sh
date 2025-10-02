#!/bin/bash

# Email Alerting System for Quantum Workspace Automation
# Provides email notifications for critical events, performance issues, and system alerts

set -euo pipefail

# Configuration
readonly CODE_DIR="${CODE_DIR:-/Users/danielstevens/Desktop/Quantum-workspace}"
readonly ALERT_CONFIG="${CODE_DIR}/Tools/Automation/config/alerting.yaml"
readonly ALERT_LOG="${CODE_DIR}/.alerts.log"

# Color codes
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly NC='\033[0m'

# Logging functions
print_status() { echo -e "${BLUE}[ALERT]${NC} $1"; }
print_success() { echo -e "${GREEN}✅ $1${NC}"; }
print_error() { echo -e "${RED}❌ $1${NC}"; }
print_warning() { echo -e "${YELLOW}⚠️  $1${NC}"; }

# Load alerting configuration
load_alert_config() {
  if [[ ! -f ${ALERT_CONFIG} ]]; then
    print_warning "Alert configuration not found: ${ALERT_CONFIG}"
    print_status "Creating default alert configuration..."

    cat >"${ALERT_CONFIG}" <<'EOF'
# Email Alerting Configuration for Quantum Workspace

alerting:
  enabled: true
  smtp_server: "smtp.gmail.com"
  smtp_port: 587
  smtp_username: ""  # Set your email
  smtp_password: ""  # Set your app password
  from_email: ""     # Set sender email
  to_emails:
    - ""            # Set recipient email

alert_types:
  critical_error:
    enabled: true
    subject: "🚨 CRITICAL: Quantum Workspace Automation Error"
    priority: high

  performance_degradation:
    enabled: true
    subject: "⚠️  WARNING: Performance Degradation Detected"
    priority: normal

  security_alert:
    enabled: true
    subject: "🔒 SECURITY: Potential Security Issue"
    priority: high

  build_failure:
    enabled: true
    subject: "❌ BUILD: Build Failure Detected"
    priority: normal

  system_health:
    enabled: false
    subject: "💊 HEALTH: System Health Report"
    priority: low

thresholds:
  performance_critical_ms: 300000  # 5 minutes
  performance_warning_ms: 120000   # 2 minutes
  error_rate_threshold: 0.05       # 5% error rate
  disk_space_warning_gb: 5         # 5GB free space warning

notification_settings:
  max_alerts_per_hour: 10
  cooldown_period_minutes: 15
  include_system_info: true
  include_logs: true
EOF

    print_success "Default alert configuration created at: ${ALERT_CONFIG}"
    print_warning "Please configure SMTP settings in: ${ALERT_CONFIG}"
    return 1
  fi

  # Load configuration values
  SMTP_SERVER=$(yq eval '.alerting.smtp_server' "${ALERT_CONFIG}" 2>/dev/null || echo "")
  SMTP_PORT=$(yq eval '.alerting.smtp_port' "${ALERT_CONFIG}" 2>/dev/null || echo "587")
  SMTP_USERNAME=$(yq eval '.alerting.smtp_username' "${ALERT_CONFIG}" 2>/dev/null || echo "")
  SMTP_PASSWORD=$(yq eval '.alerting.smtp_password' "${ALERT_CONFIG}" 2>/dev/null || echo "")
  FROM_EMAIL=$(yq eval '.alerting.from_email' "${ALERT_CONFIG}" 2>/dev/null || echo "")
  TO_EMAILS=$(yq eval '.alerting.to_emails[]' "${ALERT_CONFIG}" 2>/dev/null || echo "")

  return 0
}

# Send email alert
send_email_alert() {
  local subject="$1"
  local message="$2"
  local priority="${3:-normal}"

  # Check if alerting is enabled
  local enabled
  enabled=$(yq eval '.alerting.enabled' "${ALERT_CONFIG}" 2>/dev/null || echo "false")

  if [[ ${enabled} != "true" ]]; then
    print_status "Email alerting is disabled"
    return 0
  fi

  # Check SMTP configuration
  if [[ -z ${SMTP_SERVER} || -z ${SMTP_USERNAME} || -z ${SMTP_PASSWORD} || -z ${FROM_EMAIL} ]]; then
    print_warning "SMTP configuration incomplete. Please configure SMTP settings in: ${ALERT_CONFIG}"
    return 1
  fi

  # Check rate limiting
  check_rate_limit
  if [[ $? -eq 1 ]]; then
    print_warning "Alert rate limit exceeded. Skipping email alert."
    return 1
  fi

  print_status "Sending email alert: ${subject}"

  # Create email content
  local email_content
  email_content=$(create_email_content "${subject}" "${message}" "${priority}")

  # Send email using curl (works with most SMTP servers)
  local curl_result
  curl_result=$(curl --silent --show-error \
    --url "smtp://${SMTP_SERVER}:${SMTP_PORT}" \
    --mail-from "${FROM_EMAIL}" \
    --mail-rcpt "${TO_EMAILS}" \
    --user "${SMTP_USERNAME}:${SMTP_PASSWORD}" \
    --insecure \
    --upload-file <(echo "${email_content}") \
    2>&1)

  if send_email "${recipient}" "${subject}" "${message}"; then
    print_success "Email alert sent successfully"
    log_alert "${subject}" "sent"
    return 0
  else
    print_error "Failed to send email alert: ${curl_result}"
    log_alert "${subject}" "failed"
    return 1
  fi
}

# Create email content with proper MIME formatting
create_email_content() {
  local subject="$1"
  local message="$2"
  local priority="$3"

  local date_part
  date_part=$(date +%s)
  local rand_part
  rand_part=$(openssl rand -hex 16)
  local boundary="----=_NextPart_${date_part}_${rand_part}"
  local priority_header

  case "${priority}" in
  high) priority_header="1" ;;
  normal) priority_header="3" ;;
  low) priority_header="5" ;;
  *) priority_header="3" ;;
  esac

  cat <<EOF
From: ${FROM_EMAIL}
To: ${TO_EMAILS}
Subject: ${subject}
MIME-Version: 1.0
Content-Type: multipart/mixed; boundary="${boundary}"
X-Priority: ${priority_header}
X-Mailer: Quantum-Workspace-Automation

--${boundary}
Content-Type: text/plain; charset=UTF-8
Content-Transfer-Encoding: 7bit

${message}

--
Quantum Workspace Automation System
Generated: $(date)
System: $(hostname)

--${boundary}--
EOF
}

# Check rate limiting to prevent alert spam
check_rate_limit() {
  local max_alerts_per_hour
  max_alerts_per_hour=$(yq eval '.notification_settings.max_alerts_per_hour' "${ALERT_CONFIG}" 2>/dev/null || echo "10")

  local recent_alerts
  recent_alerts=$(grep "sent" "${ALERT_LOG}" 2>/dev/null | grep -c "$(date +%Y-%m-%dT%H)" || echo "0")

  if [[ ${recent_alerts} -ge ${max_alerts_per_hour} ]]; then
    return 1
  fi

  return 0
}

# Log alert activity
log_alert() {
  local subject="$1"
  local status="$2"

  echo "$(date '+%Y-%m-%d %H:%M:%S')|${status}|${subject}" >>"${ALERT_LOG}"
}

# Send performance alert
send_performance_alert() {
  local operation="$1"
  local duration_ms="$2"
  local threshold_ms="$3"

  local subject="⚠️  PERFORMAN${E:opera}tion exceeded threshold"
  local message
  message=$(
    cat <<EOF
Performance Alert Details:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Operation: ${operation}
Duration: $((duration_ms / 1000))s
Threshold: $((threshold_ms / 1000))s
Exceeded by: $(((duration_ms - threshold_ms) / 1000))s

System Information:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Timestamp: $(date)
Hostname: $(hostname)
Load Average: $(uptime | awk -F'load average:' '{ print $2 }' | xargs)
Disk Usage: $(df -h "${CODE_DIR}" | tail -1 | awk '{print $5}')

Recommendations:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Review recent changes that may have impacted performance
• Check system resources (CPU, memory, disk I/O)
• Consider optimizing the operation or increasing thresholds
• Monitor for recurring issues
EOF
  )

  send_email_alert "${subject}" "${message}" "normal"
}

# Send error alert
send_error_alert() {
  local error_type="$1"
  local error_message="$2"
  local project="${3-}"

  local subject="🚨 ${error_type} Error Detected"
  if [[ -n ${project} ]]; then
    subject="${subject} - ${project}"
  fi

  local message
  message=$(
    cat <<EOF
Critical Error Alert:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Error Type: ${error_type}
Project: ${project:-N/A}
Timestamp: $(date)

Error Details:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${error_message}

System Context:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Working Directory: $(pwd)
User: $(whoami)
Process ID: $$

Recent System Logs:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$(tail -10 /var/log/system.log 2>/dev/null || echo "System logs not accessible")

Immediate Actions Required:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Review error details and logs
2. Check system resources and connectivity
3. Verify recent changes or deployments
4. Consider rollback if system is unstable
5. Contact system administrator if needed
EOF
  )

  send_email_alert "${subject}" "${message}" "high"
}

# Send security alert
send_security_alert() {
  local issue_type="$1"
  local details="$2"

  local subject="🔒 SECURITY ALERT: ${issue_type}"
  local message
  message=$(
    cat <<EOF
Security Alert - Immediate Attention Required:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Issue Type: ${issue_type}
Severity: HIGH
Timestamp: $(date)

Security Details:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${details}

System Information:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Hostname: $(hostname)
IP Address: $(hostname -I | awk '{print $1}' || echo "Unknown")
Current User: $(whoami)

Recommended Actions:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. IMMEDIATELY review the security issue
2. Check for unauthorized access or changes
3. Verify integrity of critical files
4. Update security policies if needed
5. Consider system isolation if breach suspected
6. Contact security team immediately

This alert has been logged for audit purposes.
EOF
  )

  send_email_alert "${subject}" "${message}" "high"
}

# Send build failure alert
send_build_alert() {
  local project="$1"
  local build_type="$2"
  local error_details="$3"

  local subject="❌ BUILD FAILURE: ${project} ${build_type}"
  local message
  message=$(
    cat <<EOF
Build Failure Alert:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━

Project: ${project}
Build Type: ${build_type}
Timestamp: $(date)

Build Error Details:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
${error_details}

System Information:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Xcode Version: $(xcodebuild -version 2>/dev/null | head -1 || echo "Not available")
Swift Version: $(swift --version 2>/dev/null | head -1 || echo "Not available")
macOS Version: $(sw_vers -productVersion 2>/dev/null || echo "Not available")

Recent Git Commits:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
$(cd "${CODE_DIR}/Projects/${project}" 2>/dev/null && git log --oneline -5 2>/dev/null || echo "Git history not available")

Troubleshooting Steps:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
1. Clean build artifacts: rm -rf ~/Library/Developer/Xcode/DerivedData/*
2. Reset package caches: rm -rf ~/Library/Caches/org.swift.swiftpm
3. Check Xcode preferences and command line tools
4. Verify all dependencies are properly installed
5. Review recent code changes for syntax errors
EOF
  )

  send_email_alert "${subject}" "${message}" "normal"
}

# Test email configuration
test_email_config() {
  print_status "Testing email configuration..."

  local test_subject="🧪 TEST: Quantum Workspace Alert System"
  local test_message
  test_message=$(
    cat <<'EOF'
This is a test email from the Quantum Workspace Alert System.

If you received this email, the alerting system is properly configured!

Configuration Details:
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• SMTP Server: CONFIGURED
• Email Settings: VERIFIED
• Alert Types: ENABLED

The system will now send alerts for:
• Critical errors and failures
• Performance degradation
• Security issues
• Build failures

You can disable specific alert types in:
$CODE_DIR/Tools/Automation/config/alerting.yaml

Test completed successfully at: $(date)
EOF
  )

  if send_email_alert "${test_subject}" "${test_message}" "low"; then
    print_success "Email test sent successfully!"
    print_status "Check your inbox for the test email."
    return 0
  else
    print_error "Email test failed. Please check your configuration."
    return 1
  fi
}

# Show alert status and recent alerts
show_alert_status() {
  print_status "Email Alerting System Status"
  echo

  if [[ ! -f ${ALERT_CONFIG} ]]; then
    print_error "Alert configuration not found"
    return 1
  fi

  local enabled
  enabled=$(yq eval '.alerting.enabled' "${ALERT_CONFIG}" 2>/dev/null || echo "false")

  if [[ ${enabled} == "true" ]]; then
    print_success "Email alerting is ENABLED"
  else
    print_warning "Email alerting is DISABLED"
  fi

  echo
  print_status "SMTP Configuration:"
  echo "  Server: ${SMTP_SERVER:-NOT SET}"
  echo "  Port: ${SMTP_PORT:-587}"
  echo "  Username: ${SMTP_USERNAME:-NOT SET}"
  echo "  From: ${FROM_EMAIL:-NOT SET}"

  local recipient_count
  recipient_count=$(yq eval '.alerting.to_emails | length' "${ALERT_CONFIG}" 2>/dev/null || echo "0")
  echo "  Recipients: ${recipient_count} configured"

  echo
  print_status "Alert Types:"
  local alert_types=("critical_error" "performance_degradation" "security_alert" "build_failure" "system_health")

  for alert_type in "${alert_types[@]}"; do
    local enabled_status
    enabled_status=$(yq eval ".alert_types.${alert_type}.enabled" "${ALERT_CONFIG}" 2>/dev/null || echo "false")

    if [[ ${enabled_status} == "true" ]]; then
      echo -e "  ${GREEN}• ${alert_type}${NC}"
    else
      echo -e "  ${YELLOW}• ${alert_type} (disabled)${NC}"
    fi
  done

  echo
  print_status "Recent Alerts (last 10):"
  if [[ -f ${ALERT_LOG} ]]; then
    tail -10 "${ALERT_LOG}" | while IFS='|' read -r timestamp status subject; do
      if [[ ${status} == "sent" ]]; then
        echo -e "  ${GREEN}✅${NC} ${timestamp} - ${subject}"
      else
        echo -e "  ${RED}❌${NC} ${timestamp} - ${subject}"
      fi
    done
  else
    echo "  No alerts logged yet"
  fi
}

# Main function
main() {
  case "${1:-help}" in
  "test")
    load_alert_config && test_email_config
    ;;
  "status")
    load_alert_config && show_alert_status
    ;;
  "performance")
    if [[ $# -lt 4 ]]; then
      print_error "Usage: $0 performance <operation> <duration_ms> <threshold_ms>"
      exit 1
    fi
    load_alert_config && send_performance_alert "$2" "$3" "$4"
    ;;
  "error")
    if [[ $# -lt 3 ]]; then
      print_error "Usage: $0 error <error_type> <error_message> [project]"
      exit 1
    fi
    load_alert_config && send_error_alert "$2" "$3" "${4-}"
    ;;
  "security")
    if [[ $# -lt 3 ]]; then
      print_error "Usage: $0 security <issue_type> <details>"
      exit 1
    fi
    load_alert_config && send_security_alert "$2" "$3"
    ;;
  "build")
    if [[ $# -lt 4 ]]; then
      print_error "Usage: $0 build <project> <build_type> <error_details>"
      exit 1
    fi
    load_alert_config && send_build_alert "$2" "$3" "$4"
    ;;
  "config")
    if [[ ! -f ${ALERT_CONFIG} ]]; then
      load_alert_config
    else
      print_status "Alert configuration: ${ALERT_CONFIG}"
      echo "Edit this file to configure SMTP settings and alert preferences."
    fi
    ;;
  "help" | "-h" | "--help")
    cat <<'EOF'
Quantum Workspace Email Alerting System

Usage: alert_system.sh <command> [options]

Commands:
  test                    Send test email to verify configuration
  status                  Show alerting system status and recent alerts
  config                  Show/edit alert configuration file
  performance <op> <dur> <thresh>  Send performance alert
  error <type> <msg> [proj]         Send error alert
  security <type> <details>        Send security alert
  build <proj> <type> <details>    Send build failure alert

Examples:
  ./alert_system.sh test
  ./alert_system.sh status
  ./alert_system.sh performance "build_ios" 300000 120000
  ./alert_system.sh error "compilation" "Swift syntax error in ViewController.swift" "MyApp"
  ./alert_system.sh security "exposed_secret" "API key found in commit history"
  ./alert_system.sh build "MyApp" "iOS" "Undefined symbols for architecture arm64"

Configuration:
  Edit: $CODE_DIR/Tools/Automation/config/alerting.yaml
  Required: SMTP server, credentials, and recipient emails

EOF
    ;;
  *)
    print_error "Unknown command: ${1-}"
    echo "Use '$0 help' for usage information"
    exit 1
    ;;
  esac
}

# Load configuration and run main function
load_alert_config
main "$@"
