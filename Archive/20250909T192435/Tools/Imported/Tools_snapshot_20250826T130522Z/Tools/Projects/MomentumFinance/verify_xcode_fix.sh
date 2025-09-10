#!/bin/bash

echo "Verifying Xcode project fix..."

# Count files in Shared
SHARED_COUNT=$(find Shared -name "*.swift" -type f | wc -l)

# Count references in project
if [ -f "MomentumFinance.xcodeproj/project.pbxproj" ]; then
    PROJECT_COUNT=$(grep -c "\.swift.*=.*PBXFileReference" "MomentumFinance.xcodeproj/project.pbxproj")
    echo "Swift files in Shared/: $SHARED_COUNT"
    echo "Swift files in project: $PROJECT_COUNT"
    
    if [ "$SHARED_COUNT" -eq "$PROJECT_COUNT" ]; then
        echo "✅ Project appears to be fixed!"
    else
        echo "⚠️  File count mismatch. Some files may still be missing."
    fi
else
    echo "❌ Project file not found"
fi
