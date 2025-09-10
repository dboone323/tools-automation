#!/bin/bash

# Script to add missing Swift files to Xcode project

PROJECT_FILE="/Users/danielstevens/Desktop/MomentumFinaceApp/MomentumFinance.xcodeproj/project.pbxproj"

# Create backup
cp "$PROJECT_FILE" "$PROJECT_FILE.backup_$(date +%s)"

# Files to add
FILES=(
    "SubscriptionManagementViews.swift"
    "SubscriptionSummaryViews.swift" 
    "SubscriptionRowViews.swift"
    "EnhancedGoalsSectionViews.swift"
)

# Generate unique IDs for files
MANAGEMENT_ID="6B1A2BA02C0D1E9100123456"
SUMMARY_ID="6B1A2BA22C0D1E9100123456"
ROW_ID="6B1A2BA42C0D1E9100123456"
ENHANCED_ID="6B1A2BA62C0D1E9100123456"

# Build file IDs
MANAGEMENT_BUILD_ID="6B1A2BA12C0D1E9100123456"
SUMMARY_BUILD_ID="6B1A2BA32C0D1E9100123456"
ROW_BUILD_ID="6B1A2BA52C0D1E9100123456"
ENHANCED_BUILD_ID="6B1A2BA72C0D1E9100123456"

# Add PBXBuildFile entries
sed -i '' '/6B1A2B880C0D1E9100123456.*SettingsView.swift in Sources/a\
		'"$MANAGEMENT_BUILD_ID"' /* SubscriptionManagementViews.swift in Sources */ = {isa = PBXBuildFile; fileRef = '"$MANAGEMENT_ID"' /* SubscriptionManagementViews.swift */; };\
		'"$SUMMARY_BUILD_ID"' /* SubscriptionSummaryViews.swift in Sources */ = {isa = PBXBuildFile; fileRef = '"$SUMMARY_ID"' /* SubscriptionSummaryViews.swift */; };\
		'"$ROW_BUILD_ID"' /* SubscriptionRowViews.swift in Sources */ = {isa = PBXBuildFile; fileRef = '"$ROW_ID"' /* SubscriptionRowViews.swift */; };\
		'"$ENHANCED_BUILD_ID"' /* EnhancedGoalsSectionViews.swift in Sources */ = {isa = PBXBuildFile; fileRef = '"$ENHANCED_ID"' /* EnhancedGoalsSectionViews.swift */; };
' "$PROJECT_FILE"

# Add PBXFileReference entries  
sed -i '' '/6B1A2B872C0D1E9100123456.*SettingsView.swift/a\
		'"$MANAGEMENT_ID"' /* SubscriptionManagementViews.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SubscriptionManagementViews.swift; sourceTree = "<group>"; };\
		'"$SUMMARY_ID"' /* SubscriptionSummaryViews.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SubscriptionSummaryViews.swift; sourceTree = "<group>"; };\
		'"$ROW_ID"' /* SubscriptionRowViews.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = SubscriptionRowViews.swift; sourceTree = "<group>"; };\
		'"$ENHANCED_ID"' /* EnhancedGoalsSectionViews.swift */ = {isa = PBXFileReference; lastKnownFileType = sourcecode.swift; path = EnhancedGoalsSectionViews.swift; sourceTree = "<group>"; };
' "$PROJECT_FILE"

# Add files to Subscriptions group
sed -i '' '/6B1A2B772C0D1E9100123456.*SubscriptionDetailView.swift/a\
				'"$MANAGEMENT_ID"' /* SubscriptionManagementViews.swift */,\
				'"$SUMMARY_ID"' /* SubscriptionSummaryViews.swift */,\
				'"$ROW_ID"' /* SubscriptionRowViews.swift */,
' "$PROJECT_FILE"

# Add enhanced goals file to GoalsAndReports group  
sed -i '' '/6B1A2B852C0D1E9100123456.*GoalUtilityViews.swift/a\
				'"$ENHANCED_ID"' /* EnhancedGoalsSectionViews.swift */,
' "$PROJECT_FILE"

# Add to Sources build phase
sed -i '' '/6B1A2B880C0D1E9100123456.*SettingsView.swift in Sources/a\
				'"$MANAGEMENT_BUILD_ID"' /* SubscriptionManagementViews.swift in Sources */,\
				'"$SUMMARY_BUILD_ID"' /* SubscriptionSummaryViews.swift in Sources */,\
				'"$ROW_BUILD_ID"' /* SubscriptionRowViews.swift in Sources */,\
				'"$ENHANCED_BUILD_ID"' /* EnhancedGoalsSectionViews.swift in Sources */,
' "$PROJECT_FILE"

echo "Files added to Xcode project successfully!"
