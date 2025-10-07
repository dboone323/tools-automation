#!/bin/bash
# OA-06: Log Rotation Script
# Automatically rotates, compresses, and cleans up old log files

set -euo pipefail

# Configuration
readonly SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
readonly ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"
readonly LOG_DIR="${ROOT_DIR}/Tools/Automation"
readonly MAX_LOG_SIZE_MB=10
readonly RETENTION_DAYS=30
readonly MCP_SERVER="${MCP_SERVER:-http://localhost:3000}"

# Colors for output
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${GREEN}[INFO]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

# Convert MB to bytes
mb_to_bytes() {
  echo $(($1 * 1024 * 1024))
}

# Get file size in bytes
get_file_size() {
  local file="$1"
  if [[ ! -f "$file" ]]; then
    echo 0
    return
  fi

  # Explicit OS detection
  if [[ $(uname -s) == "Darwin" ]]; then
    stat -f%z "$file" 2>/dev/null || echo 0
  else
    stat -c%s "$file" 2>/dev/null || echo 0
  fi
}

# Rotate a log file
rotate_log() {
  local logfile="$1"
  local timestamp=$(date +%Y%m%d_%H%M%S)
  local rotated="${logfile}.${timestamp}"

  log_info "Rotating: ${logfile}"

  # Move and create new log file (more efficient for large logs)
  mv "$logfile" "$rotated"
  touch "$logfile"

  # Compress rotated log
  gzip "$rotated"
  log_info "Compressed: ${rotated}.gz"

  return 0
}

# Delete old logs
cleanup_old_logs() {
  local dir="$1"
  local days="$2"
  local count=0

  log_info "Cleaning up logs older than ${days} days in ${dir}"

  # Find and delete old compressed logs
  while IFS= read -r -d '' file; do
    rm -f "$file"
    ((count++))
    log_info "Deleted: ${file}"
  done < <(find "$dir" -name "*.log.*.gz" -mtime "+${days}" -print0 2>/dev/null)

  if [[ $count -gt 0 ]]; then
    log_info "Deleted ${count} old log file(s)"
  else
    log_info "No old logs to delete"
  fi

  return 0
}

# Publish rotation summary to MCP
publish_to_mcp() {
  local rotated_count="$1"
  local deleted_count="$2"
  local total_size_mb="$3"

  local payload=$(
    cat <<EOF
{
  "source": "log_rotation",
  "level": "info",
  "message": "Log rotation completed",
  "details": {
    "rotated_files": ${rotated_count},
    "deleted_files": ${deleted_count},
    "space_freed_mb": ${total_size_mb},
    "timestamp": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  }
}
EOF
  )

  if curl -sf -X POST "${MCP_SERVER}/alerts" \
    -H "Content-Type: application/json" \
    -d "$payload" >/dev/null 2>&1; then
    log_info "Published rotation summary to MCP"
  else
    log_warning "Failed to publish to MCP (server may be offline)"
  fi
}

# Main rotation logic
main() {
  log_info "Starting log rotation..."
  log_info "Log directory: ${LOG_DIR}"
  log_info "Max size: ${MAX_LOG_SIZE_MB}MB"
  log_info "Retention: ${RETENTION_DAYS} days"

  local rotated_count=0
  local deleted_count=0
  local total_freed_bytes=0
  local max_size_bytes=$(mb_to_bytes "$MAX_LOG_SIZE_MB")

  # Find all log files in automation directories
  while IFS= read -r -d '' logfile; do
    local size=$(get_file_size "$logfile")

    # Skip if file doesn't exist or is empty
    [[ ! -f "$logfile" ]] && continue
    [[ $size -eq 0 ]] && continue

    # Rotate if size exceeds threshold
    if [[ $size -gt $max_size_bytes ]]; then
      local size_mb=$((size / 1024 / 1024))
      log_warning "Log exceeds ${MAX_LOG_SIZE_MB}MB: ${logfile} (${size_mb}MB)"

      if rotate_log "$logfile"; then
        ((rotated_count++))
        total_freed_bytes=$((total_freed_bytes + size))
      else
        log_error "Failed to rotate: ${logfile}"
      fi
    fi
  done < <(find "$LOG_DIR" -type f -name "*.log" -print0 2>/dev/null)

  # Clean up old compressed logs
  local old_count=$(find "$LOG_DIR" -name "*.log.*.gz" -mtime "+${RETENTION_DAYS}" 2>/dev/null | wc -l | tr -d ' ')
  cleanup_old_logs "$LOG_DIR" "$RETENTION_DAYS"
  deleted_count=$old_count

  # Calculate total freed space
  local total_freed_mb=$((total_freed_bytes / 1024 / 1024))

  # Summary
  log_info "================================================"
  log_info "Log Rotation Summary:"
  log_info "  - Files rotated: ${rotated_count}"
  log_info "  - Files deleted: ${deleted_count}"
  log_info "  - Space freed: ${total_freed_mb}MB"
  log_info "================================================"

  # Publish to MCP
  publish_to_mcp "$rotated_count" "$deleted_count" "$total_freed_mb"

  log_info "Log rotation complete!"
}

# Run main function
main "$@"
