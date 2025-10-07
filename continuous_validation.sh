#!/bin/bash

# Continuous Validation Hook
# Runs automated validation checks after code changes and publishes results to MCP

CODE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
PROJECTS_DIR="${CODE_DIR}/Projects"
MCP_URL="${MCP_URL:-http://127.0.0.1:5005}"
VALIDATION_REPORT_DIR="${CODE_DIR}/validation_reports"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
  echo -e "${BLUE}[VALIDATION]${NC} $1"
}

print_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
  echo -e "${RED}[ERROR]${NC} $1"
}

# Source AI helpers if available
if [[ -f "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh" ]]; then
  source "${CODE_DIR}/Tools/Automation/ai_enhanced_automation.sh"
fi

# Validate a single project
validate_project() {
  local project_name="$1"
  local project_path="${PROJECTS_DIR}/${project_name}"

  if [[ ! -d ${project_path} ]]; then
    print_error "Project ${project_name} not found"
    return 1
  fi

  print_status "Running validation for ${project_name}..."

  local timestamp
  timestamp=$(date +%Y%m%d_%H%M%S)
  local report_file="${VALIDATION_REPORT_DIR}/${project_name}_validation_${timestamp}.json"
  mkdir -p "${VALIDATION_REPORT_DIR}"

  local lint_status="not_run"
  local format_status="not_run"
  local build_status="not_run"
  local lint_warnings=0
  local lint_errors=0

  # Run SwiftLint if available
  if command -v swiftlint &>/dev/null; then
    print_status "Running SwiftLint on ${project_name}..."
    local lint_output
    lint_output=$(cd "${project_path}" && swiftlint 2>&1) || true

    lint_warnings=$(echo "${lint_output}" | grep -c "warning:" || echo "0")
    lint_errors=$(echo "${lint_output}" | grep -c "error:" || echo "0")

    if [[ ${lint_errors} -eq 0 ]]; then
      lint_status="passed"
      print_success "SwiftLint passed (${lint_warnings} warnings)"
    else
      lint_status="failed"
      print_error "SwiftLint failed (${lint_errors} errors, ${lint_warnings} warnings)"
    fi
  else
    print_warning "SwiftLint not available"
    lint_status="skipped"
  fi

  # Check SwiftFormat if available
  if command -v swiftformat &>/dev/null; then
    print_status "Checking format on ${project_name}..."
    local format_output
    format_output=$(cd "${project_path}" && swiftformat --lint . 2>&1) || true

    if echo "${format_output}" | grep -q "no changes"; then
      format_status="passed"
      print_success "Format check passed"
    elif echo "${format_output}" | grep -q "formatted"; then
      format_status="needs_formatting"
      print_warning "Format check found issues (run swiftformat to fix)"
    else
      format_status="passed"
    fi
  else
    print_warning "SwiftFormat not available"
    format_status="skipped"
  fi

  # Quick build check (compile-only, no archive)
  if command -v xcodebuild &>/dev/null; then
    print_status "Running quick build check on ${project_name}..."
    local xcodeproj
    xcodeproj=$(find "${project_path}" -maxdepth 1 -name "*.xcodeproj" | head -1)

    if [[ -n ${xcodeproj} ]]; then
      local scheme_name
      scheme_name=$(basename "${xcodeproj}" .xcodeproj)

      # Determine platform
      local destination="generic/platform=macOS"
      if grep -q "TARGETED_DEVICE_FAMILY.*1" "${xcodeproj}/project.pbxproj" 2>/dev/null; then
        destination="generic/platform=iOS"
      fi

      # Try consolidated build first if available
      local build_output
      if [[ -f "${WORKSPACE_ROOT}/Projects/scripts/consolidated_build.sh" ]]; then
        print_status "Using consolidated_build.sh for comprehensive validation..."
        if build_output=$(cd "${WORKSPACE_ROOT}/Projects" && ./scripts/consolidated_build.sh --json 2>&1); then
          build_status="passed"
          print_success "Consolidated build passed"
          # Extract build metadata if available
          if echo "${build_output}" | jq -e '.builds[]' &>/dev/null; then
            local build_count
            build_count=$(echo "${build_output}" | jq '.builds | length')
            print_success "Successfully built ${build_count} configurations"
          fi
        else
          build_status="failed"
          print_error "Consolidated build failed"
        fi
      else
        # Fallback to quick xcodebuild check
        if timeout 180 xcodebuild -project "${xcodeproj}" \
          -scheme "${scheme_name}" \
          -destination "${destination}" \
          -quiet \
          clean build CODE_SIGNING_ALLOWED=NO >/dev/null 2>&1; then
          build_status="passed"
          print_success "Build check passed"
        else
          build_status="failed"
          print_error "Build check failed"
        fi
      fi
    else
      build_status="no_project"
      print_warning "No Xcode project found"
    fi
  else
    build_status="skipped"
    print_warning "xcodebuild not available"
  fi

  # Generate validation report
  local overall_status="passed"
  if [[ ${lint_status} == "failed" ]] || [[ ${build_status} == "failed" ]]; then
    overall_status="failed"
  elif [[ ${format_status} == "needs_formatting" ]]; then
    overall_status="warning"
  fi

  cat >"${report_file}" <<EOF
{
  "project": "${project_name}",
  "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)",
  "overall_status": "${overall_status}",
  "checks": {
    "lint": {
      "status": "${lint_status}",
      "warnings": ${lint_warnings},
      "errors": ${lint_errors}
    },
    "format": {
      "status": "${format_status}"
    },
    "build": {
      "status": "${build_status}"
    }
  }
}
EOF

  print_success "Validation report saved to ${report_file}"

  # Publish to MCP if available
  if command -v curl &>/dev/null; then
    publish_validation_report "${project_name}" "${overall_status}" "${report_file}"
  fi

  # Return status
  [[ ${overall_status} != "failed" ]]
}

# Publish validation results to MCP dashboard
publish_validation_report() {
  local project="$1"
  local status="$2"
  local report_file="$3"

  local level="info"
  [[ ${status} == "failed" ]] && level="error"
  [[ ${status} == "warning" ]] && level="warning"

  local message="Validation completed for ${project}: ${status}"

  local payload
  payload=$(
    cat <<EOF
{
  "message": "${message}",
  "level": "${level}",
  "component": "continuous-validation",
  "metadata": {
    "project": "${project}",
    "report_file": "${report_file}",
    "status": "${status}"
  }
}
EOF
  )

  if curl -s -X POST "${MCP_URL}/alerts" \
    -H "Content-Type: application/json" \
    -d "${payload}" >/dev/null 2>&1; then
    print_status "Published validation report to MCP"
  else
    print_warning "Could not publish to MCP (server may be offline)"
  fi
}

# Run validation on all projects
validate_all() {
  print_status "Running validation on all projects..."

  local total=0
  local passed=0
  local failed=0

  for project in "${PROJECTS_DIR}"/*; do
    if [[ -d ${project} ]]; then
      local project_name
      project_name=$(basename "${project}")

      # Skip non-Swift projects
      local swift_count
      swift_count=$(find "${project}" -name "*.swift" 2>/dev/null | wc -l | tr -d ' ')
      if [[ ${swift_count} -eq 0 ]]; then
        continue
      fi

      total=$((total + 1))

      if validate_project "${project_name}"; then
        passed=$((passed + 1))
      else
        failed=$((failed + 1))
      fi

      echo ""
    fi
  done

  print_status "Validation summary: ${passed}/${total} passed, ${failed} failed"

  # Publish summary to MCP
  if command -v curl &>/dev/null; then
    local summary_payload
    summary_payload=$(
      cat <<EOF
{
  "message": "Validation run completed: ${passed}/${total} passed",
  "level": "info",
  "component": "continuous-validation",
  "metadata": {
    "total": ${total},
    "passed": ${passed},
    "failed": ${failed}
  }
}
EOF
    )
    curl -s -X POST "${MCP_URL}/alerts" \
      -H "Content-Type: application/json" \
      -d "${summary_payload}" >/dev/null 2>&1 || true
  fi

  [[ ${failed} -eq 0 ]]
}

# Watch mode - run validation when files change
watch_mode() {
  local project="${1-}"

  print_status "Starting watch mode for continuous validation..."

  if ! command -v fswatch &>/dev/null; then
    print_error "fswatch not installed. Install with: brew install fswatch"
    return 1
  fi

  local watch_path="${PROJECTS_DIR}"
  if [[ -n ${project} ]]; then
    watch_path="${PROJECTS_DIR}/${project}"
    if [[ ! -d ${watch_path} ]]; then
      print_error "Project ${project} not found"
      return 1
    fi
  fi

  print_status "Watching ${watch_path} for Swift file changes..."

  fswatch -0 -e ".*" -i "\\.swift$" "${watch_path}" | while read -r -d "" event; do
    local changed_file
    changed_file=$(basename "${event}")
    print_status "Detected change: ${changed_file}"

    # Extract project from path
    local detected_project
    detected_project=$(echo "${event}" | sed "s|${PROJECTS_DIR}/||" | cut -d'/' -f1)

    if [[ -n ${project} ]]; then
      validate_project "${project}"
    elif [[ -n ${detected_project} ]]; then
      validate_project "${detected_project}"
    fi

    sleep 2 # Debounce
  done
}

# Main execution
main() {
  case "${1-}" in
  "project" | "validate")
    if [[ -z ${2-} ]]; then
      print_error "Usage: $0 validate <project_name>"
      exit 1
    fi
    validate_project "$2"
    ;;
  "all")
    validate_all
    ;;
  "watch")
    watch_mode "${2-}"
    ;;
  "report")
    # List recent validation reports
    if [[ -d ${VALIDATION_REPORT_DIR} ]]; then
      print_status "Recent validation reports:"
      find "${VALIDATION_REPORT_DIR}" -name "*.json" -type f -printf '%T@ %p\n' 2>/dev/null | sort -nr | head -10 | cut -d' ' -f2- | xargs ls -lht 2>/dev/null || echo "No reports found"
    else
      print_warning "No validation reports directory found"
    fi
    ;;
  *)
    cat <<'USAGE'
Usage: ./continuous_validation.sh <command> [args]

Commands:
  validate <project>  - Run validation checks on a single project
  all                 - Run validation on all projects
  watch [project]     - Watch for file changes and auto-validate
  report              - List recent validation reports

Environment:
  MCP_URL             - MCP server endpoint (default: http://127.0.0.1:5005)

Examples:
  ./continuous_validation.sh validate CodingReviewer
  ./continuous_validation.sh all
  ./continuous_validation.sh watch PlannerApp
USAGE
    exit 1
    ;;
  esac
}

main "$@"
