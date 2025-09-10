#!/bin/bash

# MacOS UI Enhancement Integration Script
# This script integrates all macOS UI enhancements into the Momentum Finance app

# Color definitions
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

echo -e "${BLUE}=== Momentum Finance - macOS UI Enhancement Integration ===${NC}"
echo ""
echo -e "${YELLOW}This script will integrate the enhanced macOS UI components into your app.${NC}"
echo -e "${YELLOW}Make sure to close Xcode before running this script.${NC}"
echo ""

# Check if Xcode is running
if pgrep -x "Xcode" > /dev/null
then
    echo -e "${RED}Xcode appears to be running. Please close Xcode and try again.${NC}"
    exit 1
fi

# Ask for confirmation
read -p "Do you want to continue with the integration? (y/n) " -n 1 -r
echo ""
if [[ ! $REPLY =~ ^[Yy]$ ]]
then
    echo -e "${YELLOW}Integration cancelled.${NC}"
    exit 0
fi

# Make a backup of critical files
echo -e "${BLUE}Creating backups...${NC}"
BACKUP_DIR="MacOS_UI_Backup_$(date +%Y%m%d_%H%M%S)"
mkdir -p "$BACKUP_DIR"
cp MomentumFinance/MomentumFinanceApp.swift "$BACKUP_DIR/"
cp Shared/ContentView.swift "$BACKUP_DIR/"
echo -e "${GREEN}Backups created in $BACKUP_DIR${NC}"

# Update app entry point
echo -e "${BLUE}Updating app entry point...${NC}"
cp macOS/UpdatedMomentumFinanceApp.swift MomentumFinance/MomentumFinanceApp.swift
echo -e "${GREEN}App entry point updated${NC}"

# Add the macOS UI files to the Xcode project
echo -e "${BLUE}Adding macOS UI files to Xcode project...${NC}"

# Function to check if a file is already in the project
is_file_in_project() {
    grep -q "path = \"$1\"" MomentumFinance.xcodeproj/project.pbxproj
    return $?
}

# Add files to the project
add_file_to_project() {
    local file_path=$1
    local file_name=$(basename "$file_path")
    
    if is_file_in_project "$file_path"; then
        echo -e "${YELLOW}File $file_name is already in project${NC}"
        return 0
    fi
    
    # Get the macOS group UUID from the project file
    MAC_OS_GROUP_UUID=$(grep -A 3 "path = macOS;" MomentumFinance.xcodeproj/project.pbxproj | grep "name = macOS;" | cut -d' ' -f1 | sed 's/;//g')
    
    if [ -z "$MAC_OS_GROUP_UUID" ]; then
        echo -e "${RED}Couldn't find macOS group in project. Manual addition required.${NC}"
        return 1
    fi
    
    # Generate a UUID for the file
    FILE_UUID=$(uuidgen)
    FILE_REF_UUID=$(uuidgen)
    
    # Add file reference
    sed -i '' "/* Begin PBXFileReference section */,/* End PBXFileReference section */" -e "s/\/\* End PBXFileReference section \*\//\t\t$FILE_UUID \/* $file_name \*\/ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"$file_path\"; sourceTree = \"<group>\"; };\n\t\t\/\* End PBXFileReference section \*\//" MomentumFinance.xcodeproj/project.pbxproj
    
    # Add file to macOS group
    sed -i '' "/$MAC_OS_GROUP_UUID \/* macOS \*\/ = {/,/};/s/\t\t\t\);\n/\t\t\t\t$FILE_UUID \/* $file_name \*\/,\n\t\t\t);\n/" MomentumFinance.xcodeproj/project.pbxproj
    
    # Add build file
    sed -i '' "/* Begin PBXBuildFile section */,/* End PBXBuildFile section */" -e "s/\/\* End PBXBuildFile section \*\//\t\t$FILE_REF_UUID \/* $file_name in Sources \*\/ = {isa = PBXBuildFile; fileRef = $FILE_UUID \/* $file_name \*\/; };\n\t\t\/\* End PBXBuildFile section \*\//" MomentumFinance.xcodeproj/project.pbxproj
    
    # Add file to build phase
    BUILD_PHASE_UUID=$(grep -A 3 "isa = PBXSourcesBuildPhase;" MomentumFinance.xcodeproj/project.pbxproj | grep -m 1 "files = (" | head -1 | awk '{print $1}')
    
    if [ -z "$BUILD_PHASE_UUID" ]; then
        echo -e "${RED}Couldn't find build phase in project. Manual addition required.${NC}"
        return 1
    fi
    
    # Add file to build phase files array
    sed -i '' "/$BUILD_PHASE_UUID \/* Sources \*\/ = {/,/files = (/s/files = (/files = (\n\t\t\t\t$FILE_REF_UUID \/* $file_name in Sources \*\/,/" MomentumFinance.xcodeproj/project.pbxproj
    
    echo -e "${GREEN}Added $file_name to project${NC}"
    return 0
}

# Add all macOS UI files to project
MACOS_UI_FILES=(
    "macOS/EnhancedContentView_macOS.swift"
    "macOS/KeyboardShortcutManager.swift"
    "macOS/DragAndDropSupport.swift"
    "macOS/EnhancedAccountDetailView.swift"
    "macOS/EnhancedBudgetDetailView.swift"
    "macOS/EnhancedDetailViews.swift"
    "macOS/EnhancedSubscriptionDetailView.swift"
    "macOS/MacOSUIIntegration.swift"
)

for file in "${MACOS_UI_FILES[@]}"; do
    add_file_to_project "$file"
done

# Update Development Tracker with progress
echo -e "${BLUE}Updating Development Tracker...${NC}"
DATE_TODAY=$(date +"%B %-d, %Y")

# Create a marker for where to insert the update
MARKER="### 🚀 PHASE 7: NEXT DEVELOPMENT ENHANCEMENTS"

# Create the update content
read -r -d '' UPDATE_CONTENT << EOM
### 📝 RECENT UPDATES ($DATE_TODAY)

#### **macOS UI Enhancement Complete**
- ✅ **Three-Column Navigation**: Implemented professional macOS UI with sidebar, list, and detail views
- ✅ **Enhanced Screen Utilization**: Detail views now take full advantage of desktop screen space
- ✅ **Sidebar Navigation**: Added collapsible sidebar with category sections and visual indicators
- ✅ **Rich Data Visualization**: Comprehensive charts and visual data presentation
- ✅ **Contextual Content Lists**: Middle column adapts based on selected sidebar item
- ✅ **Keyboard Shortcuts**: Professional-grade keyboard navigation for power users
- ✅ **Advanced Detail Views**: Enhanced visualizations for accounts, transactions, budgets, and subscriptions
- ✅ **Platform Coordination**: Updated NavigationCoordinator to support both iOS and macOS patterns

#### **Implementation Details**
- Platform-specific entry points in MomentumFinanceApp.swift for iOS and macOS
- Comprehensive keyboard shortcut system with menu integration
- Drag-and-drop support for intuitive data management
- Three-column NavigationSplitView layout for optimal screen utilization
- Enhanced detail views with tabbed organization of complex information
- Data analysis visualizations with interactive charts
- Account management with balance history and spending breakdown
- Budget tracking with daily allowance calculations and transaction integration
- Subscription management with cost analysis and cancellation assistance

EOM

# Update the development tracker file
if grep -q "$MARKER" DEVELOPMENT_TRACKER.md; then
    sed -i '' "/$MARKER/i\\
$UPDATE_CONTENT\\

" DEVELOPMENT_TRACKER.md
    echo -e "${GREEN}Development tracker updated${NC}"
else
    echo -e "${YELLOW}Couldn't find marker in DEVELOPMENT_TRACKER.md.${NC}"
    echo -e "${YELLOW}Please manually add the following update:${NC}"
    echo "$UPDATE_CONTENT"
fi

echo ""
echo -e "${GREEN}=== macOS UI Enhancement Integration Complete ===${NC}"
echo ""
echo -e "${BLUE}Next steps:${NC}"
echo -e "1. Open the Xcode project"
echo -e "2. Verify that all macOS UI files are included in the project"
echo -e "3. Build and run the app on macOS to see the enhanced UI"
echo -e "4. Test navigation, keyboard shortcuts, and detail views"
echo ""
echo -e "${YELLOW}Note: If there are any build errors, you may need to manually fix imports or references.${NC}"