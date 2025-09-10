#!/bin/bash
# Smart Multi-Platform Builder for Xcode Projects
# Automatically detects platform support and builds accordingly

set -e

# Color codes for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Detect project platform support
detect_platform() {
    local project_name=$(basename "$(pwd)")
    echo "🔍 Detecting platform support for: $project_name"
    
    # Hard-coded platform detection based on known project requirements
    case "$project_name" in
        "CodingReviewer")
            echo "💻 CodingReviewer: macOS-only project"
            PLATFORM="macos"
            ;;
        "MomentumFinance")
            echo "📱💻 MomentumFinance: Multi-platform project (iOS + macOS)"
            PLATFORM="multi"
            ;;
        "HabitQuest")
            echo "📱 HabitQuest: iOS-only project"
            PLATFORM="ios"
            ;;
        *)
            # Fallback to file-based detection
            if grep -q "IPHONEOS_DEPLOYMENT_TARGET\|iOS" *.xcodeproj/project.pbxproj 2>/dev/null; then
                if grep -q "MACOSX_DEPLOYMENT_TARGET\|macOS" *.xcodeproj/project.pbxproj 2>/dev/null; then
                    echo "📱💻 Multi-platform project (iOS + macOS)"
                    PLATFORM="multi"
                else
                    echo "📱 iOS-only project"
                    PLATFORM="ios"
                fi
            elif grep -q "MACOSX_DEPLOYMENT_TARGET\|macOS" *.xcodeproj/project.pbxproj 2>/dev/null; then
                echo "💻 macOS-only project"
                PLATFORM="macos"
            else
                echo "❓ Platform unclear, defaulting to iOS"
                PLATFORM="ios"
            fi
            ;;
    esac
}

# Get available schemes
get_schemes() {
    echo "📋 Available schemes:"
    if ls *.xcodeproj 1> /dev/null 2>&1; then
        xcodebuild -list 2>/dev/null | grep -A 10 "Schemes:" | grep -v "Schemes:" | sed 's/^[[:space:]]*//' | grep -v '^$' || echo "No schemes found"
    else
        echo "No Xcode project found"
    fi
}

# Build for macOS
build_macos() {
    local scheme="$1"
    echo -e "${BLUE}💻 Building for macOS...${NC}"
    
    # Try different macOS build strategies
    local strategies=(
        "platform=macOS"
        "platform=macOS,arch=x86_64"
        "platform=macOS,arch=arm64"
        "generic/platform=macOS"
    )
    
    for strategy in "${strategies[@]}"; do
        echo "🔨 Attempting macOS build with destination: $strategy"
        # Try with project file first, then without
        if ls *.xcodeproj 1> /dev/null 2>&1; then
            if xcodebuild -scheme "$scheme" -destination "$strategy" build 2>/dev/null || \
               xcodebuild -project *.xcodeproj -scheme "$scheme" -destination "$strategy" build; then
                echo -e "${GREEN}✅ macOS build successful with strategy: $strategy${NC}"
                return 0
            fi
        else
            echo "⚠️  No Xcode project file found, skipping strategy: $strategy"
        fi
        echo -e "${YELLOW}⚠️ macOS build failed with strategy: $strategy${NC}"
    done
    
    echo -e "${RED}❌ All macOS build strategies failed${NC}"
    return 1
}

# Build for iOS
build_ios() {
    local scheme="$1"
    echo -e "${BLUE}📱 Building for iOS...${NC}"
    
    # Try different iOS build strategies
    local strategies=(
        "platform=iOS Simulator,name=iPhone 15"
        "generic/platform=iOS Simulator"
        "platform=iOS Simulator,name=iPhone 14"
    )
    
    for strategy in "${strategies[@]}"; do
        echo "🔨 Attempting iOS build with destination: $strategy"
        # Try with project file first, then without
        if ls *.xcodeproj 1> /dev/null 2>&1; then
            if xcodebuild -scheme "$scheme" -destination "$strategy" build 2>/dev/null || \
               xcodebuild -project *.xcodeproj -scheme "$scheme" -destination "$strategy" build; then
                echo -e "${GREEN}✅ iOS build successful with strategy: $strategy${NC}"
                return 0
            fi
        else
            echo "⚠️  No Xcode project file found, skipping strategy: $strategy"
        fi
        echo -e "${YELLOW}⚠️ iOS build failed with strategy: $strategy${NC}"
    done
    
    echo -e "${RED}❌ All iOS build strategies failed${NC}"
    return 1
}

# Test for macOS
test_macos() {
    local scheme="$1"
    echo -e "${BLUE}🧪 Testing on macOS...${NC}"
    
    if xcodebuild test -scheme "$scheme" -destination "platform=macOS"; then
        echo -e "${GREEN}✅ macOS tests passed${NC}"
        return 0
    else
        echo -e "${RED}❌ macOS tests failed${NC}"
        return 1
    fi
}

# Test for iOS
test_ios() {
    local scheme="$1"
    echo -e "${BLUE}🧪 Testing on iOS Simulator...${NC}"
    
    if xcodebuild test -scheme "$scheme" -destination "platform=iOS Simulator,name=iPhone 15"; then
        echo -e "${GREEN}✅ iOS tests passed${NC}"
        return 0
    else
        echo -e "${RED}❌ iOS tests failed${NC}"
        return 1
    fi
}

# Main build function
main() {
    echo "🚀 Smart Multi-Platform Builder Starting..."
    
    # Check for Xcode project
    if ! ls *.xcodeproj 1> /dev/null 2>&1; then
        echo -e "${RED}❌ No Xcode project found in current directory${NC}"
        exit 1
    fi
    
    # Detect platform
    detect_platform
    get_schemes
    
    # Get the scheme name (assume first scheme if multiple)
    if ls *.xcodeproj 1> /dev/null 2>&1; then
        SCHEME=$(xcodebuild -list 2>/dev/null | grep -A 10 "Schemes:" | grep -v "Schemes:" | sed 's/^[[:space:]]*//' | grep -v '^$' | head -n 1)
    else
        # Fallback: try to derive scheme name from project directory
        SCHEME=$(basename "$(pwd)")
    fi
    
    if [ -z "$SCHEME" ]; then
        echo -e "${RED}❌ No build scheme found${NC}"
        exit 1
    fi
    
    echo "🎯 Using scheme: $SCHEME"
    echo "🏗️ Platform configuration: $PLATFORM"
    
    # Build based on platform
    BUILD_SUCCESS=false
    
        case "$PLATFORM" in
        "macos")
            if build_macos "$SCHEME"; then
                BUILD_SUCCESS=true
                [ -n "$GITHUB_ENV" ] && echo "BUILD_SUCCESS=true" >> $GITHUB_ENV || true
            fi
            ;;
        "ios")
            if build_ios "$SCHEME"; then
                BUILD_SUCCESS=true
                [ -n "$GITHUB_ENV" ] && echo "BUILD_SUCCESS=true" >> $GITHUB_ENV || true
            fi
            ;;
        "multi")
            # Try macOS first, then iOS
            if build_macos "$SCHEME"; then
                BUILD_SUCCESS=true
                [ -n "$GITHUB_ENV" ] && echo "BUILD_SUCCESS=true" >> $GITHUB_ENV || true
            elif build_ios "$SCHEME"; then
                BUILD_SUCCESS=true
                [ -n "$GITHUB_ENV" ] && echo "BUILD_SUCCESS=true" >> $GITHUB_ENV || true
            fi
            ;;
    esac    if [ "$BUILD_SUCCESS" = false ]; then
        echo -e "${RED}❌ All build attempts failed${NC}"
        exit 1
    fi
    
    # Run tests if build succeeded and testing is requested
    if [ "$1" = "test" ] && [ "$BUILD_SUCCESS" = true ]; then
        echo "🧪 Running tests..."
        case "$PLATFORM" in
            "macos")
                test_macos "$SCHEME"
                ;;
            "ios")
                test_ios "$SCHEME"
                ;;
            "multi")
                # Test on the platform that built successfully
                if build_macos "$SCHEME" >/dev/null 2>&1; then
                    test_macos "$SCHEME"
                else
                    test_ios "$SCHEME"
                fi
                ;;
        esac
    fi
    
    echo -e "${GREEN}🎉 Smart builder completed successfully!${NC}"
}

# Run main function with all arguments
main "$@"
