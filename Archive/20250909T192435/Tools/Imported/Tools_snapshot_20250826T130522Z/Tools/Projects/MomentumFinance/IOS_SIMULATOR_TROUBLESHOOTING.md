# iOS Simulator Launch Error - Troubleshooting Guide

## Error Summary
- **Error**: "No such process" (NSPOSIXErrorDomain Code 3)
- **Issue**: App builds successfully but fails to launch in simulator
- **Device**: iPhone 16 Pro Max (iOS 18.5)

## Quick Fixes (Try in Order)

### 1. Clean and Rebuild
In Xcode:
1. **Clean Build Folder**: Shift+Cmd+K
2. **Quit Xcode** completely
3. **Quit Simulator** app
4. Reopen Xcode
5. Build and Run (Cmd+R)

### 2. Reset Simulator
Run the provided script:
```bash
chmod +x fix_ios_simulator_launch.sh
./fix_ios_simulator_launch.sh
```

Or manually:
```bash
# Reset specific simulator
xcrun simctl shutdown "15AB3298-270F-449B-B0BA-DCB97024C8C6"
xcrun simctl erase "15AB3298-270F-449B-B0BA-DCB97024C8C6"

# Or reset all simulators
xcrun simctl shutdown all
xcrun simctl erase all
```

### 3. Try Different Simulator
1. In Xcode, click the device selector (next to the scheme)
2. Choose a different simulator (e.g., iPhone 15 or iPhone 14)
3. Build and Run

### 4. Check Build Settings
1. Select project → MomentumFinance target
2. Build Settings tab
3. Verify:
   - **iOS Deployment Target**: 17.0 (not 18.0)
   - **Build Active Architecture Only**: Yes (for Debug)
   - **Valid Architectures**: arm64

### 5. Delete Derived Data
```bash
rm -rf ~/Library/Developer/Xcode/DerivedData/MomentumFinance-*
# Or delete all DerivedData
rm -rf ~/Library/Developer/Xcode/DerivedData/*
```

### 6. Check Info.plist
Ensure Info.plist has:
```xml
<key>CFBundleExecutable</key>
<string>$(EXECUTABLE_NAME)</string>
<key>CFBundleIdentifier</key>
<string>$(PRODUCT_BUNDLE_IDENTIFIER)</string>
<key>UIApplicationSceneManifest</key>
<dict>
    <key>UIApplicationSupportsMultipleScenes</key>
    <false/>
    <key>UISceneConfigurations</key>
    <dict>
        <key>UIWindowSceneSessionRoleApplication</key>
        <array>
            <dict>
                <key>UISceneConfigurationName</key>
                <string>Default Configuration</string>
                <key>UISceneDelegateClassName</key>
                <string>$(PRODUCT_MODULE_NAME).SceneDelegate</string>
            </dict>
        </array>
    </dict>
</dict>
```

## Advanced Troubleshooting

### A. Simulator Issues
1. **Reset Simulator Content**:
   - Simulator → Device → Erase All Content and Settings
   
2. **Re-download Simulator Runtime**:
   - Xcode → Settings → Platforms
   - Delete iOS Simulator
   - Re-download

3. **Check Simulator Logs**:
   ```bash
   # View simulator logs
   xcrun simctl spawn booted log stream --level debug --predicate 'processImagePath contains "MomentumFinance"'
   ```

### B. Build Configuration
1. **Edit Scheme**:
   - Product → Scheme → Edit Scheme
   - Run → Info → Build Configuration: Debug
   - Run → Arguments → Environment Variables:
     - Add: `OS_ACTIVITY_MODE` = `disable` (reduces log noise)

2. **Check Executable**:
   ```bash
   # Verify app bundle exists
   find ~/Library/Developer/Xcode/DerivedData -name "MomentumFinance.app" -type d
   
   # Check if executable exists in app bundle
   ls -la ~/Library/Developer/Xcode/DerivedData/*/Build/Products/Debug-iphonesimulator/MomentumFinance.app/
   ```

### C. Code Signing (Simulator shouldn't need this, but just in case)
1. Select project → MomentumFinance target
2. Signing & Capabilities tab
3. Ensure:
   - Automatically manage signing: ✅
   - Team: Your Apple ID team
   - Bundle Identifier: com.momentumfinance.MomentumFinance

### D. SwiftUI App Lifecycle
Verify `MomentumFinanceApp.swift` has proper structure:
```swift
import SwiftUI

@main
struct MomentumFinanceApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}
```

## Nuclear Options

### 1. Complete Xcode Reset
```bash
# Quit Xcode
# Delete all Xcode caches
rm -rf ~/Library/Developer/Xcode/DerivedData
rm -rf ~/Library/Caches/com.apple.dt.Xcode
rm -rf ~/Library/Developer/Xcode/iOS\ DeviceSupport
rm -rf ~/Library/Developer/Xcode/watchOS\ DeviceSupport

# Restart Mac
```

### 2. Create New Target
1. In Xcode: File → New → Target
2. Choose iOS App
3. Configure with same bundle ID
4. Move all files to new target

### 3. Test on Physical Device
If simulator continues to fail:
1. Connect iPhone via USB
2. Select your device as target
3. Build and Run

## Common Causes

1. **iOS 18.5 Beta Issues**: You're using iOS 18.5 which might be beta. Try iOS 17.x simulator
2. **Xcode 26 Beta**: You're using Xcode 26 (beta). Known to have simulator issues
3. **Architecture Mismatch**: M1/M2 Mac simulator issues
4. **Corrupted Simulator**: Reset helps
5. **Missing Entitlements**: Usually not for simulator, but check

## If Nothing Works

1. **File a Radar**: This might be an Xcode 26 beta bug
2. **Try Stable Xcode**: Download Xcode 15.x from developer.apple.com
3. **Use Different Mac**: Test on another machine
4. **Contact Apple Developer Support**: If you have a paid developer account

## Success Indicators
- Simulator launches
- App icon appears on home screen
- App launches when tapped
- No crash logs in Console.app