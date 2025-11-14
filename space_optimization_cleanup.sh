#!/opt/homebrew/bin/bash
# Space Optimization Cleanup Script for Hybrid Desktop + Cloud System
# This script safely removes redundant files and optimizes storage for the hybrid deployment

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🧹 Starting Space Optimization Cleanup for Hybrid System${NC}"
echo "=================================================="

# Get current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Track space saved
SPACE_SAVED=0

# Function to calculate file size in MB
get_size_mb() {
    local file="$1"
    if [[ -f "$file" ]]; then
        du -m "$file" 2>/dev/null | cut -f1
    else
        echo "0"
    fi
}

# Function to add to space saved counter
add_space_saved() {
    local size="$1"
    SPACE_SAVED=$((SPACE_SAVED + size))
}

echo -e "${YELLOW}Phase 1: Removing backup and temporary files${NC}"
echo "---------------------------------------------"

# Remove backup files
BACKUP_COUNT=$(find . -name "*.backup" -o -name "*.bak" -o -name "*~" -o -name "*.tmp" -o -name "*.swp" | wc -l)
if [[ $BACKUP_COUNT -gt 0 ]]; then
    echo "Found $BACKUP_COUNT backup/temporary files"
    find . -name "*.backup" -o -name "*.bak" -o -name "*~" -o -name "*.tmp" -o -name "*.swp" | while read -r file; do
        size=$(get_size_mb "$file")
        echo "Removing: $file (${size}MB)"
        rm -f "$file"
        add_space_saved "$size"
    done
else
    echo "No backup/temporary files found"
fi

echo -e "\n${YELLOW}Phase 2: Cleaning up old archives (keeping recent ones)${NC}"
echo "-----------------------------------------------------"

# Remove archives older than 7 days
OLD_ARCHIVES=$(find ./archives -name "*.tar.gz" -mtime +7 2>/dev/null || true)
if [[ -n "$OLD_ARCHIVES" ]]; then
    echo "$OLD_ARCHIVES" | while read -r file; do
        if [[ -f "$file" ]]; then
            size=$(get_size_mb "$file")
            echo "Removing old archive: $file (${size}MB)"
            rm -f "$file"
            add_space_saved "$size"
        fi
    done
else
    echo "No old archives to remove"
fi

echo -e "\n${YELLOW}Phase 3: Cleaning up generated documentation${NC}"
echo "-----------------------------------------------"

# Remove large generated API references (can be regenerated)
if [[ -f "docs/api_references.txt" ]]; then
    size=$(get_size_mb "docs/api_references.txt")
    echo "Removing generated API references: docs/api_references.txt (${size}MB)"
    rm -f "docs/api_references.txt"
    add_space_saved "$size"
fi

echo -e "\n${YELLOW}Phase 4: Truncating large log files${NC}"
echo "-------------------------------------"

# Truncate log files larger than 5MB (keep last 1000 lines)
find . -name "*.log" -type f -size +5M | while read -r logfile; do
    size_before=$(get_size_mb "$logfile")
    echo "Truncating large log: $logfile (${size_before}MB)"
    tail -n 1000 "$logfile" >"${logfile}.tmp" && mv "${logfile}.tmp" "$logfile"
    size_after=$(get_size_mb "$logfile")
    saved=$((size_before - size_after))
    add_space_saved "$saved"
    echo "  Reduced to ${size_after}MB (saved ${saved}MB)"
done

echo -e "\n${YELLOW}Phase 5: Identifying redundant systems${NC}"
echo "----------------------------------------"

# List dashboard implementations for manual review
echo "Dashboard implementations found:"
find . -name "*dashboard*" -type f | grep -v "\.log\|\.json\|\.csv" | head -10

echo -e "\nMonitoring systems found:"
find . -name "*monitor*" -type f | grep -v "\.log\|\.json\|\.csv\|\.pid\|\.out" | head -10

echo -e "\n${GREEN}Cleanup Summary${NC}"
echo "==============="
echo "Space saved: ${SPACE_SAVED}MB"
echo ""
echo -e "${BLUE}Next Steps for Manual Review:${NC}"
echo "1. Review dashboard implementations - consolidate duplicates"
echo "2. Review monitoring systems - keep primary, remove redundant"
echo "3. Consider archiving large task_queue.json files if not actively needed"
echo "4. Run: du -sh * | sort -hr | head -10  (to verify space savings)"
echo ""
echo -e "${GREEN}Cleanup completed successfully!${NC}"
