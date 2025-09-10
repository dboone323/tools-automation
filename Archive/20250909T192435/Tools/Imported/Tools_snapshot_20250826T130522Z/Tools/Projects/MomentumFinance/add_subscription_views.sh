#!/bin/bash

PROJECT_FILE="/Users/danielstevens/Desktop/MomentumFinaceApp/MomentumFinance.xcodeproj/project.pbxproj"

echo "Adding subscription view files to Xcode project..."

# Create backup
cp "$PROJECT_FILE" "$PROJECT_FILE.backup_add_subscription_views"

# Files to add
FILES=(
    "SubscriptionManagementViews.swift"
    "SubscriptionSummaryViews.swift" 
    "SubscriptionRowViews.swift"
)

# Add file references and build entries
for file in "${FILES[@]}"; do
    # Generate unique UUIDs for this file
    BUILD_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-' | cut -c 1-24)
    FILE_UUID=$(uuidgen | tr '[:upper:]' '[:lower:]' | tr -d '-' | cut -c 1-24)
    
    echo "Adding $file with IDs: ${BUILD_UUID}, ${FILE_UUID}"
    
    # Add PBXBuildFile entry (after the last existing one)
    sed -i '' "/\/\* End PBXBuildFile section \*\//i\\
\\t\\t${BUILD_UUID} /* ${file} in Sources */ = {isa = PBXBuildFile; fileRef = ${FILE_UUID} /* ${file} */; };
" "$PROJECT_FILE"
    
    # Add PBXFileReference entry (after the last existing one)
    sed -i '' "/\/\* End PBXFileReference section \*\//i\\
\\t\\t${FILE_UUID} /* ${file} */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = ${file}; sourceTree = \"<group>\"; };
" "$PROJECT_FILE"
    
    # Add to Sources build phase (find the build phase and add before the closing parenthesis)
    sed -i '' "/files = (/,/);/ {
        /);/i\\
\\t\\t\\t\\t${BUILD_UUID} /* ${file} in Sources */,
    }" "$PROJECT_FILE"
done

echo "Added subscription view files to Xcode project"
