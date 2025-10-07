#!/bin/bash
# cleanup_old_metrics.sh - Remove metrics snapshots older than retention period
# Part of OA-06 Observability & Hygiene System

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
METRICS_DIR="${ROOT_DIR}/Tools/Automation/metrics"
SNAPSHOTS_DIR="${METRICS_DIR}/snapshots"
RETENTION_DAYS="${RETENTION_DAYS:-90}" # Default 90 days retention

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*"
}

# Main execution
main() {
  log_info "Starting metrics cleanup (retention: ${RETENTION_DAYS} days)..."

  if [[ ! -d "$SNAPSHOTS_DIR" ]]; then
    log_warning "Snapshots directory not found: $SNAPSHOTS_DIR"
    log_info "No cleanup needed."
    return 0
  fi

  # Count snapshots before cleanup
  local total_before
  total_before=$(find "$SNAPSHOTS_DIR" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')

  # Calculate disk usage before
  local size_before
  size_before=$(du -sk "$SNAPSHOTS_DIR" 2>/dev/null | awk '{print $1}')

  log_info "Current snapshots: ${total_before}"
  log_info "Current size: $((size_before / 1024)) MB"

  # Find and delete old snapshots
  local deleted_count=0
  local old_snapshots=()

  while IFS= read -r -d '' snapshot; do
    old_snapshots+=("$snapshot")
  done < <(find "$SNAPSHOTS_DIR" -name "*.json" -type f -mtime +${RETENTION_DAYS} -print0 2>/dev/null)

  if [[ ${#old_snapshots[@]} -eq 0 ]]; then
    log_success "No snapshots older than ${RETENTION_DAYS} days found."
    return 0
  fi

  log_info "Found ${#old_snapshots[@]} snapshot(s) to delete..."

  for snapshot in "${old_snapshots[@]}"; do
    local snapshot_name
    snapshot_name=$(basename "$snapshot")

    if rm -f "$snapshot" 2>/dev/null; then
      ((deleted_count++))
      log_info "Deleted: $snapshot_name"
    else
      log_error "Failed to delete: $snapshot_name"
    fi
  done

  # Calculate disk usage after
  local size_after
  size_after=$(du -sk "$SNAPSHOTS_DIR" 2>/dev/null | awk '{print $1}')
  local space_freed=$((size_before - size_after))

  # Count snapshots after cleanup
  local total_after
  total_after=$(find "$SNAPSHOTS_DIR" -name "*.json" -type f 2>/dev/null | wc -l | tr -d ' ')

  log_success "================================================"
  log_success "Metrics Cleanup Summary:"
  log_success "  - Retention period: ${RETENTION_DAYS} days"
  log_success "  - Snapshots before: ${total_before}"
  log_success "  - Snapshots deleted: ${deleted_count}"
  log_success "  - Snapshots remaining: ${total_after}"
  log_success "  - Space freed: $((space_freed / 1024)) MB"
  log_success "================================================"
}

# Run main function
main "$@"
