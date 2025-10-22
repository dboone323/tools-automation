#!/bin/bash

# AI Analysis Files Cleanup Script
# This script archives old AI analysis files to reduce repository clutter

set -e

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ARCHIVE_DIR="${REPO_ROOT}/Archives/AI_Analysis"
KEEP_DAYS=30

log_info() {
    echo "[CLEANUP] $(date '+%Y-%m-%d %H:%M:%S') - $1"
}

log_error() {
    echo "[CLEANUP-ERROR] $(date '+%Y-%m-%d %H:%M:%S') - $1" >&2
}

# Create archive directory
mkdir -p "${ARCHIVE_DIR}"

# Find and archive old AI analysis files
find "${REPO_ROOT}/Projects" -type f \( \
    -name "AI_ANALYSIS_*.md" \
    -o -name "AI_CODE_REVIEW_*.md" \
    -o -name "AI_PERFORMANCE_OPTIMIZATION_*.md" \
    -o -name "AUTOMATION_SUMMARY_*.md" \
    -o -name "AI_AUTOMATION_SUMMARY_*.md" \
    -o -name "AI_QUALITY_PIPELINE_SUMMARY.md" \
    \) -mtime +${KEEP_DAYS} 2>/dev/null | while read -r file; do
    if [[ -f "$file" ]]; then
        # Get relative path for archive structure
        rel_path="${file#"${REPO_ROOT}"/}"
        archive_path="${ARCHIVE_DIR}/${rel_path}"

        # Create archive subdirectory
        archive_subdir="$(dirname "${archive_path}")"
        mkdir -p "${archive_subdir}"

        # Move file to archive
        mv "$file" "${archive_path}"
        log_info "Archived: ${rel_path}"
    fi
done

# Clean up empty directories in Projects
find "${REPO_ROOT}/Projects" -type d -empty -delete 2>/dev/null || true

# Create archive index
ARCHIVE_INDEX="${ARCHIVE_DIR}/archive_index_$(date +%Y%m%d_%H%M%S).txt"
{
    echo "# AI Analysis Archive Index"
    echo "Generated: $(date)"
    echo "Keep Period: ${KEEP_DAYS} days"
    echo ""
    echo "## Archived Files:"
    find "${ARCHIVE_DIR}" -type f -name "*.md" | sort | while read -r file; do
        echo "- ${file#"${ARCHIVE_DIR}"/}"
    done
} >"${ARCHIVE_INDEX}"

log_info "Cleanup completed. Archive index: ${ARCHIVE_INDEX}"

# Optional: Compress old archives (older than 90 days)
find "${ARCHIVE_DIR}" -name "archive_index_*.txt" -mtime +90 -exec gzip {} \; 2>/dev/null || true

log_info "Cleanup script completed successfully"
