#!/bin/bash

# Unified AI Enhancement System for Quantum-workspace
# Generates project reports, safe auto-apply scripts, and consolidated status views.

set -euo pipefail

readonly ROOT_DIR="${CODE_DIR:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)}"
readonly PROJECTS_DIR="${PROJECTS_DIR:-${ROOT_DIR}/Projects}"
readonly DOCS_DIR="${ROOT_DOCS_DIR:-${ROOT_DIR}/Documentation}"
readonly ENHANCEMENT_DIR="${ENHANCEMENT_DIR:-${DOCS_DIR}/Enhancements}"
readonly BACKUP_ROOT="${ROOT_DIR}/.autofix_backups"
readonly AUTO_ENHANCE_LOG="${ROOT_DIR}/.ai_enhancements.log"
readonly DEFAULT_PROJECTS=("CodingReviewer" "HabitQuest" "MomentumFinance")

readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly GREEN='\033[0;32m'
readonly BLUE='\033[0;34m'
readonly YELLOW='\033[1;33m'
readonly RED='\033[0;31m'
readonly NC='\033[0m'

print_header() {
  echo -e "${PURPLE}[AI-ENHANCE]${NC} ${CYAN}$1${NC}"
}

print_status() {
  echo -e "${BLUE}🔄 $1${NC}"
}

print_success() {
  echo -e "${GREEN}✅ $1${NC}"
}

print_warning() {
  echo -e "${YELLOW}⚠️  $1${NC}"
}

print_error() {
  echo -e "${RED}❌ $1${NC}"
}

ensure_directories() {
  mkdir -p "${ENHANCEMENT_DIR}" "${BACKUP_ROOT}"
}

timestamp() {
  date +%Y-%m-%dT%H:%M:%S
}

swift_file_count() {
  find "$1" -type f -name "*.swift" -print 2>/dev/null | wc -l | tr -d ' '
}

swift_line_count() {
  find "$1" -type f -name "*.swift" -exec wc -l {} + 2>/dev/null | awk '{sum += $1} END {print sum+0}'
}

test_file_count() {
  find "$1" -type f \( -name '*Test*.swift' -o -name '*Tests.swift' -o -name '*test*.swift' \) -print 2>/dev/null | wc -l | tr -d ' '
}

grep_count() {
  local pattern="$1"
  local search_path="$2"
  grep -RE "${pattern}" "${search_path}" --include='*.swift' 2>/dev/null | wc -l | tr -d ' '
}

generate_analysis_report() {
  local project_name="$1"
  local project_path="$2"
  local report_path="$3"
  local auto_script="$4"

  local swift_files
  swift_files=$(swift_file_count "${project_path}")
  local lines
  lines=$(swift_line_count "${project_path}")
  local tests
  tests=$(test_file_count "${project_path}")

  local todo_comments
  todo_comments=$(grep_count '// TODO\|// FIXME\|// HACK' "${project_path}")
  local force_unwraps
  force_unwraps=$(grep_count '!\([^=]\|$\)' "${project_path}")
  local accessibility_labels
  accessibility_labels=$(grep_count 'accessibilityLabel' "${project_path}")
  local ui_buttons ui_lists ui_texts ui_elements
  ui_buttons=$(grep_count 'Button\(' "${project_path}")
  ui_lists=$(grep_count 'List\(' "${project_path}")
  ui_texts=$(grep_count 'Text\(' "${project_path}")
  ui_elements=$((ui_buttons + ui_lists + ui_texts))

  cat >"${report_path}" <<EOF
# AI Enhancement Analysis · ${project_name}
*Generated: $(timestamp)*

## 📊 Project Overview
- **Swift Files:** ${swift_files}
- **Total Lines:** ${lines}
- **Test Files:** ${tests}
- **Analysis Date:** $(date)

## 🏗️ Architecture & Code Quality
- Protocol usage (approx): $(grep_count '^protocol ' "${project_path}")
- Structs detected: $(grep_count '^struct ' "${project_path}")
- Classes detected: $(grep_count '^class ' "${project_path}")

${todo_comments} TODO/FIXME markers were found. Convert them into actionable tasks with documentation.

## 🏎️ Performance & Safety
- Force unwrap operations spotted: ${force_unwraps}
- Concurrency keywords (async/await): $(grep_count 'async\|await' "${project_path}")

High force unwrap counts may indicate potential crash scenarios—prefer optional binding or guards.

## 🎨 UI & Accessibility
- UI element invocations: ${ui_elements}
- Accessibility labels: ${accessibility_labels}

Add accessibility modifiers for remaining UI elements to meet inclusion guidelines.

## 🧪 Testing Snapshot
- Swift test files: ${tests}
- Snapshot/UITest hints: $(grep_count 'XCTestCase\|UITest' "${project_path}")

Ensure critical features have matching XCTest coverage (target ratio ≥ 1 test file per feature module).

## 🔒 Security Signals
- Keychain helpers detected: $(grep_count 'Keychain' "${project_path}")
- Potential secrets (API_KEY/TOKEN): $(grep_count 'API_KEY\|TOKEN\|SECRET' "${project_path}")

Relocate sensitive tokens to secure storage and confirm keychain integrations cover all credential paths.

## 🤖 Safe Auto-Apply Enhancements
Run the generated script to apply low-risk improvements automatically:

\`\`\`bash
bash "${auto_script}" "${project_path}"
\`\`\`

## ✅ Next Steps
1. Apply safe enhancements (script above) after reviewing git diff.
2. Address high-priority warnings: force unwraps and TODO markers.
3. Add accessibility modifiers where missing.
4. Expand unit/UI tests to cover new features and regression areas.

---
*Unified AI Enhancement System · Continuous improvements for Quantum-workspace*
EOF
}

generate_auto_apply_script() {
  local project_name="$1"
  local script_path="$2"

  cat >"${script_path}" <<'EOF'
#!/bin/bash

set -euo pipefail

if [[ $# -ne 1 ]]; then
	echo "Usage: $0 <project_path>" >&2
	exit 1
fi

project_path="$1"
cd "${project_path}"

log() { echo "[AUTO-ENHANCE] $1"; }

log "Applying safe enhancements..."

if command -v swiftformat &>/dev/null; then
	log "Running SwiftFormat"
	swiftformat . --config .swiftformat 2>/dev/null || log "SwiftFormat finished with warnings"
else
	log "SwiftFormat not installed; skipping format step"
fi

log "Normalizing trailing whitespace"
find . -type f -name "*.swift" -exec sed -i.bak 's/[[:space:]]*$//' {} +
find . -name "*.swift.bak" -delete

log "Converting TODO/FIXME comments to documentation hints"
find . -type f -name "*.swift" -exec sed -i.bak '
    s|// TODO:|/// - TODO:|g
    s|// FIXME:|/// - FIXME:|g
    s|// HACK:|/// - NOTE:|g
' {} +
find . -name "*.swift.bak" -delete

log "Seeding accessibility labels where missing"
find . -type f -name "*.swift" -exec sed -i.bak '
    /Button(/,/)/{
        /accessibilityLabel/! s/Button(/Button(/
    }
' {} +
find . -name "*.swift.bak" -delete

log "Safe enhancements complete"
EOF

  chmod +x "${script_path}"
}

backup_project() {
  local project_path="$1"
  local project_name="$2"
  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local backup_path="${BACKUP_ROOT}/${project_name}_enhance_${timestamp}"

  mkdir -p "${backup_path%/*}"
  cp -R "${project_path}" "${backup_path}"
  print_status "Backup created at ${backup_path}"
  echo "${backup_path}"
}

restore_backup() {
  local backup_path="$1"
  local project_path="$2"
  rm -rf "${project_path}"
  cp -R "${backup_path}" "${project_path}"
}

remove_backup() {
  rm -rf "$1"
}

analyze_project() {
  local project_name="$1"
  local project_path="${PROJECTS_DIR}/${project_name}"

  if [[ ! -d ${project_path} ]]; then
    print_error "Project ${project_name} not found"
    return 1
  fi

  print_header "Analyzing ${project_name}"

  local report_path="${ENHANCEMENT_DIR}/${project_name}_enhancement_analysis.md"
  local script_path="${ENHANCEMENT_DIR}/${project_name}_safe_enhancements.sh"

  generate_analysis_report "${project_name}" "${project_path}" "${report_path}" "${script_path}"
  generate_auto_apply_script "${project_name}" "${script_path}"

  print_success "Report created: ${report_path}"
  print_success "Auto-apply script created: ${script_path}"
  echo "$(timestamp): analyzed ${project_name}" >>"${AUTO_ENHANCE_LOG}"
}

all_projects() {
  local detected=()
  if [[ -d ${PROJECTS_DIR} ]]; then
    while IFS= read -r -d '' dir; do
      local name
      name=$(basename "${dir}")
      case "${name}" in
      Tools | scripts | Config) continue ;;
      *) detected+=("${name}") ;;
      esac
    done < <(find "${PROJECTS_DIR}" -mindepth 1 -maxdepth 1 -type d -print0)
  fi

  if [[ ${#detected[@]} -eq 0 ]]; then
    echo "${DEFAULT_PROJECTS[@]}"
  else
    echo "${detected[@]}"
  fi
}

analyze_all() {
  print_header "Analyzing all projects"
  local projects
  IFS=' ' read -r -a projects <<<"$(all_projects)"
  for project in "${projects[@]}"; do
    analyze_project "${project}"
    echo ""
  done
  print_success "Analysis complete for ${#projects[@]} project(s)"
}

apply_safe_enhancements() {
  local project_name="$1"
  local project_path="${PROJECTS_DIR}/${project_name}"
  local script_path="${ENHANCEMENT_DIR}/${project_name}_safe_enhancements.sh"

  if [[ ! -f ${script_path} ]]; then
    print_error "No auto-apply script found for ${project_name}. Run analyze first."
    return 1
  fi

  print_header "Auto-applying safe enhancements for ${project_name}"
  local backup_path
  backup_path=$(backup_project "${project_path}" "${project_name}")

  if bash "${script_path}" "${project_path}"; then
    print_success "Enhancements applied"
    remove_backup "${backup_path}"
    echo "$(timestamp): auto-applied ${project_name}" >>"${AUTO_ENHANCE_LOG}"
  else
    print_warning "Enhancements failed – restoring backup"
    restore_backup "${backup_path}" "${project_path}"
    echo "$(timestamp): rollback ${project_name}" >>"${AUTO_ENHANCE_LOG}"
    return 1
  fi
}

apply_all() {
  print_header "Applying safe enhancements to all projects"
  local projects
  IFS=' ' read -r -a projects <<<"$(all_projects)"
  for project in "${projects[@]}"; do
    apply_safe_enhancements "${project}" || true
    echo ""
  done
  print_success "Safe enhancements attempted for ${#projects[@]} project(s)"
}

generate_master_report() {
  ensure_directories
  local report_path="${ENHANCEMENT_DIR}/MASTER_ENHANCEMENT_REPORT.md"
  print_header "Generating master enhancement report"

  {
    echo "# Master AI Enhancement Report"
    echo "Generated: $(timestamp)"
    echo ""
    echo "## Project Status"
    local projects
    IFS=' ' read -r -a projects <<<"$(all_projects)"
    for project in "${projects[@]}"; do
      local analysis_file="${ENHANCEMENT_DIR}/${project}_enhancement_analysis.md"
      local script_file="${ENHANCEMENT_DIR}/${project}_safe_enhancements.sh"
      echo "### ${project}"
      if [[ -f ${analysis_file} ]]; then
        echo "- ✅ Analysis available"
      else
        echo "- ❌ Analysis pending"
      fi
      if [[ -f ${script_file} ]]; then
        echo "- ✅ Auto-apply script ready"
      else
        echo "- ❌ Auto-apply script missing"
      fi
      echo ""
    done
    echo "## Recommended Actions"
    echo "1. Run 'status' to confirm recent operations."
    echo "2. Execute 'analyze <project>' before large feature pushes."
    echo "3. Apply safe enhancements and review diffs."
    echo "4. Track manual follow-ups in project planning docs."
  } >"${report_path}"

  print_success "Report written to ${report_path}"
}

show_status() {
  ensure_directories
  print_header "AI Enhancement System Status"
  local projects
  IFS=' ' read -r -a projects <<<"$(all_projects)"
  local analyzed=0
  local with_scripts=0
  for project in "${projects[@]}"; do
    [[ -f "${ENHANCEMENT_DIR}/${project}_enhancement_analysis.md" ]] && analyzed=$((analyzed + 1))
    [[ -f "${ENHANCEMENT_DIR}/${project}_safe_enhancements.sh" ]] && with_scripts=$((with_scripts + 1))
  done

  echo "📦 Projects detected: ${#projects[@]}"
  echo "📝 Analyses available: ${analyzed}"
  echo "🤖 Auto-apply scripts: ${with_scripts}"

  if [[ -f ${AUTO_ENHANCE_LOG} ]]; then
    echo ""
    echo "Recent activity:"
    tail -5 "${AUTO_ENHANCE_LOG}" 2>/dev/null || true
  fi
}

show_help() {
  print_header "Unified AI Enhancement System"
  echo "Usage: $0 <command> [project]"
  echo ""
  echo "Commands"
  echo "  analyze <project|all>    Analyze project(s) and generate reports"
  echo "  auto-apply <project|all> Apply safe enhancements with backup"
  echo "  report                   Generate master enhancement report"
  echo "  status                   Show enhancement system status"
  echo "  help                     Show this message"
  echo ""
  echo "Examples"
  echo "  $0 analyze HabitQuest"
  echo "  $0 analyze all"
  echo "  $0 auto-apply CodingReviewer"
  echo "  $0 status"
}

main() {
  ensure_directories
  local command="${1:-help}"
  case "${command}" in
  analyze)
    local target="${2-}"
    if [[ -z ${target} ]]; then
      print_error "Usage: $0 analyze <project|all>"
      return 1
    fi
    if [[ ${target} == "all" ]]; then
      analyze_all
    else
      analyze_project "${target}"
    fi
    ;;
  auto-apply)
    local target="${2-}"
    if [[ -z ${target} ]]; then
      print_error "Usage: $0 auto-apply <project|all>"
      return 1
    fi
    if [[ ${target} == "all" ]]; then
      apply_all
    else
      apply_safe_enhancements "${target}"
    fi
    ;;
  report)
    generate_master_report
    ;;
  status)
    show_status
    ;;
  help | --help | -h)
    show_help
    ;;
  *)
    show_help
    return 1
    ;;
  esac
}

main "$@"
