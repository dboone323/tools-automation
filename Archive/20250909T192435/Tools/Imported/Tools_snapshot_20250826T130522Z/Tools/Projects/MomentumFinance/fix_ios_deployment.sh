#!/bin/bash

echo "Fixing iOS deployment issues..."

# 1. Clean everything
echo "1. Cleaning build artifacts..."
rm -rf ~/Library/Developer/Xcode/DerivedData/MomentumFinance-*
rm -rf build/

# 2. Reset simulators
echo "2. Resetting simulators..."
if command -v xcrun &> /dev/null; then
    xcrun simctl shutdown all
    killall Simulator 2>/dev/null || true
fi

# 3. Update project file to use iOS 17.0 (more compatible)
echo "3. Updating deployment target to iOS 17.0..."
sed -i '' 's/IPHONEOS_DEPLOYMENT_TARGET = 18.0/IPHONEOS_DEPLOYMENT_TARGET = 17.0/g' MomentumFinance.xcodeproj/project.pbxproj

# 4. Build for simulator
echo "4. Building for iOS Simulator..."
xcodebuild -project MomentumFinance.xcodeproj \
    -scheme MomentumFinance \
    -configuration Debug \
    -destination 'platform=iOS Simulator,name=iPhone 15,OS=latest' \
    -derivedDataPath build \
    ONLY_ACTIVE_ARCH=YES \
    build

if [ $? -eq 0 ]; then
    echo "✅ Build succeeded!"
    
    # 5. Open simulator
    echo "5. Opening simulator..."
    open -a Simulator
    sleep 3
    
    # 6. Install app
    echo "6. Installing app..."
    APP_PATH=$(find build -name "MomentumFinance.app" -path "*/Debug-iphonesimulator/*" | head -1)
    
    if [ -n "$APP_PATH" ]; then
        echo "Found app at: $APP_PATH"
        
        # Boot simulator if needed
        xcrun simctl boot "iPhone 15" 2>/dev/null || true
        sleep 2
        
        # Install app
        xcrun simctl install "iPhone 15" "$APP_PATH"
        
        if [ $? -eq 0 ]; then
            echo "✅ App installed successfully!"
            
            # Launch app
            echo "7. Launching app..."
            xcrun simctl launch "iPhone 15" "com.momentumfinance.MomentumFinance"
        else
            echo "❌ Failed to install app"
            echo "Check if simulator is running and try again"
        fi
    else
        echo "❌ Could not find built app"
    fi
else
    echo "❌ Build failed!"
    echo "Check the error messages above"
fi