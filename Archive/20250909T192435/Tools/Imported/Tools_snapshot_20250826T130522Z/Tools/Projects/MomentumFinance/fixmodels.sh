#!/bin/bash

echo "🛠 Fixing SwiftData model dependencies..."

# Create symbolic links from the root MomentumFinance folder to the Shared/Models folder
echo "Creating model links..."
cd /Users/danielstevens/Desktop/MomentumFinaceApp

# Remove the duplicate files from MomentumFinance folder
rm -f MomentumFinance/Budget.swift MomentumFinance/ExpenseCategory.swift

# Create symbolic links
ln -sf ../Shared/Models/Budget.swift MomentumFinance/Budget.swift
ln -sf ../Shared/Models/ExpenseCategory.swift MomentumFinance/ExpenseCategory.swift

echo "✅ Model files have been consolidated. Running compilation test..."

# Run the compilation test
./test-compilation.sh

echo "🏁 Model fix process completed!"