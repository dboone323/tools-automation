#!/bin/bash

# Fix all duplicate Swift files in the project

echo "🔧 Fixing all duplicate Swift files..."
echo "===================================="

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Counter for removed files
removed_count=0

echo -e "${YELLOW}This script will remove duplicate files, keeping the organized versions in Shared/${NC}\n"

# Function to remove file and report
remove_duplicate() {
    local file=$1
    if [ -f "$file" ]; then
        echo -e "${RED}Removing:${NC} $file"
        rm "$file"
        ((removed_count++))
    else
        echo -e "${BLUE}Already removed:${NC} $file"
    fi
}

echo -e "${YELLOW}Step 1: Removing duplicates from MomentumFinance/ folder${NC}"
echo "These files belong in Shared/Models/, not in MomentumFinance/"
echo ""

# Remove model files from MomentumFinance folder
remove_duplicate "./MomentumFinance/Category.swift"
remove_duplicate "./MomentumFinance/ComplexDataGenerators.swift"
remove_duplicate "./MomentumFinance/FinancialAccount.swift"
remove_duplicate "./MomentumFinance/FinancialTransaction.swift"
remove_duplicate "./MomentumFinance/SampleData.swift"
remove_duplicate "./MomentumFinance/SampleDataGenerators.swift"
remove_duplicate "./MomentumFinance/SampleDataProviders.swift"
remove_duplicate "./MomentumFinance/SavingsGoal.swift"
remove_duplicate "./MomentumFinance/Subscription.swift"
remove_duplicate "./MomentumFinance/Transaction.swift"

# Remove other files from MomentumFinance folder
remove_duplicate "./MomentumFinance/ContentView.swift"
remove_duplicate "./MomentumFinance/MomentumFinanceApp.swift"
remove_duplicate "./MomentumFinance/NavigationCoordinator.swift"
remove_duplicate "./MomentumFinance/NotificationManager.swift"

echo -e "\n${YELLOW}Step 2: Removing duplicates from Shared/ root (keeping organized versions)${NC}"
echo ""

# Remove files from Shared root that have organized versions
remove_duplicate "./Shared/DataExportView.swift"  # Keep in Shared/Views/Settings/
remove_duplicate "./Shared/DataImportView.swift"  # Keep in Shared/Views/Settings/
remove_duplicate "./Shared/SettingsView.swift"    # Keep in Shared/Views/Settings/

echo -e "\n${GREEN}✅ Removed $removed_count duplicate files${NC}"

# Create symlinks to maintain compatibility (optional)
echo -e "\n${YELLOW}Step 3: Creating compatibility symlinks${NC}"
echo "This helps if there are any hardcoded paths in the project"

# Create symlinks in MomentumFinance folder pointing to Shared
cd MomentumFinance 2>/dev/null || { echo "MomentumFinance directory not found"; exit 1; }

# Only create symlinks for files that might be referenced
if [ ! -e "Budget.swift" ]; then
    ln -s ../Shared/Models/Budget.swift Budget.swift 2>/dev/null && echo "Created symlink: MomentumFinance/Budget.swift"
fi
if [ ! -e "ExpenseCategory.swift" ]; then
    ln -s ../Shared/Models/ExpenseCategory.swift ExpenseCategory.swift 2>/dev/null && echo "Created symlink: MomentumFinance/ExpenseCategory.swift"
fi

cd ..

echo -e "\n${BLUE}Step 4: Next steps in Xcode${NC}"
echo "1. Open your project in Xcode"
echo "2. You'll see red (missing) files - these are the removed duplicates"
echo "3. For each red file:"
echo "   - Right-click and select 'Delete'"
echo "   - Choose 'Remove Reference'"
echo "4. The project should already have references to the correct files in Shared/"
echo "5. If any files are still missing, add them from the Shared/ folder"
echo "6. Clean build: ⌘ + Shift + K"
echo "7. Build: ⌘ + B"

echo -e "\n${GREEN}File Organization Structure:${NC}"
echo "✅ Shared/Models/          - Data models"
echo "✅ Shared/Views/           - UI views"
echo "✅ Shared/Navigation/      - Navigation files"
echo "✅ Shared/Utilities/       - Utility classes"
echo "✅ Shared/Features/        - Feature modules"

# Backup info
echo -e "\n${YELLOW}Note:${NC} Original files are deleted. Make sure you have a backup or can recover from git if needed."
echo "To restore: git checkout -- <filename>"