#!/bin/bash

echo "=== Fixing iOS Simulator Launch Issue (Safe Version) ==="
echo "This version preserves the symlinks needed for building"
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

# 3. Clean build artifacts (but not DerivedData to preserve build)
echo "3. Cleaning simulator caches..."
rm -rf ~/Library/Developer/CoreSimulator/Caches/dyld/

# 4. Try a different simulator
echo "4. Available simulators:"
xcrun simctl list devices | grep -E "iPhone (14|15|16)" | grep -v "unavailable"
echo
echo "Consider trying iPhone 15 Pro or iPhone 14 Pro instead"

# 5. Boot the simulator
echo "5. Booting simulator..."
xcrun simctl boot "$DEVICE_ID" 2>/dev/null || true
sleep 3

# 6. Open Simulator app
echo "6. Opening Simulator app..."
open -a Simulator

echo
echo "✅ Simulator reset complete!"
echo
echo "Next steps in Xcode:"
echo "1. Build (Cmd+B) - should succeed now with symlinks in place"
echo "2. Try running on iPhone 15 Pro instead of iPhone 16 Pro Max"
echo "3. In Xcode: Product → Destination → iPhone 15 Pro"
echo "4. Run (Cmd+R)"
echo
echo "The iOS 18.5 simulator seems to have issues. Try iOS 17.x simulators."