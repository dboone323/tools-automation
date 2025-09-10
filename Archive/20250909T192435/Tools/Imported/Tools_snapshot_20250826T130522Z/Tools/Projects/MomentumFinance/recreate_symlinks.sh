#!/bin/bash

echo "=== Recreating Required Symlinks ==="
echo

# Create MomentumFinance directory if it doesn't exist
mkdir -p MomentumFinance

# Recreate symlinks that Xcode expects
echo "Creating symlinks for files Xcode is looking for..."

# MomentumFinance directory symlinks
if [ -f "Shared/MomentumFinanceApp.swift" ]; then
    ln -sf ../Shared/MomentumFinanceApp.swift MomentumFinance/MomentumFinanceApp.swift
    echo "✅ Created: MomentumFinance/MomentumFinanceApp.swift"
fi

if [ -f "Shared/ContentView.swift" ]; then
    ln -sf ../Shared/ContentView.swift MomentumFinance/ContentView.swift
    echo "✅ Created: MomentumFinance/ContentView.swift"
fi

# Shared directory symlinks
if [ -f "Shared/Views/Settings/DataExportView.swift" ]; then
    ln -sf Views/Settings/DataExportView.swift Shared/DataExportView.swift
    echo "✅ Created: Shared/DataExportView.swift"
fi

if [ -f "Shared/Views/Settings/DataImportView.swift" ]; then
    ln -sf Views/Settings/DataImportView.swift Shared/DataImportView.swift
    echo "✅ Created: Shared/DataImportView.swift"
fi

if [ -f "Shared/Utils/HapticManager.swift" ]; then
    ln -sf Utils/HapticManager.swift Shared/HapticManager.swift
    echo "✅ Created: Shared/HapticManager.swift"
fi

if [ -f "Shared/Views/Settings/SettingsView.swift" ]; then
    ln -sf Views/Settings/SettingsView.swift Shared/SettingsView.swift
    echo "✅ Created: Shared/SettingsView.swift"
fi

echo
echo "✅ Symlinks recreated!"
echo
echo "Now try building again in Xcode (Cmd+B)"