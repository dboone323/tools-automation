#!/bin/bash

# Simple Backup Compressor for Quantum Workspace
# Compresses a few old backup directories at a time

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
    echo -e "${BLUE}[BACKUP-COMPRESS]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Compress a single backup directory
compress_backup() {
    local backup_path="$1"
    local backup_name
    backup_name="$(basename "$backup_path")"
    local compressed_path="${backup_path}.tar.gz"

    if [[ -f "$compressed_path" ]]; then
        print_warning "Already compressed: $backup_name"
        return 0
    fi

    print_status "Compressing: $backup_name"
    if tar -czf "$compressed_path" -C "$(dirname "$backup_path")" "$backup_name" >/dev/null 2>&1; then
        rm -rf "$backup_path"
        print_success "Compressed and removed: $backup_name"
        return 0
    else
        print_error "Failed to compress: $backup_name"
        return 1
    fi
}

# Compress a few old directories
compress_old_backups() {
    local max_to_compress=5
    local compressed=0

    print_status "Finding uncompressed backup directories..."

    # Get directories sorted by modification time (oldest first)
    while IFS= read -r backup_dir; do
        if [[ $compressed -ge $max_to_compress ]]; then
            break
        fi

        # Only process directories
        if [[ -d "$backup_dir" ]]; then
            if compress_backup "$backup_dir"; then
                ((compressed++))
            fi
        fi
    done < <(find "$BACKUP_DIR" -maxdepth 1 -type d -name "CodingReviewer_*" | xargs ls -tr)

    print_success "Compressed $compressed backup directories"
}

# Show current stats
show_stats() {
    local dir_count
    dir_count=$(find "$BACKUP_DIR" -maxdepth 1 -type d -name "CodingReviewer_*" | wc -l | tr -d ' ')
    local file_count
    file_count=$(find "$BACKUP_DIR" -maxdepth 1 -name "CodingReviewer_*.tar.gz" | wc -l | tr -d ' ')
    local total_size
    total_size=$(du -sh "$BACKUP_DIR" 2>/dev/null | cut -f1)

    echo "Current status:"
    echo "  Directories (uncompressed): $dir_count"
    echo "  Compressed files: $file_count"
    echo "  Total size: $total_size"
}

# Main function
main() {
    echo "=================================================="
    print_status "Simple Backup Compression"
    echo "=================================================="

    if [[ ! -d "$BACKUP_DIR" ]]; then
        echo "Backup directory not found: $BACKUP_DIR"
        exit 1
    fi

    show_stats
    echo ""

    compress_old_backups
    echo ""

    print_status "Final status:"
    show_stats
}

main "$@"
