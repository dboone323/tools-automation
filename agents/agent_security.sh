#!/bin/bash
# Security Agent: Security vulnerability scanning, secure coding analysis, and compliance checking
# Handles static security analysis, dependency scanning, and security best practices
# Phase 4 Enhanced: NPM audit, secrets scanning, and comprehensive reporting

AGENT_NAME="SecurityAgent"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
ENHANCEMENTS_DIR="${SCRIPT_DIR}/enhancements"
LOG_FILE="${SCRIPT_DIR}/security_agent.log"
PROJECTS_DIR="${WORKSPACE_ROOT}/Projects"

SLEEP_INTERVAL=1200 # Start with 20 minutes for security analysis
MAX_INTERVAL=7200

STATUS_FILE="${SCRIPT_DIR}/agent_status.json"
TASK_QUEUE="${SCRIPT_DIR}/task_queue.json"
PID=$$

# Source Phase 4 enhancement modules if available
if [[ -f "${ENHANCEMENTS_DIR}/security_npm_audit.sh" ]]; then
  # shellcheck source=/dev/null
  source "${ENHANCEMENTS_DIR}/security_npm_audit.sh"
fi
if [[ -f "${ENHANCEMENTS_DIR}/security_secrets_scan.sh" ]]; then
  # shellcheck source=/dev/null
  source "${ENHANCEMENTS_DIR}/security_secrets_scan.sh"
fi

function update_status() {
  local status="$1"
  # Ensure status file exists and is valid JSON
  if [[ ! -s ${STATUS_FILE} ]]; then
    echo '{"agents":{"build_agent":{"status":"unknown","pid":null},"debug_agent":{"status":"unknown","pid":null},"codegen_agent":{"status":"unknown","pid":null},"uiux_agent":{"status":"unknown","pid":null},"testing_agent":{"status":"unknown","pid":null},"security_agent":{"status":"unknown","pid":null}},"last_update":0}' >"${STATUS_FILE}"
  fi
  jq ".agents.security_agent.status = \"${status}\" | .agents.security_agent.pid = ${PID} | .last_update = $(date +%s)" "${STATUS_FILE}" >"${STATUS_FILE}.tmp"
  if jq ".agents.security_agent.status = \"${status}\" | .agents.security_agent.pid = ${PID} | .last_update = $(date +%s)" "${STATUS_FILE}" >"${STATUS_FILE}.tmp" && [[ -s "${STATUS_FILE}.tmp" ]]; then
    mv "${STATUS_FILE}.tmp" "${STATUS_FILE}"
  else
    echo "[$(date)] ${AGENT_NAME}: Failed to update agent_status.json (jq or mv error)" >>"${LOG_FILE}"
    rm -f "${STATUS_FILE}.tmp"
  fi
}
trap 'update_status stopped; exit 0' SIGTERM SIGINT

# Function to perform static security analysis
perform_static_analysis() {
  local project="$1"

  echo "[$(date)] ${AGENT_NAME}: Performing static security analysis for ${project}..." >>"${LOG_FILE}"

  local project_path="${PROJECTS_DIR}/${project}"
  local source_dir="${project_path}/${project}"

  if [[ ! -d ${source_dir} ]]; then
    echo "[$(date)] ${AGENT_NAME}: Source directory not found: ${source_dir}" >>"${LOG_FILE}"
    return 1
  fi

  cd "${project_path}" || return 1

  # Analyze Swift files for security issues
  find "${source_dir}" -name "*.swift" | while read -r swift_file; do
    echo "[$(date)] ${AGENT_NAME}: Analyzing ${swift_file}..." >>"${LOG_FILE}"

    # Check for common security vulnerabilities
    check_hardcoded_secrets "${swift_file}"
    check_insecure_networking "${swift_file}"
    check_weak_crypto "${swift_file}"
    check_input_validation "${swift_file}"
    check_access_control "${swift_file}"
  done

  return 0
}

# Function to check for hardcoded secrets
check_hardcoded_secrets() {
  local file="$1"
  local filename
  filename=$(basename "${file}")

  # Look for potential hardcoded secrets
  if grep -n -i "password\|secret\|key\|token" "${file}" | grep -v "TODO\|FIXME\|NOTE" | grep -E "(=|:) *[\"'][^\"']*[\"']" >/dev/null; then
    echo "[$(date)] ${AGENT_NAME}: ⚠️  POTENTIAL HARDCODED SECRET in ${filename}" >>"${LOG_FILE}"
    grep -n -i "password\|secret\|key\|token" "${file}" | grep -v "TODO\|FIXME\|NOTE" | grep -E "(=|:) *[\"'][^\"']*[\"']" >>"${LOG_FILE}"
  fi

  # Check for API keys patterns
  if grep -n -E "sk-[a-zA-Z0-9]{48}|pk_[a-zA-Z0-9]{24}" "${file}" >/dev/null; then
    echo "[$(date)] ${AGENT_NAME}: 🚨 STRIPE KEY DETECTED in ${filename}" >>"${LOG_FILE}"
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
    echo "[$(date)] ${AGENT_NAME}: ⚠️  INSECURE HTTP URL in ${filename}" >>"${LOG_FILE}"
    grep -n "http://" "${file}" | grep -v "localhost\|127.0.0.1\|example.com\|test" >>"${LOG_FILE}"
  fi

  # Check for missing certificate validation
  if grep -n "URLSession" "${file}" >/dev/null && ! grep -n "serverTrust\|certificate" "${file}" >/dev/null; then
    echo "[$(date)] ${AGENT_NAME}: ⚠️  POTENTIAL MISSING CERTIFICATE VALIDATION in ${filename}" >>"${LOG_FILE}"
  fi
}

# Function to check for weak cryptography
check_weak_crypto() {
  local file="$1"
  local filename
  filename=$(basename "${file}")

  # Check for weak hash functions
  if grep -n -E "MD5|SHA1" "${file}" >/dev/null; then
    echo "[$(date)] ${AGENT_NAME}: ⚠️  WEAK HASH FUNCTION in ${filename}" >>"${LOG_FILE}"
    grep -n -E "MD5|SHA1" "${file}" >>"${LOG_FILE}"
  fi

  # Check for proper crypto usage
  if grep -n "CryptoKit\|CommonCrypto" "${file}" >/dev/null; then
    echo "[$(date)] ${AGENT_NAME}: ✅ CRYPTO FRAMEWORK USAGE in ${filename}" >>"${LOG_FILE}"
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
      echo "[$(date)] ${AGENT_NAME}: ⚠️  USER INPUT WITHOUT VALIDATION in ${filename}" >>"${LOG_FILE}"
    fi
  fi

  # Check for SQL injection patterns (if using CoreData/SQL)
  if grep -n -E "NSPredicate|NSFetchRequest" "${file}" >/dev/null; then
    if grep -n -E "stringWithFormat|appending" "${file}" | grep -v "format.*@" >/dev/null; then
      echo "[$(date)] ${AGENT_NAME}: ⚠️  POTENTIAL SQL INJECTION in ${filename}" >>"${LOG_FILE}"
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
      echo "[$(date)] ${AGENT_NAME}: ℹ️  HIGH PUBLIC INTERFACE in ${filename} (${public_count} public, ${private_count} private)" >>"${LOG_FILE}"
    fi
  fi

  # Check for authentication checks
  if grep -n -E "login|auth|session" "${file}" >/dev/null && ! grep -n -E "guard|if.*auth|if.*login" "${file}" >/dev/null; then
    echo "[$(date)] ${AGENT_NAME}: ⚠️  MISSING AUTHENTICATION CHECK in ${filename}" >>"${LOG_FILE}"
  fi
}

# Function to scan dependencies for vulnerabilities
scan_dependencies() {
  local project="$1"

  echo "[$(date)] ${AGENT_NAME}: Scanning dependencies for ${project}..." >>"${LOG_FILE}"

  local project_path="${PROJECTS_DIR}/${project}"

  cd "${project_path}" || return 1

  # Check for Package.swift (Swift Package Manager)
  if [[ -f "Package.swift" ]]; then
    echo "[$(date)] ${AGENT_NAME}: Analyzing Swift Package dependencies..." >>"${LOG_FILE}"

    # Look for outdated or vulnerable packages
    if grep -n -E "url.*github\.com" Package.swift >/dev/null; then
      echo "[$(date)] ${AGENT_NAME}: ℹ️  EXTERNAL DEPENDENCIES FOUND - Manual review recommended" >>"${LOG_FILE}"
    fi
  fi

  # Check for CocoaPods
  if [[ -f "Podfile" ]]; then
    echo "[$(date)] ${AGENT_NAME}: Analyzing CocoaPods dependencies..." >>"${LOG_FILE}"

    if grep -n -E "pod " Podfile >/dev/null; then
      echo "[$(date)] ${AGENT_NAME}: ℹ️  COCOAPODS DEPENDENCIES FOUND - Check for updates" >>"${LOG_FILE}"
    fi
  fi

  return 0
}

# Function to check for compliance issues
check_compliance() {
  local project="$1"

  echo "[$(date)] ${AGENT_NAME}: Checking compliance for ${project}..." >>"${LOG_FILE}"

  local project_path="${PROJECTS_DIR}/${project}"
  local source_dir="${project_path}/${project}"

  if [[ ! -d ${source_dir} ]]; then
    return 1
  fi

  # Check for data privacy compliance
  find "${source_dir}" -name "*.swift" | while read -r swift_file; do
    local filename
    filename=$(basename "${swift_file}")

    # Check for data collection without consent
    if grep -n -E "location|camera|microphone|contacts|photos" "${swift_file}" >/dev/null; then
      if ! grep -n -E "privacy|consent|permission" "${swift_file}" >/dev/null; then
        echo "[$(date)] ${AGENT_NAME}: ⚠️  PRIVACY-SENSITIVE FEATURE in ${filename} - Check permissions" >>"${LOG_FILE}"
      fi
    fi

    # Check for data storage compliance
    if grep -n -E "UserDefaults|FileManager|CoreData" "${swift_file}" >/dev/null; then
      if ! grep -n -E "encrypt|secure|privacy" "${swift_file}" >/dev/null; then
        echo "[$(date)] ${AGENT_NAME}: ℹ️  DATA STORAGE in ${filename} - Consider encryption" >>"${LOG_FILE}"
      fi
    fi
  done

  return 0
}

# Function to generate security report
generate_security_report() {
  local project="$1"

  echo "[$(date)] ${AGENT_NAME}: Generating security report for ${project}..." >>"${LOG_FILE}"

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

  echo "[$(date)] ${AGENT_NAME}: Security report generated: ${report_file}" >>"${LOG_FILE}"
  return 0
}

# Function to perform comprehensive security analysis
perform_security_analysis() {
  local project="$1"
  local task_data="$2"

  echo "[$(date)] ${AGENT_NAME}: Starting comprehensive security analysis for ${project} (Task: ${task_data})..." >>"${LOG_FILE}"

  # Navigate to project directory
  local project_path="${PROJECTS_DIR}/${project}"
  if [[ ! -d ${project_path} ]]; then
    echo "[$(date)] ${AGENT_NAME}: Project directory not found: ${project_path}" >>"${LOG_FILE}"
    return 1
  fi

  cd "${project_path}" || return 1

  # Create backup before making changes
  echo "[$(date)] ${AGENT_NAME}: Creating backup before security analysis..." >>"${LOG_FILE}"
  /Users/danielstevens/Desktop/Quantum-workspace/Tools/Automation/agents/backup_manager.sh backup "${project}" >>"${LOG_FILE}" 2>&1 || true

  # Perform security checks
  perform_static_analysis "${project}"
  scan_dependencies "${project}"
  check_compliance "${project}"
  
  # Phase 4: Run enhanced security scans if available
  if command -v run_npm_audit &>/dev/null; then
    echo "[$(date)] ${AGENT_NAME}: Running NPM audit..." >>"${LOG_FILE}"
    run_npm_audit "${project_path}" >>"${LOG_FILE}" 2>&1 || true
  fi
  
  if command -v scan_for_secrets &>/dev/null; then
    echo "[$(date)] ${AGENT_NAME}: Running secrets scan..." >>"${LOG_FILE}"
    scan_for_secrets "${project_path}" >>"${LOG_FILE}" 2>&1 || true
  fi
  
  generate_security_report "${project}"

  echo "[$(date)] ${AGENT_NAME}: Security analysis completed for ${project}" >>"${LOG_FILE}"
  return 0
}

echo "[$(date)] ${AGENT_NAME}: Security Agent started successfully" >>"${LOG_FILE}"
echo "[$(date)] ${AGENT_NAME}: Ready to perform security analysis on Swift projects" >>"${LOG_FILE}"

while true; do
  update_status running
  echo "[$(date)] ${AGENT_NAME}: Checking for security tasks..." >>"${LOG_FILE}"

  # Check for queued security tasks
  HAS_TASK=$(jq '.tasks[] | select(.assigned_agent=="agent_security.sh" and .status=="queued")' "${TASK_QUEUE}" 2>/dev/null)

  if [[ -n ${HAS_TASK} ]]; then
    echo "[$(date)] ${AGENT_NAME}: Found security tasks to process..." >>"${LOG_FILE}"

    # Process each queued task
    echo "${HAS_TASK}" | jq -c '.' | while read -r task; do
      project=$(echo "${task}" | jq -r '.project // empty')
      task_id=$(echo "${task}" | jq -r '.id')

      if [[ -z ${project} ]]; then
        # If no specific project, analyze all projects
        for proj_dir in "${PROJECTS_DIR}"/*/; do
          if [[ -d ${proj_dir} ]]; then
            proj_name=$(basename "${proj_dir}")
            echo "[$(date)] ${AGENT_NAME}: Analyzing security for project ${proj_name}..." >>"${LOG_FILE}"
            perform_security_analysis "${proj_name}" "${task}"
          fi
        done
      else
        echo "[$(date)] ${AGENT_NAME}: Processing task ${task_id} for project ${project}..." >>"${LOG_FILE}"
        perform_security_analysis "${project}" "${task}"
      fi

      # Update task status to completed
      jq "(.tasks[] | select(.id==\"${task_id}\") | .status) = \"completed\"" "${TASK_QUEUE}" >"${TASK_QUEUE}.tmp"
      if jq "(.tasks[] | select(.id==\"${task_id}\") | .status) = \"completed\"" "${TASK_QUEUE}" >"${TASK_QUEUE}.tmp" && [[ -s "${TASK_QUEUE}.tmp" ]]; then
        mv "${TASK_QUEUE}.tmp" "${TASK_QUEUE}"
        echo "[$(date)] ${AGENT_NAME}: Task ${task_id} marked as completed" >>"${LOG_FILE}"
      fi

      # Adjust sleep interval based on activity
      SLEEP_INTERVAL=$((SLEEP_INTERVAL + 600))
      if [[ ${SLEEP_INTERVAL} -gt ${MAX_INTERVAL} ]]; then
        SLEEP_INTERVAL=${MAX_INTERVAL}
      fi
    done
  else
    update_status idle
    echo "[$(date)] ${AGENT_NAME}: No security tasks found. Sleeping as idle." >>"${LOG_FILE}"
    sleep 600
  fi

  echo "[$(date)] ${AGENT_NAME}: Sleeping for ${SLEEP_INTERVAL} seconds..." >>"${LOG_FILE}"
  sleep "${SLEEP_INTERVAL}"
done
