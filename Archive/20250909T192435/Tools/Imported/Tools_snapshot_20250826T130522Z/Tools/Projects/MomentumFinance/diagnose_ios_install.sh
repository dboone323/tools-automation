#!/bin/bash

echo "=== iOS App Installation Diagnostic ==="
echo

# Check if build directory exists
echo "1. Checking for build products..."
DERIVED_DATA_PATH=~/Library/Developer/Xcode/DerivedData
BUILD_PRODUCT=$(find $DERIVED_DATA_PATH -name "MomentumFinance.app" -path "*/Debug-iphonesimulator/*" 2>/dev/null | head -1)

if [ -z "$BUILD_PRODUCT" ]; then
    echo "❌ No build product found in DerivedData"
    echo "   Make sure the build succeeded for iOS Simulator"
    exit 1
else
    echo "✅ Found build product: $BUILD_PRODUCT"
fi

# Check app bundle
echo
echo "2. Checking app bundle..."
if [ -d "$BUILD_PRODUCT" ]; then
    echo "✅ App bundle exists"
    
    # Check Info.plist
    PLIST_PATH="$BUILD_PRODUCT/Info.plist"
    if [ -f "$PLIST_PATH" ]; then
        echo "✅ Info.plist exists"
        
        # Check bundle identifier
        BUNDLE_ID=$(/usr/libexec/PlistBuddy -c "Print :CFBundleIdentifier" "$PLIST_PATH" 2>/dev/null)
        if [ -z "$BUNDLE_ID" ]; then
            echo "❌ Bundle identifier is missing!"
        else
            echo "✅ Bundle identifier: $BUNDLE_ID"
        fi
        
        # Check executable
        EXEC_NAME=$(/usr/libexec/PlistBuddy -c "Print :CFBundleExecutable" "$PLIST_PATH" 2>/dev/null)
        if [ -z "$EXEC_NAME" ]; then
            echo "❌ Executable name is missing!"
        else
            echo "✅ Executable name: $EXEC_NAME"
            
            # Check if executable exists
            if [ -f "$BUILD_PRODUCT/$EXEC_NAME" ]; then
                echo "✅ Executable exists"
                
                # Check executable architecture
                echo "   Architecture: $(lipo -info "$BUILD_PRODUCT/$EXEC_NAME" 2>&1)"
            else
                echo "❌ Executable not found at $BUILD_PRODUCT/$EXEC_NAME"
            fi
        fi
        
    else
        echo "❌ Info.plist not found!"
    fi
else
    echo "❌ App bundle is not a directory"
fi

# Check simulator state
echo
echo "3. Checking simulator state..."
if command -v xcrun &> /dev/null; then
    echo "Available simulators:"
    xcrun simctl list devices | grep -E "(iPhone|iPad)" | grep -v "unavailable" | head -10
else
    echo "⚠️  xcrun not available - are Xcode command line tools installed?"
fi

echo
echo "=== Diagnostic Summary ==="
echo "If all checks pass but app still won't install:"
echo "1. Try resetting the simulator: Device > Erase All Content and Settings"
echo "2. Clean build folder in Xcode: Product > Clean Build Folder"
echo "3. Delete DerivedData: rm -rf ~/Library/Developer/Xcode/DerivedData/MomentumFinance-*"
echo "4. Restart Xcode and simulator"