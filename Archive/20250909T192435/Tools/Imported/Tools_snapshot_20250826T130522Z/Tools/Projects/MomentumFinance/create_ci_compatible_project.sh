#!/bin/bash
# Convert Xcode project from newer format (Xcode 16+) to older format (Xcode 15 compatible)

set -e  # Exit on any error

echo "🔧 Converting Xcode project to be compatible with older Xcode versions..."

PROJECT_FILE="MomentumFinance.xcodeproj/project.pbxproj"

if [ ! -f "$PROJECT_FILE" ]; then
    echo "❌ Project file not found: $PROJECT_FILE"
    exit 1
fi

echo "📋 Current project analysis:"
echo "Object version: $(grep 'objectVersion' "$PROJECT_FILE" || echo 'not found')"
echo "Synchronized groups found: $(grep -c 'PBXFileSystemSynchronized' "$PROJECT_FILE" || echo '0')"

# Check if conversion is actually needed
if ! grep -q "PBXFileSystemSynchronized" "$PROJECT_FILE"; then
    echo "✅ Project already compatible - no FileSystemSynchronized groups found"
    exit 0
fi

# Backup original
echo "📋 Creating backup of original project..."
cp "$PROJECT_FILE" "$PROJECT_FILE.xcode16_backup"

echo "⚠️  WARNING: This project uses Xcode 16+ File System Synchronized Groups"
echo "   These are incompatible with CI environment (Xcode 15.4)"
echo ""
echo "🔄 Removing Xcode 16+ incompatible features..."

# Use a more direct approach - sed to remove problematic sections
temp_file=$(mktemp)

# Remove the entire PBXFileSystemSynchronizedRootGroup section
sed '/Begin PBXFileSystemSynchronizedRootGroup section/,/End PBXFileSystemSynchronizedRootGroup section/d' "$PROJECT_FILE" > "$temp_file"

# Remove any remaining references to PBXFileSystemSynchronized
sed '/PBXFileSystemSynchronized/d' "$temp_file" > "${temp_file}.clean"
mv "${temp_file}.clean" "$temp_file"

# Change object version from 77 to 56 for Xcode 15 compatibility if present
sed 's/objectVersion = 77;/objectVersion = 56;/g' "$temp_file" > "${temp_file}.final"
mv "${temp_file}.final" "$temp_file"

# Validate that we haven't broken the plist structure
if plutil -lint "$temp_file" >/dev/null 2>&1; then
    echo "✅ Converted project file validates successfully"
    mv "$temp_file" "$PROJECT_FILE"
    
    echo "📋 Updated project format:"
    echo "Object version: $(grep 'objectVersion' "$PROJECT_FILE" || echo 'not found')"
    echo "Synchronized groups: $(grep -c 'PBXFileSystemSynchronized' "$PROJECT_FILE" || echo '0')"
    echo "🎯 Project is now compatible with Xcode 15.4 (CI environment)"
    
    # Verify schemes still exist
    if xcodebuild -list >/dev/null 2>&1; then
        echo "✅ Project schemes are accessible after conversion"
    else
        echo "⚠️  Warning: Project schemes may need verification"
    fi
else
    echo "❌ Converted project file failed validation"
    echo "🔄 Restoring original project..."
    mv "$PROJECT_FILE.xcode16_backup" "$PROJECT_FILE"
    rm -f "$temp_file"
    exit 1
fi

# Clean up
rm -f "$temp_file"

echo ""
echo "✅ CI Compatibility Conversion Complete!"
echo "   Original backup saved as: $PROJECT_FILE.xcode16_backup"
echo "   Project should now work with Xcode 15.4 in CI environment"
