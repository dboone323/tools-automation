#!/bin/bash

echo "Cleaning and rebuilding iOS app..."

# Clean derived data
echo "Cleaning derived data..."
rm -rf ~/Library/Developer/Xcode/DerivedData/MomentumFinance-*

# Clean build folder
echo "Cleaning build folder..."
xcodebuild clean -project MomentumFinance.xcodeproj -scheme MomentumFinance -destination "platform=iOS Simulator,name=iPhone 15"

# Kill simulator
echo "Killing simulator..."
killall "Simulator" 2>/dev/null || true

# Build the app
echo "Building app..."
xcodebuild build \
    -project MomentumFinance.xcodeproj \
    -scheme MomentumFinance \
    -destination "platform=iOS Simulator,name=iPhone 15" \
    -configuration Debug \
    PRODUCT_BUNDLE_IDENTIFIER="com.momentumfinance.MomentumFinance" \
    CODE_SIGN_IDENTITY="" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO

# Check build result
if [ $? -eq 0 ]; then
    echo "Build succeeded!"
    
    # Launch simulator
    echo "Launching simulator..."
    open -a Simulator
    
    # Wait for simulator to boot
    echo "Waiting for simulator to boot..."
    xcrun simctl boot "iPhone 15" 2>/dev/null || true
    sleep 5
    
    # Install and launch app
    echo "Installing app..."
    xcrun simctl install "iPhone 15" ~/Library/Developer/Xcode/DerivedData/MomentumFinance-*/Build/Products/Debug-iphonesimulator/MomentumFinance.app
    
    echo "Launching app..."
    xcrun simctl launch "iPhone 15" com.momentumfinance.MomentumFinance
else
    echo "Build failed!"
    exit 1
fi