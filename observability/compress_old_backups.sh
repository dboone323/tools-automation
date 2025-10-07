#!/bin/bash
# compress_old_backups.sh - Compress backups older than 24 hours
# Part of OA-06 Observability & Hygiene System

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BACKUPS_DIR="${ROOT_DIR}/Tools/Automation/agents/backups"
AUTOFIX_BACKUPS_DIR="${ROOT_DIR}/.autofix_backups"
AGE_THRESHOLD=1 # Compress backups older than 1 day
LOG_FILE="${ROOT_DIR}/Tools/Automation/logs/backup_compression_$(date +%Y%m%d_%H%M%S).log"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
  echo -e "${BLUE}[INFO]${NC} $*" | tee -a "$LOG_FILE"
}

log_success() {
  echo -e "${GREEN}[SUCCESS]${NC} $*" | tee -a "$LOG_FILE"
}

log_warning() {
  echo -e "${YELLOW}[WARNING]${NC} $*" | tee -a "$LOG_FILE"
}

log_error() {
  echo -e "${RED}[ERROR]${NC} $*" | tee -a "$LOG_FILE"
}

# Compress backups in a directory
compress_directory_backups() {
  local dir="$1"
  local dir_name="$(basename "$dir")"

  if [[ ! -d "$dir" ]]; then
    log_warning "Directory not found: $dir"
    return 0
  fi

  log_info "Processing backups in: $dir"

  # Find directories older than AGE_THRESHOLD days (not already compressed)
  local old_backups=()
  local find_tmpfile
  find_tmpfile=$(mktemp)
  find "$dir" -maxdepth 1 -type d ! -path "$dir" -mtime +${AGE_THRESHOLD} -print0 2>/dev/null >"$find_tmpfile"
  local find_status=$?
  while IFS= read -r -d '' backup; do
    old_backups+=("$backup")
  done <"$find_tmpfile"
  rm -f "$find_tmpfile"
  if [[ $find_status -ne 0 ]]; then
    log_warning "find command failed while processing $dir_name (exit code $find_status). Some backups may not have been found."
  fi

  local total=${#old_backups[@]}

  if [[ $total -eq 0 ]]; then
    log_info "No backups older than ${AGE_THRESHOLD} day(s) found in $dir_name"
    return 0
  fi

  log_info "Found $total backup(s) to compress in $dir_name"

  local compressed_count=0
  local failed_count=0
  local space_saved=0

  for backup in "${old_backups[@]}"; do
    local backup_name
    backup_name=$(basename "$backup")
    local backup_size
    backup_size=$(du -sk "$backup" 2>/dev/null | awk '{print $1}')

    log_info "Compressing: $backup_name (${backup_size}KB)"

    # Compress to tar.gz
    if tar -czf "${backup}.tar.gz" -C "$(dirname "$backup")" "$backup_name" 2>/dev/null; then
      # Verify archive
      if tar -tzf "${backup}.tar.gz" >/dev/null 2>&1; then
        # Remove original directory
        if rm -rf "$backup" 2>/dev/null; then
          ((compressed_count++))

          local compressed_size
          compressed_size=$(du -sk "${backup}.tar.gz" 2>/dev/null | awk '{print $1}')
          local saved=$((backup_size - compressed_size))
          space_saved=$((space_saved + saved))

          log_success "Compressed: $backup_name (saved ${saved}KB)"
        else
          log_error "Failed to remove original: $backup_name"
          rm -f "${backup}.tar.gz"
          ((failed_count++))
        fi
      else
        log_error "Archive verification failed: $backup_name"
        rm -f "${backup}.tar.gz"
        ((failed_count++))
      fi
    else
      log_error "Compression failed: $backup_name"
      ((failed_count++))
    fi
  done

  log_info "================================================"
  log_info "$dir_name Compression Summary:"
  log_info "  - Backups found: $total"
  log_info "  - Successfully compressed: $compressed_count"
  log_info "  - Failed: $failed_count"
  log_info "  - Space saved: ${space_saved}KB (~$((space_saved / 1024))MB)"
  log_info "================================================"

  return 0
}

# Main execution
main() {
  log_info "Starting backup compression process..."
  log_info "Age threshold: Compress backups older than ${AGE_THRESHOLD} day(s)"
  echo

  # Compress agent backups
  if [[ -d "$BACKUPS_DIR" ]]; then
    compress_directory_backups "$BACKUPS_DIR"
    echo
  fi

  # Compress autofix backups
  if [[ -d "$AUTOFIX_BACKUPS_DIR" ]]; then
    compress_directory_backups "$AUTOFIX_BACKUPS_DIR"
    echo
  fi

  log_success "Backup compression complete!"
  log_info "Log file: $LOG_FILE"
}

# Run main function
main "$@"
