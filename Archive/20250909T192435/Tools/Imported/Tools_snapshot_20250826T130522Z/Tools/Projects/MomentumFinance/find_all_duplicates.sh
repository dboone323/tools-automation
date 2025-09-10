#!/bin/bash

# Find all duplicate Swift files in the project

echo "🔍 Finding all duplicate Swift files..."
echo "====================================="

# Colors
RED='\033[0;31m'
YELLOW='\033[1;33m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m'

# Find all Swift files and group by filename
echo -e "${YELLOW}Duplicate files found:${NC}\n"

# Create a temporary file to store results
TEMP_FILE=$(mktemp)

# Find all Swift files with their paths
find . -name "*.swift" -type f | while read -r file; do
    basename=$(basename "$file")
    echo "$basename|$file"
done | sort > "$TEMP_FILE"

# Process duplicates
current_file=""
duplicate_count=0
total_duplicates=0

while IFS='|' read -r basename filepath; do
    if [ "$basename" = "$current_file" ]; then
        if [ $duplicate_count -eq 0 ]; then
            echo -e "${RED}❌ $basename${NC}"
            echo "   $prev_filepath"
            ((total_duplicates++))
        fi
        echo "   $filepath"
        ((duplicate_count++))
    else
        if [ $duplicate_count -gt 0 ]; then
            echo ""
        fi
        current_file="$basename"
        prev_filepath="$filepath"
        duplicate_count=0
    fi
done < "$TEMP_FILE"

# Clean up
rm "$TEMP_FILE"

echo -e "\n${YELLOW}Summary:${NC}"
echo "Total files with duplicates: $total_duplicates"

echo -e "\n${BLUE}These duplicates need to be resolved in Xcode:${NC}"
echo "1. For each duplicate, decide which location is correct"
echo "2. Remove the incorrect file reference in Xcode"
echo "3. If needed, move the file to the correct location"

echo -e "\n${GREEN}Common duplicate patterns:${NC}"
echo "- Files in both MomentumFinance/ and Shared/"
echo "- Files in both root folders and organized subfolders"
echo "- Backup or temporary copies that weren't removed"