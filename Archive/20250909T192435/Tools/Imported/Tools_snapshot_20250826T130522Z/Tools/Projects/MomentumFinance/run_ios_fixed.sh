#!/bin/bash

# Fixed iOS launcher for MomentumFinance
# With improved path handling

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}📱 Running MomentumFinance on iOS Simulator${NC}"
echo "=========================================="

# Get available simulators
DEVICE_ID=$(xcrun simctl list devices available | grep "iPhone 16" | head -1 | sed -E 's/.*\(([0-9A-Z-]+)\).*/\1/')
DEVICE_NAME=$(xcrun simctl list devices available | grep "iPhone 16" | head -1 | sed -n 's/.*\(iPhone [^)]*\).*/\1/p')

if [ -z "$DEVICE_ID" ]; then
  echo -e "${YELLOW}No iPhone 16 found, looking for any iPhone...${NC}"
  DEVICE_ID=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed -E 's/.*\(([0-9A-Z-]+)\).*/\1/')
  DEVICE_NAME=$(xcrun simctl list devices available | grep "iPhone" | head -1 | sed -n 's/.*\(iPhone [^)]*\).*/\1/p')
fi

if [ -z "$DEVICE_ID" ]; then
  echo -e "${RED}No iPhone simulator found. Please create one in Xcode.${NC}"
  exit 1
fi

echo "Selected device: $DEVICE_NAME ($DEVICE_ID)"

# Boot simulator
echo "Booting simulator..."
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || echo "Simulator already booted"

# Open simulator
echo "Opening Simulator app..."
open -a Simulator

# Wait for simulator to be ready
echo "Waiting for simulator to be ready..."
sleep 3

# Build the app
echo "Building app (this may take a moment)..."
BUILD_DIR=$(mktemp -d)/build
xcodebuild -project MomentumFinance.xcodeproj -scheme MomentumFinance -destination "platform=iOS Simulator,id=$DEVICE_ID" -derivedDataPath "$BUILD_DIR" build

if [ $? -eq 0 ]; then
  echo -e "${GREEN}✅ Build successful!${NC}"
  
  # Find the app bundle
  APP_PATH=$(find "$BUILD_DIR" -name "*.app" -type d | head -1)
  
  if [ -z "$APP_PATH" ]; then
    echo -e "${RED}❌ Could not find the built app.${NC}"
    exit 1
  fi
  
  echo "Found app at: $APP_PATH"
  
  # Install the app
  echo "Installing app to simulator..."
  xcrun simctl install "$DEVICE_ID" "$APP_PATH"
  
  if [ $? -eq 0 ]; then
    echo "App installed successfully!"
    
    # Launch the app
    echo "Launching app..."
    xcrun simctl launch "$DEVICE_ID" "com.momentumfinance.MomentumFinance"
    
    echo -e "${GREEN}✨ MomentumFinance launched in $DEVICE_NAME simulator!${NC}"
  else
    echo -e "${RED}❌ Failed to install the app.${NC}"
  fi
else
  echo -e "${RED}❌ Build failed${NC}"
fi
