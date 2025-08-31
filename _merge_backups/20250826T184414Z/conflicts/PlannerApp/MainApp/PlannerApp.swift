// PlannerApp/MainApp/PlannerApp.swift (Updated)
import Foundation
import SwiftUI

@main
struct PlannerApp: App {
    // Create and keep alive a single instance of ThemeManager for the entire app.
    // @StateObject ensures it persists throughout the app's lifecycle.
    @StateObject private var themeManager = ThemeManager()

    // State variable to hold the tag of the currently selected tab.
    // This is needed to programmatically set the initial tab based on user settings.
    @State private var selectedTabTag: String

    // Custom initializer to read the default view setting from UserDefaults
    // *before* the main body view is created. This ensures the correct tab
    // is selected right from the start.
    init() {
        // Read the saved default view identifier from UserDefaults.
        let initialTab = UserDefaults.standard.string(forKey: AppSettingKeys.defaultView)
            // Use the Dashboard tag as a fallback if nothing is saved.
            ?? MainTabView.TabTags.dashboard
        // Initialize the @State variable with the value read from UserDefaults.
        // The underscore syntax is used here because we are initializing the State wrapper itself.
        _selectedTabTag = State(initialValue: initialTab)
        print("App starting. Initial tab set to: \(initialTab)") // Debugging log
    }

    var body: some Scene {
        WindowGroup {
            // Apply the primary background color from the current theme to the entire window group.
            themeManager.currentTheme.primaryBackgroundColor
                .ignoresSafeArea()
                .overlay(
                    // Use enhanced navigation for better cross-platform UX
                    MainTabView(selectedTabTag: $selectedTabTag)
                )
                .environmentObject(themeManager)
        }
        #if os(macOS)
        .windowStyle(.hiddenTitleBar)
        .windowToolbarStyle(.unified)
        #endif
    }
}
