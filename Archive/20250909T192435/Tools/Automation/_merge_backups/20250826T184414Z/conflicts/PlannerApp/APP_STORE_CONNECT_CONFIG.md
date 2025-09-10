# App Store Connect CloudKit Configuration Guide

This document outlines the steps needed to properly configure your PlannerApp for distribution through App Store Connect, with specific focus on CloudKit integration.

## Prerequisites

- Apple Developer Account with App Store Connect access
- Xcode 14+ with your PlannerApp project
- Bundle ID reserved in App Store Connect

## Step 1: Configure iCloud Container in Developer Portal

1. Log in to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to "Certificates, IDs & Profiles"
3. Select "Identifiers" from the sidebar
4. Find your app's identifier and click on it
5. Ensure "iCloud" capability is enabled
6. Under iCloud, check "CloudKit" and configure containers:
   - Click "+" to add a container
   - Name format: `iCloud.com.yourcompany.PlannerApp`
   - Description: "PlannerApp CloudKit Container"
   - Click "Continue" and "Register"

## Step 2: Configure CloudKit Dashboard

1. Go to [CloudKit Dashboard](https://icloud.developer.apple.com/dashboard/)
2. Select your newly created container
3. Configure schema for your record types:
   - Create "Task" record type with fields:
     - title (String)
     - isCompleted (Int/Boolean)
     - dueDate (Date/Time)
     - createdAt (Date/Time)
     - completedAt (Date/Time)
     - modifiedAt (Date/Time)
     - notes (String)
     - priority (Int)
   - Repeat for "Goal", "CalendarEvent", and "JournalEntry" record types
4. Configure indexes for better performance
5. Set up security roles if needed

## Step 3: Configure App in Xcode

1. Open your PlannerApp in Xcode
2. Select your app target
3. Go to "Signing & Capabilities"
4. Ensure "iCloud" capability is added
5. Check "CloudKit" and select your container
6. Verify entitlements file contains:
   ```xml
   <key>com.apple.developer.icloud-container-identifiers</key>
   <array>
       <string>iCloud.com.yourcompany.PlannerApp</string>
   </array>
   <key>com.apple.developer.icloud-services</key>
   <array>
       <string>CloudKit</string>
   </array>
   ```

## Step 4: Configure App Store Connect

1. Log in to [App Store Connect](https://appstoreconnect.apple.com/)
2. Navigate to "My Apps" and select your app
3. Go to "App Information"
4. Under "iCloud Container Environment", select:
   - Development: Use during TestFlight testing
   - Production: Use for App Store distribution
5. Save changes

## Step 5: TestFlight Configuration

1. Upload a build to TestFlight
2. In App Store Connect, go to "TestFlight" → your app
3. Under "Build Information" verify iCloud container is listed
4. Enable "TestFlight Beta Testing" to test with external users

## Step 6: Production Release

1. When you're ready to publish:
2. Go to "App Store" tab in App Store Connect
3. Prepare your app metadata, screenshots, etc.
4. Under "Build", select your TestFlight-tested build
5. Verify iCloud container is correctly configured

## Common Issues and Solutions

### Container Mismatch

**Issue**: The container ID in your code doesn't match the one in App Store Connect
**Solution**: Double-check that the container ID is identical in:

- Xcode project entitlements
- Developer Portal registration
- App Store Connect settings

### Sandbox vs. Production

**Issue**: Data doesn't sync between TestFlight and Production versions
**Solution**: Development and Production environments use separate databases. When moving to production, users will start with empty CloudKit data.

### Schema Changes

**Issue**: Adding new fields to your data models after release
**Solution**:

1. Update CloudKit schema in dashboard first
2. Add migration code to handle missing fields in older versions
3. Use conditional code to check if fields exist

### CloudKit Quotas

**Issue**: Reaching CloudKit storage limits
**Solution**:

1. Monitor usage in CloudKit Dashboard
2. Implement data cleanup for old records
3. Consider paid CloudKit options for heavy usage

By following these steps, your PlannerApp will be properly configured for CloudKit syncing across all Apple devices when distributed through the App Store.
