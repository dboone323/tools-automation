#!/bin/bash

# Workflow Status Dashboard - Complete overview of development environment
CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
RED='\033[0;31m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m'

print_header() {
  printf "%b\n" "${CYAN}╔══════════════════════════════════════════════════════════════════════╗${NC}"
  printf "%b\n" "${CYAN}║${NC}              🚀 ENHANCED DEVELOPMENT WORKFLOWS DASHBOARD              ${CYAN}║${NC}"
  printf "%b\n\n" "${CYAN}╚══════════════════════════════════════════════════════════════════════╝${NC}"
}

print_section() {
  printf "%b\n" "${BLUE}📋 $1${NC}"
  printf "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━\n"
}

check_tool() {
  local tool_name="$1"
  local tool_command="$2"

  if command -v "${tool_command}" &>/dev/null; then
    local version_output
    version_output=$(${tool_command} --version 2>/dev/null | head -n 1)
    if [[ -n ${version_output} ]]; then
      printf "  ✅ %b%b%b (%s)\n" "${GREEN}" "${tool_name}" "${NC}" "${version_output}"
    else
      printf "  ✅ %b%b%b\n" "${GREEN}" "${tool_name}" "${NC}"
    fi
    return 0
  fi

  printf "  ❌ %b%b%b - Not installed\n" "${RED}" "${tool_name}" "${NC}"
  return 1
}

check_project_status() {
  local project_path="$1"
  local project_name
  project_name=$(basename "${project_path}")

  [[ -d ${project_path} ]] || return 1

  (
    cd "${project_path}" || exit 1

    local swift_files test_files total_lines
    swift_files=$(find . -type f -name "*.swift" | wc -l | tr -d ' ')
    test_files=$(find . -type f \( -name "*Tests*.swift" -o -name "*Test*.swift" \) | wc -l | tr -d ' ')
    total_lines=$(find . -type f -name "*.swift" -exec wc -l {} + 2>/dev/null | awk '{sum += $1} END {print sum+0}')

    local git_status git_branch
    git_status="❌ Not a Git repo"
    git_branch=""
    if git rev-parse --git-dir >/dev/null 2>&1; then
      git_branch=$(git branch --show-current 2>/dev/null || echo "detached")
      local changes
      changes=$(git status --porcelain | wc -l | tr -d ' ')
      if [[ ${changes} -eq 0 ]]; then
        git_status="✅ Clean (${git_branch})"
      else
        git_status="⚠️ ${changes} changes (${git_branch})"
      fi
    fi

    local lint_status
    if command -v swiftlint &>/dev/null; then
      if swiftlint --quiet >/dev/null 2>&1; then
        lint_status="✅ Clean"
      else
        lint_status="⚠️ Violations detected"
      fi
    else
      lint_status="❓ SwiftLint unavailable"
    fi

    printf "  %b%s%b\n" "${PURPLE}" "${project_name}" "${NC}"
    printf "     📊 Files: %s Swift | %s Test | %s total lines\n" "${swift_files}" "${test_files}" "${total_lines}"
    printf "     🌿 Git: %s\n" "${git_status}"
    printf "     🔍 Lint: %s\n\n" "${lint_status}"
  )
}

workflow_status_dashboard() {
  print_header

  print_section "Development Tools Status"
  check_tool "SwiftFormat" "swiftformat"
  check_tool "SwiftLint" "swiftlint"
  check_tool "Fastlane" "fastlane"
  check_tool "CocoaPods" "pod"
  check_tool "Xcode Build Tools" "xcodebuild"
  check_tool "Git" "git"
  check_tool "Swift" "swift"
  printf "\n"

  print_section "Configuration Files"

  local swiftformat_config="${CODE_DIR}/.swiftformat"
  if [[ -f ${swiftformat_config} ]]; then
    printf "  ✅ %b.swiftformat%b - Configuration present\n" "${GREEN}" "${NC}"
  else
    printf "  ❌ %b.swiftformat%b - Configuration missing\n" "${RED}" "${NC}"
  fi

  local automation_script="${CODE_DIR}/Tools/Automation/master_automation.sh"
  if [[ -f ${automation_script} ]]; then
    printf "  ✅ %bmaster_automation.sh%b - Available\n" "${GREEN}" "${NC}"
  else
    printf "  ❌ %bmaster_automation.sh%b - Missing\n" "${RED}" "${NC}"
  fi

  local enhanced_workflow="${CODE_DIR}/Tools/Automation/enhanced_workflow.sh"
  if [[ -f ${enhanced_workflow} ]]; then
    printf "  ✅ %benhanced_workflow.sh%b - Available\n" "${GREEN}" "${NC}"
  else
    printf "  ❌ %benhanced_workflow.sh%b - Missing\n" "${RED}" "${NC}"
  fi

  local git_workflow="${CODE_DIR}/Tools/Automation/git_workflow.sh"
  if [[ -f ${git_workflow} ]]; then
    printf "  ✅ %bgit_workflow.sh%b - Available\n" "${GREEN}" "${NC}"
  else
    printf "  ❌ %bgit_workflow.sh%b - Missing\n" "${RED}" "${NC}"
  fi
  printf "\n"

  print_section "Projects Overview"

  local projects_found=0
  for project_dir in "${CODE_DIR}/Projects"/*; do
    if [[ -d ${project_dir} ]]; then
      check_project_status "${project_dir}"
      ((projects_found++))
    fi
  done

  if [[ ${projects_found} -eq 0 ]]; then
    printf "  ❌ No projects found in %s/Projects/\n\n" "${CODE_DIR}"
  fi

  print_section "Available Workflow Commands"
  printf "  🔧 %bMaster Automation:%b\n" "${BLUE}" "${NC}"
  printf "     ./Tools/Automation/master_automation.sh {list|run|all|status|format|lint|pods|fastlane|workflow}\n\n"
  printf "  ⚡ %bEnhanced Workflows:%b\n" "${BLUE}" "${NC}"
  printf "     ./Tools/Automation/enhanced_workflow.sh {pre-commit|ios-setup|qa|deps} <project>\n\n"
  printf "  🌿 %bGit Workflows:%b\n" "${BLUE}" "${NC}"
  printf "     ./Tools/Automation/git_workflow.sh {smart-commit|feature|release|status}\n\n"
}

workflow_status_dashboard "$@"
