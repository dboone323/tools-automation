#!/bin/bash

# Launch MomentumFinance on iPhone 16 iOS 18.1 Simulator
# Momentum Finance - Personal Finance App
# Copyright © 2025 Momentum Finance. All rights reserved.

echo "🚀 Launching MomentumFinance on iPhone 16 iOS 18.1 simulator..."

# Set working directory
cd "$(dirname "$0")"

# iPhone 16 iOS 18.1 simulator details
DEVICE_ID="891E4B4F-9FEA-494A-8DD0-DA1C058B5253"
DEVICE_NAME="iPhone 16"
IOS_VERSION="18.1"

echo "📱 Target Device: $DEVICE_NAME (iOS $IOS_VERSION)"
echo "🆔 Device ID: $DEVICE_ID"

# Boot the simulator if not already running
echo "⚡ Booting simulator..."
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || echo "Simulator already booted"

# Open the simulator app
echo "📲 Opening simulator..."
open -a Simulator

# Wait a moment for simulator to start
sleep 3

# Build and install the app
echo "🔨 Building app for simulator..."
xcodebuild -project MomentumFinance.xcodeproj \
           -scheme MomentumFinance \
           -destination "platform=iOS Simulator,name=$DEVICE_NAME,OS=$IOS_VERSION" \
           -derivedDataPath ./DerivedData \
           clean build install

if [ $? -eq 0 ]; then
    echo "✅ Build successful!"
    
    # Get the app bundle identifier
    APP_BUNDLE_ID="com.momentumfinance.MomentumFinance"
    
    # Install and launch the app
    echo "📦 Installing app on simulator..."
    xcrun simctl install "$DEVICE_ID" "./DerivedData/Build/Products/Debug-iphonesimulator/MomentumFinance.app"
    
    echo "🚀 Launching app..."
    xcrun simctl launch "$DEVICE_ID" "$APP_BUNDLE_ID"
    
    echo "✨ MomentumFinance launched successfully on iPhone 16!"
    echo "🎯 Configuration: iPhone 16 (iOS 18.1) - Latest device target achieved!"
    
else
    echo "❌ Build failed. Please check the error messages above."
    exit 1
fi
