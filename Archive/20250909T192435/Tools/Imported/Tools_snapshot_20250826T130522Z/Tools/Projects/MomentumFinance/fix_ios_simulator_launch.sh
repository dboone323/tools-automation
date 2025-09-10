#!/bin/bash

echo "=== Fixing iOS Simulator Launch Issue ==="
echo

# 1. Kill any stuck simulator processes
echo "1. Cleaning up simulator processes..."
killall Simulator 2>/dev/null || true
killall SimulatorTrampoline 2>/dev/null || true

# 2. Reset the specific simulator
echo "2. Resetting iPhone 16 Pro Max simulator..."
DEVICE_ID="15AB3298-270F-449B-B0BA-DCB97024C8C6"
xcrun simctl shutdown "$DEVICE_ID" 2>/dev/null || true
xcrun simctl erase "$DEVICE_ID"

# 3. Clean build artifacts
echo "3. Cleaning build artifacts..."
rm -rf ~/Library/Developer/Xcode/DerivedData/MomentumFinance-*

# 4. Reset all simulators (optional - more thorough)
echo "4. Would you like to reset ALL simulators? (y/n)"
read -r response
if [[ "$response" =~ ^[Yy]$ ]]; then
    xcrun simctl shutdown all
    xcrun simctl erase all
    echo "   All simulators reset"
fi

# 5. Boot the simulator
echo "5. Booting simulator..."
xcrun simctl boot "$DEVICE_ID"
sleep 5

# 6. Open Simulator app
echo "6. Opening Simulator app..."
open -a Simulator

echo
echo "✅ Simulator reset complete!"
echo
echo "Next steps in Xcode:"
echo "1. Clean Build Folder (Shift+Cmd+K)"
echo "2. Select iPhone 16 Pro Max as target"
echo "3. Build and Run (Cmd+R)"
echo
echo "If the issue persists, try:"
echo "- Xcode → Settings → Platforms → Delete and re-download iOS Simulator"
echo "- Restart your Mac"
echo "- Check if the app runs on a different simulator (e.g., iPhone 15)"