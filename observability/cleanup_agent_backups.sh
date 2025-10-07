#!/bin/bash
# cleanup_agent_backups.sh - Clean up old agent backup directories
# Part of OA-06 Observability & Hygiene System

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "$SCRIPT_DIR/../../.." && pwd)"
BACKUPS_DIR="${ROOT_DIR}/Tools/Automation/agents/backups"
KEEP_COUNT=10 # Keep the 10 most recent backups
LOG_FILE="${ROOT_DIR}/Tools/Automation/logs/backup_cleanup_$(date +%Y%m%d_%H%M%S).log"

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

# Check if backups directory exists
if [[ ! -d "$BACKUPS_DIR" ]]; then
  log_warning "Backups directory not found: $BACKUPS_DIR"
  exit 0
fi

# Count total backups
total_backups=$(find "$BACKUPS_DIR" -maxdepth 1 -type d ! -path "$BACKUPS_DIR" | wc -l | tr -d ' ')

log_info "Starting agent backup cleanup..."
log_info "Backups directory: $BACKUPS_DIR"
log_info "Total backups found: $total_backups"
log_info "Keeping most recent: $KEEP_COUNT"

if [[ $total_backups -le $KEEP_COUNT ]]; then
  log_success "No cleanup needed. Total backups ($total_backups) <= Keep count ($KEEP_COUNT)"
  exit 0
fi

# Calculate disk usage before cleanup
before_size=$(du -sh "$BACKUPS_DIR" 2>/dev/null | awk '{print $1}')
log_info "Current backups size: $before_size"

# Get list of backups sorted by modification time (newest first)
# Keep the newest KEEP_COUNT, delete the rest
log_info "Identifying backups to delete..."

# Create temporary file to store backups to delete
temp_delete_list=$(mktemp)

# List all backup directories, sort by name (which includes timestamp), keep oldest for deletion
find "$BACKUPS_DIR" -maxdepth 1 -type d ! -path "$BACKUPS_DIR" -print0 |
  xargs -0 ls -1dt |
  tail -n +$((KEEP_COUNT + 1)) >"$temp_delete_list"

backups_to_delete=$(wc -l <"$temp_delete_list" | tr -d ' ')

if [[ $backups_to_delete -eq 0 ]]; then
  log_success "No backups to delete"
  rm "$temp_delete_list"
  exit 0
fi

log_info "Backups to delete: $backups_to_delete"

# Show sample of what will be deleted
log_info "Sample of backups to be deleted (first 5):"
head -5 "$temp_delete_list" | while read -r backup; do
  backup_size=$(du -sh "$backup" 2>/dev/null | awk '{print $1}' || echo "unknown")
  log_info "  - $(basename "$backup") (${backup_size})"
done

if [[ $backups_to_delete -gt 5 ]]; then
  log_info "  ... and $((backups_to_delete - 5)) more"
fi

# Confirmation prompt (can be skipped with --force flag)
if [[ "${1:-}" != "--force" ]]; then
  echo
  read -p "Proceed with deletion? (y/N): " -n 1 -r
  echo
  if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_warning "Cleanup cancelled by user"
    rm "$temp_delete_list"
    exit 0
  fi
fi

# Perform deletion
log_info "Deleting old backups..."
deleted_count=0
failed_count=0

while IFS= read -r backup; do
  if rm -rf "$backup" 2>/dev/null; then
    ((deleted_count++))
    if [[ $((deleted_count % 100)) -eq 0 ]]; then
      log_info "Deleted $deleted_count backups..."
    fi
  else
    ((failed_count++))
    log_error "Failed to delete: $(basename "$backup")"
  fi
done <"$temp_delete_list"

rm "$temp_delete_list"

# Calculate disk usage after cleanup
after_size=$(du -sh "$BACKUPS_DIR" 2>/dev/null | awk '{print $1}')
log_success "Deleted $deleted_count backups"

if [[ $failed_count -gt 0 ]]; then
  log_warning "Failed to delete $failed_count backups"
fi

# Summary
echo
log_info "================================================"
log_info "Backup Cleanup Summary:"
log_info "  - Total backups before: $total_backups"
log_info "  - Backups kept: $KEEP_COUNT"
log_info "  - Backups deleted: $deleted_count"
log_info "  - Failed deletions: $failed_count"
log_info "  - Size before: $before_size"
log_info "  - Size after: $after_size"
log_info "  - Remaining backups: $((total_backups - deleted_count))"
log_info "================================================"
echo

log_success "Backup cleanup complete!"
log_info "Log file: $LOG_FILE"

exit 0
