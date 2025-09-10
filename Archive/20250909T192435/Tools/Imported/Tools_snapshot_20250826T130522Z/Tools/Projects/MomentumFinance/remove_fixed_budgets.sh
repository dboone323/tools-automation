#!/bin/bash

PROJECT_FILE="/Users/danielstevens/Desktop/MomentumFinaceApp/MomentumFinance.xcodeproj/project.pbxproj"

echo "Removing BudgetsView_Fixed.swift references from Xcode project..."

# Create backup
cp "$PROJECT_FILE" "$PROJECT_FILE.backup_remove_fixed"

# Remove the specific lines containing BudgetsView_Fixed references
sed -i '' '/BudgetsView_Fixed\.swift/d' "$PROJECT_FILE"

echo "Removed BudgetsView_Fixed.swift references from project file"
