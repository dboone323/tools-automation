#!/bin/bash

# Simple iOS launcher for MomentumFinance
# Avoids extended attribute issues

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}📱 Running MomentumFinance on iOS Simulator (Simple)${NC}"
echo "==============================================="

# Get available simulators
DEVICE_ID=$(xcrun simctl list devices available | grep "iPhone 16" | head -1 | sed -E 's/.*\(([0-9A-Z-]+)\).*/\1/')

if [ -z "$DEVICE_ID" ]; then
  echo -e "${RED}No iPhone simulator found. Please create one in Xcode.${NC}"
  exit 1
fi

# Clean DerivedData directory to avoid conflicts
echo "Cleaning build artifacts..."
rm -rf ~/Library/Developer/Xcode/DerivedData/MomentumFinance-*
rm -rf ./DerivedData

# Build and run
echo "Opening simulator..."
open -a Simulator

echo "Building and running in simulator..."
xcodebuild -scheme MomentumFinance -destination "platform=iOS Simulator,id=$DEVICE_ID" -quiet build
if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Build successful!${NC}"
  xcrun simctl install $DEVICE_ID ./DerivedData/Build/Products/Debug-iphonesimulator/MomentumFinance.app
  xcrun simctl launch $DEVICE_ID com.momentumfinance.MomentumFinance
  echo -e "${GREEN}✨ App launched in simulator!${NC}"
else
  echo -e "${RED}❌ Build failed${NC}"
fi
