#!/bin/bash

echo "=== Removing Problematic Symlinks ==="
echo
echo "This will remove symlinks that are confusing Xcode's file reference system"
echo

# Check and remove symlinks
echo "Checking for symlinks to remove..."

# MomentumFinance directory symlinks
if [ -L "MomentumFinance/MomentumFinanceApp.swift" ]; then
    echo "Removing: MomentumFinance/MomentumFinanceApp.swift"
    rm -f MomentumFinance/MomentumFinanceApp.swift
fi

if [ -L "MomentumFinance/ContentView.swift" ]; then
    echo "Removing: MomentumFinance/ContentView.swift"
    rm -f MomentumFinance/ContentView.swift
fi

# Shared directory symlinks
if [ -L "Shared/DataExportView.swift" ]; then
    echo "Removing: Shared/DataExportView.swift"
    rm -f Shared/DataExportView.swift
fi

if [ -L "Shared/DataImportView.swift" ]; then
    echo "Removing: Shared/DataImportView.swift"
    rm -f Shared/DataImportView.swift
fi

if [ -L "Shared/HapticManager.swift" ]; then
    echo "Removing: Shared/HapticManager.swift"
    rm -f Shared/HapticManager.swift
fi

if [ -L "Shared/SettingsView.swift" ]; then
    echo "Removing: Shared/SettingsView.swift"
    rm -f Shared/SettingsView.swift
fi

echo
echo "✅ Symlinks removed"
echo
echo "Next steps:"
echo "1. Open MomentumFinance.xcodeproj in Xcode"
echo "2. Remove all file references (select all → Delete → Remove References)"
echo "3. Add the entire Shared folder back:"
echo "   - Right-click project root → Add Files"
echo "   - Select the Shared folder"
echo "   - ✅ Create groups"
echo "   - ❌ Copy items if needed (unchecked)"
echo "   - ✅ Add to targets: MomentumFinance"
echo
echo "See fix_xcode_references_detailed.md for complete instructions"