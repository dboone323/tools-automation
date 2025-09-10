#!/bin/bash

# Fix Git Pull Configuration

echo "🔧 Fixing Git pull configuration..."
echo "==================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "\n${YELLOW}This will set up Git to use merge strategy for pulls (recommended for most users)${NC}"
echo "This is the safest option that preserves your commit history."

# Set pull strategy to merge (not rebase)
git config pull.rebase false

echo -e "${GREEN}✅ Git pull configuration fixed!${NC}"

echo -e "\n${BLUE}Now pulling the latest changes...${NC}"

# Get current branch
CURRENT_BRANCH=$(git branch --show-current)

# Try to pull
if git pull origin "$CURRENT_BRANCH"; then
    echo -e "${GREEN}✅ Successfully pulled latest changes!${NC}"
else
    echo -e "\n${YELLOW}If you still have issues, you may have local changes.${NC}"
    echo "Try running: git stash && git pull && git stash pop"
fi

echo -e "\n${BLUE}Configuration applied:${NC}"
echo "- Pull strategy: merge (pull.rebase = false)"
echo "- This setting is saved for this repository"
echo ""
echo "If you want this setting for ALL repositories, run:"
echo "  git config --global pull.rebase false"