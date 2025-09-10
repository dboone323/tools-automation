#!/bin/bash

# Momentum Finance - Sync Setup Script
# Sets up git aliases and sync tools for easier workflow

echo "🔧 Setting up Momentum Finance sync tools..."
echo "==========================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get the script directory
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"

# Setup git aliases for easier sync
echo -e "\n${YELLOW}Setting up Git aliases...${NC}"

# Sync aliases
git config alias.sync-cursor "!bash $SCRIPT_DIR/sync.sh"
git config alias.quick-sync "!bash $SCRIPT_DIR/quick-sync.sh"
git config alias.sync "!bash $SCRIPT_DIR/quick-sync.sh"

# Status aliases
git config alias.st "status -sb"
git config alias.s "status -s"

# Branch aliases
git config alias.branches "branch -a"
git config alias.cursor-branches "branch -r | grep cursor/"

# Log aliases
git config alias.recent "log --oneline -10"
git config alias.today "log --oneline --since='1 day ago'"
git config alias.changes "log -p -1"

# Fetch aliases
git config alias.update "fetch --all --prune"

# Stash aliases
git config alias.save "stash push -m"
git config alias.stashes "stash list"

# Make scripts executable
chmod +x "$SCRIPT_DIR/sync.sh"
chmod +x "$SCRIPT_DIR/quick-sync.sh"
chmod +x "$SCRIPT_DIR/build_xcode.sh"

echo -e "${GREEN}✅ Git aliases configured!${NC}"

# Create a convenience script in user's bin directory
if [[ -d "$HOME/bin" ]]; then
    echo -e "\n${YELLOW}Installing sync command to ~/bin...${NC}"
    cat > "$HOME/bin/mf-sync" << 'EOF'
#!/bin/bash
# Momentum Finance sync shortcut

# Find the project directory
PROJECT_DIR=$(find ~ -name "MomentumFinance.xcodeproj" -type d 2>/dev/null | head -1 | xargs dirname)

if [[ -z "$PROJECT_DIR" ]]; then
    echo "❌ Could not find MomentumFinance project"
    echo "Please run from project directory or set PROJECT_DIR environment variable"
    exit 1
fi

cd "$PROJECT_DIR" && ./quick-sync.sh
EOF
    chmod +x "$HOME/bin/mf-sync"
    echo -e "${GREEN}✅ Installed mf-sync command${NC}"
fi

echo -e "\n${GREEN}🎉 Setup complete!${NC}"
echo ""
echo "Available commands:"
echo "  ${YELLOW}Git aliases:${NC}"
echo "    git sync         - Quick sync (pulls latest changes)"
echo "    git sync-cursor  - Interactive sync with branch selection"
echo "    git st           - Compact status"
echo "    git recent       - Show recent commits"
echo "    git cursor-branches - List Cursor branches"
echo ""
echo "  ${YELLOW}Shell scripts:${NC}"
echo "    ./sync.sh        - Interactive sync tool"
echo "    ./quick-sync.sh  - Quick sync (no prompts)"
echo "    ./build_xcode.sh - Build with Xcode"

if [[ -f "$HOME/bin/mf-sync" ]]; then
    echo ""
    echo "  ${YELLOW}Global command:${NC}"
    echo "    mf-sync         - Sync from anywhere"
fi

echo ""
echo "📝 Next steps:"
echo "1. Run 'git sync' to pull latest changes"
echo "2. Run 'git sync-cursor' for interactive sync"
echo "3. Run './build_xcode.sh' to build the project"