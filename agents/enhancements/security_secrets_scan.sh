#!/bin/bash
# Security Enhancement: Secrets Scanning with git-secrets
# Detects hardcoded secrets and sensitive data

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../../.." && pwd)"
METRICS_DIR="${WORKSPACE_ROOT}/.metrics/security"

mkdir -p "${METRICS_DIR}"

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [secrets_scan] $*"
}

install_git_secrets() {
  if ! command -v git-secrets &>/dev/null; then
    log "git-secrets not found, attempting to install..."
    if command -v brew &>/dev/null; then
      brew install git-secrets 2>&1 | tee -a "${METRICS_DIR}/git_secrets_install.log"
    else
      log "Homebrew not available, skipping git-secrets installation"
      return 1
    fi
  else
    log "git-secrets already installed"
  fi
  return 0
}

add_custom_patterns() {
  local repo_path="$1"

  cd "${repo_path}" || return 1

  # AWS keys
  git secrets --add 'AKIA[0-9A-Z]{16}' 2>/dev/null || true

  # Private keys
  git secrets --add '-----BEGIN (RSA|DSA|EC) PRIVATE KEY-----' 2>/dev/null || true

  # API tokens
  git secrets --add '(api|token|key).*[=:]\s*['\''"][a-zA-Z0-9]{32,}['\''"]' 2>/dev/null || true

  # Stripe keys
  git secrets --add '(sk|pk)_(test|live)_[a-zA-Z0-9]{24,}' 2>/dev/null || true

  # Database URLs
  git secrets --add '(mongodb|postgresql|mysql)://.*:.*@' 2>/dev/null || true

  log "Custom patterns added"
}

scan_for_secrets() {
  local project_path="$1"
  local report_file="${METRICS_DIR}/secrets_scan_$(date +%Y%m%d_%H%M%S).txt"

  log "Scanning for secrets in ${project_path}"

  cd "${project_path}" || return 1

  # Check if git-secrets is available
  if ! command -v git-secrets &>/dev/null; then
    log "git-secrets not available, using basic pattern matching"

    # Basic secret patterns
    {
      echo "=== Secrets Scan Report ==="
      echo "Date: $(date)"
      echo "Project: ${project_path}"
      echo ""

      # Search for common secret patterns
      echo "--- Potential API Keys ---"
      grep -r -n -E "(api_key|apikey|api-key|API_KEY)\s*[:=]\s*['\"][a-zA-Z0-9]{20,}['\"]" \
        --include="*.swift" --include="*.json" --include="*.plist" \
        "${project_path}" 2>/dev/null || echo "None found"

      echo ""
      echo "--- Potential Passwords ---"
      grep -r -n -E "(password|passwd|pwd)\s*[:=]\s*['\"][^'\"]{8,}['\"]" \
        --include="*.swift" --include="*.json" --include="*.plist" \
        "${project_path}" 2>/dev/null || echo "None found"

      echo ""
      echo "--- Potential Private Keys ---"
      grep -r -n "BEGIN.*PRIVATE KEY" \
        --include="*.pem" --include="*.key" \
        "${project_path}" 2>/dev/null || echo "None found"

    } >"${report_file}"

  else
    # Use git-secrets
    git secrets --scan -r >"${report_file}" 2>&1 || true
  fi

  log "Secrets scan report: ${report_file}"

  # Check if secrets were found
  if grep -q "potential secret" "${report_file}" 2>/dev/null ||
    grep -q "Potential API Keys" "${report_file}" 2>/dev/null; then
    log "⚠️  Potential secrets detected! Review ${report_file}"

    # Create GitHub issue if secrets found
    if command -v gh &>/dev/null; then
      gh issue create --title "🔐 Potential Secrets Detected in Codebase" \
        --body "Secrets scan found potential sensitive data. See ${report_file} for details." \
        --label "security,secrets" 2>/dev/null || log "Failed to create GitHub issue"
    fi
  else
    log "✅ No secrets detected"
  fi

  echo "${report_file}"
}

# If called directly, run scan
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  if [[ $# -eq 0 ]]; then
    echo "Usage: $0 <project_path>"
    exit 1
  fi

  scan_for_secrets "$1"
fi
