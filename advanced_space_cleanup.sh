#!/opt/homebrew/bin/bash
# Advanced Space Optimization for Hybrid Desktop + Cloud System
# Removes build artifacts, caches, and temporary files while preserving functionality

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 Advanced Space Optimization for Hybrid System${NC}"
echo "================================================="

# Get current directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$SCRIPT_DIR"

# Track space saved
SPACE_SAVED=0

# Function to calculate file size in MB
get_size_mb() {
    local file="$1"
    if [[ -f "$file" ]] || [[ -d "$file" ]]; then
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

echo -e "${YELLOW}Phase 1: Cleaning Swift build artifacts${NC}"
echo "------------------------------------------"

# Clean Swift build artifacts (safe to remove)
if [[ -d "shared-kit/.build" ]]; then
    size=$(get_size_mb "shared-kit/.build")
    echo "Removing Swift build artifacts: shared-kit/.build (${size}MB)"
    rm -rf "shared-kit/.build"
    add_space_saved "$size"
fi

# Clean other Swift build directories
for build_dir in $(find . -name ".build" -type d -not -path "./shared-kit/.build"); do
    if [[ -d "$build_dir" ]]; then
        size=$(get_size_mb "$build_dir")
        echo "Removing Swift build artifacts: $build_dir (${size}MB)"
        rm -rf "$build_dir"
        add_space_saved "$size"
    fi
done

echo -e "\n${YELLOW}Phase 2: Cleaning Python cache files${NC}"
echo "----------------------------------------"

# Remove Python __pycache__ directories
PYCACHE_COUNT=$(find . -name "__pycache__" -type d | wc -l)
if [[ $PYCACHE_COUNT -gt 0 ]]; then
    echo "Found $PYCACHE_COUNT __pycache__ directories"
    find . -name "__pycache__" -type d -exec rm -rf {} + 2>/dev/null || true
    echo "Removed Python cache directories"
fi

# Remove .pyc files
PYC_COUNT=$(find . -name "*.pyc" -type f | wc -l)
if [[ $PYC_COUNT -gt 0 ]]; then
    echo "Found $PYC_COUNT .pyc files"
    find . -name "*.pyc" -type f -delete
    echo "Removed .pyc files"
fi

echo -e "\n${YELLOW}Phase 3: Cleaning Node.js artifacts${NC}"
echo "--------------------------------------"

# Clean node_modules/.cache if it exists
if [[ -d "node_modules/.cache" ]]; then
    size=$(get_size_mb "node_modules/.cache")
    echo "Removing Node.js cache: node_modules/.cache (${size}MB)"
    rm -rf "node_modules/.cache"
    add_space_saved "$size"
fi

echo -e "\n${YELLOW}Phase 4: Cleaning log archives${NC}"
echo "----------------------------------"

# Remove old log archives (keep last 7 days)
find ./logs -name "*.log.*" -mtime +7 -type f -delete 2>/dev/null || true
find ./agents -name "*.log.*" -mtime +7 -type f -delete 2>/dev/null || true

echo -e "\n${YELLOW}Phase 5: Optimizing virtual environments${NC}"
echo "---------------------------------------------"

# Clean pip cache in venv
if [[ -d "venv" ]]; then
    echo "Cleaning pip cache in venv..."
    # Remove pip cache and temporary files
    find venv -name "*.dist-info" -type d | head -20 | while read -r dist_info; do
        if [[ -d "$dist_info" ]]; then
            size=$(get_size_mb "$dist_info")
            echo "Removing pip metadata: $dist_info (${size}MB)"
            rm -rf "$dist_info"
            add_space_saved "$size"
        fi
    done
fi

echo -e "\n${YELLOW}Phase 6: Removing temporary workspace files${NC}"
echo "------------------------------------------------"

# Remove VS Code temporary files
find . -name ".vscode-test" -type d -exec rm -rf {} + 2>/dev/null || true
find . -name "*.vsix" -type f -delete 2>/dev/null || true

# Remove macOS DS_Store files
find . -name ".DS_Store" -type f -delete 2>/dev/null || true

echo -e "\n${YELLOW}Phase 7: Consolidating redundant dashboards${NC}"
echo "-----------------------------------------------"

# List dashboard files for manual review (don't auto-delete)
echo "Dashboard files found (review for consolidation):"
find . -name "*dashboard*" -type f | grep -v "\.log\|\.json\|\.csv\|\.pid" | head -15

echo -e "\nMonitoring systems found (review for consolidation):"
find . -name "*monitor*" -type f | grep -v "\.log\|\.json\|\.csv\|\.pid\|\.out\|\.md" | head -10

echo -e "\n${GREEN}Optimization Summary${NC}"
echo "======================"
echo "Space saved: ${SPACE_SAVED}MB"
echo ""
echo -e "${BLUE}Current Space Usage (Top 10):${NC}"
du -sh * 2>/dev/null | sort -hr | head -10 || true

echo ""
echo -e "${YELLOW}Next Steps:${NC}"
echo "1. Review dashboard/monitoring systems for consolidation"
echo "2. Consider archiving large task_queue.json files if not actively needed"
echo "3. Test autonomous system functionality after cleanup"
echo "4. Run desktop app development with freed space"
echo ""
echo -e "${GREEN}Advanced cleanup completed!${NC}"
