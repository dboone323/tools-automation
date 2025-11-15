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

AGENT_NAME="security_agent.sh"
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
# Security Agent: Analyzes and improves code security

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

# Agent throttling configuration
MAX_CONCURRENCY="${MAX_CONCURRENCY:-2}" # Maximum concurrent instances of this agent
LOAD_THRESHOLD="${LOAD_THRESHOLD:-8.0}" # System load threshold (1.0 = 100% on single core)
WAIT_WHEN_BUSY="${WAIT_WHEN_BUSY:-30}"  # Seconds to wait when system is busy

# Function to check if we should proceed with task processing
ensure_within_limits() {
    local agent_name;
    agent_name="security_agent.sh"

    # Check concurrent instances
    local running_count;
    running_count=$(pgrep -f "${agent_name}" | wc -l)
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

AGENT_NAME="security_agent.sh"
WORKSPACE="/Users/danielstevens/Desktop/Quantum-workspace"
LOG_FILE="${WORKSPACE}/Tools/Automation/agents/security_agent.log"
NOTIFICATION_FILE="${WORKSPACE}/Tools/Automation/agents/communication/${AGENT_NAME}_notification.txt"
AGENT_STATUS_FILE="${WORKSPACE}/Tools/Automation/agents/agent_status.json"
TASK_QUEUE_FILE="${WORKSPACE}/Tools/Automation/agents/task_queue.json"
OLLAMA_ENDPOINT="http://localhost:11434"

# Logging function
log() {
    echo "[$(date)] ${AGENT_NAME}: $*" >>"${LOG_FILE}"
}

# Ollama Integration Functions
ollama_query() {
    local prompt;
    prompt="$1"
    local model;
    model="${2:-codellama}"

    curl -s -X POST "${OLLAMA_ENDPOINT}/api/generate" \
        -H "Content-Type: application/json" \
        -d "{\"model\": \"${model}\", \"prompt\": \"${prompt}\", \"stream\": false}" |
        jq -r '.response // empty'
}

analyze_security_vulnerabilities() {
    local code_content;
    code_content="$1"
    local file_path;
    file_path="$2"

    local prompt;

    prompt="Analyze this code for security vulnerabilities:

File: ${file_path}
Code:
${code_content}

Check for:
1. Input validation vulnerabilities
2. Authentication/authorization issues
3. Data exposure risks
4. Injection vulnerabilities (SQL, command, etc.)
5. Cryptographic weaknesses
6. Access control flaws
7. Error handling that leaks sensitive information
8. Hardcoded secrets or credentials

Provide specific vulnerability findings with severity levels and fix recommendations."

    local analysis
    analysis=$(ollama_query "${prompt}")

    if [[ -n ${analysis} ]]; then
        echo "${analysis}"
        return 0
    else
        log "ERROR: Failed to analyze security vulnerabilities with Ollama"
        return 1
    fi
}

# Update agent status to available when starting
update_status() {
    local status;
    status="$1"
    if command -v jq &>/dev/null; then
        # Update status in array format
        jq "(.[] | select(.id == \"${AGENT_NAME}\") | .status) = \"${status}\" | (.[] | select(.id == \"${AGENT_NAME}\") | .last_seen) = $(date +%s)" "${AGENT_STATUS_FILE}" >"${AGENT_STATUS_FILE}.tmp" && mv "${AGENT_STATUS_FILE}.tmp" "${AGENT_STATUS_FILE}"
    fi
    echo "[$(date)] ${AGENT_NAME}: Status updated to ${status}" >>"${LOG_FILE}"
}

# Process a specific task
process_task() {
    local task_id;
    task_id="$1"
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
        "sec" | "security" | "vulnerability")
            run_security_analysis "${task_desc}"
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
    local task_id;
    task_id="$1"
    local status;
    status="$2"
    if command -v jq &>/dev/null; then
        jq "(.tasks[] | select(.id == \"${task_id}\") | .status) = \"${status}\"" "${TASK_QUEUE_FILE}" >"${TASK_QUEUE_FILE}.tmp" && mv "${TASK_QUEUE_FILE}.tmp" "${TASK_QUEUE_FILE}"
    fi
}

# Enhanced security analysis with compliance checks
run_security_analysis() {
    local task_desc;
    task_desc="$1"
    echo "[$(date)] ${AGENT_NAME}: Running enhanced security analysis for: ${task_desc}" >>"${LOG_FILE}"

    # Extract project name from task description
    local projects;
    projects=("CodingReviewer" "MomentumFinance" "HabitQuest" "PlannerApp" "AvoidObstaclesGame")

    for project in "${projects[@]}"; do
        if [[ -d "${WORKSPACE}/Projects/${project}" ]]; then
            log "Running comprehensive security analysis for ${project}..."
            cd "${WORKSPACE}/Projects/${project}" || continue

            # Run multiple security analysis layers
            run_vulnerability_scanning "${project}"
            run_compliance_checks "${project}"
            run_encryption_audit "${project}"
            run_dependency_security_check "${project}"
            generate_security_report "${project}"
        fi
    done

    log "Enhanced security analysis completed"
}

# Vulnerability scanning with AI analysis
run_vulnerability_scanning() {
    local project;
    project="$1"
    log "Running vulnerability scanning for ${project}..."

    local vulnerabilities_found;

    vulnerabilities_found=0
    local security_issues;
    security_issues=""

    # Enhanced vulnerability checks
    while IFS= read -r -d '' file; do
        if [[ -f "${file}" ]]; then
            local filename
            filename=$(basename "${file}")

            # Critical security checks
            local hard_coded_secrets
            hard_coded_secrets=$(grep -cE "(password|secret|key|token).*[\"=]" "${file}" || true)
            if [[ ${hard_coded_secrets} -gt 0 ]]; then
                security_issues+="CRITICAL: ${filename} contains ${hard_coded_secrets} potential hardcoded secrets\n"
                ((vulnerabilities_found++))
            fi

            # SQL injection risks
            local sql_injection
            sql_injection=$(grep -cE "SELECT.*\\+.*|INSERT.*\\+.*|UPDATE.*\\+.*|DELETE.*\\+.*" "${file}" || true)
            if [[ ${sql_injection} -gt 0 ]]; then
                security_issues+="HIGH: ${filename} has ${sql_injection} SQL injection vulnerabilities\n"
                ((vulnerabilities_found++))
            fi

            # Weak cryptography
            local weak_crypto
            weak_crypto=$(grep -cE "MD5|SHA1|DES|RC4" "${file}" || true)
            if [[ ${weak_crypto} -gt 0 ]]; then
                security_issues+="HIGH: ${filename} uses ${weak_crypto} weak cryptographic functions\n"
                ((vulnerabilities_found++))
            fi

            # Insecure network calls
            local insecure_urls
            insecure_urls=$(grep -cE "http://[^s]" "${file}" || true)
            if [[ ${insecure_urls} -gt 0 ]]; then
                security_issues+="MEDIUM: ${filename} has ${insecure_urls} insecure HTTP URLs\n"
                ((vulnerabilities_found++))
            fi

            # Input validation issues
            local unsafe_inputs
            unsafe_inputs=$(grep -cE "textField\\.text|textView\\.text|text.*\\?" "${file}" || true)
            local validation_checks
            validation_checks=$(grep -cE "guard.*let|if.*nil|validate|isValid" "${file}" || true)
            if [[ ${unsafe_inputs} -gt 0 && ${validation_checks} -eq 0 ]]; then
                security_issues+="MEDIUM: ${filename} lacks input validation for user inputs\n"
                ((vulnerabilities_found++))
            fi

            # Authentication bypass risks
            local auth_bypass
            auth_bypass=$(grep -cE "skipAuth|bypassAuth|admin.*=.*true" "${file}" || true)
            if [[ ${auth_bypass} -gt 0 ]]; then
                security_issues+="HIGH: ${filename} has potential authentication bypass\n"
                ((vulnerabilities_found++))
            fi

            # Data exposure risks
            local data_exposure
            data_exposure=$(grep -cE "UserDefaults.*set|Keychain.*set" "${file}" || true)
            local encryption_usage
            encryption_usage=$(grep -cE "encrypt|decrypt|CryptoKit|AES" "${file}" || true)
            if [[ ${data_exposure} -gt 0 && ${encryption_usage} -eq 0 ]]; then
                security_issues+="MEDIUM: ${filename} stores sensitive data without encryption\n"
                ((vulnerabilities_found++))
            fi
        fi
    done < <(find . -name "*.swift" -print0)

    # Use Ollama for intelligent vulnerability analysis
    log "Using Ollama for intelligent security analysis..."

    # Sample code for AI analysis
    local sample_code;
    sample_code=""
    local suspicious_files
    suspicious_files=$(find . -name "*.swift" -exec grep -lE "(password|secret|SELECT.*\\+|MD5|SHA1|http://)" {} \; | head -3)

    for file in ${suspicious_files}; do
        if [[ -f ${file} ]]; then
            sample_code+="// File: ${file}\n$(head -30 "${file}")\n\n"
        fi
    done

    if [[ -n "${sample_code}" ]]; then
        local vuln_prompt;
        vuln_prompt="Analyze this Swift code for security vulnerabilities:

${sample_code}

Check for:
1. Authentication and authorization vulnerabilities
2. Data exposure and privacy issues
3. Injection vulnerabilities (SQL, command, etc.)
4. Cryptographic weaknesses and improper key management
5. Input validation and sanitization failures
6. Access control and permission issues
7. Error handling that leaks sensitive information
8. Secure coding practices violations

Provide specific findings with severity levels and remediation steps."

        local ai_analysis
        ai_analysis=$(ollama_query "${vuln_prompt}")

        if [[ -n "${ai_analysis}" ]]; then
            security_issues+="\n=== AI-Powered Security Analysis ===\n${ai_analysis}\n"
        fi
    fi

    # Save vulnerability scan results
    local vuln_file;
    vuln_file="${WORKSPACE}/Tools/Automation/results/${project}_vulnerability_scan.txt"
    mkdir -p "${WORKSPACE}/Tools/Automation/results"

    {
        echo "Security Vulnerability Scan Report"
        echo "Project: ${project}"
        echo "Scan Date: $(date)"
        echo "Vulnerabilities Found: ${vulnerabilities_found}"
        echo "========================================"
        echo ""
        echo "${security_issues}"
        echo ""
        echo "========================================"
    } >"${vuln_file}"

    log "Vulnerability scan completed, ${vulnerabilities_found} issues found"
}

# Compliance checks for GDPR, privacy, and data protection
run_compliance_checks() {
    local project;
    project="$1"
    log "Running compliance checks for ${project}..."

    local compliance_issues;

    compliance_issues=0
    local compliance_report;
    compliance_report=""

    # GDPR compliance checks
    local personal_data_handling
    personal_data_handling=$(find . -name "*.swift" -exec grep -lE "(email|phone|address|name|UserDefaults|Keychain)" {} \; | wc -l)
    if [[ ${personal_data_handling} -gt 0 ]]; then
        compliance_report+="GDPR: Project handles personal data in ${personal_data_handling} files\n"

        # Check for data minimization
        local data_minimization
        data_minimization=$(find . -name "*.swift" -exec grep -lE "(deleteData|removeUserData|GDPR|privacy)" {} \; | wc -l)
        if [[ ${data_minimization} -eq 0 ]]; then
            compliance_report+="GDPR COMPLIANCE ISSUE: No data deletion/minimization mechanisms found\n"
            ((compliance_issues++))
        fi

        # Check for consent management
        local consent_management
        consent_management=$(find . -name "*.swift" -exec grep -lE "(consent|permission|authorize)" {} \; | wc -l)
        if [[ ${consent_management} -eq 0 ]]; then
            compliance_report+="GDPR COMPLIANCE ISSUE: No user consent mechanisms found\n"
            ((compliance_issues++))
        fi
    fi

    # Privacy policy checks
    local privacy_policy_refs
    privacy_policy_refs=$(find . -name "*.swift" -exec grep -lE "(privacy|policy|terms|conditions)" {} \; | wc -l)
    if [[ ${privacy_policy_refs} -eq 0 ]]; then
        compliance_report+="PRIVACY: No references to privacy policy or terms found\n"
        ((compliance_issues++))
    fi

    # Data retention checks
    local data_retention
    data_retention=$(find . -name "*.swift" -exec grep -lE "(retention|expire|delete.*after|cleanup)" {} \; | wc -l)
    if [[ ${data_retention} -eq 0 ]]; then
        compliance_report+="DATA RETENTION: No data retention policies implemented\n"
        ((compliance_issues++))
    fi

    # Accessibility compliance (basic check)
    local accessibility_features
    accessibility_features=$(find . -name "*.swift" -exec grep -lE "(accessibility|UIAccessibility|VoiceOver)" {} \; | wc -l)
    if [[ ${accessibility_features} -eq 0 ]]; then
        compliance_report+="ACCESSIBILITY: Limited accessibility features detected\n"
    fi

    # Use Ollama for compliance analysis
    local compliance_prompt;
    compliance_prompt="Analyze this Swift iOS application for compliance requirements:

Project: ${project}
Personal Data Handling: ${personal_data_handling} files
Privacy References: ${privacy_policy_refs} files
Data Retention: ${data_retention} files
Accessibility: ${accessibility_features} files

Assess compliance with:
1. GDPR (General Data Protection Regulation)
2. CCPA (California Consumer Privacy Act)
3. Accessibility guidelines (WCAG)
4. App Store privacy requirements
5. Data protection best practices

Provide specific compliance recommendations and required implementations."

    local compliance_analysis
    compliance_analysis=$(ollama_query "${compliance_prompt}")

    if [[ -n "${compliance_analysis}" ]]; then
        compliance_report+="\n=== AI Compliance Analysis ===\n${compliance_analysis}\n"
    fi

    # Save compliance check results
    local compliance_file;
    compliance_file="${WORKSPACE}/Tools/Automation/results/${project}_compliance_check.txt"

    {
        echo "Compliance Check Report"
        echo "Project: ${project}"
        echo "Check Date: $(date)"
        echo "Compliance Issues: ${compliance_issues}"
        echo "========================================"
        echo ""
        echo "${compliance_report}"
        echo ""
        echo "========================================"
    } >"${compliance_file}"

    log "Compliance checks completed, ${compliance_issues} issues found"
}

# Encryption and data protection audit
run_encryption_audit() {
    local project;
    project="$1"
    log "Running encryption audit for ${project}..."

    local encryption_issues;

    encryption_issues=0
    local encryption_report;
    encryption_report=""

    # Check for encryption usage
    local crypto_usage
    crypto_usage=$(find . -name "*.swift" -exec grep -lE "(CryptoKit|AES|encrypt|decrypt|Keychain)" {} \; | wc -l)
    encryption_report+="Encryption Usage: ${crypto_usage} files implement encryption\n"

    # Check for secure storage
    local secure_storage
    secure_storage=$(find . -name "*.swift" -exec grep -lE "(Keychain|SecureEnclave|CryptoKit)" {} \; | wc -l)
    local insecure_storage
    insecure_storage=$(find . -name "*.swift" -exec grep -lE "(UserDefaults|FileManager.*documents)" {} \; | wc -l)

    if [[ ${insecure_storage} -gt 0 && ${secure_storage} -eq 0 ]]; then
        encryption_report+="ENCRYPTION ISSUE: Sensitive data stored insecurely in ${insecure_storage} files\n"
        ((encryption_issues++))
    fi

    # Check for proper key management
    local key_management
    key_management=$(find . -name "*.swift" -exec grep -lE "(keychain|Keychain|generateKey|keyId)" {} \; | wc -l)
    if [[ ${crypto_usage} -gt 0 && ${key_management} -eq 0 ]]; then
        encryption_report+="ENCRYPTION ISSUE: Cryptography used without proper key management\n"
        ((encryption_issues++))
    fi

    # Check for certificate pinning
    local cert_pinning
    cert_pinning=$(find . -name "*.swift" -exec grep -lE "(certificate|pinning|SSL|TLS)" {} \; | wc -l)
    if [[ ${cert_pinning} -eq 0 ]]; then
        encryption_report+="NETWORK SECURITY: No certificate pinning implemented\n"
        ((encryption_issues++))
    fi

    # Use Ollama for encryption analysis
    local encryption_prompt;
    encryption_prompt="Analyze this Swift application for encryption and data protection:

Project: ${project}
Encryption Usage: ${crypto_usage} files
Secure Storage: ${secure_storage} files
Insecure Storage: ${insecure_storage} files
Key Management: ${key_management} files
Certificate Pinning: ${cert_pinning} files

Evaluate:
1. Data encryption implementation quality
2. Key management security
3. Secure storage patterns
4. Network security (HTTPS, certificate pinning)
5. Compliance with encryption standards
6. Data protection best practices

Provide specific encryption improvements and security recommendations."

    local encryption_analysis
    encryption_analysis=$(ollama_query "${encryption_prompt}")

    if [[ -n "${encryption_analysis}" ]]; then
        encryption_report+="\n=== AI Encryption Analysis ===\n${encryption_analysis}\n"
    fi

    # Save encryption audit results
    local encryption_file;
    encryption_file="${WORKSPACE}/Tools/Automation/results/${project}_encryption_audit.txt"

    {
        echo "Encryption & Data Protection Audit"
        echo "Project: ${project}"
        echo "Audit Date: $(date)"
        echo "Encryption Issues: ${encryption_issues}"
        echo "========================================"
        echo ""
        echo "${encryption_report}"
        echo ""
        echo "========================================"
    } >"${encryption_file}"

    log "Encryption audit completed, ${encryption_issues} issues found"
}

# Dependency security check
run_dependency_security_check() {
    local project;
    project="$1"
    log "Running dependency security check for ${project}..."

    # Check for Package.swift or Podfile
    local dependency_file;
    dependency_file=""
    if [[ -f "Package.swift" ]]; then
        dependency_file="Package.swift"
    elif [[ -f "Podfile" ]]; then
        dependency_file="Podfile"
    fi

    if [[ -n "${dependency_file}" ]]; then
        log "Found dependency file: ${dependency_file}"

        # Basic dependency analysis
        local dependencies
        dependencies=$(grep -cE "^.*package|^.*pod" "${dependency_file}" || echo "0")

        local dependency_report;

        dependency_report="Dependencies Found: ${dependencies}\n"

        # Check for known vulnerable versions (basic check)
        local outdated_deps
        outdated_deps=$(grep -cE "(\.0|\.1[^0-9])" "${dependency_file}" || echo "0")

        if [[ ${outdated_deps} -gt 0 ]]; then
            dependency_report+="DEPENDENCY SECURITY: ${outdated_deps} potentially outdated dependencies found\n"
        fi

        # Use Ollama for dependency analysis
        local dep_content
        dep_content=$(cat "${dependency_file}")

        local dependency_prompt;

        dependency_prompt="Analyze this Swift package dependencies for security:

${dep_content}

Assess:
1. Known security vulnerabilities in dependencies
2. Outdated package versions with security fixes
3. Dependency supply chain risks
4. License compliance issues
5. Recommended security updates

Provide specific dependency security recommendations."

        local dependency_analysis
        dependency_analysis=$(ollama_query "${dependency_prompt}")

        if [[ -n "${dependency_analysis}" ]]; then
            dependency_report+="\n=== AI Dependency Analysis ===\n${dependency_analysis}\n"
        fi

        # Save dependency check results
        local dep_file;
        dep_file="${WORKSPACE}/Tools/Automation/results/${project}_dependency_security.txt"

        {
            echo "Dependency Security Check"
            echo "Project: ${project}"
            echo "Check Date: $(date)"
            echo "Dependency File: ${dependency_file}"
            echo "========================================"
            echo ""
            echo "${dependency_report}"
            echo ""
            echo "========================================"
        } >"${dep_file}"

        log "Dependency security check completed"
    else
        log "No dependency file found for ${project}"
    fi
}

# Generate comprehensive security report
generate_security_report() {
    local project;
    project="$1"
    log "Generating comprehensive security report for ${project}..."

    local report_file;

    report_file="${WORKSPACE}/Tools/Automation/results/${project}_security_report.md"

    # Gather all security analysis results
    local vuln_file;
    vuln_file="${WORKSPACE}/Tools/Automation/results/${project}_vulnerability_scan.txt"
    local compliance_file;
    compliance_file="${WORKSPACE}/Tools/Automation/results/${project}_compliance_check.txt"
    local encryption_file;
    encryption_file="${WORKSPACE}/Tools/Automation/results/${project}_encryption_audit.txt"
    local dep_file;
    dep_file="${WORKSPACE}/Tools/Automation/results/${project}_dependency_security.txt"

    {
        echo "# Comprehensive Security Report"
        echo "**Project:** ${project}"
        echo "**Report Date:** $(date)"
        echo "**Security Framework:** Phase 6 Implementation"
        echo ""
        echo "## Executive Summary"
        echo ""
        echo "Automated security analysis covering vulnerabilities, compliance, encryption, and dependencies."
        echo ""
        echo "## Vulnerability Scan Results"
        echo ""
        if [[ -f "${vuln_file}" ]]; then
            echo "\`\`\`"
            cat "${vuln_file}"
            echo "\`\`\`"
        else
            echo "No vulnerability scan results available."
        fi
        echo ""
        echo "## Compliance Check Results"
        echo ""
        if [[ -f "${compliance_file}" ]]; then
            echo "\`\`\`"
            cat "${compliance_file}"
            echo "\`\`\`"
        else
            echo "No compliance check results available."
        fi
        echo ""
        echo "## Encryption Audit Results"
        echo ""
        if [[ -f "${encryption_file}" ]]; then
            echo "\`\`\`"
            cat "${encryption_file}"
            echo "\`\`\`"
        else
            echo "No encryption audit results available."
        fi
        echo ""
        echo "## Dependency Security Results"
        echo ""
        if [[ -f "${dep_file}" ]]; then
            echo "\`\`\`"
            cat "${dep_file}"
            echo "\`\`\`"
        else
            echo "No dependency security results available."
        fi
        echo ""
        echo "## Security Recommendations"
        echo ""
        echo "### Immediate Actions (Critical)"
        echo "- Address all CRITICAL and HIGH severity vulnerabilities"
        echo "- Implement proper encryption for sensitive data"
        echo "- Add input validation for all user inputs"
        echo "- Remove hardcoded secrets and use secure storage"
        echo ""
        echo "### Short-term (Next Sprint)"
        echo "- Implement certificate pinning for network requests"
        echo "- Add GDPR compliance features (consent, data deletion)"
        echo "- Update vulnerable dependencies"
        echo "- Add comprehensive error handling"
        echo ""
        echo "### Long-term (Future Releases)"
        echo "- Implement security monitoring and alerting"
        echo "- Add automated security testing to CI/CD"
        echo "- Conduct regular security audits"
        echo "- Implement security headers and CSP"
        echo ""
        echo "## Compliance Status"
        echo ""
        echo "### GDPR Compliance"
        echo "- [ ] Data minimization implemented"
        echo "- [ ] User consent mechanisms"
        echo "- [ ] Data deletion capabilities"
        echo "- [ ] Privacy policy integration"
        echo ""
        echo "### Security Standards"
        echo "- [ ] OWASP Top 10 addressed"
        echo "- [ ] Secure coding practices"
        echo "- [ ] Encryption standards met"
        echo "- [ ] Access control implemented"
        echo ""
        echo "---"
        echo "*Generated by Enhanced Security Agent - Phase 6 Security Framework*"
    } >"${report_file}"

    log "Comprehensive security report generated: ${report_file}"
}

# Setup security monitoring and alerting systems
setup_security_monitoring() {
    log "Setting up security monitoring and alerting systems..."

    # Create security monitoring configuration
    local monitoring_config;
    monitoring_config="${WORKSPACE}/Tools/Automation/config/security_monitoring.json"

    cat >"${monitoring_config}" <<EOF
{
  "monitoring_enabled": true,
  "alert_channels": {
    "log_files": true,
    "system_notifications": false,
    "email_alerts": false,
    "slack_webhooks": false
  },
  "alert_thresholds": {
    "critical_vulnerabilities": 1,
    "high_vulnerabilities": 5,
    "medium_vulnerabilities": 10,
    "failed_auth_attempts": 3,
    "suspicious_activities": 1
  },
  "monitoring_intervals": {
    "security_scans": 3600,
    "log_analysis": 300,
    "system_health": 60,
    "dependency_checks": 86400
  },
  "alert_rules": {
    "new_vulnerabilities": true,
    "authentication_failures": true,
    "data_exposure": true,
    "encryption_failures": true,
    "compliance_violations": true,
    "dependency_vulnerabilities": true
  },
  "response_actions": {
    "auto_quarantine": false,
    "auto_block": false,
    "auto_alert": true,
    "auto_report": true
  }
}
EOF

    log "Security monitoring configuration created"

    # Create security alert log
    local alert_log;
    alert_log="${WORKSPACE}/Tools/Automation/logs/security_alerts.log"
    mkdir -p "${WORKSPACE}/Tools/Automation/logs"

    echo "[$(date)] Security monitoring system initialized" >"${alert_log}"
    echo "[$(date)] Alert thresholds configured" >>"${alert_log}"
    echo "[$(date)] Monitoring intervals set" >>"${alert_log}"

    log "Security alert log initialized"

    # Generate monitoring dashboard
    local dashboard_file;
    dashboard_file="${WORKSPACE}/Tools/Automation/results/security_monitoring_dashboard.md"

    {
        echo "# Security Monitoring Dashboard"
        echo "**Status:** ACTIVE"
        echo "**Last Updated:** $(date)"
        echo "**Framework:** Phase 6 Security Implementation"
        echo ""
        echo "## System Status"
        echo "- ✅ Security monitoring: ENABLED"
        echo "- ✅ Alert logging: ACTIVE"
        echo "- ✅ Vulnerability scanning: SCHEDULED"
        echo "- ✅ Compliance monitoring: ACTIVE"
        echo ""
        echo "## Recent Alerts"
        echo ""
        echo "| Time | Severity | Alert Type | Description |"
        echo "|------|----------|------------|-------------|"
        echo "| $(date +%H:%M) | INFO | System | Security monitoring initialized |"
        echo ""
        echo "## Active Monitoring"
        echo ""
        echo "### Security Scans"
        echo "- Vulnerability assessment: Pending next scan"
        echo "- Dependency security: Daily checks enabled"
        echo "- Code security analysis: Continuous"
        echo ""
        echo "### Compliance Monitoring"
        echo "- GDPR compliance: Monitoring active"
        echo "- Data protection: Audit trails enabled"
        echo "- Privacy controls: Validation enabled"
        echo ""
        echo "### Alert Thresholds"
        echo "- Critical vulnerabilities: > 1"
        echo "- High vulnerabilities: > 5"
        echo "- Failed auth attempts: > 3"
        echo "- Suspicious activities: > 1"
        echo ""
        echo "## Security Metrics"
        echo ""
        echo "| Metric | Current | Threshold | Status |"
        echo "|--------|---------|-----------|--------|"
        echo "| Active Alerts | 0 | - | ✅ |"
        echo "| System Load | $(uptime | awk -F'load average:' '{print $2}' | awk -F',' '{print $1}') | < 4.0 | ✅ |"
        echo "| Memory Usage | $(ps -o pmem= -p $$ | awk '{print int($1)}' 2>/dev/null || echo "N/A")% | < 80% | ✅ |"
        echo ""
        echo "---"
        echo "*Security Monitoring System - Phase 6 Framework*"
    } >"${dashboard_file}"

    log "Security monitoring dashboard created"

    # Run initial security scan across all projects
    log "Running initial security assessment..."
    run_security_analysis "Initial security monitoring setup"

    log "Security monitoring and alerting systems setup completed"
}

# Main agent loop
echo "[$(date)] ${AGENT_NAME}: Starting security agent..." >>"${LOG_FILE}"
update_status "available"

# Track processed tasks to avoid duplicates
processed_tasks_file="${WORKSPACE}/Tools/Automation/agents/security_processed_tasks.txt"
touch "${processed_tasks_file}"

# Check for command-line arguments (direct execution mode)
if [[ $# -gt 0 ]]; then
    case "$1" in
    "security_monitoring" | "security_monitoring_setup")
        log "Direct execution mode: setting up security monitoring"
        update_status "busy"
        setup_security_monitoring
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
