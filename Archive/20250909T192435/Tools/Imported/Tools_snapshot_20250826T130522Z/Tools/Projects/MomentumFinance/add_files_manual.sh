#!/bin/bash

PROJECT_FILE="/Users/danielstevens/Desktop/MomentumFinaceApp/MomentumFinance.xcodeproj/project.pbxproj"

# Create backup
cp "$PROJECT_FILE" "$PROJECT_FILE.backup_manual"

# Essential files to add
FILES=(
    "Budget.swift"
    "Category.swift"
    "ExpenseCategory.swift"
    "FinancialAccount.swift"
    "FinancialTransaction.swift"
    "SavingsGoal.swift"
    "Subscription.swift"
    "NavigationCoordinator.swift"
    "NotificationManager.swift"
)

echo "Adding files to Xcode project manually..."

# Start from a simple ID sequence
BASE_ID=50
for file in "${FILES[@]}"; do
    FILE_ID=$(printf "6B1A2B%02X2C0D1E8F00123456" $BASE_ID)
    BUILD_ID=$(printf "6B1A2B%02X2C0D1E8F00123456" $((BASE_ID + 1)))
    
    # Add file reference
    if ! grep -q "$file" "$PROJECT_FILE"; then
        # Add to file references section (after ContentView.swift)
        sed -i '' "/6B1A2B2E2C0D1E8F00123456.*ContentView.swift.*sourceTree/a\\
		$FILE_ID /* $file */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = $file; sourceTree = \"<group>\"; };
" "$PROJECT_FILE"
        
        # Add build file entry (after ContentView.swift in Sources)
        sed -i '' "/6B1A2B2E2C0D1E8F00123456.*ContentView.swift in Sources/a\\
		$BUILD_ID /* $file in Sources */ = {isa = PBXBuildFile; fileRef = $FILE_ID /* $file */; };
" "$PROJECT_FILE"
        
        # Add to sources build phase (after ContentView.swift in Sources)
        sed -i '' "/6B1A2B2E2C0D1E8F00123456.*ContentView.swift in Sources.*,/a\\
				$BUILD_ID /* $file in Sources */,
" "$PROJECT_FILE"
        
        # Add to MomentumFinance group (after ContentView.swift)
        sed -i '' "/6B1A2B2E2C0D1E8F00123456.*ContentView.swift.*,/a\\
				$FILE_ID /* $file */,
" "$PROJECT_FILE"
        
        echo "Added $file to project"
    fi
    
    BASE_ID=$((BASE_ID + 2))
done

echo "All files added to Xcode project successfully!"
