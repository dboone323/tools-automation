#!/bin/bash

# Momentum Finance - Xcode Build Script
# This script helps build the project through Xcode on macOS

echo "🚀 Building Momentum Finance through Xcode..."

# Check if running on macOS
if [[ "$OSTYPE" != "darwin"* ]]; then
    echo "❌ This script must be run on macOS"
    exit 1
fi

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo "❌ Xcode is not installed. Please install Xcode from the App Store."
    exit 1
fi

# Clean build folder
echo "🧹 Cleaning build folder..."
xcodebuild clean -project MomentumFinance.xcodeproj -scheme MomentumFinance -configuration Debug

# Build for iOS Simulator
echo "📱 Building for iOS Simulator..."
xcodebuild build \
    -project MomentumFinance.xcodeproj \
    -scheme MomentumFinance \
    -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 15 Pro,OS=latest' \
    -derivedDataPath ./DerivedData \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Check build result
if [ $? -eq 0 ]; then
    echo "✅ Build succeeded!"
    echo "📍 Build products are in: ./DerivedData/Build/Products/"
else
    echo "❌ Build failed. Check the error messages above."
    exit 1
fi

# Optional: Open in Xcode
read -p "Would you like to open the project in Xcode? (y/n) " -n 1 -r
echo
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open MomentumFinance.xcodeproj
fi