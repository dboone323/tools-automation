#!/bin/bash
# Simulator Warmup Script for CI/CD
# Pre-boots and warms up iOS simulators before running tests

set -e

# Configuration
SIMULATOR_DEVICE="${1:-iPhone 17}"
WARMUP_DELAY="${2:-15}"
MAX_RETRIES=3

echo "🚀 Starting simulator warmup for: $SIMULATOR_DEVICE"

# Function to check if simulator is booted
is_booted() {
    local device="$1"
    xcrun simctl list devices | grep "$device" | grep -q "Booted"
}

# Function to boot simulator
boot_simulator() {
    local device="$1"
    local retry_count=0
    
    while [ $retry_count -lt $MAX_RETRIES ]; do
        echo "📱 Attempting to boot simulator (attempt $((retry_count + 1))/$MAX_RETRIES)..."
        
        if xcrun simctl boot "$device" 2>/dev/null; then
            echo "✅ Simulator boot command sent successfully"
            return 0
        elif is_booted "$device"; then
            echo "✅ Simulator already booted"
            return 0
        else
            echo "⚠️  Boot attempt failed, retrying..."
            retry_count=$((retry_count + 1))
            sleep 3
        fi
    done
    
    echo "❌ Failed to boot simulator after $MAX_RETRIES attempts"
    return 1
}

# Function to wait for simulator to be ready
wait_for_ready() {
    local device="$1"
    local delay="$2"
    
    echo "⏳ Waiting ${delay}s for simulator to fully boot..."
    sleep "$delay"
    
    # Verify simulator is still booted
    if is_booted "$device"; then
        echo "✅ Simulator is ready"
        return 0
    else
        echo "❌ Simulator not in booted state"
        return 1
    fi
}

# Function to warm up simulator (launch and quit a simple app)
warmup_simulator() {
    local device="$1"
    
    echo "🔥 Warming up simulator..."
    
    # Open simulator app to ensure UI is responsive
    open -a Simulator 2>/dev/null || true
    sleep 2
    
    # Launch Settings app to warm up the runtime
    xcrun simctl launch "$device" com.apple.Preferences 2>/dev/null || true
    sleep 1
    xcrun simctl terminate "$device" com.apple.Preferences 2>/dev/null || true
    
    echo "✅ Simulator warmup complete"
}

# Main execution
main() {
    echo "================================================"
    echo "Simulator Warmup Script"
    echo "Device: $SIMULATOR_DEVICE"
    echo "Warmup Delay: ${WARMUP_DELAY}s"
    echo "================================================"
    
    # Boot the simulator
    if ! boot_simulator "$SIMULATOR_DEVICE"; then
        exit 1
    fi
    
    # Wait for simulator to be ready
    if ! wait_for_ready "$SIMULATOR_DEVICE" "$WARMUP_DELAY"; then
        exit 1
    fi
    
    # Warm up the simulator
    warmup_simulator "$SIMULATOR_DEVICE"
    
    echo ""
    echo "✅ Simulator warmup completed successfully!"
    echo "   You can now run your tests."
    echo ""
}

main
