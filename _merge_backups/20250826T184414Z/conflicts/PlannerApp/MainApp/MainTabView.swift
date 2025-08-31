// PlannerApp/MainApp/MainTabView.swift (Updated)
import SwiftUI
#if os(macOS)
    import AppKit
#else
    import UIKit
#endif

struct MainTabView: View {
    // Access the shared ThemeManager instance from the environment.
    @EnvironmentObject var themeManager: ThemeManager
    // Receive the binding for the selected tab tag from the parent view (PlannerApp).
    // Changes to this binding will update the currently visible tab.
    @Binding var selectedTabTag: String

    // Define constants or an enum for tab tags to avoid string typos.
    enum TabTags {
        static let dashboard = "Dashboard"
        static let tasks = "Tasks"
        static let calendar = "Calendar"
        static let goals = "Goals"
        static let journal = "Journal"
        static let settings = "Settings"
    }

    var body: some View {
        // TabView container. The `selection` parameter is bound to `selectedTabTag`.
        TabView(selection: $selectedTabTag) {
            // --- Dashboard Tab ---
            DashboardView()
                .tabItem { Label(TabTags.dashboard, systemImage: "house") } // Text and icon for the tab item
                .tag(TabTags.dashboard) // Assign a unique tag to identify this tab

            // --- Tasks Tab ---
            TaskManagerView()
                .tabItem { Label(TabTags.tasks, systemImage: "checkmark.square") }
                .tag(TabTags.tasks)

            // --- Calendar Tab ---
            CalendarView()
                .tabItem { Label(TabTags.calendar, systemImage: "calendar") }
                .tag(TabTags.calendar)

            // --- Goals Tab ---
            GoalsView()
                .tabItem { Label(TabTags.goals, systemImage: "target") }
                .tag(TabTags.goals)

            // --- Journal Tab ---
            JournalView() // Consider adding biometric check wrapper here if enabled
                .tabItem { Label(TabTags.journal, systemImage: "book") }
                .tag(TabTags.journal)

            // --- Settings Tab ---
            SettingsView()
                .tabItem { Label(TabTags.settings, systemImage: "gear") }
                .tag(TabTags.settings)
        }
        // Apply the theme's primary accent color to the selected tab item's icon and text tint.
        .accentColor(themeManager.currentTheme.primaryAccentColor)
        // Attempt to influence the appearance of unselected tabs by setting the color scheme.
        // This is an indirect way, as direct styling of unselected items is limited.
        // It tells SwiftUI whether the overall view context is light or dark.
        .environment(\.colorScheme, themeManager.currentTheme.primaryBackgroundColor.isDark() ? .dark : .light)
        #if os(macOS)
            // Ensure full window utilization on macOS
            .frame(minWidth: 800, minHeight: 600)
        #endif
    }
}

// Helper extension to determine if a Color is perceived as dark.
// Used to adjust the color scheme for tab items.
extension Color {
    func isDark() -> Bool {
        #if os(macOS)
            // For macOS, we'll use NSColor to determine if a color is dark
            let nsColor = NSColor(self)
            let colorSpace = NSColorSpace.deviceRGB
            guard let convertedColor = nsColor.usingColorSpace(colorSpace) else { return false }

            let red = convertedColor.redComponent
            let green = convertedColor.greenComponent
            let blue = convertedColor.blueComponent

            // Calculate luminance using standard coefficients.
            let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            // Consider the color dark if luminance is below a threshold (e.g., 0.5).
            return luminance < 0.5
        #else
            // For iOS/iPadOS, we'll use UIColor to determine if a color is dark
            let uiColor = UIColor(self)
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0

            uiColor.getRed(&red, green: &green, blue: &blue, alpha: &alpha)

            // Calculate luminance using standard coefficients.
            let luminance = 0.2126 * red + 0.7152 * green + 0.0722 * blue
            // Consider the color dark if luminance is below a threshold (e.g., 0.5).
            return luminance < 0.5
        #endif
    }
}

// Preview Provider for MainTabView
struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        // Provide a constant binding for the preview (doesn't change).
        MainTabView(selectedTabTag: .constant(MainTabView.TabTags.dashboard))
            // Provide the ThemeManager environment object for the preview.
            .environmentObject(ThemeManager())
    }
}
