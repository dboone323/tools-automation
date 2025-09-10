#!/bin/bash

# Script to fix Momentum Finance project structure
# Creates a backup of current structure before making changes

PROJECT_DIR="/Users/danielstevens/Desktop/MomentumFinaceApp"
BACKUP_DIR="$PROJECT_DIR/Structure_Backup_$(date +%Y%m%d_%H%M%S)"

# Create backup folder
echo "Creating backup at $BACKUP_DIR"
mkdir -p "$BACKUP_DIR"

# Copy everything except the backup folder itself
find "$PROJECT_DIR" -mindepth 1 -maxdepth 1 ! -name "$(basename $BACKUP_DIR)" -exec cp -R {} "$BACKUP_DIR/" \;

echo "Structure backed up. Proceeding to reorganize project..."

# Create recommended structure if not exists
mkdir -p "$PROJECT_DIR/Shared/Models"
mkdir -p "$PROJECT_DIR/Shared/Features/Dashboard"
mkdir -p "$PROJECT_DIR/Shared/Features/Transactions"
mkdir -p "$PROJECT_DIR/Shared/Features/Budgets"
mkdir -p "$PROJECT_DIR/Shared/Features/Subscriptions"
mkdir -p "$PROJECT_DIR/Shared/Features/GoalsAndReports"
mkdir -p "$PROJECT_DIR/Shared/Navigation"
mkdir -p "$PROJECT_DIR/Shared/Utilities"
mkdir -p "$PROJECT_DIR/iOS"
mkdir -p "$PROJECT_DIR/macOS"

echo "Project structure verified. Add files to Xcode project next..."

echo "Project structure reorganization completed."
