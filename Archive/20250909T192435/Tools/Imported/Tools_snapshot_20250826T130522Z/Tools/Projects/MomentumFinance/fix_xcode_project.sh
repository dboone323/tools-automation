#!/bin/bash

# Script to properly add all Shared files to Xcode project build target

PROJECT_FILE="/Users/danielstevens/Desktop/MomentumFinaceApp/MomentumFinance.xcodeproj/project.pbxproj"
SHARED_DIR="/Users/danielstevens/Desktop/MomentumFinaceApp/Shared"

# Create backup
cp "$PROJECT_FILE" "$PROJECT_FILE.backup_$(date +%s)"

echo "Adding all Shared Swift files to Xcode project..."

# Core model files that are essential
CORE_FILES=(
    "Shared/Models/FinancialAccount.swift"
    "Shared/Models/FinancialTransaction.swift"
    "Shared/Models/Budget.swift"
    "Shared/Models/Subscription.swift"
    "Shared/Models/ExpenseCategory.swift"
    "Shared/Models/SavingsGoal.swift"
    "Shared/Models/Category.swift"
    "Shared/Navigation/NavigationCoordinator.swift"
    "Shared/Utilities/NotificationManager.swift"
    "Shared/Utilities/ErrorHandler.swift"
    "Shared/Utilities/Logger.swift"
)

# Find current highest ID in project
LAST_ID=$(grep -o '6B1A2B[0-9A-F][0-9A-F]2C0D1E91[0-9][0-9]123456' "$PROJECT_FILE" | sort | tail -1)
if [ -z "$LAST_ID" ]; then
    LAST_ID="6B1A2B2C2C0D1E8F00123456"
fi

# Extract the incremental part and convert to decimal
INCREMENT_PART=$(echo "$LAST_ID" | sed 's/6B1A2B\([0-9A-F][0-9A-F]\)2C0D1E91[0-9][0-9]123456/\1/')
INCREMENT_DECIMAL=$(printf "%d" 0x$INCREMENT_PART)

# Function to generate next ID
generate_next_id() {
    INCREMENT_DECIMAL=$((INCREMENT_DECIMAL + 2))
    printf "6B1A2B%02X2C0D1E9100123456" $INCREMENT_DECIMAL
}

# Function to generate build file ID
generate_build_id() {
    local file_id=$1
    echo $file_id | sed 's/\(..\)\(..\)\(.*\)/\1\2\3/' | sed 's/6B1A2B\(..\)/6B1A2B\1/'
}

echo "Adding file references..."

# Add PBXFileReference entries
for file in "${CORE_FILES[@]}"; do
    filename=$(basename "$file")
    if ! grep -q "$filename" "$PROJECT_FILE"; then
        file_id=$(generate_next_id)
        # Add to file references section
        sed -i '' "/6B1A2B2E2C0D1E8F00123456.*ContentView.swift.*sourceTree/a\\
		$file_id /* $filename */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = \"$filename\"; sourceTree = \"<group>\"; };
" "$PROJECT_FILE"
        echo "Added file reference for $filename with ID $file_id"
    fi
done

echo "Adding build file entries..."

# Add PBXBuildFile entries
for file in "${CORE_FILES[@]}"; do
    filename=$(basename "$file")
    if ! grep -q "$filename.*in Sources" "$PROJECT_FILE"; then
        file_id=$(grep "$filename.*sourceTree" "$PROJECT_FILE" | grep -o '6B1A2B[0-9A-F][0-9A-F]2C0D1E91[0-9][0-9]123456' | head -1)
        if [ ! -z "$file_id" ]; then
            build_id=$(generate_next_id)
            # Add to build files section
            sed -i '' "/6B1A2B2E2C0D1E8F00123456.*ContentView.swift in Sources/a\\
		$build_id /* $filename in Sources */ = {isa = PBXBuildFile; fileRef = $file_id /* $filename */; };
" "$PROJECT_FILE"
            echo "Added build file for $filename with build ID $build_id"
        fi
    fi
done

echo "Adding files to Sources build phase..."

# Add files to the Sources build phase
for file in "${CORE_FILES[@]}"; do
    filename=$(basename "$file")
    build_id=$(grep "$filename in Sources" "$PROJECT_FILE" | grep -o '6B1A2B[0-9A-F][0-9A-F]2C0D1E91[0-9][0-9]123456' | head -1)
    if [ ! -z "$build_id" ] && ! grep -A 10 "isa = PBXSourcesBuildPhase" "$PROJECT_FILE" | grep -q "$build_id"; then
        # Add to sources build phase
        sed -i '' "/6B1A2B2E2C0D1E8F00123456.*ContentView.swift in Sources/a\\
				$build_id /* $filename in Sources */,
" "$PROJECT_FILE"
        echo "Added $filename to Sources build phase"
    fi
done

echo "Xcode project updated successfully!"
echo "Files added to build target. You can now build the project."
