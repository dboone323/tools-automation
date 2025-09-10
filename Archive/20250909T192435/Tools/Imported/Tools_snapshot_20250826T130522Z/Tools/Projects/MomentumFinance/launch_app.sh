#!/bin/bash

# MomentumFinance App Launcher
# This script builds and runs the MomentumFinance app using Swift Package Manager

echo "🚀 MomentumFinance App Launcher"
echo "==============================="

# Check if we're in the right directory
if [ ! -f "Package.swift" ]; then
    echo "❌ Error: Package.swift not found. Please run this script from the project root directory."
    exit 1
fi

# Build the app
echo "🔨 Building MomentumFinance..."
if swift build; then
    echo "✅ Build successful!"
    echo ""
    echo "🏃 Running MomentumFinance app..."
    echo "   (Press Ctrl+C to stop the app)"
    echo ""
    swift run MomentumFinance
else
    echo "❌ Build failed. Please check the errors above."
    exit 1
fi
