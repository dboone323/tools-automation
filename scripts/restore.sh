#!/bin/bash
#
# Restore Script
#
# Usage: ./scripts/restore.sh [search_term]
#
# This script searches the archive and quarantine directories for files matching
# the search term and offers to restore them to their original location.
#

set -e

ARCHIVE_BASE_DIR="$HOME/tools-automation-archive"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

if [[ -z "$1" ]]; then
    echo "Usage: $0 <filename_or_path_fragment>"
    exit 1
fi

SEARCH_TERM="$1"

echo -e "${BLUE}Searching for '$SEARCH_TERM' in archives...${NC}"

# Find candidates
# We look in both date-based archives and quarantine
CANDIDATES=$(find "$ARCHIVE_BASE_DIR" -name "*${SEARCH_TERM}*" 2>/dev/null | head -n 20)

if [[ -z "$CANDIDATES" ]]; then
    echo -e "${YELLOW}No matches found.${NC}"
    exit 0
fi

echo -e "${GREEN}Found candidates:${NC}"
PS3="Select a file to restore (or 0 to cancel): "
select FILE in $CANDIDATES; do
    if [[ -n "$FILE" ]]; then
        echo -e "Selected: $FILE"
        
        # Determine original path relative to archive root structure
        # This is a bit heuristic; we assume the structure mirrors the repo
        # We strip the archive prefix until we find a recognizable repo path or just ask user
        
        # Simple approach: Ask user for destination or try to infer
        # For now, let's restore to current directory or ask
        
        echo -e "${YELLOW}Where should this be restored to?${NC}"
        echo "1) Original location (inferred)"
        echo "2) Current directory"
        echo "3) Custom path"
        
        read -r -p "Choice [1-3]: " DEST_CHOICE
        
        case $DEST_CHOICE in
            1)
                # Try to infer relative path from archive structure
                # Structure is usually .../YYYYMMDD/path/to/file OR .../quarantine/YYYYMMDD/path/to/file
                # We try to strip the date/quarantine part
                
                # Remove base dir
                REL_PATH="${FILE#$ARCHIVE_BASE_DIR/}"
                # Remove quarantine if present
                REL_PATH="${REL_PATH#quarantine/}"
                # Remove date dir (YYYYMMDD)
                REL_PATH="${REL_PATH#*/}"
                
                DEST="$REPO_ROOT/$REL_PATH"
                ;;
            2)
                DEST="$(pwd)/$(basename "$FILE")"
                ;;
            3)
                read -r -p "Enter absolute path: " DEST
                ;;
            *)
                echo "Invalid choice."
                exit 1
                ;;
        esac
        
        echo -e "Restoring to: ${BLUE}$DEST${NC}"
        mkdir -p "$(dirname "$DEST")"
        
        if [[ "$FILE" == *".tar.gz" ]]; then
            tar -xzf "$FILE" -C "$(dirname "$DEST")"
        else
            cp -R "$FILE" "$DEST"
        fi
        
        echo -e "${GREEN}Restore complete.${NC}"
        break
    else
        echo "Cancelled."
        break
    fi
done
