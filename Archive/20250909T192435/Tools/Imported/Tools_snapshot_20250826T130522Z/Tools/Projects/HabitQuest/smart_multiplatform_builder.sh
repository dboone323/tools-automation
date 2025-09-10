#!/bin/bash
# Smart Multi-Platform CI Builder
# Detects project capabilities and builds for appropriate platforms

set -e

PROJECT_FILE="project.pbxproj"
if [ -f "*.xcodeproj/project.pbxproj" ]; then
    PROJECT_FILE="$(ls *.xcodeproj/project.pbxproj | head -1)"
fi

echo "🔍 Analyzing project capabilities..."

# Check if project supports macOS
SUPPORTS_MACOS=false
if grep -q "MACOSX_DEPLOYMENT_TARGET\|macosx\|macOS" "$PROJECT_FILE" 2>/dev/null; then
    SUPPORTS_MACOS=true
    echo "✅ Project supports macOS"
else
    echo "📱 Project is iOS-only"
fi

# Check if project supports iOS
SUPPORTS_IOS=false
if grep -q "IPHONEOS_DEPLOYMENT_TARGET\|iphoneos\|iOS" "$PROJECT_FILE" 2>/dev/null; then
    SUPPORTS_IOS=true
    echo "✅ Project supports iOS"
fi

echo "🏗️ Starting multi-platform build..."

BUILD_SUCCESS=false

# Strategy 1: iOS Simulator (most compatible)
if [ "$SUPPORTS_IOS" = true ]; then
    echo "📱 Attempting iOS Simulator build..."
    set +e
    # Prefer iPhone 16 on CI and locally where available
    if [ -n "$CI" ] || [ -n "$GITHUB_ACTIONS" ]; then
        xcodebuild -scheme "$1" -destination "platform=iOS Simulator,name=iPhone 16" CODE_SIGNING_ALLOWED=${CODE_SIGNING_ALLOWED:-NO} CODE_SIGNING_REQUIRED=${CODE_SIGNING_REQUIRED:-NO} build
    else
        xcodebuild -scheme "$1" -destination "platform=iOS Simulator,name=iPhone 16" build
    fi
    if [ $? -eq 0 ]; then
        echo "✅ iOS Simulator build successful!"
        BUILD_SUCCESS=true
        exit 0
    else
        echo "⚠️ iOS Simulator build failed, trying next strategy..."
    fi
    set -e
fi

# Strategy 2: macOS (if supported)
if [ "$SUPPORTS_MACOS" = true ]; then
    echo "🖥️ Attempting macOS build..."
    set +e
    xcodebuild -scheme "$1" -destination "platform=macOS" build
    if [ $? -eq 0 ]; then
        echo "✅ macOS build successful!"
        BUILD_SUCCESS=true
        exit 0
    else
        echo "⚠️ macOS build failed, trying next strategy..."
    fi
    set -e
fi

# Strategy 3: Generic iOS Simulator 
if [ "$SUPPORTS_IOS" = true ]; then
    echo "📱 Attempting generic iOS Simulator build..."
    set +e
    xcodebuild -scheme "$1" -destination "generic/platform=iOS Simulator" build
    if [ $? -eq 0 ]; then
        echo "✅ Generic iOS Simulator build successful!"
        BUILD_SUCCESS=true
        exit 0
    else
        echo "⚠️ Generic iOS Simulator build failed"
    fi
    set -e
fi

if [ "$BUILD_SUCCESS" = false ]; then
    echo "❌ All build strategies failed"
    exit 1
fi
