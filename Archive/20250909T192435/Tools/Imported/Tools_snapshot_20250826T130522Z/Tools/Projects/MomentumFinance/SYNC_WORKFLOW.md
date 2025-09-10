# Momentum Finance - Sync Workflow Guide

This guide explains how to easily sync changes between your Cursor workspace and your local Mac project.

## 🚀 Quick Start

### 1. Initial Setup (One-time only)
```bash
cd /Users/danielstevens/Desktop/MomentumFinance
./setup-sync.sh
```

This sets up git aliases and makes all scripts executable.

### 2. Daily Sync Commands

#### Quick Sync (Recommended for most cases)
```bash
git sync
# or
./quick-sync.sh
```
- Automatically stashes local changes
- Pulls latest from current branch
- Restores your local changes

#### Interactive Sync
```bash
git sync-cursor
# or
./sync.sh
```
- Shows all available Cursor branches
- Lets you choose which branch to sync
- Option to merge to main
- Shows detailed changes

## 📋 Available Commands

### Git Aliases (work from anywhere in the project)
- `git sync` - Quick sync current branch
- `git sync-cursor` - Interactive sync with options
- `git st` - Compact status view
- `git recent` - Show last 10 commits
- `git cursor-branches` - List all Cursor branches
- `git update` - Fetch all changes without merging

### Shell Scripts (run from project root)
- `./quick-sync.sh` - Fast sync without prompts
- `./sync.sh` - Interactive sync tool
- `./build_xcode.sh` - Build project with Xcode

## 🔄 Typical Workflow

### Before Starting Work
```bash
cd /Users/danielstevens/Desktop/MomentumFinance
git sync
```

### After Cursor Makes Changes
```bash
# Quick sync if you're on the right branch
git sync

# Or use interactive sync to switch branches
git sync-cursor
```

### See What Changed
```bash
git recent          # List recent commits
git changes         # Show detailed last change
git st             # Check current status
```

## 🌿 Working with Branches

### List Cursor Branches
```bash
git cursor-branches
```

### Switch to a Cursor Branch
```bash
git checkout cursor/branch-name
git pull
```

### Merge Cursor Changes to Main
```bash
git checkout main
git merge cursor/branch-name
git push origin main
```

## 🚨 Troubleshooting

### "You have uncommitted changes"
The sync script will offer to stash them. Say 'y' to stash, sync, then restore.

### "Not in a git repository"
Make sure you're in the MomentumFinance directory:
```bash
cd /Users/danielstevens/Desktop/MomentumFinance
```

### "Permission denied"
Run the setup script first:
```bash
./setup-sync.sh
```

## 💡 Pro Tips

1. **Use `git sync` frequently** - It's safe and preserves your local changes
2. **Check status before big operations** - `git st` shows current state
3. **Review changes** - `git recent` shows what's new
4. **Work on feature branches** - Keep main stable

## 🔐 Security Note

Your changes are synced through GitHub. The repository is private and only accessible to authorized users.