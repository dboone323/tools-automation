// filepath: /Users/danielstevens/Desktop/PlannerApp/Views/Settings/SettingsView.swift
// PlannerApp/Views/Settings/SettingsView.swift

import LocalAuthentication
import SwiftUI
import UserNotifications
#if os(macOS)
    import AppKit
#endif
import Foundation

struct SettingsView: View {
    // Import ThemeManager properly
    @EnvironmentObject var themeManager: ThemeManager

    // State properties with AppStorage keys
    @AppStorage(AppSettingKeys.userName) private var userName: String = ""
    @AppStorage(AppSettingKeys.dashboardItemLimit) private var dashboardItemLimit: Int = 3
    @AppStorage(AppSettingKeys.notificationsEnabled) private var notificationsEnabled: Bool = true
    @AppStorage(AppSettingKeys.use24HourTime) private var use24HourTime: Bool = false
    @AppStorage(AppSettingKeys.autoDeleteCompleted) private var autoDeleteCompleted: Bool = false
    @AppStorage(AppSettingKeys.journalBiometricsEnabled) private var journalBiometricsEnabled: Bool = false
    @AppStorage(AppSettingKeys.autoSyncEnabled) private var autoSyncEnabled: Bool = true
    @AppStorage(AppSettingKeys.enableHapticFeedback) private var enableHapticFeedback: Bool = true
    @AppStorage(AppSettingKeys.enableAnalytics) private var enableAnalytics: Bool = false
    @AppStorage(AppSettingKeys.firstDayOfWeek) private var firstDayOfWeek: Int = Calendar.current.firstWeekday
    @AppStorage(AppSettingKeys.defaultReminderTime) private var defaultReminderTime: Int = 900 // 15 minutes
    @AppStorage(AppSettingKeys.defaultView) private var defaultView: String = "Dashboard"
    @AppStorage(AppSettingKeys.autoDeleteDays) private var autoDeleteDays: Int = 7
    @AppStorage(AppSettingKeys.syncFrequency) private var syncFrequency: String = "hourly"

    // State for managing UI elements
    @State private var showingNotificationAlert = false
    @State private var showingClearDataConfirmation = false
    @State private var showingExportShareSheet = false
    @State private var exportURL: URL?
    @State private var showingCloudKitSheet = false
    @State private var showingThemePreview = false

    // Computed properties
    private var canUseBiometrics: Bool {
        let context = LAContext()
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: nil)
    }

    private let reminderTimeOptions: [String: Int] = [
        "5 minutes": 300,
        "15 minutes": 900,
        "30 minutes": 1800,
        "1 hour": 3600,
        "1 day": 86400,
    ]

    private var sortedReminderKeys: [String] {
        reminderTimeOptions.keys.sorted { reminderTimeOptions[$0]! < reminderTimeOptions[$1]! }
    }

    private let defaultViewOptions = ["Dashboard", "Tasks", "Calendar", "Goals", "Journal"]

    var body: some View {
        NavigationStack {
            Form {
                // Profile Section
                Section("Profile") {
                    HStack {
                        Text("Name")
                        Spacer()
                        TextField("Your Name", text: $userName)
                            .multilineTextAlignment(.trailing)
                    }
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // Appearance Section
                Section("Appearance") {
                    Picker("Theme", selection: $themeManager.currentThemeName) {
                        ForEach(Theme.availableThemes, id: \.name) { theme in
                            Text(theme.name).tag(theme.name)
                        }
                    }
                    .pickerStyle(.menu)

                    Button(action: { showingThemePreview = true }) {
                        HStack {
                            Text("Theme Preview")
                                .foregroundColor(themeManager.currentTheme.primaryTextColor)
                            Spacer()
                            Circle()
                                .fill(themeManager.currentTheme.primaryAccentColor)
                                .frame(width: 20, height: 20)
                            Image(systemName: "chevron.right")
                                .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                        }
                    }
                    .buttonStyle(.plain)
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // Dashboard Section
                Section("Dashboard") {
                    Stepper("Items per section: \(dashboardItemLimit)", value: $dashboardItemLimit, in: 1 ... 10)
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // Notifications Section
                Section("Notifications") {
                    Toggle("Enable Reminders", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, newValue in
                            handleNotificationToggle(enabled: newValue)
                        }

                    Picker("Default Reminder", selection: $defaultReminderTime) {
                        ForEach(sortedReminderKeys, id: \.self) { key in
                            Text(key).tag(reminderTimeOptions[key]!)
                        }
                    }
                    .disabled(!notificationsEnabled)
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // Date & Time Section
                Section("Date & Time") {
                    Picker("First Day of Week", selection: $firstDayOfWeek) {
                        Text("System Default").tag(Calendar.current.firstWeekday)
                        Text("Sunday").tag(1)
                        Text("Monday").tag(2)
                    }

                    Toggle("Use 24-Hour Time", isOn: $use24HourTime)
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // App Behavior Section
                Section("App Behavior") {
                    Picker("Default View on Launch", selection: $defaultView) {
                        ForEach(defaultViewOptions, id: \.self) { viewName in
                            Text(viewName).tag(viewName)
                        }
                    }

                    Toggle("Auto-Delete Completed Tasks", isOn: $autoDeleteCompleted)

                    if autoDeleteCompleted {
                        Stepper("Delete after: \(autoDeleteDays) days", value: $autoDeleteDays, in: 1 ... 90)
                    }
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // Security Section
                Section("Security") {
                    if canUseBiometrics {
                        Toggle("Protect Journal with Biometrics", isOn: $journalBiometricsEnabled)
                    } else {
                        Text("Biometric authentication not available on this device.")
                            .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                    }
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // Sync & Cloud Section
                Section("Sync & Cloud") {
                    Button(action: { showingCloudKitSheet = true }) {
                        HStack {
                            Image(systemName: "icloud")
                                .foregroundColor(.blue)
                            Text("iCloud Sync")
                                .foregroundColor(themeManager.currentTheme.primaryTextColor)
                            Spacer()
                            Image(systemName: "chevron.right")
                                .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                        }
                    }

                    Toggle("Auto Sync", isOn: $autoSyncEnabled)

                    Picker("Sync Frequency", selection: $syncFrequency) {
                        Text("Every 15 minutes").tag("15min")
                        Text("Hourly").tag("hourly")
                        Text("Daily").tag("daily")
                        Text("Manual only").tag("manual")
                    }
                    .disabled(!autoSyncEnabled)
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // Enhanced Features Section
                Section("Enhanced Features") {
                    Toggle("Haptic Feedback", isOn: $enableHapticFeedback)
                    Toggle("Enable Analytics", isOn: $enableAnalytics)

                    if enableAnalytics {
                        Text("Help improve PlannerApp by sharing anonymous usage data.")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                    }
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // Data Management Section
                Section("Data Management") {
                    Button("Export Data", action: exportData)
                        .foregroundColor(themeManager.currentTheme.primaryAccentColor)

                    Button("Clear Old Completed Tasks...", action: { showingClearDataConfirmation = true })
                        .foregroundColor(themeManager.currentTheme.destructiveColor)
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // About Section
                Section("About") {
                    HStack {
                        Text("App Version")
                            .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                        Spacer()
                        Text(Bundle.main.appVersion ?? "N/A")
                            .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                    }
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)
            }
            .navigationTitle("Settings")
            .background(themeManager.currentTheme.primaryBackgroundColor.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .foregroundColor(themeManager.currentTheme.primaryTextColor)
            .accentColor(themeManager.currentTheme.primaryAccentColor)
            .sheet(isPresented: $showingCloudKitSheet) {
                CloudKitSettingsView()
            }
            .sheet(isPresented: $showingThemePreview) {
                ThemePreviewSheet()
                    .environmentObject(themeManager)
            }
            .alert("Notification Permissions", isPresented: $showingNotificationAlert) {
                Button("Open Settings", action: openAppSettings)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Enable notifications in Settings to receive reminders.")
            }
            .alert("Confirm Deletion", isPresented: $showingClearDataConfirmation) {
                Button("Delete", role: .destructive, action: performClearOldData)
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to permanently delete completed tasks older than \(autoDeleteDays) days? This cannot be undone.")
            }
        }
        .accentColor(themeManager.currentTheme.primaryAccentColor)
    }

    // MARK: - Action Handlers

    func handleNotificationToggle(enabled: Bool) {
        if enabled {
            requestNotificationPermission()
        }
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if !granted {
                    self.showingNotificationAlert = true
                    self.notificationsEnabled = false
                }
                if error != nil {
                    self.notificationsEnabled = false
                }
            }
        }
    }

    func openAppSettings() {
        #if os(iOS)
            if let settingsURL = URL(string: UIApplication.openSettingsURLString) {
                UIApplication.shared.open(settingsURL)
            }
        #elseif os(macOS)
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.notifications")!)
        #endif
    }

    func exportData() {
        let csvString = "Type,ID,Title\nSample,1,Test Data\n"
        guard let data = csvString.data(using: .utf8) else { return }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("PlannerExport.csv")
        do {
            try data.write(to: tempURL, options: .atomic)
            self.exportURL = tempURL
            self.showingExportShareSheet = true
        } catch {
            print("Failed to write export file: \(error)")
        }
    }

    func performClearOldData() {
        // Implementation for clearing old data
        print("Clearing old data...")
    }
}

// MARK: - CloudKit Settings View

struct CloudKitSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                Text("CloudKit Sync")
                    .font(.title)
                    .padding()
                Text("CloudKit integration coming soon...")
                    .foregroundColor(.secondary)
                Button("Done") {
                    dismiss()
                }
                .padding()
            }
            .frame(minWidth: 400, minHeight: 300)
        }
    }
}

// MARK: - Theme Preview Sheet

struct ThemePreviewSheet: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    ForEach(Theme.availableThemes, id: \.name) { theme in
                        ThemeCard(theme: theme, isSelected: theme.name == themeManager.currentTheme.name) {
                            themeManager.setTheme(theme)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Theme Preview")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
            .background(themeManager.currentTheme.primaryBackgroundColor.ignoresSafeArea())
        }
    }
}

// MARK: - Theme Card

struct ThemeCard: View {
    let theme: Theme
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 8) {
                HStack(spacing: 6) {
                    Circle()
                        .fill(theme.primaryAccentColor)
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(theme.secondaryAccentColor)
                        .frame(width: 16, height: 16)
                    Spacer()
                }

                Text(theme.name)
                    .font(.headline)
                    .foregroundColor(theme.primaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Text("Sample text")
                    .font(.caption)
                    .foregroundColor(theme.secondaryTextColor)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding()
            .background(theme.secondaryBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isSelected ? theme.primaryAccentColor : Color.clear, lineWidth: 2)
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Bundle Extension

extension Bundle {
    var appVersion: String? {
        infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

// MARK: - Preview

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(ThemeManager())
    }
}
