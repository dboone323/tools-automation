// PlannerApp/Views/Settings/SettingsView.swift
// Simplified version for compilation

import SwiftUI
import UserNotifications
import LocalAuthentication
#if os(macOS)
import AppKit
#endif
import Foundation

struct SettingsView: View {
    // Environment Object to access the shared ThemeManager instance
    @EnvironmentObject var themeManager: ThemeManager

    // --- AppStorage properties to bind UI controls directly to UserDefaults ---
    @AppStorage(AppSettingKeys.userName) private var userName: String = ""
    @AppStorage(AppSettingKeys.dashboardItemLimit) private var dashboardItemLimit: Int = 3
    @AppStorage(AppSettingKeys.themeColorName) private var selectedThemeName: String = Theme.defaultTheme.name

    // Notification Settings
    @AppStorage(AppSettingKeys.notificationsEnabled) private var notificationsEnabled: Bool = true
    @AppStorage(AppSettingKeys.defaultReminderTime) private var defaultReminderTime: Double = 3600

    // Date & Time Settings
    @AppStorage(AppSettingKeys.firstDayOfWeek) private var firstDayOfWeek: Int = Calendar.current.firstWeekday
    @AppStorage(AppSettingKeys.use24HourTime) private var use24HourTime: Bool = false

    // App Behavior Settings
    @AppStorage(AppSettingKeys.autoDeleteCompleted) private var autoDeleteCompleted: Bool = false
    @AppStorage(AppSettingKeys.autoDeleteDays) private var autoDeleteDays: Int = 30
    @AppStorage(AppSettingKeys.defaultView) private var defaultView: String = "Dashboard"

    // Journal Security
    @AppStorage(AppSettingKeys.journalBiometricsEnabled) private var journalBiometricsEnabled: Bool = false
    
    // Additional settings
    @AppStorage(AppSettingKeys.autoSyncEnabled) private var autoSyncEnabled: Bool = true
    @AppStorage(AppSettingKeys.syncFrequency) private var syncFrequency: String = "hourly"
    @AppStorage(AppSettingKeys.enableHapticFeedback) private var enableHapticFeedback: Bool = true
    @AppStorage(AppSettingKeys.enableAnalytics) private var enableAnalytics: Bool = false

    // --- State for managing UI elements ---
    @State private var showingNotificationAlert = false
    @State private var showingClearDataConfirmation = false
    @State private var showingExportShareSheet = false
    @State private var exportURL: URL?
    @State private var showingCloudKitSheet = false
    @State private var showingThemePreview = false

    // --- Options for Pickers ---
    let reminderTimeOptions: [String: Double] = [
        "None": 0, "At time of event": 1, "5 minutes before": 300,
        "15 minutes before": 900, "30 minutes before": 1800, "1 hour before": 3600,
        "1 day before": 86400
    ]
    
    var sortedReminderKeys: [String] {
        reminderTimeOptions.keys.sorted { reminderTimeOptions[$0]! < reminderTimeOptions[$1]! }
    }
    
    let defaultViewOptions = ["Dashboard", "Tasks", "Calendar", "Goals", "Journal"]

    // --- Biometric Check ---
    var canUseBiometrics: Bool {
        let context = LAContext()
        var error: NSError?
        return context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error)
    }

    var body: some View {
        NavigationStack {
            Form {
                // --- Profile Section ---
                Section("Profile") {
                    HStack {
                        Text("Name")
                            .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                        TextField("Enter your name", text: $userName)
                            .multilineTextAlignment(.trailing)
                            .foregroundColor(themeManager.currentTheme.primaryTextColor)
                    }
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // --- Appearance Section ---
                Section("Appearance") {
                    Picker("Theme", selection: $selectedThemeName) {
                        ForEach(ThemeManager.availableThemeNames, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    
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
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // --- Dashboard Section ---
                Section("Dashboard") {
                    Stepper("Items per section: \\(dashboardItemLimit)", value: $dashboardItemLimit, in: 1...10)
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // --- Notifications Section ---
                Section("Notifications") {
                    Toggle("Enable Reminders", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, newValue in
                            handleNotificationToggle(enabled: newValue)
                        }
                        .alert("Notification Permissions", isPresented: $showingNotificationAlert, actions: notificationAlertActions)

                    Picker("Default Reminder", selection: $defaultReminderTime) {
                        ForEach(sortedReminderKeys, id: \.self) { key in
                            Text(key).tag(reminderTimeOptions[key]!)
                        }
                    }
                    .disabled(!notificationsEnabled)
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // --- Date & Time Section ---
                Section("Date & Time") {
                    Picker("First Day of Week", selection: $firstDayOfWeek) {
                        Text("System Default").tag(Calendar.current.firstWeekday)
                        Text("Sunday").tag(1)
                        Text("Monday").tag(2)
                    }

                    Toggle("Use 24-Hour Time", isOn: $use24HourTime)
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // --- App Behavior Section ---
                Section("App Behavior") {
                    Picker("Default View on Launch", selection: $defaultView) {
                        ForEach(defaultViewOptions, id: \.self) { viewName in
                            Text(viewName).tag(viewName)
                        }
                    }

                    Toggle("Auto-Delete Completed Tasks", isOn: $autoDeleteCompleted)
                    
                    if autoDeleteCompleted {
                        Stepper("Delete after: \\(autoDeleteDays) days", value: $autoDeleteDays, in: 1...90)
                    }
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // --- Security Section ---
                Section("Security") {
                    if canUseBiometrics {
                        Toggle("Protect Journal with Biometrics", isOn: $journalBiometricsEnabled)
                    } else {
                        Text("Biometric authentication not available on this device.")
                            .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                    }
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // --- Sync & Cloud Section ---
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

                // --- Enhanced Features Section ---
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

                // --- Data Management Section ---
                Section("Data Management") {
                    Button("Export Data", action: exportData)
                        .foregroundColor(themeManager.currentTheme.primaryAccentColor)

                    Button("Clear Old Completed Tasks...", action: { showingClearDataConfirmation = true })
                        .foregroundColor(themeManager.currentTheme.destructiveColor)
                        .alert("Confirm Deletion", isPresented: $showingClearDataConfirmation) {
                            Button("Delete", role: .destructive, action: performClearOldData)
                            Button("Cancel", role: .cancel) {}
                        } message: {
                            Text("Are you sure you want to permanently delete completed tasks older than \\(autoDeleteDays) days? This cannot be undone.")
                        }
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // --- About Section ---
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
            // Simplified sheet presentations
            .sheet(isPresented: $showingCloudKitSheet) {
                // Placeholder for CloudKit sync view
                VStack {
                    Text("CloudKit Sync")
                        .font(.title)
                        .padding()
                    Text("CloudKit integration coming soon...")
                        .foregroundColor(.secondary)
                    Button("Done") {
                        showingCloudKitSheet = false
                    }
                    .padding()
                }
                .frame(minWidth: 400, minHeight: 300)
            }
            .sheet(isPresented: $showingThemePreview) {
                // Placeholder for theme preview
                VStack {
                    Text("Theme Preview")
                        .font(.title)
                        .padding()
                    Text("Theme preview coming soon...")
                        .foregroundColor(.secondary)
                    Button("Done") {
                        showingThemePreview = false
                    }
                    .padding()
                }
                .frame(minWidth: 400, minHeight: 300)
            }
        }
        .accentColor(themeManager.currentTheme.primaryAccentColor)
    }

    // --- Action Handlers ---
    func handleNotificationToggle(enabled: Bool) {
        if enabled {
            requestNotificationPermission()
        }
        print("Notification toggle changed: \\(enabled)")
    }

    @ViewBuilder
    func notificationAlertActions() -> some View {
        Button("Open Settings", action: openAppSettings)
        Button("Cancel", role: .cancel) {}
    }

    func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, error in
            DispatchQueue.main.async {
                if !granted {
                    self.showingNotificationAlert = true
                    self.notificationsEnabled = false
                }
                if let error = error {
                    print("Notification permission error: \\(error.localizedDescription)")
                    self.notificationsEnabled = false
                }
            }
        }
    }

    func openAppSettings() {
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Notifications") else {
            print("Cannot open system preferences URL.")
            return
        }
        NSWorkspace.shared.open(url)
    }

    func exportData() {
        print("Export Data action triggered")
        // Simplified export for now
        let csvString = "Type,ID,Title\\nSample,1,Test Data\\n"
        guard let data = csvString.data(using: .utf8) else {
            print("Failed to generate export data")
            return
        }

        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent("PlannerExport.csv")
        do {
            try data.write(to: tempURL, options: .atomic)
            self.exportURL = tempURL
            self.showingExportShareSheet = true
            print("Export file created at: \\(tempURL)")
        } catch {
            print("Failed to write export file: \\(error)")
        }
    }

    func performClearOldData() {
        print("Performing clear old data...")
        // Simplified clear function for now
        print("Clear old data functionality needs TaskDataManager integration")
    }
}

// --- Helper extension for getting App Version ---
extension Bundle {
    var appVersion: String? {
        self.infoDictionary?["CFBundleShortVersionString"] as? String
    }
}

#Preview {
    SettingsView()
        .environmentObject(ThemeManager())
}
