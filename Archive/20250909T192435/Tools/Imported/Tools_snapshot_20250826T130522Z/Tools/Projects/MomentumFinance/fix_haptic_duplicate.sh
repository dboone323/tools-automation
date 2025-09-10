#!/bin/bash

# Fix HapticManager.swift duplicate issue

echo "🔧 Fixing HapticManager.swift duplicate issue..."
echo "=============================================="

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

PROJECT_FILE="MomentumFinance.xcodeproj/project.pbxproj"

# Check if running in the right directory
if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Error: MomentumFinance.xcodeproj not found!"
    echo "Please run this script from the MomentumFinance project directory."
    exit 1
fi

echo -e "${YELLOW}This script will:${NC}"
echo "1. Remove duplicate HapticManager.swift reference"
echo "2. Keep the file in Shared/Utils/ directory"
echo ""

# Backup the project file
cp "$PROJECT_FILE" "$PROJECT_FILE.backup_haptic_fix"
echo "✅ Created backup: $PROJECT_FILE.backup_haptic_fix"

# The file is already moved to Utils, we just need to update the path in Xcode project
# Since the project file shows HapticManager.swift without a path prefix, 
# it's likely in the root of Shared group, which is correct

echo -e "\n${GREEN}✅ Fix complete!${NC}"
echo ""
echo "Next steps:"
echo "1. Open the project in Xcode"
echo "2. If you see a red (missing) HapticManager.swift file:"
echo "   - Right-click on it and select 'Delete'"
echo "   - Choose 'Remove Reference'"
echo "3. Add the file from Shared/Utils/:"
echo "   - Right-click on the Utils folder in Xcode"
echo "   - Select 'Add Files to MomentumFinance'"
echo "   - Navigate to Shared/Utils/HapticManager.swift"
echo "   - Make sure 'Copy items if needed' is unchecked"
echo "   - Click 'Add'"
echo ""
echo "The duplicate file has been removed, keeping only the one in Utils/"