#!/bin/bash

echo "Starting AvoidObstaclesGame test..."

# Build and run the project in the simulator
cd /Users/danielstevens/Desktop/AvoidObstaclesGame

echo "Building project..."
xcodebuild -project AvoidObstaclesGame.xcodeproj -scheme AvoidObstaclesGame -destination 'platform=iOS Simulator,name=iPhone 16' build

if [ $? -eq 0 ]; then
	echo "Build successful! Starting simulator..."

	# Boot the simulator if not already running
	xcrun simctl boot "iPhone 16" 2>/dev/null || true

	# Open the simulator
	open -a Simulator

	# Install and launch the app
	APP_PATH="/Users/danielstevens/Library/Developer/Xcode/DerivedData/AvoidObstaclesGame-bhbjbhmmtvjkotgsgpqwvuwmtezr/Build/Products/Debug-iphonesimulator/AvoidObstaclesGame.app"

	if [ -d "$APP_PATH" ]; then
		echo "Installing app on simulator..."
		xcrun simctl install "iPhone 16" "$APP_PATH"

		echo "Launching AvoidObstaclesGame..."
		xcrun simctl launch "iPhone 16" com.DanielStevens.AvoidObstaclesGame

		echo "Game launched successfully! Check the simulator to test all features:"
		echo "1. High score tracking (top 10 scores)"
		echo "2. Progressive difficulty system"
		echo "3. Enhanced UI with level indicators"
		echo "4. Visual feedback for level ups and high scores"
	else
		echo "Error: App bundle not found at $APP_PATH"
	fi
else
	echo "Build failed!"
fi
