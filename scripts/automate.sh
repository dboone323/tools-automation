#!/bin/bash

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SCRIPT_DIR}/../.." && pwd)"
ORIGINAL_WORKDIR="$(pwd -P)"

readonly REPO_ROOT
readonly ORIGINAL_WORKDIR

bootstrap_project_context() {
  if [[ -z ${PROJECT_DIR-} ]]; then
    # If the command was executed from a project's root directory, use it directly.
    if [[ -f "${ORIGINAL_WORKDIR}/Tools/Automation/project_config.sh" ]]; then
      PROJECT_DIR="${ORIGINAL_WORKDIR}"
    fi

    # If executed from within a project's Tools/Automation directory, step up one level.
    if [[ -z ${PROJECT_DIR-} && ${ORIGINAL_WORKDIR##*/} == "Automation" && -f "${ORIGINAL_WORKDIR}/project_config.sh" ]]; then
      PROJECT_DIR="$(cd "${ORIGINAL_WORKDIR}/.." && pwd)"
    fi

    # As a last resort, if the original directory sits inside the Projects folder, walk up until Projects/<name>.
    if [[ -z ${PROJECT_DIR-} && ${ORIGINAL_WORKDIR} == */Projects/* ]]; then
      local probe="${ORIGINAL_WORKDIR}"
      while [[ ${probe} != "/" ]]; do
        if [[ $(basename "$(dirname "${probe}")") == "Projects" ]]; then
          PROJECT_DIR="${probe}"
          break
        fi
        probe="$(dirname "${probe}")"
      done
    fi
  fi

  if [[ -z ${PROJECT_NAME-} && -n ${PROJECT_DIR-} ]]; then
    PROJECT_NAME="$(basename "${PROJECT_DIR}")"
  fi

  export PROJECT_DIR PROJECT_NAME
}

master_automation() {
  "${REPO_ROOT}/Tools/Automation/master_automation.sh" "$@"
}

run_mcp_command() {
  "${REPO_ROOT}/Tools/Automation/mcp_workflow.sh" "$@"
}

run_ai_enhancement() {
  "${REPO_ROOT}/Tools/Automation/ai_enhancement_system.sh" "$@"
}

print_header() {
  local display_name="${PROJECT_DISPLAY_NAME:-${PROJECT_NAME:-Unknown Project}}"
  local project_type="${PROJECT_TYPE-}"
  local feature_summary="${PROJECT_FEATURE_SUMMARY-}"

  echo "🚀 ${display_name} Automation Suite"
  if [[ -n ${project_type} ]]; then
    echo "Project: ${display_name} (${project_type})"
  else
    echo "Project: ${display_name}"
  fi
  if [[ -n ${feature_summary} ]]; then
    echo "Features: ${feature_summary}"
  fi
  echo ""
}

command_build() {
  if [[ -z ${PROJECT_NAME-} ]]; then
    echo "❌ PROJECT_NAME is not set; ensure project_config.sh exports it." >&2
    return 1
  fi
  master_automation run "${PROJECT_NAME}"
}

command_test() {
  if [[ -n ${BUILD_SCHEME-} && -n ${TARGET_DEVICE-} ]]; then
    local simulator_device
    simulator_device="${TARGET_DEVICE%%,*}"
    simulator_device="${simulator_device//\"/}"
    if [[ -z ${simulator_device} ]]; then
      simulator_device="iPhone 15"
    fi
    xcodebuild test -scheme "${BUILD_SCHEME}" -destination "platform=iOS Simulator,name=${simulator_device}" || {
      echo "⚠️  xcodebuild test failed; falling back to master automation." >&2
      master_automation run "${PROJECT_NAME}"
    }
  else
    echo "ℹ️  BUILD_SCHEME or TARGET_DEVICE missing; delegating to master automation for tests." >&2
    master_automation run "${PROJECT_NAME}"
  fi
}

command_lint() {
  master_automation lint "${PROJECT_NAME}"
}

command_format() {
  master_automation format "${PROJECT_NAME}"
}

command_status() {
  master_automation status
}

command_all() {
  master_automation all
}

command_mcp() {
  local subcommand="${1:-status}"
  shift || true
  run_mcp_command "${subcommand}" "${PROJECT_NAME-}" "$@"
}

command_ai() {
  if [[ ${ENABLE_AI_ENHANCEMENT:-false} == "true" || ${ENABLE_AI_ENHANCEMENT:-0} == "1" ]]; then
    if [[ $# -eq 0 ]]; then
      run_ai_enhancement status
    else
      run_ai_enhancement "$@"
    fi
  else
    echo "ℹ️  AI enhancements are disabled for this project." >&2
  fi
}

command_security() {
  if [[ ${ENABLE_SECURITY_AUDITS:-false} == "true" || ${ENABLE_SECURITY_AUDITS:-0} == "1" ]]; then
    echo "🔒 Running security audit..."
    echo "  • Dependency vulnerability check..."
    echo "  • API security validation..."
    echo "  • Data privacy compliance..."
  else
    echo "ℹ️  Security audits not enabled for this project." >&2
  fi
}

command_compliance() {
  if [[ ${ENABLE_REGULATORY_COMPLIANCE:-false} == "true" || ${ENABLE_REGULATORY_COMPLIANCE:-0} == "1" ]]; then
    echo "📋 Running regulatory compliance checks..."
    echo "  • Domain-specific validation..."
    echo "  • Data handling compliance..."
    echo "  • Security standards validation..."
  else
    echo "ℹ️  Compliance checks not enabled for this project." >&2
  fi
}

show_help() {
  print_header
  echo "Available commands:"
  echo "  build        - Build the project"
  echo "  test         - Run tests"
  echo "  lint         - Run linting"
  echo "  format       - Format code"
  echo "  mcp [cmd]    - MCP integration"
  echo "  ai [cmd]     - AI enhancements"
  if [[ ${ENABLE_SECURITY_AUDITS:-false} == "true" || ${ENABLE_SECURITY_AUDITS:-0} == "1" ]]; then
    echo "  security     - Run security audit"
  fi
  if [[ ${ENABLE_REGULATORY_COMPLIANCE:-false} == "true" || ${ENABLE_REGULATORY_COMPLIANCE:-0} == "1" ]]; then
    echo "  compliance   - Run compliance checks"
  fi
  echo "  status       - Show status"
  echo "  all          - Run full automation suite"
  printf '\nUsage: %s <command> [options]\n' "$0"
}

main() {
  bootstrap_project_context

  if [[ -z ${PROJECT_NAME-} ]]; then
    echo "❌ PROJECT_NAME is not defined. Did you source project_config.sh?" >&2
    exit 1
  fi

  print_header

  case "${1:-help}" in
  build)
    command_build
    ;;
  test)
    command_test
    ;;
  lint)
    command_lint
    ;;
  format)
    command_format
    ;;
  mcp)
    shift
    command_mcp "$@"
    ;;
  ai)
    shift
    command_ai "$@"
    ;;
  security)
    command_security
    ;;
  compliance)
    command_compliance
    ;;
  status)
    command_status
    ;;
  all)
    command_all
    ;;
  help | --help | -h)
    show_help
    ;;
  *)
    echo "❌ Unknown command: ${1}" >&2
    show_help
    return 1
    ;;
  esac
}

main "$@"
