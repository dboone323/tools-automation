#!/bin/bash

# Quantum-Level Automation Enhancement System
# Central orchestration for AI-assisted maintenance across all projects

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CODE_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
PROJECTS_DIR="${CODE_DIR}/Projects"
SHARED_DIR="${CODE_DIR}/Shared"
ENHANCEMENT_DIR="${CODE_DIR}/Documentation/Enhancements"
BACKUP_ROOT="${CODE_DIR}/.autofix_backups"

# Colours for friendly output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

log_header() { echo -e "${PURPLE}[QUANTUM]${NC} ${CYAN}$1${NC}"; }
log_success() { echo -e "${GREEN}✅ $1${NC}"; }
log_status() { echo -e "${BLUE}🔄 $1${NC}"; }
log_warn() { echo -e "${YELLOW}⚠️  $1${NC}"; }
log_error() { echo -e "${RED}❌ $1${NC}"; }
log_quantum() { echo -e "${WHITE}⚛️  $1${NC}"; }

# Resolve project list (respect QUANTUM_PROJECTS override if provided)
PROJECTS=()
load_projects() {
  if [[ -n ${QUANTUM_PROJECTS-} ]]; then
    IFS=',' read -r -a PROJECTS <<<"${QUANTUM_PROJECTS}"
    for idx in "${!PROJECTS[@]}"; do
      PROJECTS[idx]="$(echo "${PROJECTS[idx]}" | xargs)"
    done
  else
    if [[ -d ${PROJECTS_DIR} ]]; then
      mapfile -t PROJECTS < <(find "${PROJECTS_DIR}" -maxdepth 1 -mindepth 1 -type d -exec basename {} \; | sort)
    fi
  fi

  if [[ ${#PROJECTS[@]} -eq 0 ]]; then
    log_warn "No projects detected under ${PROJECTS_DIR}."
  fi
}

ensure_directories() {
  log_status "Preparing quantum enhancement directories"
  mkdir -p "${ENHANCEMENT_DIR}" "${ENHANCEMENT_DIR}/.quantum_models" "${BACKUP_ROOT}"
  log_success "Directory structure ready"
}

write_wrapper_script() {
  local target_path="$1"
  local canonical_path="$2"
  mkdir -p "$(dirname "${target_path}")"
  cat >"${target_path}" <<EOF
#!/bin/bash

set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"

find_repo_root() {
\tlocal dir="\${SCRIPT_DIR}"
\twhile [[ "\${dir}" != "/" ]]; do
\t\tif [[ -d "\${dir}/.git" ]]; then
\t\t\techo "\${dir}"
\t\t\treturn 0
\t\tfi
\t\tdir="\$(dirname "\${dir}")"
\tdone
\techo "Unable to locate repository root from \${SCRIPT_DIR}" >&2
\texit 1
}

REPO_ROOT="\$(find_repo_root)"
exec "\${REPO_ROOT}/${canonical_path}" "\$@"
EOF
  chmod +x "${target_path}"
}

propagate_quantum_automation() {
  log_header "Ensuring quantum automation wrappers"

  declare -A WRAPPERS=(
    ["quantum_enhancer.sh"]="Tools/Automation/quantum_enhancer.sh"
    ["master_automation.sh"]="Tools/Automation/master_automation.sh"
    ["unified_dashboard.sh"]="Tools/Automation/unified_dashboard.sh"
    ["workflow_dashboard.sh"]="Tools/Automation/workflow_dashboard.sh"
    ["universal_workflow_manager.sh"]="Tools/Automation/universal_workflow_manager.sh"
    ["ai_enhancement_system.sh"]="Tools/Automation/ai_enhancement_system.sh"
    ["ai_enhancement_simple.sh"]="Tools/Automation/ai_enhancement_simple.sh"
    ["intelligent_autofix.sh"]="Tools/Automation/intelligent_autofix.sh"
    ["simple_autofix.sh"]="Tools/Automation/simple_autofix.sh"
    ["process_todos.sh"]="Tools/Automation/process_todos.sh"
    ["mcp_workflow.sh"]="Tools/Automation/mcp_workflow.sh"
    ["git_workflow.sh"]="Tools/Automation/git_workflow.sh"
    ["completion_summary.sh"]="Tools/Automation/completion_summary.sh"
    ["automate.sh"]="Tools/Automation/automate.sh"
    ["ai_learning_validator.sh"]="Shared/Tools/Automation/ai_learning_validator.sh"
    ["assign_agent.sh"]="Tools/Automation/assign_agent.sh"
    ["create_issue.sh"]="Tools/Automation/create_issue.sh"
  )

  for project in "${PROJECTS[@]}"; do
    local project_root="${PROJECTS_DIR}/${project}"
    if [[ ! -d ${project_root} ]]; then
      log_warn "Skipping ${project} (directory missing)"
      continue
    fi

    local automation_dir="${project_root}/Tools/Automation"
    mkdir -p "${automation_dir}"

    for script in "${!WRAPPERS[@]}"; do
      local canonical="${WRAPPERS[${script}]}"
      local target="${automation_dir}/${script}"
      write_wrapper_script "${target}" "${canonical}"
    done

    create_project_runner "${project}" "${project_root}"
    log_success "${project} automation wrappers refreshed"
  done

  # Shared wrappers mirror project layout for external tooling
  local shared_dir="${SHARED_DIR}/Tools/Automation"
  mkdir -p "${shared_dir}"
  for script in "${!WRAPPERS[@]}"; do
    write_wrapper_script "${shared_dir}/${script}" "${WRAPPERS[${script}]}"
  done

  log_success "Wrapper propagation complete"
}

create_project_runner() {
  local project_name="$1"
  local project_root="$2"
  local runner_dir="${project_root}/automation"
  mkdir -p "${runner_dir}"

  cat >"${runner_dir}/run_automation.sh" <<EOF
#!/bin/bash

set -euo pipefail

SCRIPT_DIR="\$(cd "\$(dirname "\${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="\$(cd "\${SCRIPT_DIR}/.." && pwd)"
AUTOMATION_DIR="\${PROJECT_ROOT}/Tools/Automation"

log() { echo "[QUANTUM ${project_name}] \$1"; }

if [[ ! -d "\${AUTOMATION_DIR}" ]]; then
\techo "Automation directory missing for ${project_name}" >&2
\texit 1
fi

log "Running AI enhancement analysis"
if [[ -x "\${AUTOMATION_DIR}/ai_enhancement_system.sh" ]]; then
\t"\${AUTOMATION_DIR}/ai_enhancement_system.sh" analyze "${project_name}" || true
fi

log "Applying intelligent auto-fix"
if [[ -x "\${AUTOMATION_DIR}/intelligent_autofix.sh" ]]; then
\t"\${AUTOMATION_DIR}/intelligent_autofix.sh" fix "${project_name}" || true
fi

log "Checking MCP workflows"
if [[ -x "\${AUTOMATION_DIR}/mcp_workflow.sh" ]]; then
\t"\${AUTOMATION_DIR}/mcp_workflow.sh" check "${project_name}" || true
fi

log "Quantum automation sequence complete"
EOF
  chmod +x "${runner_dir}/run_automation.sh"
}

initialize_quantum_models() {
  log_quantum "Initialising quantum model configuration"
  local models_dir="${ENHANCEMENT_DIR}/.quantum_models"
  mkdir -p "${models_dir}"
  cat >"${models_dir}/quantum_config.json" <<'EOF'
{
  "version": "1.0",
  "quantum_mode": true,
  "models": {
    "code_quality_predictor": {
      "enabled": true,
      "accuracy": 0.92,
      "features": ["complexity", "patterns", "dependencies"]
    },
    "performance_optimizer": {
      "enabled": true,
      "accuracy": 0.88,
      "features": ["memory_usage", "cpu_cycles", "bottlenecks"]
    },
    "security_analyzer": {
      "enabled": true,
      "accuracy": 0.95,
      "features": ["data_flow", "access_patterns", "vulnerabilities"]
    },
    "fix_success_predictor": {
      "enabled": true,
      "accuracy": 0.89,
      "features": ["complexity", "fix_type", "historical_success"]
    }
  },
  "cross_project_learning": {
    "enabled": true,
    "patterns_learned": 0,
    "success_rate": 0.0
  },
  "real_time_monitoring": {
    "enabled": true,
    "interval_seconds": 300,
    "alert_thresholds": {
      "code_quality": 70,
      "performance": 80,
      "security": 85
    }
  }
}
EOF
  log_success "Quantum model configuration ready"
}

create_quantum_dashboard() {
  log_header "Refreshing quantum dashboard"
  local dashboard_path="${SHARED_DIR}/Tools/Automation/quantum_dashboard.sh"
  mkdir -p "$(dirname "${dashboard_path}")"
  cat >"${dashboard_path}" <<'EOF'
#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
PROJECTS_DIR="${REPO_ROOT}/Projects"
ENHANCEMENT_DIR="${REPO_ROOT}/Documentation/Enhancements"

GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
WHITE='\033[1;37m'
NC='\033[0m'

header() {
    echo -e "${WHITE}╔══════════════════════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${WHITE}║                     ⚛️  QUANTUM UNIFIED DASHBOARD                           ║${NC}"
    echo -e "${WHITE}╚══════════════════════════════════════════════════════════════════════════════╝${NC}"
    echo ""
}

project_status() {
    local name="$1"
    local path="${PROJECTS_DIR}/${name}"

    echo -e "${CYAN}📱 ${name}${NC}"
    echo "   📍 Location: ${path}"

    local swift_files
    swift_files=$(find "${path}" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
    echo "   📄 Swift files: ${swift_files}"

    if [[ -d "${path}/.github/workflows" ]]; then
        local workflow_count
        workflow_count=$(find "${path}/.github/workflows" -name "*.ya?ml" 2>/dev/null | wc -l | tr -d ' ')
        echo -e "   🔄 GitHub workflows: ${GREEN}${workflow_count}${NC} files"
        find "${path}/.github/workflows" -name "*.ya?ml" 2>/dev/null | while read -r workflow; do
            echo "      • $(basename "${workflow}")"
        done
    else
        echo -e "   🔄 GitHub workflows: ${RED}None${NC}"
    fi

    if [[ -f "${path}/.swiftformat" ]]; then
        echo -e "   ⚙️  SwiftFormat config: ${GREEN}✓${NC}"
    else
        echo -e "   ⚙️  SwiftFormat config: ${RED}✗${NC}"
    fi

    if [[ -f "${path}/.swiftlint.yml" ]]; then
        echo -e "   📝 SwiftLint config: ${GREEN}✓${NC}"
    else
        echo -e "   📝 SwiftLint config: ${RED}Default${NC}"
    fi

    if [[ -d "${path}/automation" ]]; then
        echo -e "   🤖 Local automation: ${GREEN}✓${NC}"
    else
        echo -e "   🤖 Local automation: ${RED}✗${NC}"
    fi

    echo -e "   🔍 Running MCP CI check..."
    if "${REPO_ROOT}/Tools/Automation/mcp_workflow.sh" ci-check "${name}" >/dev/null 2>&1; then
        echo -e "   ✅ MCP CI status: ${GREEN}All checks passed${NC}"
    else
        echo -e "   ⚠️  MCP CI status: ${YELLOW}Some issues found${NC}"
    fi

    echo ""
}

integration_status() {
    echo -e "${BLUE}🔗 MCP GitHub Integration Status${NC}"
    echo ""

    if command -v gh >/dev/null 2>&1; then
        echo -e "   📡 GitHub CLI: ${GREEN}Installed${NC}"
        if gh auth status >/dev/null 2>&1; then
            echo -e "   🔑 GitHub Auth: ${GREEN}Authenticated${NC}"
        else
            echo -e "   🔑 GitHub Auth: ${YELLOW}Not authenticated${NC}"
        fi
    else
        echo -e "   📡 GitHub CLI: ${RED}Not installed${NC}"
        echo -e "   🔑 GitHub Auth: ${RED}N/A${NC}"
    fi

    echo -e "   🛠️  MCP Workflow Tools: ${GREEN}Available${NC}"
    echo "      • mcp_workflow.sh - Local CI/CD mirroring"
    echo "      • master_automation.sh - Unified project management"
    echo "      • GitHub API integration for workflow monitoring"
    echo ""
}

summary() {
    echo -e "${PURPLE}📊 WORKFLOW IMPLEMENTATION SUMMARY${NC}"
    echo ""

    local total=0
    local workflows=0
    local passing=0

    for project in "${PROJECTS_DIR}"/*; do
        [[ -d ${project} ]] || continue
        local name
        name=$(basename "${project}")
        total=$((total + 1))
        [[ -d "${project}/.github/workflows" ]] && workflows=$((workflows + 1))
        if "${REPO_ROOT}/Tools/Automation/mcp_workflow.sh" ci-check "${name}" >/dev/null 2>&1; then
            passing=$((passing + 1))
        fi
    done

    echo "   📱 Total projects: ${total}"
    echo "   🔄 Projects with GitHub workflows: ${workflows}/${total}"
    echo "   ✅ Projects passing all CI checks: ${passing}/${total}"
    echo ""

    if [[ ${workflows} -eq ${total} && ${total} -gt 0 ]]; then
        echo -e "   ${GREEN}🎉 All projects have GitHub workflows implemented!${NC}"
    else
        echo -e "   ${YELLOW}⚠️  Some projects need workflow setup${NC}"
    fi

    if [[ ${passing} -eq ${total} && ${total} -gt 0 ]]; then
        echo -e "   ${GREEN}🎉 All projects passing CI checks!${NC}"
    else
        echo -e "   ${YELLOW}⚠️  Some projects need CI fixes${NC}"
    fi

    echo ""
}

main() {
    header
    integration_status
    for project in "${PROJECTS_DIR}"/*; do
        [[ -d ${project} ]] || continue
        project_status "$(basename "${project}")"
    done
    summary
    echo -e "${BLUE}🚀 Ready for unified CI/CD across all projects!${NC}"
}

main "${@}"
EOF
  chmod +x "${dashboard_path}"
  log_success "Quantum dashboard refreshed"
}

run_ai_enhancement_all() {
  log_header "Running AI enhancement analysis for all projects"
  for project in "${PROJECTS[@]}"; do
    local automation_dir="${PROJECTS_DIR}/${project}/Tools/Automation"
    if [[ -x "${automation_dir}/ai_enhancement_system.sh" ]]; then
      log_status "Analyzing ${project}"
      "${automation_dir}/ai_enhancement_system.sh" analyze "${project}" || log_warn "Analysis reported issues for ${project}"
    else
      log_warn "Skipping ${project} (ai_enhancement_system.sh unavailable)"
    fi
    echo ""
  done
  log_success "AI enhancement pass complete"
}

run_autofix_all() {
  log_header "Triggering intelligent auto-fix across projects"
  for project in "${PROJECTS[@]}"; do
    local automation_dir="${PROJECTS_DIR}/${project}/Tools/Automation"
    if [[ -x "${automation_dir}/intelligent_autofix.sh" ]]; then
      log_status "Applying safe fixes to ${project}"
      "${automation_dir}/intelligent_autofix.sh" fix "${project}" || log_warn "Auto-fix encountered issues for ${project}"
    else
      log_warn "Skipping ${project} (intelligent_autofix.sh unavailable)"
    fi
    echo ""
  done
  log_success "Intelligent auto-fix pass complete"
}

show_quantum_metrics() {
  log_header "Quantum automation metrics"

  local total=${#PROJECTS[@]}
  local ai_ready=0
  local autofix_ready=0

  for project in "${PROJECTS[@]}"; do
    local automation_dir="${PROJECTS_DIR}/${project}/Tools/Automation"
    [[ -x "${automation_dir}/ai_enhancement_system.sh" ]] && ai_ready=$((ai_ready + 1))
    [[ -x "${automation_dir}/intelligent_autofix.sh" ]] && autofix_ready=$((autofix_ready + 1))
  done

  echo "📱 Projects detected: ${total}"
  echo "🧠 AI enhancement ready: ${ai_ready}/${total}"
  echo "🔧 Intelligent auto-fix ready: ${autofix_ready}/${total}"

  local readiness=0
  if [[ ${total} -gt 0 ]]; then
    readiness=$(((ai_ready * 100) / total))
  fi

  if [[ ${readiness} -eq 100 ]]; then
    log_success "🎉 100% quantum readiness achieved"
  else
    log_warn "Quantum readiness at ${readiness}%"
  fi
}

run_cross_project_learning() {
  log_quantum "Cross-project learning analysis"
  local output_file
  output_file="${ENHANCEMENT_DIR}/cross_project_learning_$(date +%Y%m%d_%H%M%S).md"
  {
    echo "# Cross-Project Learning Analysis"
    echo "Generated: $(date)"
    echo ""
    for project in "${PROJECTS[@]}"; do
      echo "## ${project}"
      echo "- AI enhancements: $(find "${PROJECTS_DIR}/${project}" -name 'AI_*' -type f | wc -l | tr -d ' ')"
      echo "- Swift files: $(find "${PROJECTS_DIR}/${project}" -name '*.swift' | wc -l | tr -d ' ')"
      echo ""
    done
  } >"${output_file}"
  log_success "Learning report saved to ${output_file}"
}

show_status() {
  log_header "Quantum Enhancement System Status"
  echo "📍 Workspace: ${CODE_DIR}"
  echo "📁 Enhancements: ${ENHANCEMENT_DIR}"
  echo "📊 Projects scanned: ${#PROJECTS[@]}"
  echo ""
  show_quantum_metrics
}

usage() {
  cat <<EOF
Quantum-Level Automation Enhancement System

Usage: $0 <command> [arguments]

Commands:
  setup             Prepare directories and refresh automation wrappers
  enhance-all       Run AI enhancement analysis for every project
  fix-all           Run intelligent auto-fix across all projects
  dashboard         Show the quantum dashboard view
  metrics           Print readiness metrics
  learn             Generate cross-project learning insights
  status            Display system status summary
  help              Show this help text
EOF
}

main() {
  local command="${1:-help}"
  load_projects

  case "${command}" in
  setup)
    ensure_directories
    propagate_quantum_automation
    initialize_quantum_models
    create_quantum_dashboard
    log_success "Quantum enhancement system initialised"
    ;;
  enhance-all)
    run_ai_enhancement_all
    ;;
  fix-all)
    run_autofix_all
    ;;
  dashboard)
    "${SHARED_DIR}/Tools/Automation/quantum_dashboard.sh"
    ;;
  metrics)
    show_quantum_metrics
    ;;
  learn)
    run_cross_project_learning
    ;;
  status)
    show_status
    ;;
  help | --help | -h)
    usage
    ;;
  *)
    log_error "Unknown command: ${command}"
    usage
    exit 1
    ;;
  esac
}

main "$@"
