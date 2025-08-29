// PlannerApp/Styling/ThemeManager.swift

import SwiftUI
import Combine
import Foundation

// Include Theme from the same Styling directory
// Include AppSettingKeys from Utilities directory

class ThemeManager: ObservableObject {

    // Published property holding the currently active theme. Views observe this.
    // Initialize by finding the theme matching the name currently stored in UserDefaults.
    @Published var currentTheme: Theme = Theme.availableThemes.first {
        $0.name == UserDefaults.standard.string(forKey: AppSettingKeys.themeColorName)
    } ?? Theme.defaultTheme // Fallback to default theme if no match or nothing saved

    // Monitors UserDefaults for changes to the theme name setting.
    // When the value in UserDefaults changes (e.g., via the Picker in SettingsView),
    // the `didSet` observer calls `updateCurrentTheme`.
    @AppStorage(AppSettingKeys.themeColorName) var currentThemeName: String = Theme.defaultTheme.name {
        didSet {
            updateCurrentTheme()
        }
    }

    init() {
        // Initial theme is set by the @Published property initializer above.
        // This ensures the theme is correct even before `selectedThemeName.didSet` is first called.
        print("ThemeManager initialized. Current theme loaded: \(currentTheme.name)")
    }

    // Finds the Theme struct corresponding to the name stored in `currentThemeName`
    // and updates the `currentTheme` published property if it has changed.
    private func updateCurrentTheme() {
        // Find the theme matching the name stored in `currentThemeName`.
        let newTheme = Theme.availableThemes.first { $0.name == currentThemeName } ?? Theme.defaultTheme

        // Only update the published property if the theme actually changed.
        // This prevents unnecessary UI refreshes if the picker selects the current theme again.
        if newTheme != self.currentTheme {
            self.currentTheme = newTheme
            print("Theme updated to: \(self.currentTheme.name)") // For debugging
        }
    }

    // Static computed property to easily get the names of available themes,
    // useful for populating Pickers in the UI.
    static var availableThemeNames: [String] {
        Theme.availableThemes.map { $0.name }
    }
    
    // Manually set a theme (used by ThemePreviewView)
    func setTheme(_ theme: Theme) {
        currentThemeName = theme.name
        // The didSet observer will trigger updateCurrentTheme automatically
    }
}
