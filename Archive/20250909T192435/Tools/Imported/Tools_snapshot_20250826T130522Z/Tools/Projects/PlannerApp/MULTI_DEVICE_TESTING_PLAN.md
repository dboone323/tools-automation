# Multi-Device Testing Plan for PlannerApp

## Overview
This document outlines the testing procedure to verify that iCloud syncing works correctly across multiple Apple devices. Testing should be performed before final app submission to ensure a seamless user experience.

## Prerequisites
- At least two Apple devices (any combination of Mac, iPhone, iPad)
- Same Apple ID signed in on all test devices
- Internet connection on all devices
- Development builds of PlannerApp installed on all test devices

## Test Scenarios

### 1. Basic CloudKit Account Verification
**On Device 1:**
- Launch the app
- Verify that the app recognizes the iCloud account
- If prompted, complete the CloudKit onboarding flow

**Expected Result:**
- App should display the user's iCloud account info
- Sync status indicator should show "Connected"

### 2. Data Creation & Sync
**On Device 1:**
- Add a new task with title "CloudKit Test Task"
- Add a new goal with title "CloudKit Test Goal"
- Add a new calendar event with title "CloudKit Test Event"
- Add a new journal entry with title "CloudKit Test Journal"

**On Device 2:**
- Launch the app and wait for automatic sync (or trigger manual sync)
- Navigate to each section (Tasks, Goals, Calendar, Journal)

**Expected Result:**
- All items created on Device 1 should appear on Device 2
- The sync status indicator should show "Synced" after completion

### 3. Data Modification Test
**On Device 2:**
- Modify the "CloudKit Test Task" (mark as completed)
- Edit the "CloudKit Test Goal" description
- Change the date of "CloudKit Test Event"
- Edit the content of "CloudKit Test Journal"

**On Device 1:**
- Trigger a sync (or wait for automatic sync)
- Verify all modifications from Device 2 appear

**Expected Result:**
- All modifications should sync back to Device 1
- Changes should be reflected accurately in all data fields

### 4. Conflict Resolution Test
**On Device 1 & 2 simultaneously:**
- Put both devices in airplane mode
- On Device 1: Edit "CloudKit Test Task" to have priority "High"
- On Device 2: Edit the same "CloudKit Test Task" to have priority "Low"
- Take both devices out of airplane mode and sync

**Expected Result:**
- The app should resolve the conflict based on timestamp
- The device with the most recent edit should win
- The sync operation should complete successfully

### 5. New Device Setup Test
**On a new Device 3 (or reset app on Device 2):**
- Install the app fresh
- Sign in with the same iCloud account
- Observe the onboarding/setup flow

**Expected Result:**
- User should be asked if they want to download existing iCloud data
- After choosing yes, all existing data should appear
- No duplicate items should be created

### 6. Offline Mode Test
**On Device 1:**
- Enable airplane mode
- Create a new task "Offline Task"
- Create a new goal "Offline Goal"
- Disable airplane mode and watch sync behavior

**Expected Result:**
- Items created while offline should upload to iCloud when connectivity returns
- Sync status should update from "Pending" to "Synced"

## Reporting Issues
Document any failures in the above tests with:
1. Device information (model, OS version)
2. Screenshots of the issue
3. Exact steps to reproduce
4. Network conditions at time of failure

## Success Criteria
The iCloud integration can be considered verified when all the above test scenarios pass on at least two different device types (e.g., one Mac and one iOS device).