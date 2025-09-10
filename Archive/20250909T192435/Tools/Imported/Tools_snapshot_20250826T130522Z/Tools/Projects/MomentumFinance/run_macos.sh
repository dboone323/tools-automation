#!/bin/bash

# Run MomentumFinance on macOS
echo "Building and running MomentumFinance on macOS..."

# Build the project
echo "Building project..."
swift build

if [ $? -eq 0 ]; then
    echo "Build successful! Running the app..."
    # Run the built executable
    ./.build/debug/MomentumFinance
else
    echo "Build failed!"
    exit 1
fi
