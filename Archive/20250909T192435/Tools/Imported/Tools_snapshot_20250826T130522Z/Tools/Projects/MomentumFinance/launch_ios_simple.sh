#!/bin/bash

# Simple iOS launcher for MomentumFinance
# Uses the currently booted simulator or boots iPhone 16 iOS 18.1
# Momentum Finance - Personal Finance App
# Copyright © 2025 Momentum Finance. All rights reserved.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}📱 MomentumFinance iOS Simple Launcher${NC}"
echo "======================================"

# Set working directory
cd "$(dirname "$0")"

# Use the iPhone 16 iOS 18.1 that we know exists and is booted
DEVICE_ID="891E4B4F-9FEA-494A-8DD0-DA1C058B5253"
DEVICE_NAME="iPhone 16"
IOS_VERSION="18.1"

echo -e "${GREEN}✅ Using: $DEVICE_NAME (iOS $IOS_VERSION)${NC}"
echo "Device ID: $DEVICE_ID"

# Make sure the simulator is booted
echo "⚡ Ensuring simulator is booted..."
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || echo "Simulator already booted"

# Open the simulator app
echo "📲 Opening simulator..."
open -a Simulator

# Wait for simulator to be ready
echo "⏳ Waiting for simulator to be ready..."
sleep 3

# Build the app using Xcode with simplified approach
echo "🔨 Building app with Xcode..."
xcodebuild -project MomentumFinance.xcodeproj \
           -scheme MomentumFinance \
           -destination "platform=iOS Simulator,id=$DEVICE_ID" \
           build

BUILD_SUCCESS=$?

if [ $BUILD_SUCCESS -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
    
    # Get the app bundle identifier and path
    APP_BUNDLE_ID="com.momentumfinance.MomentumFinance"
    APP_PATH=$(find . -name "MomentumFinance.app" -path "*/Build/Products/Debug-iphonesimulator/*" | head -1)
    
    if [ -z "$APP_PATH" ]; then
        echo -e "${YELLOW}⚠️  App bundle not found in expected location, searching...${NC}"
        APP_PATH=$(find . -name "MomentumFinance.app" | head -1)
    fi
    
    if [ ! -z "$APP_PATH" ]; then
        # Install the app
        echo "📦 Installing app: $APP_PATH"
        xcrun simctl install "$DEVICE_ID" "$APP_PATH"
        
        # Launch the app
        echo "🚀 Launching app..."
        xcrun simctl launch "$DEVICE_ID" "$APP_BUNDLE_ID"
        
        echo -e "${GREEN}✨ MomentumFinance launched successfully on $DEVICE_NAME!${NC}"
        echo "🎯 iOS Configuration: $DEVICE_NAME (iOS $IOS_VERSION)"
    else
        echo -e "${RED}❌ Could not find app bundle after build${NC}"
        exit 1
    fi
    
else
    echo -e "${RED}❌ Build failed${NC}"
    echo "Let's try a simpler approach without Xcode project..."
    
    # Alternative: Just open the simulator and let user manually install
    echo "🔄 Opening simulator for manual testing..."
    echo "You can drag and drop the app bundle or use other installation methods."
    
    exit 1
fi
