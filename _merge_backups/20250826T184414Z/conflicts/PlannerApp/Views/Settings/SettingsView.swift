// PlannerApp/Views/Settings/SettingsView.swift

import LocalAuthentication
import SwiftUI
import UserNotifications
#if os(macOS)
    import AppKit
#endif
import Foundation

struct SettingsView: View {
    @EnvironmentObject var themeManager: ThemeManager

    // State properties with AppStorage keys
    @AppStorage(AppSettingKeys.userName) private var userName: String = ""
    @AppStorage(AppSettingKeys.dashboardItemLimit) private var dashboardItemLimit: Int = 3
    @AppStorage(AppSettingKeys.notificationsEnabled) private var notificationsEnabled: Bool = true
    @AppStorage(AppSettingKeys.use24HourTime) private var use24HourTime: Bool = false
    @AppStorage(AppSettingKeys.autoDeleteCompleted) private var autoDeleteCompleted: Bool = false
    @AppStorage(AppSettingKeys.autoSyncEnabled) private var autoSyncEnabled: Bool = true

    // State for managing UI elements
    @State private var showingNotificationAlert = false
    @State private var showingThemePreview = false

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
                    Toggle("Enable Notifications", isOn: $notificationsEnabled)
                        .onChange(of: notificationsEnabled) { _, newValue in
                            if newValue {
                                requestNotificationPermission()
                            }
                        }
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)

                // General Settings Section
                Section("General") {
                    Toggle("24-Hour Time", isOn: $use24HourTime)
                    Toggle("Auto-delete Completed Tasks", isOn: $autoDeleteCompleted)
                    Toggle("Auto Sync", isOn: $autoSyncEnabled)
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)
            }
            .navigationTitle("Settings")
            .background(themeManager.currentTheme.primaryBackgroundColor)
            .scrollContentBackground(.hidden)
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
        }
    }

    // MARK: - Helper Methods

    private func requestNotificationPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { granted, _ in
            DispatchQueue.main.async {
                if !granted {
                    showingNotificationAlert = true
                }
            }
        }
    }

    private func openAppSettings() {
        #if os(macOS)
            NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Notifications")!)
        #else
            UIApplication.shared.open(URL(string: UIApplication.openSettingsURLString)!)
        #endif
    }
}

// MARK: - Theme Preview Sheet

struct ThemePreviewSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150)),
                ], spacing: 16) {
                    ForEach(Theme.availableThemes, id: \.name) { theme in
                        ThemeCard(theme: theme)
                            .environmentObject(themeManager)
                    }
                }
                .padding()
            }
            .navigationTitle("Choose Theme")
            #if os(iOS)
                .navigationBarTitleDisplayMode(.inline)
            #endif
                .toolbar {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
        .background(themeManager.currentTheme.primaryBackgroundColor)
    }
}

// MARK: - Theme Card

struct ThemeCard: View {
    let theme: Theme
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(spacing: 12) {
            // Theme preview
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.primaryBackgroundColor)
                .overlay(
                    VStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.secondaryBackgroundColor)
                            .frame(height: 40)
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(theme.primaryAccentColor)
                                    .frame(width: 60, height: 20)
                            )

                        HStack(spacing: 4) {
                            Circle()
                                .fill(theme.primaryAccentColor)
                                .frame(width: 12, height: 12)
                            Circle()
                                .fill(theme.secondaryTextColor)
                                .frame(width: 12, height: 12)
                            Circle()
                                .fill(theme.primaryTextColor.opacity(0.3))
                                .frame(width: 12, height: 12)
                        }
                    }
                    .padding(12)
                )
                .frame(height: 100)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(
                            themeManager.currentTheme.name == theme.name ?
                                theme.primaryAccentColor : Color.clear,
                            lineWidth: 2
                        )
                )

            // Theme name
            Text(theme.name)
                .font(.caption)
                .fontWeight(.medium)
                .foregroundColor(themeManager.currentTheme.primaryTextColor)
        }
        .onTapGesture {
            themeManager.currentThemeName = theme.name
        }
    }
}

struct SettingsView_Previews: PreviewProvider {
    static var previews: some View {
        SettingsView()
            .environmentObject(ThemeManager())
    }
}
