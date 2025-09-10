#!/bin/bash
#!/bin/bash
#!/bin/bash
#!/bin/bash
#!/bin/bash
#!/bin/bash
#!/bin/bash
#!/bin/bash
#!/bin/bash
#!/bin/bash

# iOS-specific launcher for MomentumFinance
# Momentum Finance - Personal Finance App
# Copyright © 2025 Momentum Finance. All rights reserved.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}📱 MomentumFinance iOS Launcher${NC}"
echo "================================"

# Set working directory
cd "$(dirname "$0")"

# Look for iPhone 16 simulator with iOS 18.1
echo "🔍 Checking for iPhone 16 simulator..."
DEVICE_ID=$(xcrun simctl list devices available | grep "iPhone 16 (" | grep -i "18.1" | head -1 | sed -E 's/.*\(([0-9A-Z-]+)\).*/\1/')
DEVICE_NAME="iPhone 16"

if [ -z "$DEVICE_ID" ]; then
    # Try iPhone 16 Pro as a fallback
    echo "Looking for iPhone 16 Pro simulator..."
    DEVICE_ID=$(xcrun simctl list devices available | grep "iPhone 16 Pro (" | grep -i "18.1" | head -1 | sed -E 's/.*\(([0-9A-Z-]+)\).*/\1/')
    DEVICE_NAME="iPhone 16 Pro"
fi

if [ -z "$DEVICE_ID" ]; then
    # Last resort: any iPhone simulator
    echo "Looking for any iPhone simulator..."
    DEVICE_ID=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed -E 's/.*\(([0-9A-Z-]+)\).*/\1/')
    DEVICE_NAME=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed -E 's/.*iPhone ([^(]+).*/iPhone \1/' | xargs)
fi

if [ -z "$DEVICE_ID" ]; then
    echo -e "${RED}❌ Could not find any iPhone simulator${NC}"
    echo "Available simulators:"
    xcrun simctl list devices available
    exit 1
fi

echo -e "${GREEN}✅ Selected: $DEVICE_NAME${NC}"
echo "Device ID: $DEVICE_ID"

# Boot the simulator
echo "⚡ Booting simulator..."
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || echo "Simulator already booted"

# Open the simulator app
echo "📲 Opening simulator..."
open -a Simulator

# Wait for simulator to be ready
echo "⏳ Waiting for simulator to be ready..."
sleep 5

# Build the app using Xcode
echo "🔨 Building app with Xcode..."
xcodebuild -project MomentumFinance.xcodeproj \
           -scheme MomentumFinance \
           -destination "platform=iOS Simulator,id=$DEVICE_ID" \
           -derivedDataPath ./DerivedData \
           clean build

if [ $? -eq 0 ]; then
    echo -e "${GREEN}✅ Build successful!${NC}"
    
    # Get the app bundle identifier
    APP_BUNDLE_ID="com.momentumfinance.MomentumFinance"
    APP_PATH="./DerivedData/Build/Products/Debug-iphonesimulator/MomentumFinance.app"
    
    # Install the app
    echo "📦 Installing app on simulator..."
    xcrun simctl install "$DEVICE_ID" "$APP_PATH"
    
    # Launch the app
    echo "🚀 Launching app..."
    xcrun simctl launch "$DEVICE_ID" "$APP_BUNDLE_ID"
    
    echo -e "${GREEN}✨ MomentumFinance launched successfully on $DEVICE_NAME!${NC}"
else
    echo -e "${RED}❌ Build failed${NC}"
    exit 1
fi
