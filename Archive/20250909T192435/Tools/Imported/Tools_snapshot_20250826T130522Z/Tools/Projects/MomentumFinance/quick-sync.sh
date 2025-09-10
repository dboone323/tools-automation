#!/bin/bash

# Momentum Finance - Quick Sync Script
# Fast sync without prompts - just pull latest changes

echo "🚀 Quick Sync - Momentum Finance"
echo "================================"

# Check if in git repo
if ! git rev-parse --git-dir > /dev/null 2>&1; then
    echo "❌ Not in a git repository!"
    exit 1
fi

# Stash any local changes
if [[ -n $(git status -s) ]]; then
    echo "📦 Stashing local changes..."
    git stash push -m "Quick sync stash $(date)"
fi

# Fetch and pull
echo "🔄 Fetching latest changes..."
git fetch --all --prune

CURRENT_BRANCH=$(git branch --show-current)
echo "📥 Pulling $CURRENT_BRANCH..."
git pull origin "$CURRENT_BRANCH"

# Show what changed
echo ""
echo "📝 Recent changes:"
git log --oneline -5

# Restore stashed changes if any
if git stash list | grep -q "Quick sync stash"; then
    echo ""
    echo "📦 Restoring stashed changes..."
    git stash pop
fi

echo ""
echo "✅ Quick sync complete!"