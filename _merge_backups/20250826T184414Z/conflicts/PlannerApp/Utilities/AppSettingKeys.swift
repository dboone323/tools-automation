// PlannerApp/Utilities/AppSettingKeys.swift
// (Create a new folder Utilities if it doesn't exist)

import Foundation

// Centralized keys for UserDefaults settings accessed via @AppStorage
struct AppSettingKeys {
    // Profile
    static let userName = "userDisplayName"

    // Dashboard
    static let dashboardItemLimit = "dashboardItemLimit"

    // Appearance
    static let themeColorName = "themeColorName"
    // Note: themeFontName is not used in this simplified ThemeManager,
    // font is tied to the selected color theme name. Add if needed.
    // static let themeFontName = "themeFontName"

    // Notifications (Keys for storing preferences)
    static let notificationsEnabled = "notificationsEnabled"
    static let defaultReminderTime = "defaultReminderTime" // Store as TimeInterval

    // Date & Time
    static let firstDayOfWeek = "firstDayOfWeek" // Store as Int (1=Sun, 2=Mon etc.)
    static let use24HourTime = "use24HourTime"

    // App Behavior
    static let autoDeleteCompleted = "autoDeleteCompleted"
    static let autoDeleteDays = "autoDeleteDays" // Days after completion to delete
    static let defaultView = "defaultView" // Store identifier for the default tab

    // Journal Security
    static let journalBiometricsEnabled = "journalBiometricsEnabled"

    // CloudKit & Sync Settings
    static let autoSyncEnabled = "autoSyncEnabled"
    static let syncFrequency = "syncFrequency"
    
    // User Experience Settings
    static let enableHapticFeedback = "enableHapticFeedback"
    static let enableAnalytics = "enableAnalytics"

    // Add more keys as needed
}
