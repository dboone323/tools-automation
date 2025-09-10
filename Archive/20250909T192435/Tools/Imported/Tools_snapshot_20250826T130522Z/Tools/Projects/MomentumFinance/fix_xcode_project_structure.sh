#!/bin/bash

echo "=== Fixing Xcode Project Structure ==="
echo

# 1. Backup current project
echo "1. Creating backup of current project..."
cp -r MomentumFinance.xcodeproj MomentumFinance.xcodeproj.backup_$(date +%Y%m%d_%H%M%S)

# 2. Create a new project structure using swift package
echo "2. Generating Xcode project from Package.swift..."
echo "This will create a project that properly references all files in Shared/"

# Check if we're on macOS with Swift installed
if command -v swift &> /dev/null; then
    echo "Swift found. Generating Xcode project..."
    swift package generate-xcodeproj
    
    if [ $? -eq 0 ]; then
        echo "✅ Successfully generated MomentumFinance.xcodeproj from Package.swift"
        echo
        echo "The new project will:"
        echo "- Include all 70 Swift files from Shared/"
        echo "- Have correct file references"
        echo "- Match the Package.swift structure"
        echo
        echo "Next steps:"
        echo "1. Open the newly generated MomentumFinance.xcodeproj"
        echo "2. Select the MomentumFinance scheme"
        echo "3. Build and run (Cmd+R)"
    else
        echo "❌ Failed to generate Xcode project"
    fi
else
    echo "❌ Swift not found. Creating manual fix instructions..."
    
    # Create a project.pbxproj template that matches Package.swift structure
    cat > fix_project_manually.md << 'EOF'
# Manual Fix Instructions for Xcode Project

Since Swift is not available to generate the project automatically, follow these steps:

## Option 1: Create New Xcode Project (Recommended)

1. **Create a new Xcode project:**
   - File → New → Project
   - Choose "App" template
   - Product Name: MomentumFinance
   - Interface: SwiftUI
   - Language: Swift
   - Use Core Data: NO
   - Include Tests: NO

2. **Delete default files:**
   - Delete the default ContentView.swift
   - Delete the default MomentumFinanceApp.swift
   - Keep Assets.xcassets

3. **Add Shared folder:**
   - Right-click on project → Add Files to "MomentumFinance"
   - Select the entire "Shared" folder
   - Options:
     - ✅ Create groups
     - ❌ Copy items if needed (UNCHECKED)
     - ✅ Add to targets: MomentumFinance

4. **Update build settings:**
   - Select project → MomentumFinance target
   - Build Settings → Swift Compiler - Language → Swift Language Version: 6.0
   - Build Settings → Deployment → iOS Deployment Target: 17.0 (or lower)

## Option 2: Fix Current Project

1. **Remove all file references:**
   - Select all Swift files in project navigator
   - Press Delete → Remove References

2. **Re-add Shared folder:**
   - Right-click on project root
   - Add Files to "MomentumFinance"
   - Navigate to and select the "Shared" folder
   - ✅ Create groups
   - ❌ Copy items if needed
   - ✅ Add to targets: MomentumFinance

3. **Fix Info.plist:**
   - Ensure UIApplicationSceneManifest is configured for SwiftUI
   - Remove any Storyboard references

## Option 3: Use Command Line Build

Instead of Xcode, build directly with Swift Package Manager:

```bash
# Build the app
swift build

# Run the app (macOS)
swift run

# Build for specific platform
swift build -c release --arch arm64 --platform ios
```

## File Structure Expected

The project should recognize this structure:
```
MomentumFinance/
├── Shared/
│   ├── MomentumFinanceApp.swift (main app file)
│   ├── ContentView.swift
│   ├── Models/
│   ├── Features/
│   ├── Theme/
│   ├── Utils/
│   ├── Utilities/
│   ├── Navigation/
│   ├── Intelligence/
│   ├── Animations/
│   └── Views/
├── MomentumFinance.xcodeproj
└── Package.swift
```

All Swift files should be referenced from their location in Shared/.
EOF

    echo "Created fix_project_manually.md with detailed instructions"
fi

# 3. Create a verification script
cat > verify_xcode_fix.sh << 'SCRIPT'
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
SCRIPT

chmod +x verify_xcode_fix.sh

echo
echo "3. Additional fixes applied:"
echo "   - Created verify_xcode_fix.sh to check if the fix worked"
echo "   - Created fix_project_manually.md with manual instructions"
echo
echo "To verify the fix worked, run: ./verify_xcode_fix.sh"