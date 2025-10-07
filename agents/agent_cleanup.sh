#!/bin/bash
# Agent Cleanup - Workspace hygiene automation
# Handles log rotation, cache pruning, temp file cleanup, and workspace maintenance

# Source shared functions for file locking and monitoring
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
source "${SCRIPT_DIR}/shared_functions.sh"

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WORKSPACE_ROOT="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
AGENTS_DIR="${SCRIPT_DIR}"
AGENT_NAME="agent_cleanup"
MCP_URL="${MCP_URL:-http://127.0.0.1:5005}"
LOG_FILE="${AGENTS_DIR}/${AGENT_NAME}.log"
STATUS_FILE="${AGENTS_DIR}/agent_status.json"
CLEANUP_REPORT_DIR="${WORKSPACE_ROOT}/.metrics/cleanup"

# Source AI enhancement modules
ENHANCEMENTS_DIR="${SCRIPT_DIR}/../enhancements"
if [[ -f "${ENHANCEMENTS_DIR}/ai_cleanup_optimizer.sh" ]]; then
  # shellcheck source=../enhancements/ai_cleanup_optimizer.sh
  source "${ENHANCEMENTS_DIR}/ai_cleanup_optimizer.sh"
fi

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

mkdir -p "${CLEANUP_REPORT_DIR}"

# Rotate log files
rotate_logs() {
  info "Rotating log files..."

  local rotated_count=0
  local compressed_count=0

  # Find large log files (>10MB)
  local large_logs
  large_logs=$(find "${AGENTS_DIR}" "${WORKSPACE_ROOT}/Projects" -name "*.log" -size +10M 2>/dev/null || echo "")

  if [[ -n "${large_logs}" ]]; then
    while IFS= read -r log_file; do
      [[ -z "${log_file}" ]] && continue

      local timestamp
      timestamp=$(date +%Y%m%d_%H%M%S)
      local rotated_name="${log_file}.${timestamp}"

      info "Rotating: ${log_file}"

      # Copy and truncate
      cp "${log_file}" "${rotated_name}"
      : >"${log_file}" # Truncate file

      # Compress rotated log
      if command -v gzip &>/dev/null; then
        gzip "${rotated_name}"
        compressed_count=$((compressed_count + 1))
      fi

      rotated_count=$((rotated_count + 1))
    done <<<"${large_logs}"
  fi

  success "Rotated ${rotated_count} log file(s), compressed ${compressed_count}"
}

# Clean old log files
clean_old_logs() {
  local retention_days="${1:-14}"

  info "Cleaning logs older than ${retention_days} days..."

  local deleted_count=0
  local space_freed=0

  # Find old compressed logs
  local old_logs
  old_logs=$(find "${AGENTS_DIR}" "${WORKSPACE_ROOT}/Projects" -name "*.log.*.gz" -mtime +${retention_days} 2>/dev/null || echo "")

  if [[ -n "${old_logs}" ]]; then
    while IFS= read -r log_file; do
      [[ -z "${log_file}" ]] && continue

      local size
      size=$(du -k "${log_file}" 2>/dev/null | awk '{print $1}')
      space_freed=$((space_freed + size))

      rm -f "${log_file}"
      deleted_count=$((deleted_count + 1))
    done <<<"${old_logs}"
  fi

  success "Deleted ${deleted_count} old log(s), freed ${space_freed} KB"
}

# Clean build artifacts
clean_build_artifacts() {
  info "Cleaning old build artifacts..."

  local deleted_count=0
  local space_freed=0

  # Find old build directories (>7 days)
  local build_dirs=(
    "${WORKSPACE_ROOT}/Projects/*/build"
    "${WORKSPACE_ROOT}/Projects/*/.build"
    "${WORKSPACE_ROOT}/.build"
  )

  for pattern in "${build_dirs[@]}"; do
    local dirs
    dirs=$(find "$(dirname "${pattern}")" -name "$(basename "${pattern}")" -type d -mtime +7 2>/dev/null || echo "")

    if [[ -n "${dirs}" ]]; then
      while IFS= read -r build_dir; do
        [[ -z "${build_dir}" ]] && continue

        local size
        size=$(du -sk "${build_dir}" 2>/dev/null | awk '{print $1}')
        space_freed=$((space_freed + size))

        info "Removing: ${build_dir}"
        rm -rf "${build_dir}"
        deleted_count=$((deleted_count + 1))
      done <<<"${dirs}"
    fi
  done

  success "Cleaned ${deleted_count} build director(ies), freed $((space_freed / 1024)) MB"
}

# Clean Xcode DerivedData
clean_derived_data() {
  local derived_data_dir="${HOME}/Library/Developer/Xcode/DerivedData"

  if [[ ! -d "${derived_data_dir}" ]]; then
    return 0
  fi

  info "Cleaning Xcode DerivedData..."

  # Get size before
  local size_before
  size_before=$(du -sk "${derived_data_dir}" 2>/dev/null | awk '{print $1}')

  # Clean old DerivedData (>7 days)
  find "${derived_data_dir}" -maxdepth 1 -type d -mtime +7 -exec rm -rf {} + 2>/dev/null || true

  # Get size after
  local size_after
  size_after=$(du -sk "${derived_data_dir}" 2>/dev/null | awk '{print $1}')

  local space_freed=$((size_before - size_after))

  success "Freed $((space_freed / 1024)) MB from DerivedData"
}

# Clean temp files
clean_temp_files() {
  info "Cleaning temporary files..."

  local deleted_count=0
  local space_freed=0

  # Find temp files
  local temp_patterns=(
    "*.tmp"
    "*.temp"
    "*~"
    ".DS_Store"
    "*.swp"
    "*.swo"
  )

  for pattern in "${temp_patterns[@]}"; do
    local temp_files
    temp_files=$(find "${WORKSPACE_ROOT}" -name "${pattern}" -type f 2>/dev/null || echo "")

    if [[ -n "${temp_files}" ]]; then
      while IFS= read -r temp_file; do
        [[ -z "${temp_file}" ]] && continue

        local size
        size=$(du -k "${temp_file}" 2>/dev/null | awk '{print $1}')
        space_freed=$((space_freed + size))

        rm -f "${temp_file}"
        deleted_count=$((deleted_count + 1))
      done <<<"${temp_files}"
    fi
  done

  success "Cleaned ${deleted_count} temp file(s), freed ${space_freed} KB"
}

# Clean package manager caches
clean_package_caches() {
  info "Cleaning package manager caches..."

  local space_freed=0

  # Clean Swift Package Manager cache
  if [[ -d "${HOME}/.swiftpm" ]]; then
    local spm_size
    spm_size=$(du -sk "${HOME}/.swiftpm" 2>/dev/null | awk '{print $1}')

    # Only clean if >1GB
    if [[ ${spm_size} -gt $((1024 * 1024)) ]]; then
      info "Cleaning SPM cache (${spm_size} KB)..."
      rm -rf "${HOME}/.swiftpm/cache" 2>/dev/null || true

      local spm_after
      spm_after=$(du -sk "${HOME}/.swiftpm" 2>/dev/null | awk '{print $1}')
      space_freed=$((space_freed + spm_size - spm_after))
    fi
  fi

  # Clean npm cache (if exists)
  if command -v npm &>/dev/null && [[ -d "${HOME}/.npm" ]]; then
    local npm_size
    npm_size=$(du -sk "${HOME}/.npm" 2>/dev/null | awk '{print $1}')

    if [[ ${npm_size} -gt $((1024 * 1024)) ]]; then
      info "Cleaning npm cache..."
      npm cache clean --force &>/dev/null || true

      local npm_after
      npm_after=$(du -sk "${HOME}/.npm" 2>/dev/null | awk '{print $1}')
      space_freed=$((space_freed + npm_size - npm_after))
    fi
  fi

  success "Freed $((space_freed / 1024)) MB from package caches"
}

# Clean old metrics
clean_old_metrics() {
  local retention_days="${1:-30}"

  info "Cleaning metrics older than ${retention_days} days..."

  local deleted_count=0

  if [[ -d "${WORKSPACE_ROOT}/.metrics" ]]; then
    local old_metrics
    old_metrics=$(find "${WORKSPACE_ROOT}/.metrics" -name "*.json" -mtime +${retention_days} 2>/dev/null || echo "")

    if [[ -n "${old_metrics}" ]]; then
      while IFS= read -r metric_file; do
        [[ -z "${metric_file}" ]] && continue

        rm -f "${metric_file}"
        deleted_count=$((deleted_count + 1))
      done <<<"${old_metrics}"
    fi
  fi

  success "Cleaned ${deleted_count} old metric file(s)"
}

# Generate cleanup report
generate_cleanup_report() {
  local report_file
  report_file="${CLEANUP_REPORT_DIR}/cleanup_$(date +%Y%m%d_%H%M%S).json"

  info "Generating cleanup report..."

  # Collect workspace statistics
  local workspace_size
  workspace_size=$(du -sk "${WORKSPACE_ROOT}" 2>/dev/null | awk '{print $1}')

  local file_count
  file_count=$(find "${WORKSPACE_ROOT}" -type f 2>/dev/null | wc -l | tr -d ' ')

  local dir_count
  dir_count=$(find "${WORKSPACE_ROOT}" -type d 2>/dev/null | wc -l | tr -d ' ')

  cat >"${report_file}" <<EOF
{
  "timestamp": $(date +%s),
  "date": "$(date -Iseconds)",
  "workspace": {
    "size_kb": ${workspace_size},
    "size_mb": $((workspace_size / 1024)),
    "file_count": ${file_count},
    "directory_count": ${dir_count}
  },
  "cleanup_actions": {
    "logs_rotated": true,
    "old_logs_cleaned": true,
    "build_artifacts_cleaned": true,
    "temp_files_cleaned": true,
    "derived_data_cleaned": true,
    "package_caches_cleaned": true,
    "old_metrics_cleaned": true
  }
}
EOF

  success "Cleanup report: ${report_file}"
}

# Main cleanup routine
run_full_cleanup() {
  info "Starting full workspace cleanup..."

  local start_time
  start_time=$(date +%s)

  # Run all cleanup operations
  rotate_logs
  clean_old_logs 14
  clean_build_artifacts
  clean_derived_data
  clean_temp_files
  clean_package_caches
  clean_old_metrics 30

  # Generate report
  generate_cleanup_report

  local end_time
  end_time=$(date +%s)
  local duration=$((end_time - start_time))

  success "Full cleanup complete in ${duration} seconds"
}

# Main agent loop
main() {
  log "Cleanup Agent starting..."
  update_agent_status "agent_cleanup.sh" "starting" $$ ""

  echo $$ >"${AGENTS_DIR}/${AGENT_NAME}.pid"

  # Register with MCP
  if command -v curl &>/dev/null; then
    curl -s -X POST "${MCP_URL}/register" \
      -H "Content-Type: application/json" \
      -d "{\"agent\": \"${AGENT_NAME}\", \"capabilities\": [\"cleanup\", \"maintenance\", \"hygiene\"]}" \
      &>/dev/null || warning "Failed to register with MCP"
  fi

  update_agent_status "agent_cleanup.sh" "available" $$ ""
  success "Cleanup Agent ready"

  # Main loop - run daily at 2 AM equivalent (every 24 hours)
  while true; do
    update_agent_status "agent_cleanup.sh" "running" $$ ""

    # Run full cleanup
    run_full_cleanup

    update_agent_status "agent_cleanup.sh" "available" $$ ""
    success "Cleanup cycle complete. Next cleanup in 24 hours."

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
  full)
    run_full_cleanup
    ;;
  logs)
    rotate_logs
    clean_old_logs "${2:-14}"
    ;;
  builds)
    clean_build_artifacts
    ;;
  derived)
    clean_derived_data
    ;;
  temp)
    clean_temp_files
    ;;
  caches)
    clean_package_caches
    ;;
  metrics)
    clean_old_metrics "${2:-30}"
    ;;
  daemon)
    trap 'update_agent_status "agent_cleanup.sh" "stopped" $$ ""; log "Cleanup Agent stopping..."; exit 0' SIGTERM SIGINT
    main "$@"
    ;;
  *)
    echo "Usage: $0 {full|logs|builds|derived|temp|caches|metrics|daemon}"
    echo ""
    echo "Commands:"
    echo "  full              - Run full cleanup suite"
    echo "  logs [days]       - Rotate and clean logs"
    echo "  builds            - Clean build artifacts"
    echo "  derived           - Clean Xcode DerivedData"
    echo "  temp              - Clean temporary files"
    echo "  caches            - Clean package manager caches"
    echo "  metrics [days]    - Clean old metrics"
    echo "  daemon            - Run as daemon (default)"
    exit 1
    ;;
  esac
fi
