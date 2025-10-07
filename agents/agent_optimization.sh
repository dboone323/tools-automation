#!/bin/bash
# Agent Optimization - Code & build optimization
# Detects dead code, optimizes dependencies, suggests refactorings

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
AGENTS_DIR="${SCRIPT_DIR}"
AGENT_NAME="agent_optimization"
MCP_URL="${MCP_URL:-http://127.0.0.1:5005}"
LOG_FILE="${AGENTS_DIR}/${AGENT_NAME}.log"
STATUS_FILE="${AGENTS_DIR}/agent_status.json"
OPTIMIZATION_REPORTS_DIR="${WORKSPACE_ROOT}/.metrics/optimization"

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

mkdir -p "${OPTIMIZATION_REPORTS_DIR}"


# Detect unused functions and classes
detect_dead_code() {
  local project_path="$1"
  local project_name
  project_name=$(basename "${project_path}")

  info "Detecting dead code in ${project_name}..."

  local dead_code_file="${OPTIMIZATION_REPORTS_DIR}/dead_code_${project_name}_$(date +%Y%m%d).txt"

  # Find all function/class definitions
  local definitions
  definitions=$(grep -rn "^\s*\(func\|class\|struct\|enum\)" "${project_path}" --include="*.swift" 2>/dev/null | grep -v "^//")

  # Build a map of all symbol references in the project (more efficient)
  local all_refs_file="/tmp/${project_name}_refs_$$.txt"
  grep -rh "\b[a-zA-Z_][a-zA-Z0-9_]*\b" "${project_path}" --include="*.swift" 2>/dev/null | sort | uniq -c >"${all_refs_file}"

  local unused_count=0

  while IFS=: read -r file line_num declaration || [[ -n "$file" ]]; do
    [[ -z "$file" ]] && continue
    [[ -z "$declaration" ]] && continue

    # Extract function/class name
    local name
    name=$(echo "$declaration" | sed 's/.*\(func\|class\|struct\|enum\) \([a-zA-Z0-9_]*\).*/\2/')
    [[ -z "$name" ]] && continue

    # Count references using the pre-built reference map
    local ref_count
    ref_count=$(grep "^\s*[0-9]* ${name}$" "${all_refs_file}" | awk '{print $1}' | tr -d ' ' || echo "0")

    if [[ ${ref_count} -le 1 ]]; then  # <= 1 because definition counts as 1
      echo "Potentially unused: ${name} in ${file}:${line_num}" >>"${dead_code_file}"
      unused_count=$((unused_count + 1))
    fi
  done <<<"$definitions"

  # Clean up temp file
  rm -f "${all_refs_file}"

  if [[ ${unused_count} -gt 0 ]]; then
    warning "Found ${unused_count} potentially unused code items in ${project_name}"
    info "Report: ${dead_code_file}"
  else
    success "No obvious dead code found in ${project_name}"
  fi
}

# Analyze build cache efficiency
analyze_build_cache() {
  info "Analyzing build cache efficiency..."

  local cache_report="${OPTIMIZATION_REPORTS_DIR}/build_cache_$(date +%Y%m%d_%H%M%S).json"

  # Check for build cache directories
  local cache_size=0
  local cache_dirs=(
    "${HOME}/Library/Developer/Xcode/DerivedData"
    "${WORKSPACE_ROOT}/.build"
    "${WORKSPACE_ROOT}/build"
  )

  for cache_dir in "${cache_dirs[@]}"; do
    if [[ -d "${cache_dir}" ]]; then
      local size
      size=$(du -sk "${cache_dir}" 2>/dev/null | awk '{print $1}')
      cache_size=$((cache_size + size))
    fi
  done

  # Generate recommendations
  cat >"${cache_report}" <<EOF
{
  "timestamp": $(date +%s),
  "date": "$(date -Iseconds)",
  "cache_size_kb": ${cache_size},
  "cache_size_mb": $((cache_size / 1024)),
  "recommendations": [
    $([ ${cache_size} -gt $((10 * 1024 * 1024)) ] && echo '"Consider cleaning build cache (>10GB)"' || echo '"Build cache size is acceptable"')
  ]
}
EOF

  info "Build cache report: ${cache_report}"
}

# Optimize dependencies
optimize_dependencies() {
  local project_path="$1"
  local project_name
  project_name=$(basename "${project_path}")

  info "Analyzing dependencies in ${project_name}..."

  local dep_report="${OPTIMIZATION_REPORTS_DIR}/dependencies_${project_name}_$(date +%Y%m%d).txt"

  # Find all imports
  local imports
  imports=$(grep -rh "^import " "${project_path}" --include="*.swift" 2>/dev/null | sort -u)

  echo "=== Import Analysis for ${project_name} ===" >"${dep_report}"
  echo "" >>"${dep_report}"

  # Count usage of each import
  while IFS= read -r import_line; do
    local module
    module=$(echo "$import_line" | awk '{print $2}')

    local usage_count
    usage_count=$(grep -rc "\b${module}\." "${project_path}" --include="*.swift" 2>/dev/null | awk -F: '{sum+=$2} END {print sum}')

    echo "${module}: ${usage_count} references" >>"${dep_report}"
  done <<<"$imports"

  success "Dependency analysis complete: ${dep_report}"
}

# Suggest refactorings
suggest_refactorings() {
  local project_path="$1"
  local project_name
  project_name=$(basename "${project_path}")

  info "Analyzing code for refactoring opportunities in ${project_name}..."

  local refactor_report="${OPTIMIZATION_REPORTS_DIR}/refactorings_${project_name}_$(date +%Y%m%d).txt"

  echo "=== Refactoring Suggestions for ${project_name} ===" >"${refactor_report}"
  echo "" >>"${refactor_report}"

  # Find large files
  echo "## Large Files (>500 lines)" >>"${refactor_report}"
  find "${project_path}" -name "*.swift" -exec wc -l {} + 2>/dev/null |
    awk '$1 > 500 {print $2 ": " $1 " lines"}' >>"${refactor_report}"

  echo "" >>"${refactor_report}"

  # Find long functions (simplified heuristic)
  echo "## Potentially Long Functions" >>"${refactor_report}"
  grep -n "func " "${project_path}"/*.swift 2>/dev/null | head -20 >>"${refactor_report}" || echo "None found" >>"${refactor_report}"

  echo "" >>"${refactor_report}"

  # Find duplicated code patterns (very simplified)
  echo "## Code Duplication Hints" >>"${refactor_report}"
  echo "Run 'swiftlint analyze' for detailed duplication detection" >>"${refactor_report}"

  success "Refactoring suggestions: ${refactor_report}"
}

# Generate optimization summary
generate_optimization_summary() {
  info "Generating optimization summary..."

  local summary_file="${OPTIMIZATION_REPORTS_DIR}/optimization_summary_$(date +%Y%m%d_%H%M%S).md"

  cat >"${summary_file}" <<EOF
# Code Optimization Summary
**Generated:** $(date)

## Projects Analyzed

EOF

  # Analyze each project
  local projects=("${WORKSPACE_ROOT}"/Projects/*)

  for project in "${projects[@]}"; do
    [[ ! -d "$project" ]] && continue

    local pname
    pname=$(basename "$project")
    [[ "$pname" == "Tools" || "$pname" == "scripts" || "$pname" == "Config" ]] && continue

    echo "### ${pname}" >>"${summary_file}"
    echo "" >>"${summary_file}"

    # Run optimizations
    detect_dead_code "$project"
    optimize_dependencies "$project"
    suggest_refactorings "$project"

    echo "✅ Analysis complete" >>"${summary_file}"
    echo "" >>"${summary_file}"
  done

  # Build cache analysis
  analyze_build_cache

  cat >>"${summary_file}" <<EOF

## Recommendations

1. Review dead code reports and remove unused functions/classes
2. Optimize imports - remove unused dependencies
3. Consider refactoring large files (>500 lines)
4. Clean build cache if size exceeds 10GB
5. Run SwiftLint analyzer for detailed metrics

## Reports Generated

\`\`\`
${OPTIMIZATION_REPORTS_DIR}/
\`\`\`

EOF

  success "Optimization summary: ${summary_file}"
  echo "${summary_file}"
}

# Main agent loop
main() {
  log "Optimization Agent starting..."
  update_agent_status "agent_optimization.sh" "starting" $$ ""

  echo $$ >"${AGENTS_DIR}/${AGENT_NAME}.pid"

  # Register with MCP
  if command -v curl &>/dev/null; then
    curl -s -X POST "${MCP_URL}/register" \
      -H "Content-Type: application/json" \
      -d "{\"agent\": \"${AGENT_NAME}\", \"capabilities\": [\"optimization\", \"dead-code\", \"refactoring\"]}" \
      &>/dev/null || warning "Failed to register with MCP"
  fi

  update_agent_status "agent_optimization.sh" "available" $$ ""
  success "Optimization Agent ready"

  # Main loop - run daily
  while true; do
    update_agent_status "agent_optimization.sh" "running" $$ ""

    # Generate full optimization report
    generate_optimization_summary

    update_agent_status "agent_optimization.sh" "available" $$ ""
    success "Optimization cycle complete. Next run in 24 hours."

    # Heartbeat
    if command -v curl &>/dev/null; then
      curl -s -X POST "${MCP_URL}/heartbeat" \
        -H "Content-Type: application/json" \
        -d "{\"agent\": \"${AGENT_NAME}\"}" &>/dev/null || true
    fi

    sleep 86400 # 24 hours
  done
}

# Handle CLI commands
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
  case "${1:-daemon}" in
  analyze)
    generate_optimization_summary
    ;;
  dead-code)
    detect_dead_code "${2:-${WORKSPACE_ROOT}/Projects}"
    ;;
  dependencies)
    optimize_dependencies "${2:-${WORKSPACE_ROOT}/Projects}"
    ;;
  refactor)
    suggest_refactorings "${2:-${WORKSPACE_ROOT}/Projects}"
    ;;
  cache)
    analyze_build_cache
    ;;
  daemon)
    trap 'update_agent_status "agent_optimization.sh" "stopped" $$ ""; log "Optimization Agent stopping..."; exit 0' SIGTERM SIGINT
    main "$@"
    ;;
  *)
    echo "Usage: $0 {analyze|dead-code|dependencies|refactor|cache|daemon}"
    echo ""
    echo "Commands:"
    echo "  analyze        - Run full optimization analysis"
    echo "  dead-code      - Detect unused code"
    echo "  dependencies   - Analyze dependency usage"
    echo "  refactor       - Suggest refactorings"
    echo "  cache          - Analyze build cache"
    echo "  daemon         - Run as daemon (default)"
    exit 1
    ;;
  esac
fi
