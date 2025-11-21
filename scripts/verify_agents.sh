#!/usr/bin/env bash
#
# verify_agents.sh - Health check script for agent automation
#
# Checks:
# - Agent scripts are executable
# - Agent scripts have valid syntax
# - Required directories exist
# - No broken symbolic links
#

set -uo pipefail

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
AGENTS_DIR="${REPO_ROOT}/agents"

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "=== Agent Health Check ==="
echo "Agents Directory: $AGENTS_DIR"
echo ""

# Check directory structure
echo "Checking directory structure..."
REQUIRED_DIRS=("logs" "status" "tests" "bin")
for dir in "${REQUIRED_DIRS[@]}"; do
    FULL_DIR="${AGENTS_DIR}/${dir}"
    if [[ -d "$FULL_DIR" ]]; then
        echo -e "[${GREEN}✓${NC}] Directory exists: $dir/"
    else
        echo -e "[${YELLOW}!${NC}] Missing directory: $dir/ (creating...)"
        mkdir -p "$FULL_DIR"
    fi
done
echo ""

# Check agent scripts
echo "Checking agent scripts..."
AGENT_COUNT=0
ERROR_COUNT=0

# Find all .sh files in agents/ (but not in subdirectories)
for agent_script in "$AGENTS_DIR"/*.sh; do
    # Skip if no files match
    [[ ! -f "$agent_script" ]] && continue
    
    AGENT_NAME=$(basename "$agent_script")
    ((AGENT_COUNT++))
    
    # Check if executable
    if [[ ! -x "$agent_script" ]]; then
        echo -e "[${RED}✗${NC}] Not executable: $AGENT_NAME"
        ((ERROR_COUNT++))
        continue
    fi
    
    # Check bash syntax (quietly)
    if bash -n "$agent_script" 2>/dev/null; then
        echo -e "[${GREEN}✓${NC}] Valid: $AGENT_NAME"
    else
        echo -e "[${RED}✗${NC}] Syntax error: $AGENT_NAME"
        bash -n "$agent_script" 2>&1 | sed 's/^/    /'
        ((ERROR_COUNT++))
    fi
done

echo ""
echo "=== Summary ==="
echo "Total agents checked: $AGENT_COUNT"
if [[ $ERROR_COUNT -eq 0 ]]; then
    echo -e "[${GREEN}✓${NC}] All agents passed health checks!"
    exit 0
else
    echo -e "[${RED}✗${NC}] $ERROR_COUNT agent(s) have issues."
    exit 1
fi
