#!/bin/bash
# Agent Validation - Pre-commit & pre-merge validation
# Enforces architecture rules, quality gates, and coding standards

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
AGENTS_DIR="${SCRIPT_DIR}"
AGENT_NAME="agent_validation"
MCP_URL="${MCP_URL:-http://127.0.0.1:5005}"
LOG_FILE="${AGENTS_DIR}/${AGENT_NAME}.log"
STATUS_FILE="${AGENTS_DIR}/agent_status.json"
QUALITY_CONFIG="${WORKSPACE_ROOT}/quality-config.yaml"
ARCHITECTURE_DOC="${WORKSPACE_ROOT}/Tools/ARCHITECTURE.md"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

log() {
  echo "[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] $*" | tee -a "${LOG_FILE}"
}

error() {
  echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ❌ $*${NC}" | tee -a "${LOG_FILE}"
}

success() {
  echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ✅ $*${NC}" | tee -a "${LOG_FILE}"
}

warning() {
  echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ⚠️  $*${NC}" | tee -a "${LOG_FILE}"
}

info() {
  echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] [${AGENT_NAME}] ℹ️  $*${NC}" | tee -a "${LOG_FILE}"
}


# Check for SwiftUI imports in data models
validate_architecture_rule_1() {
  local project_path="$1"
  local violations=0

  info "Validating Rule 1: Data models NEVER import SwiftUI"

  # Find files in SharedTypes or Models directories (exclude backups)
  while IFS= read -r file; do
    if grep -q "import SwiftUI" "$file"; then
      error "Architecture violation in $file: Data model imports SwiftUI"
      violations=$((violations + 1))
    fi
  done < <(find "${project_path}" \( -path "*/SharedTypes/*" -o -path "*/Models/*" \) -name "*.swift" -not -path "*/.backups/*" 2>/dev/null)

  if [[ ${violations} -eq 0 ]]; then
    success "Rule 1 passed: No SwiftUI imports in data models"
  else
    error "Rule 1 failed: ${violations} violations found"
  fi

  return ${violations}
}

# Check for excessive async/await usage
validate_architecture_rule_2() {
  local project_path="$1"
  local violations=0

  info "Validating Rule 2: Prefer synchronous operations with background queues"

  # Count async functions vs total functions
  local async_funcs
  local total_funcs
  async_funcs=$(grep -r "func.*async" "${project_path}" --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
  total_funcs=$(grep -r "func " "${project_path}" --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')

  if [[ ${total_funcs} -gt 0 ]]; then
    local async_ratio=$((async_funcs * 100 / total_funcs))
    if [[ ${async_ratio} -gt 30 ]]; then
      warning "Rule 2 warning: ${async_ratio}% of functions are async (threshold: 30%)"
      violations=1
    else
      success "Rule 2 passed: Async ratio is ${async_ratio}%"
    fi
  fi

  return ${violations}
}

# Check for generic naming
validate_architecture_rule_3() {
  local project_path="$1"
  local violations=0

  info "Validating Rule 3: Specific naming over generic"

  # Check for generic names
  local bad_names=("Dashboard" "Manager" "Helper" "Utility" "Base")

  for name in "${bad_names[@]}"; do
    local count
    count=$(grep -r "class ${name}" "${project_path}" --include="*.swift" 2>/dev/null | wc -l | tr -d ' ')
    if [[ ${count} -gt 0 ]]; then
      warning "Found ${count} classes named '${name}' - consider more specific names"
      violations=$((violations + count))
    fi
  done

  if [[ ${violations} -eq 0 ]]; then
    success "Rule 3 passed: No generic naming detected"
  else
    warning "Rule 3: ${violations} potential generic names found"
  fi

  return 0 # Warning only, not a hard failure
}

# Validate quality gates from quality-config.yaml
validate_quality_gates() {
  local project_path="$1"
  local project_name
  project_name=$(basename "${project_path}")
  local failures=0

  info "Validating quality gates for ${project_name}..."

  # Check file size limits (500 lines max per file)
  local oversized_files
  oversized_files=$(find "${project_path}" -name "*.swift" -not -path "*/.backups/*" -exec wc -l {} + 2>/dev/null |
    awk '$1 > 500 {print $2}' | wc -l | tr -d ' ')

  if [[ ${oversized_files} -gt 0 ]]; then
    warning "Found ${oversized_files} files exceeding 500 lines"
    failures=$((failures + 1))
  else
    success "All files within size limits"
  fi

  # Check for SwiftLint errors
  if command -v swiftlint &>/dev/null; then
    cd "${project_path}" || return 1
    if swiftlint lint --quiet --strict 2>/dev/null; then
      success "SwiftLint validation passed"
    else
      error "SwiftLint validation failed"
      failures=$((failures + 1))
    fi
    cd - >/dev/null || return 1
  fi

  return ${failures}
}

# Validate dependencies
validate_dependencies() {
  local project_path="$1"
  local project_name
  project_name=$(basename "${project_path}")
  local issues=0

  info "Validating dependencies for ${project_name}..."

  # Check for circular dependencies (simplified check)
  local imports
  imports=$(grep -rh "^import " "${project_path}" --include="*.swift" 2>/dev/null | sort -u)

  # Check for unused imports (simplified)
  while IFS= read -r file; do
    local file_imports
    file_imports=$(grep "^import " "$file" 2>/dev/null || true)

    while IFS= read -r import_line; do
      [[ -z "$import_line" ]] && continue
      local module
      module=$(echo "$import_line" | awk '{print $2}')

      # Check if module is used in file (very simplified)
      if ! grep -q "$module" "$file" 2>/dev/null; then
        warning "Potentially unused import in $file: $import_line"
        issues=$((issues + 1))
      fi
    done <<<"$file_imports"
  done < <(find "${project_path}" -name "*.swift" -not -path "*/.backups/*" 2>/dev/null | head -10) # Limit for performance

  if [[ ${issues} -eq 0 ]]; then
    success "Dependency validation passed"
  else
    warning "Found ${issues} potential dependency issues"
  fi

  return 0 # Don't fail on warnings
}

# Run full validation suite
run_validation() {
  local project_path="${1:-${WORKSPACE_ROOT}/Projects}"
  local total_failures=0

  log "Running validation suite on ${project_path}..."

  # Find all project directories
  local projects
  if [[ -d "${project_path}" ]]; then
    projects=("${project_path}")
  else
    projects=("${WORKSPACE_ROOT}"/Projects/*)
  fi

  for project in "${projects[@]}"; do
    [[ ! -d "$project" ]] && continue

    local pname
    pname=$(basename "$project")
    # Skip non-code directories and backups
    [[ "$pname" == "Tools" || "$pname" == "scripts" || "$pname" == "Config" || "$pname" == ".backups" ]] && continue

    info "=== Validating ${pname} ==="

    # Run architecture validations
    validate_architecture_rule_1 "$project" || total_failures=$((total_failures + 1))
    validate_architecture_rule_2 "$project" || total_failures=$((total_failures + 1))
    validate_architecture_rule_3 "$project" || total_failures=$((total_failures + 1))

    # Run quality gate validations
    validate_quality_gates "$project" || total_failures=$((total_failures + 1))

    # Run dependency validations
    validate_dependencies "$project" || total_failures=$((total_failures + 1))

    info "=== ${pname} validation complete ==="
    echo ""
  done

  if [[ ${total_failures} -eq 0 ]]; then
    success "✅ All validation checks passed!"
    return 0
  else
    error "❌ Validation failed with ${total_failures} errors"
    return 1
  fi
}

# Install pre-commit hook
install_pre_commit_hook() {
  local git_dir="${WORKSPACE_ROOT}/.git"

  if [[ ! -d "${git_dir}" ]]; then
    warning "Not a git repository, skipping hook installation"
    return 0
  fi

  local hook_file="${git_dir}/hooks/pre-commit"

  info "Installing pre-commit validation hook..."

  cat >"${hook_file}" <<'HOOK'
#!/bin/bash
# Pre-commit validation hook - runs validation agent

AGENT_PATH="./Tools/Automation/agents/agent_validation.sh"

if [[ ! -f "${AGENT_PATH}" ]]; then
  echo "⚠️  Validation agent not found, skipping checks"
  exit 0
fi

echo "🔍 Running pre-commit validation..."

# Run validation on staged files only
"${AGENT_PATH}" validate-staged

exit_code=$?

if [[ ${exit_code} -eq 0 ]]; then
  echo "✅ Validation passed"
else
  echo "❌ Validation failed - commit blocked"
  echo "   Run: ${AGENT_PATH} --help for details"
fi

exit ${exit_code}
HOOK

  chmod +x "${hook_file}"
  success "Pre-commit hook installed at ${hook_file}"
}

# Main agent loop
main() {
  log "Validation Agent starting..."
  update_agent_status "agent_validation.sh" "starting" $$ ""

  echo $$ >"${AGENTS_DIR}/${AGENT_NAME}.pid"

  # Register with MCP
  if command -v curl &>/dev/null; then
    curl -s -X POST "${MCP_URL}/register" \
      -H "Content-Type: application/json" \
      -d "{\"agent\": \"${AGENT_NAME}\", \"capabilities\": [\"validation\", \"quality-gates\", \"architecture\"]}" \
      &>/dev/null || warning "Failed to register with MCP"
  fi

  update_agent_status "agent_validation.sh" "available" $$ ""
  success "Validation Agent ready"

  # Install pre-commit hook if not exists
  if [[ ! -f "${WORKSPACE_ROOT}/.git/hooks/pre-commit" ]]; then
    install_pre_commit_hook
  fi

  # Main loop - check for validation tasks
  while true; do
    # Check MCP for validation tasks
    if command -v curl &>/dev/null; then
      local task
      task=$(curl -s "${MCP_URL}/task/next?agent=${AGENT_NAME}" 2>/dev/null || echo "")

      if [[ -n "$task" ]] && echo "$task" | grep -q "command"; then
        update_agent_status "agent_validation.sh" "running" $$ ""

        # Extract task details (simplified)
        local task_id
        task_id=$(echo "$task" | grep -o '"id":"[^"]*"' | cut -d'"' -f4)

        log "Processing task ${task_id}..."

        # Run validation
        if run_validation; then
          success "Task ${task_id} completed successfully"
          curl -s -X POST "${MCP_URL}/task/${task_id}/complete" \
            -H "Content-Type: application/json" \
            -d '{"status":"success"}' &>/dev/null || true
        else
          error "Task ${task_id} failed"
          curl -s -X POST "${MCP_URL}/task/${task_id}/complete" \
            -H "Content-Type: application/json" \
            -d '{"status":"failed"}' &>/dev/null || true
        fi

        update_agent_status "agent_validation.sh" "available" $$ ""
      fi
    fi

    # Send heartbeat
    if command -v curl &>/dev/null; then
      curl -s -X POST "${MCP_URL}/heartbeat" \
        -H "Content-Type: application/json" \
        -d "{\"agent\": \"${AGENT_NAME}\"}" &>/dev/null || true
    fi

    sleep 60 # Check every minute
  done
}

# Handle command-line execution
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-daemon}" in
  validate | validate-all)
    run_validation "${2:-}"
    ;;
  validate-staged)
    # Validate only staged files (exclude backups)
    info "Validating staged files..."
    # Check if there are staged Swift files outside backups
    staged_swift_files=$(git diff --cached --name-only --diff-filter=ACM | grep '\.swift$' | grep -v '\.backups/' || true)
    if [[ -z "${staged_swift_files}" ]]; then
      success "No Swift files to validate (or only backup files changed)"
      exit 0
    fi
    run_validation "${WORKSPACE_ROOT}"
    ;;
  install-hook)
    install_pre_commit_hook
    ;;
  daemon)
    trap 'update_agent_status "agent_validation.sh" "stopped" $$ ""; log "Validation Agent stopping..."; exit 0' SIGTERM SIGINT
    main "$@"
    ;;
  *)
    echo "Usage: $0 {validate|validate-staged|install-hook|daemon}"
    echo ""
    echo "Commands:"
    echo "  validate         - Run full validation suite"
    echo "  validate-staged  - Validate only staged files (for pre-commit)"
    echo "  install-hook     - Install pre-commit validation hook"
    echo "  daemon           - Run as daemon (default)"
    exit 1
    ;;
  esac
fi
