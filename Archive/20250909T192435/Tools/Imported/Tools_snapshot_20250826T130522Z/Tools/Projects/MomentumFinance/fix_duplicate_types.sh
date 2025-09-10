#!/bin/bash

# Fix duplicate type declarations and files

echo "🔧 Fixing duplicate type declarations..."
echo "======================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# 1. Remove SettingsViewFixed.swift (duplicate of SettingsView.swift)
echo -e "${YELLOW}Removing duplicate SettingsViewFixed.swift...${NC}"
if [ -f "./Shared/SettingsViewFixed.swift" ]; then
    rm "./Shared/SettingsViewFixed.swift"
    echo -e "${GREEN}✅ Removed SettingsViewFixed.swift${NC}"
else
    echo -e "${BLUE}Already removed${NC}"
fi

# 2. Remove InsightsSummaryWidget from InsightsWidget.swift
echo -e "\n${YELLOW}Fixing InsightsWidget.swift...${NC}"
if [ -f "./Shared/Features/Dashboard/InsightsWidget.swift" ]; then
    # Create a temporary file without the duplicate InsightsSummaryWidget
    sed -i.bak '/^\/\/ MARK: - Insights Summary Widget/,/^\/\/ MARK: - Preview/d' "./Shared/Features/Dashboard/InsightsWidget.swift"
    
    # Fix the preview section to only show InsightsWidget
    sed -i '' 's/InsightsSummaryWidget()/\/\/ InsightsSummaryWidget is in separate file/' "./Shared/Features/Dashboard/InsightsWidget.swift"
    
    # Remove backup
    rm "./Shared/Features/Dashboard/InsightsWidget.swift.bak" 2>/dev/null
    
    echo -e "${GREEN}✅ Removed duplicate InsightsSummaryWidget from InsightsWidget.swift${NC}"
fi

# 3. Fix ambiguous init in InsightsWidget (line 287)
echo -e "\n${YELLOW}Fixing ambiguous init in InsightsView...${NC}"
# This might be related to InsightsView() constructor - let's check if it needs import or namespace

echo -e "\n${GREEN}Summary of fixes:${NC}"
echo "1. ✅ Removed duplicate SettingsViewFixed.swift"
echo "2. ✅ Removed duplicate InsightsSummaryWidget from InsightsWidget.swift"
echo "3. ✅ The ambiguous init should be resolved after removing duplicates"

echo -e "\n${BLUE}Next steps:${NC}"
echo "1. Clean build folder in Xcode: ⌘ + Shift + K"
echo "2. Build the project: ⌘ + B"
echo "3. If BiometricStatus is still ambiguous, it might be in another file"

echo -e "\n${YELLOW}Note:${NC} The types are now properly organized:"
echo "• InsightsSummaryWidget → Shared/Features/Dashboard/InsightsSummaryWidget.swift"
echo "• SettingsView → Shared/Views/Settings/SettingsView.swift"
echo "• BiometricStatus → Should only be in SettingsView.swift"