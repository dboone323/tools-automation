#!/bin/bash

# Backup Rotation Script for Quantum Workspace
# Implements intelligent backup rotation to manage storage usage

set -euo pipefail

WORKSPACE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
BACKUP_DIR="${WORKSPACE_DIR}/Tools/Automation/agents/backups"

# Colors
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

print_status() {
    echo -e "${BLUE}[BACKUP-ROTATION]${NC} $1"
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

# Get all backup items sorted by modification time (newest first)
get_sorted_backups() {
    local backup_dir="$1"
    # Get both directories and compressed files, then sort them all by modification time
    (
        find "$backup_dir" -maxdepth 1 -type d -name "CodingReviewer_*" 2>/dev/null
        find "$backup_dir" -maxdepth 1 -name "CodingReviewer_*.tar.gz" 2>/dev/null
    ) |
        xargs ls -td 2>/dev/null
}

# Compress a backup directory
compress_backup() {
    local backup_path="$1"
    local backup_name
    backup_name="$(basename "$backup_path")"
    local compressed_path="${backup_path}.tar.gz"

    if [[ -f "$compressed_path" ]]; then
        print_warning "Compressed file already exists: $compressed_path"
        return 0
    fi

    print_status "Compressing: $backup_name"
    if tar -czf "$compressed_path" -C "$(dirname "$backup_path")" "$backup_name" >/dev/null 2>&1; then
        # Remove original directory after successful compression
        rm -rf "$backup_path"
        print_success "Compressed and removed: $backup_name"
        return 0
    else
        print_error "Failed to compress: $backup_name"
        return 1
    fi
}

# Remove old compressed backups
cleanup_old_backups() {
    local backup_dir="$1"
    local keep_days="${2:-30}"

    print_status "Removing compressed backups older than $keep_days days"

    local removed_count=0
    local space_saved=0

    while IFS= read -r backup_file; do
        if [[ -f "$backup_file" ]]; then
            local file_size
            file_size=$(stat -f%z "$backup_file" 2>/dev/null || echo "0")
            if rm -f "$backup_file"; then
                ((removed_count++))
                ((space_saved += file_size))
                print_status "Removed: $(basename "$backup_file")"
            else
                print_warning "Failed to remove: $(basename "$backup_file")"
            fi
        fi
    done < <(find "$backup_dir" -name "CodingReviewer_*.tar.gz" -mtime +"$keep_days" 2>/dev/null || true)

    if [[ $removed_count -gt 0 ]]; then
        local space_mb=$((space_saved / 1024 / 1024))
        print_success "Removed $removed_count old backups, saved ~${space_mb}MB"
    else
        print_status "No old backups to remove"
    fi
}

# Main rotation function
rotate_backups() {
    local backup_dir="$1"
    local keep_recent="${2:-10}"

    print_status "Starting backup rotation in: $backup_dir"
    print_status "Keeping $keep_recent most recent backups"

    # Get all backup items sorted by time (newest first)
    local all_backups=()
    while IFS= read -r backup; do
        all_backups+=("$backup")
    done < <(get_sorted_backups "$backup_dir")

    local total_backups=${#all_backups[@]}
    print_status "Found $total_backups backup items"

    if [[ $total_backups -le $keep_recent ]]; then
        print_success "No rotation needed - only $total_backups backups (keeping $keep_recent)"
        return 0
    fi

    # Keep the most recent N backups as-is
    # local keep_backups=("${all_backups[@]:0:$keep_recent}")

    # Compress everything older than the keep threshold (limit to avoid timeouts)
    local compress_count=0
    local max_compress=10 # Limit compression operations per run

    for ((i = keep_recent; i < total_backups && compress_count < max_compress; i++)); do
        local backup_item="${all_backups[$i]}"

        # If it's a directory, compress it
        if [[ -d "$backup_item" ]]; then
            if compress_backup "$backup_item"; then
                ((compress_count++))
            else
                print_warning "Failed to compress: $(basename "$backup_item")"
            fi
        elif [[ -f "$backup_item" && "$backup_item" == *.tar.gz ]]; then
            # Already compressed, skip silently
            true
        else
            print_warning "Unknown item type: $(basename "$backup_item")"
        fi
    done

    if [[ $compress_count -ge $max_compress ]]; then
        print_warning "Reached compression limit ($max_compress). Run script again to continue."
    fi

    if [[ $compress_count -gt 0 ]]; then
        print_success "Compressed $compress_count old backup directories"
    fi

    # Clean up very old compressed backups (older than 30 days)
    cleanup_old_backups "$backup_dir" 30
}

# Show backup statistics
show_stats() {
    local backup_dir="$1"

    print_status "Backup directory statistics:"

    local dir_count
    dir_count=$(find "$backup_dir" -maxdepth 1 -type d -name "CodingReviewer_*" | wc -l | tr -d ' ')
    local file_count
    file_count=$(find "$backup_dir" -maxdepth 1 -name "CodingReviewer_*.tar.gz" | wc -l | tr -d ' ')
    local total_size
    total_size=$(du -sh "$backup_dir" 2>/dev/null | cut -f1)

    echo "  Directories (uncompressed): $dir_count"
    echo "  Compressed files: $file_count"
    echo "  Total size: $total_size"

    if [[ $dir_count -gt 0 ]]; then
        print_warning "Consider running rotation to compress $dir_count uncompressed directories"
    fi
}

# Main function
main() {
    local keep_recent="${1:-10}"

    echo "=================================================="
    print_status "Quantum Workspace Backup Rotation"
    echo "=================================================="

    if [[ ! -d "$BACKUP_DIR" ]]; then
        print_error "Backup directory not found: $BACKUP_DIR"
        exit 1
    fi

    # Show current stats
    show_stats "$BACKUP_DIR"
    echo ""

    # Perform rotation
    rotate_backups "$BACKUP_DIR" "$keep_recent"
    echo ""

    # Show final stats
    print_status "Final statistics:"
    show_stats "$BACKUP_DIR"
    echo ""

    print_success "Backup rotation complete!"
    echo ""
    echo "Rotation Policy:"
    echo "- Keep $keep_recent most recent backups uncompressed"
    echo "- Compress older backups automatically"
    echo "- Remove compressed backups older than 30 days"
}

# Allow override of keep count via argument
keep_recent=10
if [[ $# -gt 0 ]]; then
    keep_recent="$1"
fi

main "$keep_recent"
