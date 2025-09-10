#!/bin/bash

# Momentum Finance - Easy Sync Script
# This script helps sync changes from Cursor workspace to your local project

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}🔄 Momentum Finance Sync Tool${NC}"
echo "================================"

# Function to show current status
show_status() {
    echo -e "\n${YELLOW}📊 Current Status:${NC}"
    echo -e "${BLUE}Branch:${NC} $(git branch --show-current)"
    echo -e "${BLUE}Remote:${NC} $(git remote get-url origin 2>/dev/null || echo 'No remote set')"
    
    # Check for uncommitted changes
    if [[ -n $(git status -s) ]]; then
        echo -e "${RED}⚠️  You have uncommitted changes:${NC}"
        git status -s
        echo
        read -p "Do you want to stash these changes? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git stash push -m "Auto-stash before sync $(date)"
            echo -e "${GREEN}✅ Changes stashed${NC}"
        else
            echo -e "${RED}❌ Sync cancelled - please commit or stash your changes first${NC}"
            exit 1
        fi
    fi
}

# Function to sync with remote
sync_changes() {
    echo -e "\n${YELLOW}🔄 Syncing with remote...${NC}"
    
    # Fetch all branches
    echo "Fetching latest changes..."
    git fetch --all --prune
    
    # Get current branch
    CURRENT_BRANCH=$(git branch --show-current)
    
    # Show available Cursor branches
    echo -e "\n${BLUE}Available Cursor branches:${NC}"
    git branch -r | grep "cursor/" | sed 's/origin\///' | nl -v 0
    
    # Ask which branch to sync
    echo -e "\n${YELLOW}Which branch would you like to sync?${NC}"
    echo "0) Stay on current branch and pull latest"
    echo "Enter number or branch name:"
    read -r BRANCH_CHOICE
    
    if [[ "$BRANCH_CHOICE" == "0" || -z "$BRANCH_CHOICE" ]]; then
        # Pull current branch
        echo -e "${BLUE}Pulling latest changes for $CURRENT_BRANCH...${NC}"
        git pull origin "$CURRENT_BRANCH"
    elif [[ "$BRANCH_CHOICE" =~ ^[0-9]+$ ]]; then
        # Numeric choice
        SELECTED_BRANCH=$(git branch -r | grep "cursor/" | sed 's/origin\///' | sed -n "$((BRANCH_CHOICE))p" | xargs)
        if [[ -n "$SELECTED_BRANCH" ]]; then
            switch_and_pull "$SELECTED_BRANCH"
        else
            echo -e "${RED}Invalid selection${NC}"
            exit 1
        fi
    else
        # Branch name provided
        switch_and_pull "$BRANCH_CHOICE"
    fi
}

# Function to switch branch and pull
switch_and_pull() {
    local BRANCH=$1
    echo -e "${BLUE}Switching to $BRANCH...${NC}"
    
    # Check if branch exists locally
    if git show-ref --verify --quiet "refs/heads/$BRANCH"; then
        git checkout "$BRANCH"
    else
        git checkout -b "$BRANCH" "origin/$BRANCH"
    fi
    
    # Pull latest
    git pull origin "$BRANCH"
}

# Function to show recent changes
show_recent_changes() {
    echo -e "\n${YELLOW}📝 Recent changes:${NC}"
    git log --oneline -5
    echo
    read -p "Do you want to see the detailed changes? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        git log -p -1
    fi
}

# Function to merge to main
merge_to_main() {
    echo -e "\n${YELLOW}🔀 Merge to main branch?${NC}"
    read -p "Do you want to merge these changes to main? (y/n) " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        CURRENT_BRANCH=$(git branch --show-current)
        git checkout main
        git pull origin main
        git merge "$CURRENT_BRANCH"
        echo -e "${GREEN}✅ Merged to main${NC}"
        
        read -p "Push main to remote? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git push origin main
            echo -e "${GREEN}✅ Pushed to remote${NC}"
        fi
    fi
}

# Main execution
main() {
    # Check if in a git repository
    if ! git rev-parse --git-dir > /dev/null 2>&1; then
        echo -e "${RED}❌ Not in a git repository!${NC}"
        echo "Please run this script from your MomentumFinance project directory"
        exit 1
    fi
    
    show_status
    sync_changes
    show_recent_changes
    merge_to_main
    
    echo -e "\n${GREEN}✅ Sync complete!${NC}"
    
    # Check for stashed changes
    if git stash list | grep -q "Auto-stash before sync"; then
        echo -e "\n${YELLOW}📦 You have stashed changes:${NC}"
        git stash list | grep "Auto-stash before sync"
        read -p "Do you want to restore them? (y/n) " -n 1 -r
        echo
        if [[ $REPLY =~ ^[Yy]$ ]]; then
            git stash pop
            echo -e "${GREEN}✅ Changes restored${NC}"
        fi
    fi
}

# Run main function
main