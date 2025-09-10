# Fixing Xcode File References - Detailed Guide

## The Problem
When you added files from the package, Xcode didn't create correct references because:
1. The project expects a different file structure
2. Xcode is looking for files in the wrong locations
3. The symlinks are confusing Xcode's file reference system

## Solution: Complete Project Reset

### Step 1: Remove ALL File References
1. Open `MomentumFinance.xcodeproj` in Xcode
2. In the Project Navigator (left sidebar):
   - Select the first Swift file
   - Hold Shift and click the last Swift file to select all
   - Right-click → Delete → **Remove References** (NOT Move to Trash!)
3. You should now have an empty project with just:
   - MomentumFinance (project root)
   - Products folder

### Step 2: Remove Problematic Symlinks
In Terminal:
```bash
# Remove symlinks that are confusing Xcode
rm -f MomentumFinance/MomentumFinanceApp.swift
rm -f MomentumFinance/ContentView.swift
rm -f Shared/DataExportView.swift
rm -f Shared/DataImportView.swift
rm -f Shared/HapticManager.swift
rm -f Shared/SettingsView.swift
```

### Step 3: Add the Shared Folder Correctly
1. In Xcode, right-click on the project root (MomentumFinance)
2. Select "Add Files to 'MomentumFinance'..."
3. Navigate to your project directory
4. Select the **Shared** folder (the whole folder, not individual files)
5. **CRITICAL OPTIONS**:
   - ✅ **Create groups** (NOT "Create folder references")
   - ❌ **Copy items if needed** (MUST be unchecked)
   - ✅ **Add to targets: MomentumFinance**
6. Click "Add"

### Step 4: Verify File Structure
After adding, you should see in Xcode:
```
MomentumFinance
├── Shared (blue folder icon)
│   ├── MomentumFinanceApp.swift
│   ├── ContentView.swift
│   ├── Animations (group)
│   │   ├── AnimatedComponents.swift
│   │   └── AnimationManager.swift
│   ├── Features (group)
│   │   ├── Budgets
│   │   ├── Dashboard
│   │   ├── GoalsAndReports
│   │   ├── Subscriptions
│   │   └── Transactions
│   ├── Models (group)
│   ├── Navigation (group)
│   ├── Theme (group)
│   ├── Utils (group)
│   ├── Utilities (group)
│   └── Views (group)
└── Products
```

### Step 5: Fix Build Settings
1. Select the project (top item) in navigator
2. Select the MomentumFinance target
3. Build Settings tab:
   - Search for "Swift Language Version" → Set to 6.0
   - Search for "iOS Deployment Target" → Set to 17.0
4. General tab:
   - Minimum Deployments → iOS 17.0

### Step 6: Clean and Build
1. Product → Clean Build Folder (Shift+Cmd+K)
2. Close Xcode completely
3. Delete DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData/MomentumFinance-*
   ```
4. Reopen Xcode and the project
5. Build (Cmd+B)

## If Files Still Show as Missing (Red)

This means Xcode can't find the files. For each red file:
1. Select the red file
2. Open File Inspector (right panel)
3. Click the folder icon next to "Location"
4. Navigate to where the file actually exists in Shared/
5. Select the file

## Alternative: Use Swift Package Manager

If Xcode continues to have issues, you can build directly with the Package.swift:

On macOS with Xcode installed:
```bash
# Generate a fresh Xcode project from Package.swift
swift package generate-xcodeproj

# Or build directly without Xcode
swift build
swift run
```

## Common Issues and Fixes

### Issue: "No such module" errors
- Ensure all files are added to the correct target
- Check that file names match exactly (case-sensitive)

### Issue: "Cannot find type in scope"
- Files might not be included in the target
- Select file → File Inspector → Target Membership → ✅ MomentumFinance

### Issue: Duplicate symbols
- You might have files added twice
- Check for duplicate entries in the project navigator
- Remove any duplicates (keep only one reference)

## Verification

Run this in Terminal to verify all files are accessible:
```bash
# This should show 70 Swift files
find Shared -name "*.swift" -type f | wc -l

# This should show the same files Xcode should see
find Shared -name "*.swift" -type f | sort
```

## Last Resort: Create New Project

If nothing else works:
1. Create a completely new Xcode project
2. Copy the entire Shared folder into the new project
3. Copy Assets.xcassets from the old project
4. Copy Package.swift to the new project
5. Delete the old project