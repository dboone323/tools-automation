#!/bin/bash

# Multi-platform launcher for MomentumFinance
# Supports iOS Simulator and macOS
# Momentum Finance - Personal Finance App
# Copyright © 2025 Momentum Finance. All rights reserved.

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${BLUE}🚀 MomentumFinance Multi-Platform Launcher${NC}"
echo "=========================================="

# Set working directory
cd "$(dirname "$0")"

# Function to show usage
show_usage() {
    echo "Usage: $0 [ios|macos|both]"
    echo ""
    echo "Options:"
    echo "  ios   - Launch on iPhone 16 iOS 18.1 simulator"
    echo "  macos - Launch on macOS 15 (native)"
    echo "  both  - Launch on both platforms (default)"
    echo ""
    exit 1
}

# Function to build for iOS simulator
build_ios() {
    echo -e "${YELLOW}📱 Building for iOS Simulator...${NC}"
    
    # iPhone 16 iOS 18.1 simulator details
    local DEVICE_ID="891E4B4F-9FEA-494A-8DD0-DA1C058B5253"
    local DEVICE_NAME="iPhone 16"
    local IOS_VERSION="18.1"
    
    echo "Target: $DEVICE_NAME (iOS $IOS_VERSION)"
    
    # Boot the simulator if not already running
    echo "⚡ Booting simulator..."
    xcrun simctl boot "$DEVICE_ID" 2>/dev/null || echo "Simulator already booted"
    
    # Open the simulator app
    echo "📲 Opening simulator..."
    open -a Simulator
    
    # Wait for simulator to start
    sleep 3
    
    # Build using Swift Package Manager for iOS
    echo "🔨 Building iOS app with Swift PM..."
    swift build -c release --triple arm64-apple-ios18.1-simulator
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ iOS build successful!${NC}"
        
        # Since we can't directly install SPM executables on iOS simulator,
        # we'll use xcodebuild as fallback for iOS
        echo "📦 Building with Xcode for iOS deployment..."
        xcodebuild -project MomentumFinance.xcodeproj \
                   -scheme MomentumFinance \
                   -destination "platform=iOS Simulator,name=$DEVICE_NAME,OS=$IOS_VERSION" \
                   -derivedDataPath ./DerivedData \
                   build
        
        if [ $? -eq 0 ]; then
            # Install and launch the app
            local APP_BUNDLE_ID="com.momentumfinance.MomentumFinance"
            
            echo "📦 Installing app on simulator..."
            xcrun simctl install "$DEVICE_ID" "./DerivedData/Build/Products/Debug-iphonesimulator/MomentumFinance.app"
            
            echo "🚀 Launching iOS app..."
            xcrun simctl launch "$DEVICE_ID" "$APP_BUNDLE_ID"
            
            echo -e "${GREEN}✨ MomentumFinance launched successfully on iPhone 16!${NC}"
        else
            echo -e "${RED}❌ iOS Xcode build failed${NC}"
            return 1
        fi
    else
        echo -e "${RED}❌ iOS Swift PM build failed${NC}"
        return 1
    fi
}

# Function to build and run for macOS
build_macos() {
    echo -e "${YELLOW}🖥️  Building for macOS...${NC}"
    
    # Build using Swift Package Manager for macOS
    echo "🔨 Building macOS app with Swift PM..."
    swift build -c release --triple arm64-apple-macos15.0
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ macOS build successful!${NC}"
        
        # Run the executable directly
        echo "🚀 Launching macOS app..."
        echo -e "${BLUE}Note: The app will run in the terminal. Press Ctrl+C to stop.${NC}"
        
        # Launch in background and get PID
        ./.build/release/MomentumFinance &
        MACOS_PID=$!
        
        echo -e "${GREEN}✨ MomentumFinance launched successfully on macOS!${NC}"
        echo "Process ID: $MACOS_PID"
        
        # Optional: Open the SwiftUI preview or use native macOS app if available
        if [ -f "./DerivedData/Build/Products/Release/MomentumFinance.app" ]; then
            echo "🖥️  Opening native macOS app..."
            open "./DerivedData/Build/Products/Release/MomentumFinance.app"
        fi
        
        return 0
    else
        echo -e "${RED}❌ macOS build failed${NC}"
        return 1
    fi
}

# Function to check prerequisites
check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    # Check if Xcode is installed
    if ! command -v xcodebuild &> /dev/null; then
        echo -e "${RED}❌ Xcode is not installed or not in PATH${NC}"
        exit 1
    fi
    
    # Check if Swift is available
    if ! command -v swift &> /dev/null; then
        echo -e "${RED}❌ Swift is not installed or not in PATH${NC}"
        exit 1
    fi
    
    # Check if we have the required simulators
    echo "📱 Checking for iPhone 16 simulator..."
    if ! xcrun simctl list devices | grep -q "iPhone 16.*18\.1"; then
        echo -e "${YELLOW}⚠️  iPhone 16 iOS 18.1 simulator not found. Please install it via Xcode.${NC}"
    fi
    
    echo -e "${GREEN}✅ Prerequisites check complete${NC}"
}

# Main execution
main() {
    local platform="${1:-both}"
    
    case "$platform" in
        "ios")
            check_prerequisites
            build_ios
            ;;
        "macos")
            check_prerequisites
            build_macos
            ;;
        "both")
            check_prerequisites
            echo -e "${BLUE}🎯 Launching on both platforms...${NC}"
            
            # Build for macOS first (faster)
            build_macos
            MACOS_SUCCESS=$?
            
            echo ""
            echo "=================================="
            echo ""
            
            # Build for iOS
            build_ios
            IOS_SUCCESS=$?
            
            # Summary
            echo ""
            echo -e "${BLUE}📊 Launch Summary:${NC}"
            echo "=================="
            
            if [ $MACOS_SUCCESS -eq 0 ]; then
                echo -e "${GREEN}✅ macOS: Successfully launched${NC}"
            else
                echo -e "${RED}❌ macOS: Launch failed${NC}"
            fi
            
            if [ $IOS_SUCCESS -eq 0 ]; then
                echo -e "${GREEN}✅ iOS: Successfully launched on iPhone 16${NC}"
            else
                echo -e "${RED}❌ iOS: Launch failed${NC}"
            fi
            
            echo ""
            echo -e "${BLUE}🎉 Multi-platform launch complete!${NC}"
            ;;
        *)
            echo -e "${RED}❌ Invalid platform: $platform${NC}"
            show_usage
            ;;
    esac
}

# Handle command line arguments
if [ "$1" == "--help" ] || [ "$1" == "-h" ]; then
    show_usage
fi

# Run main function
main "$@"
