#!/bin/bash
# Agent Integration - CI/CD integration & workflow management
# Manages GitHub Actions workflows, deployment automation, and artifact management

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
AGENTS_DIR="${SCRIPT_DIR}"

# Source AI enhancement modules
ENHANCEMENTS_DIR="${SCRIPT_DIR}/../enhancements"
if [[ -f "${ENHANCEMENTS_DIR}/ai_integration_optimizer.sh" ]]; then
  # shellcheck source=../enhancements/ai_integration_optimizer.sh
  source "${ENHANCEMENTS_DIR}/ai_integration_optimizer.sh"
fi

AGENT_NAME="agent_integration"
MCP_URL="${MCP_URL:-http://127.0.0.1:5005}"
LOG_FILE="${AGENTS_DIR}/${AGENT_NAME}.log"
STATUS_FILE="${AGENTS_DIR}/agent_status.json"
WORKFLOWS_DIR="${WORKSPACE_ROOT}/.github/workflows"

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


# Validate workflow YAML syntax
validate_workflow() {
  local workflow_file="$1"

  if [[ ! -f "${workflow_file}" ]]; then
    error "Workflow file not found: ${workflow_file}"
    return 1
  fi

  info "Validating ${workflow_file}..."

  # Basic YAML syntax check
  if command -v python3 &>/dev/null; then
    python3 -c "
import yaml
try:
    with open('${workflow_file}', 'r') as f:
        yaml.safe_load(f)
    print('✅ Valid YAML')
except yaml.YAMLError as e:
    print(f'❌ Invalid YAML: {e}')
    exit(1)
" || return 1
  fi

  # Check for required GitHub Actions fields
  if ! grep -q "^name:" "${workflow_file}"; then
    warning "Workflow missing 'name' field"
  fi

  if ! grep -q "^on:" "${workflow_file}"; then
    error "Workflow missing 'on' trigger field"
    return 1
  fi

  if ! grep -q "^jobs:" "${workflow_file}"; then
    error "Workflow missing 'jobs' field"
    return 1
  fi

  success "Workflow validation passed: ${workflow_file}"
  return 0
}

# Sync workflows across projects
sync_workflows() {
  info "Syncing workflows across projects..."

  local synced=0
  local failed=0

  # Common workflows that should exist in all projects
  local common_workflows=(
    "pr-validation-unified.yml"
    "swiftlint-auto-fix.yml"
    "weekly-health-check.yml"
  )

  for workflow in "${common_workflows[@]}"; do
    local source="${WORKFLOWS_DIR}/${workflow}"

    if [[ ! -f "${source}" ]]; then
      warning "Source workflow not found: ${workflow}"
      continue
    fi

    info "Checking ${workflow}..."

    # Validate source workflow
    if validate_workflow "${source}"; then
      synced=$((synced + 1))
    else
      error "Failed to validate ${workflow}"
      failed=$((failed + 1))
    fi
  done

  success "Synced ${synced} workflows, ${failed} failed"
  return 0
}

# Check workflow run status via GitHub CLI
check_workflow_status() {
  if ! command -v gh &>/dev/null; then
    warning "GitHub CLI not installed - skipping workflow status check"
    return 0
  fi

  info "Checking recent workflow runs..."

  cd "${WORKSPACE_ROOT}" || return 1

  # Get last 5 workflow runs
  local runs
  runs=$(gh run list --limit 5 --json status,conclusion,name 2>/dev/null || echo "[]")

  if [[ "${runs}" == "[]" ]]; then
    info "No recent workflow runs found"
    return 0
  fi

  # Count failures
  local failures
  failures=$(echo "${runs}" | grep -c '"conclusion":"failure"' || echo 0)

  if [[ ${failures} -gt 0 ]]; then
    warning "Found ${failures} failed workflow runs in last 5"

    # Report to MCP
    if command -v curl &>/dev/null; then
      curl -s -X POST "${MCP_URL}/alert" \
        -H "Content-Type: application/json" \
        -d "{\"agent\": \"${AGENT_NAME}\", \"level\": \"warning\", \"message\": \"${failures} workflow failures detected\"}" \
        &>/dev/null || true
    fi
  else
    success "All recent workflow runs successful"
  fi

  cd - >/dev/null || return 1
  return 0
}

# Monitor workflow health
monitor_workflows() {
  info "Monitoring workflow health..."

  local total_workflows=0
  local valid_workflows=0
  local invalid_workflows=0

  if [[ ! -d "${WORKFLOWS_DIR}" ]]; then
    error "Workflows directory not found: ${WORKFLOWS_DIR}"
    return 1
  fi

  # Validate all workflow files
  while IFS= read -r workflow; do
    total_workflows=$((total_workflows + 1))

    if validate_workflow "${workflow}"; then
      valid_workflows=$((valid_workflows + 1))
    else
      invalid_workflows=$((invalid_workflows + 1))
    fi
  done < <(find "${WORKFLOWS_DIR}" -name "*.yml" -o -name "*.yaml" 2>/dev/null)

  # Generate health report
  local health_report="${WORKSPACE_ROOT}/.metrics/workflow_health_$(date +%Y%m%d_%H%M%S).json"

  cat >"${health_report}" <<EOF
{
  "timestamp": $(date +%s),
  "date": "$(date -Iseconds)",
  "total_workflows": ${total_workflows},
  "valid_workflows": ${valid_workflows},
  "invalid_workflows": ${invalid_workflows},
  "health_score": $(awk "BEGIN {if (${total_workflows} > 0) print ${valid_workflows}/${total_workflows}; else print 0}")
}
EOF

  success "Workflow health report: ${health_report}"

  # Check for failures
  check_workflow_status

  return 0
}

# Cleanup old workflow runs (via GitHub CLI)
cleanup_old_runs() {
  if ! command -v gh &>/dev/null; then
    warning "GitHub CLI not installed - skipping run cleanup"
    return 0
  fi

  info "Cleaning up old workflow runs..."

  cd "${WORKSPACE_ROOT}" || return 1

  # Delete workflow runs older than 90 days
  local old_runs
  old_runs=$(gh run list --limit 100 --json databaseId,createdAt --jq '.[] | select(.createdAt | fromdateiso8601 < (now - 7776000)) | .databaseId' 2>/dev/null || echo "")

  if [[ -z "${old_runs}" ]]; then
    info "No old workflow runs to clean up"
    cd - >/dev/null || return 1
    return 0
  fi

  local deleted=0
  while IFS= read -r run_id; do
    [[ -z "${run_id}" ]] && continue

    if gh run delete "${run_id}" --yes 2>/dev/null; then
      deleted=$((deleted + 1))
    fi
  done <<<"${old_runs}"

  success "Deleted ${deleted} old workflow runs"

  cd - >/dev/null || return 1
  return 0
}

# Deploy workflow updates
deploy_workflows() {
  info "Deploying workflow updates..."

  # Sync workflows
  sync_workflows

  # Validate all workflows
  monitor_workflows

  # Check if there are changes to commit
  cd "${WORKSPACE_ROOT}" || return 1

  if git status --porcelain "${WORKFLOWS_DIR}" | grep -q .; then
    info "Workflow changes detected"

    # Auto-commit if configured
    if [[ "${AUTO_COMMIT_WORKFLOWS:-false}" == "true" ]]; then
      git add "${WORKFLOWS_DIR}"
      git commit -m "chore: Update GitHub Actions workflows [agent-integration]"

      if [[ "${AUTO_PUSH_WORKFLOWS:-false}" == "true" ]]; then
        git push
        success "Workflows committed and pushed"
      else
        success "Workflows committed (not pushed)"
      fi
    else
      info "Auto-commit disabled - changes staged but not committed"
    fi
  else
    info "No workflow changes to deploy"
  fi

  cd - >/dev/null || return 1
  return 0
}

# Main agent loop
main() {
  log "Integration Agent starting..."
  update_agent_status "agent_integration.sh" "starting" $$ ""

  echo $$ >"${AGENTS_DIR}/${AGENT_NAME}.pid"

  # Register with MCP
  if command -v curl &>/dev/null; then
    curl -s -X POST "${MCP_URL}/register" \
      -H "Content-Type: application/json" \
      -d "{\"agent\": \"${AGENT_NAME}\", \"capabilities\": [\"ci-cd\", \"workflows\", \"deployment\", \"integration\"]}" \
      &>/dev/null || warning "Failed to register with MCP"
  fi

  update_agent_status "agent_integration.sh" "available" $$ ""
  success "Integration Agent ready"

  # Main loop - monitor every 10 minutes
  while true; do
    update_agent_status "agent_integration.sh" "running" $$ ""

    # Monitor workflow health
    monitor_workflows

    # Check for deployment tasks
    if command -v curl &>/dev/null; then
      local task
      task=$(curl -s "${MCP_URL}/task/next?agent=${AGENT_NAME}" 2>/dev/null || echo "")

      if [[ -n "$task" ]] && echo "$task" | grep -q "command"; then
        log "Processing integration task..."

        # Handle different task types
        if echo "$task" | grep -q "deploy"; then
          deploy_workflows
        elif echo "$task" | grep -q "cleanup"; then
          cleanup_old_runs
        elif echo "$task" | grep -q "sync"; then
          sync_workflows
        fi
      fi
    fi

    update_agent_status "agent_integration.sh" "available" $$ ""
    success "Integration cycle complete. Next check in 10 minutes."

    # Heartbeat
    if command -v curl &>/dev/null; then
      curl -s -X POST "${MCP_URL}/heartbeat" \
        -H "Content-Type: application/json" \
        -d "{\"agent\": \"${AGENT_NAME}\"}" &>/dev/null || true
    fi

    sleep 600 # 10 minutes
  done
}

# Handle CLI commands
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-daemon}" in
  validate)
    validate_workflow "${2:-}"
    ;;
  sync)
    sync_workflows
    ;;
  monitor)
    monitor_workflows
    ;;
  deploy)
    deploy_workflows
    ;;
  cleanup)
    cleanup_old_runs
    ;;
  status)
    check_workflow_status
    ;;
  daemon)
    trap 'update_agent_status "agent_integration.sh" "stopped" $$ ""; log "Integration Agent stopping..."; exit 0' SIGTERM SIGINT
    main "$@"
    ;;
  *)
    echo "Usage: $0 {validate|sync|monitor|deploy|cleanup|status|daemon}"
    echo ""
    echo "Commands:"
    echo "  validate <file>  - Validate workflow YAML syntax"
    echo "  sync             - Sync workflows across projects"
    echo "  monitor          - Monitor workflow health"
    echo "  deploy           - Deploy workflow updates"
    echo "  cleanup          - Clean up old workflow runs"
    echo "  status           - Check workflow run status"
    echo "  daemon           - Run as daemon (default)"
    exit 1
    ;;
  esac
fi
