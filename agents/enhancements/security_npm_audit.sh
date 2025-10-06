#!/bin/bash
# Security Enhancement: NPM Audit Integration
# Scans package.json for vulnerabilities and generates reports

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
METRICS_DIR="${WORKSPACE_ROOT}/.metrics/security"

mkdir -p "${METRICS_DIR}"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [npm_audit] $*"
}

run_npm_audit() {
  local project_path="$1"
  local report_file="${METRICS_DIR}/npm_audit_$(date +%Y%m%d_%H%M%S).json"
  
  log "Running npm audit for ${project_path}"
  
  if [[ ! -f "${project_path}/package.json" ]]; then
    log "No package.json found, skipping npm audit"
    return 0
  fi
  
  cd "${project_path}" || return 1
  
  # Run npm audit and capture output
  if command -v npm &>/dev/null; then
    npm audit --json > "${report_file}" 2>/dev/null || true
    
    # Parse results
    local critical high moderate low
    critical=$(jq -r '.metadata.vulnerabilities.critical // 0' "${report_file}" 2>/dev/null || echo "0")
    high=$(jq -r '.metadata.vulnerabilities.high // 0' "${report_file}" 2>/dev/null || echo "0")
    moderate=$(jq -r '.metadata.vulnerabilities.moderate // 0' "${report_file}" 2>/dev/null || echo "0")
    low=$(jq -r '.metadata.vulnerabilities.low // 0' "${report_file}" 2>/dev/null || echo "0")
    
    log "Vulnerabilities found: Critical=${critical}, High=${high}, Moderate=${moderate}, Low=${low}"
    
    # Create GitHub issues for critical vulnerabilities
    if [[ ${critical} -gt 0 ]] && command -v gh &>/dev/null; then
      log "Creating GitHub issue for ${critical} critical vulnerabilities"
      gh issue create --title "🚨 Critical NPM Vulnerabilities Detected" \
        --body "NPM audit found ${critical} critical vulnerabilities. See ${report_file} for details." \
        --label "security,critical" 2>/dev/null || log "Failed to create GitHub issue"
    fi
    
    echo "${report_file}"
  else
    log "npm not found, skipping audit"
    return 1
  fi
}

run_spm_audit() {
  local project_path="$1"
  local report_file="${METRICS_DIR}/spm_audit_$(date +%Y%m%d_%H%M%S).txt"
  
  log "Running SPM dependency check for ${project_path}"
  
  if [[ ! -f "${project_path}/Package.swift" ]]; then
    log "No Package.swift found, skipping SPM audit"
    return 0
  fi
  
  cd "${project_path}" || return 1
  
  # List dependencies
  if command -v swift &>/dev/null; then
    swift package show-dependencies > "${report_file}" 2>&1 || true
    log "SPM dependencies report: ${report_file}"
    echo "${report_file}"
  else
    log "swift not found, skipping SPM audit"
    return 1
  fi
}

# If called directly, run audit
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <project_path>"
    exit 1
  fi
  
  run_npm_audit "$1"
  run_spm_audit "$1"
fi
