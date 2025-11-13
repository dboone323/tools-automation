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

AGENT_NAME="audit_agent.sh"
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
# Audit Trail Agent: Implements comprehensive audit trails and logging

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

# Agent throttling configuration
MAX_CONCURRENCY="${MAX_CONCURRENCY:-2}" # Maximum concurrent instances of this agent
LOAD_THRESHOLD="${LOAD_THRESHOLD:-8.0}" # System load threshold (1.0 = 100% on single core)
WAIT_WHEN_BUSY="${WAIT_WHEN_BUSY:-30}"  # Seconds to wait when system is busy

# Function to check if we should proceed with task processing
ensure_within_limits() {
    local agent_name="audit_agent.sh"

    # Check concurrent instances
    local running_count=$(pgrep -f "${agent_name}" | wc -l)
    if [[ ${running_count} -gt ${MAX_CONCURRENCY} ]]; then
        log "Too many concurrent instances (${running_count}/${MAX_CONCURRENCY}). Waiting..."
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
        log "System load too high (${load_avg} >= ${LOAD_THRESHOLD}). Waiting..."
        return 1
    fi

    return 0
}

AGENT_NAME="audit_agent.sh"
WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
LOG_FILE="${WORKSPACE}/Tools/Automation/agents/audit_agent.log"
NOTIFICATION_FILE="${WORKSPACE}/Tools/Automation/agents/communication/${AGENT_NAME}_notification.txt"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/Tools/Automation/agents/task_queue.json"
OLLAMA_ENDPOINT="http://localhost:11434"
AUDIT_LOG_DIR="${WORKSPACE}/Tools/Automation/audit_logs"
AUDIT_CONFIG_FILE="${WORKSPACE}/Tools/Automation/config/audit_config.json"

# Logging function
log() {
    echo "[$(date)] ${AGENT_NAME}: $*" >>"${LOG_FILE}"
}

# Ollama Integration Functions
ollama_query() {
    local prompt="$1"
    local model="${2:-codellama}"

    curl -s -X POST "${OLLAMA_ENDPOINT}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"${model}\", \"prompt\": \"${prompt}\", \"stream\": false}" |
        jq -r '.response // empty'
}

# Update agent status to available when starting
update_status() {
    local status="$1"
    if command -v jq &>/dev/null; then
        jq "(.[] | select(.id == \"${AGENT_NAME}\") | .status) = \"${status}\" | (.[] | select(.id == \"${AGENT_NAME}\") | .last_seen) = $(date +%s)" "${AGENT_STATUS_FILE}" >"${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "${AGENT_STATUS_FILE}"
    fi
    echo "[$(date)] ${AGENT_NAME}: Status updated to ${status}" >>"${LOG_FILE}"
}

# Process a specific task
process_task() {
    local task_id="$1"
    echo "[$(date)] ${AGENT_NAME}: Processing task ${task_id}" >>"${LOG_FILE}"

    # Get task details
    if command -v jq &>/dev/null; then
        local task_desc
        task_desc=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .description" "${TASK_QUEUE_FILE}")
        local task_type
        task_type=$(jq -r ".tasks[] | select(.id == \"${task_id}\") | .type" "${TASK_QUEUE_FILE}")
        echo "[$(date)] ${AGENT_NAME}: Task description: ${task_desc}" >>"${LOG_FILE}"
        echo "[$(date)] ${AGENT_NAME}: Task type: ${task_type}" >>"${LOG_FILE}"

        # Process based on task type
        case "${task_type}" in
        "audit" | "audit_trail" | "logging")
            run_audit_analysis "${task_desc}"
            ;;
        *)
            echo "[$(date)] ${AGENT_NAME}: Unknown task type: ${task_type}" >>"${LOG_FILE}"
            ;;
        esac

        # Mark task as completed
        update_task_status "${task_id}" "completed"
    increment_task_count "${AGENT_NAME}"
        echo "[$(date)] ${AGENT_NAME}: Task ${task_id} completed" >>"${LOG_FILE}"
    fi
}

# Update task status
update_task_status() {
    local task_id="$1"
    local status="$2"
    if command -v jq &>/dev/null; then
        jq "(.tasks[] | select(.id == \"${task_id}\") | .status) = \"${status}\"" "${TASK_QUEUE_FILE}" >"${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "${TASK_QUEUE_FILE}"
    fi
}

# Initialize audit configuration
initialize_audit_config() {
    log "Initializing audit configuration..."

    mkdir -p "${AUDIT_LOG_DIR}"
    mkdir -p "${WORKSPACE}/Tools/Automation/config"

    # Create default audit configuration
    cat >"${AUDIT_CONFIG_FILE}" <<EOF
{
  "audit_levels": {
    "critical": ["authentication", "authorization", "data_access", "security_events"],
    "high": ["user_actions", "data_modification", "system_changes"],
    "medium": ["read_operations", "navigation", "ui_interactions"],
    "low": ["debug_info", "performance_metrics"]
  },
  "retention_policy": {
    "critical_logs": "7_years",
    "high_logs": "2_years",
    "medium_logs": "1_year",
    "low_logs": "6_months"
  },
  "encryption": {
    "enabled": true,
    "algorithm": "AES256",
    "key_rotation_days": 90
  },
  "monitoring": {
    "alert_on_critical": true,
    "alert_on_high": true,
    "log_anomalies": true,
    "performance_thresholds": {
      "max_response_time": 5000,
      "max_memory_usage": 100000000,
      "max_error_rate": 0.05
    }
  },
  "compliance": {
    "gdpr_enabled": true,
    "sox_enabled": false,
    "hipaa_enabled": false,
    "pci_dss_enabled": false
  }
}
EOF

    log "Audit configuration initialized"
}

# Log audit event
log_audit_event() {
    local event_type="$1"
    local severity="$2"
    local user_id="${3:-system}"
    local resource="$4"
    local action="$5"
    local details="${6:-}"
    local ip_address="${7:-localhost}"
    local session_id="${8:-}"

    local timestamp
    timestamp=$(date +%Y%m%d_%H%M%S)
    local log_date
    log_date=$(date +%Y-%m-%d)
    local log_file="${AUDIT_LOG_DIR}/audit_${log_date}.log"

    # Create log entry
    local log_entry
    log_entry=$(jq -n \
        --arg timestamp "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
        --arg event_type "$event_type" \
        --arg severity "$severity" \
        --arg user_id "$user_id" \
        --arg resource "$resource" \
        --arg action "$action" \
        --arg details "$details" \
        --arg ip_address "$ip_address" \
        --arg session_id "$session_id" \
        --arg agent "$AGENT_NAME" \
        '{
      timestamp: $timestamp,
      event_type: $event_type,
      severity: $severity,
      user_id: $user_id,
      resource: $resource,
      action: $action,
      details: $details,
      ip_address: $ip_address,
      session_id: $session_id,
      agent: $agent
    }')

    # Encrypt log entry if encryption is enabled
    if [[ $(jq -r '.encryption.enabled' "${AUDIT_CONFIG_FILE}") == "true" ]]; then
        # For now, just base64 encode (in production, use proper encryption)
        local encrypted_entry
        encrypted_entry=$(echo "${log_entry}" | base64)
        echo "${encrypted_entry}" >>"${log_file}"
    else
        echo "${log_entry}" >>"${log_file}"
    fi

    # Check if alert is needed
    check_audit_alerts "${severity}" "${event_type}" "${log_entry}"

    log "Audit event logged: ${event_type} - ${severity} - ${action}"
}

# Check for audit alerts
check_audit_alerts() {
    local severity="$1"
    local event_type="$2"
    local log_entry="$3"

    local alert_needed=false

    case "${severity}" in
    "critical")
        if [[ $(jq -r '.monitoring.alert_on_critical' "${AUDIT_CONFIG_FILE}") == "true" ]]; then
            alert_needed=true
        fi
        ;;
    "high")
        if [[ $(jq -r '.monitoring.alert_on_high' "${AUDIT_CONFIG_FILE}") == "true" ]]; then
            alert_needed=true
        fi
        ;;
    esac

    if [[ ${alert_needed} == true ]]; then
        log "ALERT: ${severity} audit event detected - ${event_type}"
        # In production, this would send alerts to monitoring systems
        echo "[ALERT] ${log_entry}" >>"${AUDIT_LOG_DIR}/alerts.log"
    fi
}

# Analyze code for audit trail implementation
analyze_audit_implementation() {
    local project="$1"
    log "Analyzing audit trail implementation in ${project}..."

    cd "${WORKSPACE}/Projects/${project}" || return

    local audit_findings=""
    local audit_score=0

    # Check for logging frameworks
    local logging_usage
    logging_usage=$(find . -name "*.swift" -exec grep -lE "(NSLog|print|log|Logger|OSLog)" {} \; | wc -l)
    audit_findings+="Logging Framework Usage: ${logging_usage} files\n"

    # Check for audit-specific logging
    local audit_logging
    audit_logging=$(find . -name "*.swift" -exec grep -lE "(audit|Audit|logEvent|track)" {} \; | wc -l)
    audit_findings+="Audit-Specific Logging: ${audit_logging} files\n"

    # Check for user action tracking
    local user_tracking
    user_tracking=$(find . -name "*.swift" -exec grep -lE "(userAction|trackUser|analytics)" {} \; | wc -l)
    audit_findings+="User Action Tracking: ${user_tracking} files\n"

    # Check for error logging
    local error_logging
    error_logging=$(find . -name "*.swift" -exec grep -lE "(error|Error|exception|Exception)" {} \; | wc -l)
    audit_findings+="Error Logging: ${error_logging} files\n"

    # Check for security event logging
    local security_logging
    security_logging=$(find . -name "*.swift" -exec grep -lE "(security|Security|auth|Auth)" {} \; | wc -l)
    audit_findings+="Security Event Logging: ${security_logging} files\n"

    # Calculate audit implementation score
    audit_score=$((logging_usage + audit_logging * 2 + user_tracking * 2 + error_logging + security_logging * 3))

    # Use Ollama for audit implementation analysis
    local audit_prompt="Analyze this Swift application for audit trail implementation:

Project: ${project}
Logging Usage: ${logging_usage} files
Audit Logging: ${audit_logging} files
User Tracking: ${user_tracking} files
Error Logging: ${error_logging} files
Security Logging: ${security_logging} files

Evaluate audit trail implementation and provide recommendations for:
1. Comprehensive audit logging coverage
2. Security event tracking
3. User action monitoring
4. Data access auditing
5. Compliance logging requirements
6. Log retention and archiving
7. Log encryption and protection

Provide specific implementation recommendations."

    local audit_analysis
    audit_analysis=$(ollama_query "${audit_prompt}")

    if [[ -n "${audit_analysis}" ]]; then
        audit_findings+="\n=== AI Audit Analysis ===\n${audit_analysis}\n"
    fi

    # Save audit analysis results
    local audit_file="${WORKSPACE}/Tools/Automation/results/${project}_audit_analysis.txt"

    {
        echo "Audit Trail Implementation Analysis"
        echo "Project: ${project}"
        echo "Analysis Date: $(date)"
        echo "Audit Implementation Score: ${audit_score}"
        echo "========================================"
        echo ""
        echo "${audit_findings}"
        echo ""
        echo "========================================"
    } >"${audit_file}"

    log "Audit analysis completed for ${project}, score: ${audit_score}"
}

# Generate audit trail patterns for Swift code
generate_audit_patterns() {
    local project="$1"
    log "Generating audit trail patterns for ${project}..."

    local patterns_file="${WORKSPACE}/Tools/Automation/results/${project}_audit_patterns.txt"

    # Use Ollama to generate audit patterns
    local pattern_prompt="Generate comprehensive audit trail implementation patterns for a Swift iOS application:

Project: ${project}

Create audit logging patterns for:
1. User authentication events
2. Data access and modification
3. Security-sensitive operations
4. Error and exception handling
5. User action tracking
6. Compliance logging

Include:
- Audit event types and severity levels
- Structured logging format
- Log encryption patterns
- Compliance-specific logging
- Performance monitoring logs
- Privacy-preserving audit data

Provide complete Swift code examples with proper error handling and security considerations."

    local audit_patterns
    audit_patterns=$(ollama_query "${pattern_prompt}")

    {
        echo "Audit Trail Implementation Patterns"
        echo "Generated for ${project} on $(date)"
        echo "Phase 6 Security Framework Implementation"
        echo ""
        echo "AI-Generated Audit Implementation Guide:"
        echo "========================================"
        echo ""
        if [[ -n "${audit_patterns}" ]]; then
            echo "${audit_patterns}"
        else
            echo "AI generation failed - implement manual audit logging framework"
            echo ""
            echo "Recommended Implementation:"
            echo "1. Create AuditLogger class with OSLog integration"
            echo "2. Define AuditEventType and AuditSeverity enums"
            echo "3. Implement structured logging with JSON format"
            echo "4. Add encryption for sensitive audit data"
            echo "5. Include compliance logging for GDPR/SOX requirements"
            echo "6. Add monitoring and alerting for critical events"
        fi
        echo ""
        echo "========================================"
        echo "Generated by Audit Agent - Phase 6 Security Framework"
    } >"${patterns_file}"

    log "Audit patterns generated: ${patterns_file}"
}

# Run comprehensive audit analysis
run_audit_analysis() {
    local task_desc="$1"
    log "Running comprehensive audit analysis for: ${task_desc}"

    # Initialize audit configuration if needed
    if [[ ! -f "${AUDIT_CONFIG_FILE}" ]]; then
        initialize_audit_config
    fi

    # Extract project name from task description
    local projects=("CodingReviewer" "MomentumFinance" "HabitQuest" "PlannerApp" "AvoidObstaclesGame")

    for project in "${projects[@]}"; do
        if [[ -d "${WORKSPACE}/Projects/${project}" ]]; then
            log "Running audit analysis for ${project}..."

            # Log the audit analysis start
            log_audit_event "audit_analysis" "info" "system" "${project}" "analysis_started" "Starting comprehensive audit analysis"

            # Analyze current audit implementation
            analyze_audit_implementation "${project}"

            # Generate audit trail patterns
            generate_audit_patterns "${project}"

            # Generate audit compliance report
            generate_audit_compliance_report "${project}"

            # Log completion
            log_audit_event "audit_analysis" "info" "system" "${project}" "analysis_completed" "Audit analysis completed successfully"
        fi
    done

    log "Comprehensive audit analysis completed"
}

# Generate audit compliance report
generate_audit_compliance_report() {
    local project="$1"
    log "Generating audit compliance report for ${project}..."

    local report_file="${WORKSPACE}/Tools/Automation/results/${project}_audit_compliance_report.md"

    {
        echo "# Audit Trail Compliance Report"
        echo "**Project:** ${project}"
        echo "**Report Date:** $(date)"
        echo "**Framework:** Phase 6 Security Implementation"
        echo ""
        echo "## Executive Summary"
        echo ""
        echo "Comprehensive audit trail implementation assessment and compliance evaluation."
        echo ""
        echo "## Current Audit Implementation Status"
        echo ""
        echo "### Logging Coverage"
        echo "- [ ] Authentication events logged"
        echo "- [ ] Authorization decisions tracked"
        echo "- [ ] Data access operations audited"
        echo "- [ ] Data modification events logged"
        echo "- [ ] Security events monitored"
        echo "- [ ] Error conditions tracked"
        echo ""
        echo "### Audit Trail Quality"
        echo "- [ ] Structured logging implemented"
        echo "- [ ] Log encryption enabled"
        echo "- [ ] Log integrity protection"
        echo "- [ ] Log retention policies defined"
        echo "- [ ] Log monitoring and alerting"
        echo ""
        echo "## Compliance Requirements"
        echo ""
        echo "### GDPR Compliance"
        echo "- [ ] Data processing activities logged"
        echo "- [ ] User consent events tracked"
        echo "- [ ] Data subject access requests logged"
        echo "- [ ] Data breach incidents recorded"
        echo "- [ ] Data deletion operations audited"
        echo ""
        echo "### Security Standards"
        echo "- [ ] Access control events logged"
        echo "- [ ] Privileged operations monitored"
        echo "- [ ] Security configuration changes tracked"
        echo "- [ ] Failed authentication attempts logged"
        echo "- [ ] Suspicious activity detection"
        echo ""
        echo "## Implementation Recommendations"
        echo ""
        echo "### Immediate Actions (Critical)"
        echo "- Implement comprehensive audit logging framework"
        echo "- Add authentication event tracking"
        echo "- Enable log encryption and integrity protection"
        echo "- Define log retention and archiving policies"
        echo ""
        echo "### Short-term (Next Sprint)"
        echo "- Add GDPR compliance logging"
        echo "- Implement security event monitoring"
        echo "- Add audit log monitoring and alerting"
        echo "- Create audit log review procedures"
        echo ""
        echo "### Long-term (Future Releases)"
        echo "- Implement automated compliance reporting"
        echo "- Add audit log analytics and insights"
        echo "- Integrate with SIEM systems"
        echo "- Implement real-time audit monitoring"
        echo ""
        echo "## Audit Log Storage Requirements"
        echo ""
        echo "### Storage Security"
        echo "- Encrypted storage with access controls"
        echo "- Log integrity verification (hashing)"
        echo "- Tamper-evident log formats"
        echo "- Secure backup and recovery procedures"
        echo ""
        echo "### Retention Policies"
        echo "- Critical security events: 7 years"
        echo "- User activity logs: 2 years"
        echo "- System operation logs: 1 year"
        echo "- Debug logs: 6 months"
        echo ""
        echo "## Monitoring and Alerting"
        echo ""
        echo "### Alert Conditions"
        echo "- Critical security events"
        echo "- Audit log tampering attempts"
        echo "- Log storage failures"
        echo "- Compliance violations"
        echo ""
        echo "### Monitoring Metrics"
        echo "- Log volume and growth rate"
        echo "- Failed logging attempts"
        echo "- Audit log access patterns"
        echo "- Compliance reporting status"
        echo ""
        echo "---"
        echo "*Generated by Audit Trail Agent - Phase 6 Security Framework*"
    } >"${report_file}"

    log "Audit compliance report generated: ${report_file}"
}

# Main agent loop
echo "[$(date)] ${AGENT_NAME}: Starting audit trail agent..." >>"${LOG_FILE}"
update_status "available"

# Track processed tasks to avoid duplicates
processed_tasks_file="${WORKSPACE}/Tools/Automation/agents/${AGENT_NAME}_processed_tasks.txt"
touch "${processed_tasks_file}"

# Check for command-line arguments (direct execution mode)
if [[ $# -gt 0 ]]; then
    case "$1" in
    "run_audit" | "audit_compliance_check")
        log "Direct execution mode: running audit compliance check"
        update_status "busy"
        run_audit_analysis "Comprehensive compliance audit for all projects"
        update_status "available"
        log "Direct execution completed"
        exit 0
        ;;
    *)
        log "Unknown command: $1"
        exit 1
        ;;
    esac
fi

while true; do
    # Check if we should proceed (throttling)
    if ! ensure_within_limits; then
        # Wait when busy, with exponential backoff
        wait_time=${WAIT_WHEN_BUSY}
        attempts=0
        while ! ensure_within_limits && [[ ${attempts} -lt 10 ]]; do
            log "Waiting ${wait_time}s before retry (attempt $((attempts + 1))/10)"
            sleep "${wait_time}"
            wait_time=$((wait_time * 2))                          # Exponential backoff
            if [[ ${wait_time} -gt 300 ]]; then wait_time=300; fi # Cap at 5 minutes
            ((attempts++))
        done

        # If still busy after retries, skip this cycle
        if ! ensure_within_limits; then
            log "System still busy after retries. Skipping cycle."
            sleep 60
            continue
        fi
    fi

    # Check for new task notifications
    if [[ -f ${NOTIFICATION_FILE} ]]; then
        while IFS='|' read -r _ action task_id; do
            if [[ ${action} == "execute_task" && -z $(grep "^${task_id}$" "${processed_tasks_file}") ]]; then
                update_status "busy"
                process_task "${task_id}"
                update_status "available"
                echo "${task_id}" >>"${processed_tasks_file}"
                echo "[$(date)] ${AGENT_NAME}: Marked task ${task_id} as processed" >>"${LOG_FILE}"
            fi
        done <"${NOTIFICATION_FILE}"

        # Clear processed notifications to prevent re-processing
        true >"${NOTIFICATION_FILE}"
    fi

    # Update last seen timestamp
    update_status "available"

    sleep 30 # Check every 30 seconds
done
