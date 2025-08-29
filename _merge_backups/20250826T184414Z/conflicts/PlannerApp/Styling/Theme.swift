//
//  Theme.swift
//  PlannerApp
//
//  Created by Daniel Stevens on 4/29/25.
//


// PlannerApp/Styling/Theme.swift
// (Create a new folder Styling if it doesn't exist)

import SwiftUI
#if os(macOS)
import AppKit
#else
import UIKit
#endif

// Defines the properties of a visual theme
struct Theme: Identifiable, Equatable { // Added Equatable for comparison
    let id = UUID()
    let name: String

    // --- Colors ---
    let primaryAccentColor: Color // Main interactive color (buttons, toggles)
    let secondaryAccentColor: Color // Subtle accents, secondary info
    let primaryBackgroundColor: Color // Main background for views
    let secondaryBackgroundColor: Color // Background for cards, sections, List rows
    let primaryTextColor: Color // Main text color
    let secondaryTextColor: Color // Subtitles, secondary info text
    let destructiveColor: Color // For delete buttons etc.
    let completedColor: Color // Color for completed items (e.g., tasks)

    // --- Fonts ---
    // Using Font names. Ensure these fonts are available or load custom fonts.
    // If using custom fonts, ensure they are added to the project and Info.plist.
    let primaryFontName: String? // Use nil for system default
    let secondaryFontName: String? // Use nil for system default

    // Helper to get Font objects
    func font(forName name: String?, size: CGFloat, weight: Font.Weight = .regular) -> Font {
        if let fontName = name {
            // Attempt to load by name. Use correct PostScript names for custom fonts.
            return Font.custom(fontName, size: size).weight(weight)
        } else {
            // Return system font if no name provided
            return Font.system(size: size, weight: weight)
        }
    }

    // --- Predefined Themes ---

    static let defaultTheme = Theme(
        name: "Default",
        primaryAccentColor: Color.accentColor, // Use the system/asset catalog accent
        secondaryAccentColor: Color.gray,
        primaryBackgroundColor: defaultPrimaryBackgroundColor,
        secondaryBackgroundColor: defaultSecondaryBackgroundColor,
        primaryTextColor: defaultPrimaryTextColor,
        secondaryTextColor: defaultSecondaryTextColor,
        destructiveColor: Color.red,
        completedColor: Color.green,
        primaryFontName: nil, // System default
        secondaryFontName: nil // System default
    )
    
    // Platform-specific default colors
    private static var defaultPrimaryBackgroundColor: Color {
        #if os(macOS)
        return Color(nsColor: .windowBackgroundColor)
        #else
        return Color(UIColor.systemBackground)
        #endif
    }
    
    private static var defaultSecondaryBackgroundColor: Color {
        #if os(macOS)
        return Color(nsColor: .controlBackgroundColor)
        #else
        return Color(UIColor.secondarySystemBackground)
        #endif
    }
    
    private static var defaultPrimaryTextColor: Color {
        #if os(macOS)
        return Color(nsColor: .labelColor)
        #else
        return Color(UIColor.label)
        #endif
    }
    
    private static var defaultSecondaryTextColor: Color {
        #if os(macOS)
        return Color(nsColor: .secondaryLabelColor)
        #else
        return Color(UIColor.secondaryLabel)
        #endif
    }

    static let oceanBlue = Theme(
        name: "Ocean Blue",
        primaryAccentColor: Color(red: 0.0, green: 0.48, blue: 0.87), // Modern blue
        secondaryAccentColor: Color(red: 0.35, green: 0.68, blue: 0.95),
        primaryBackgroundColor: Color(red: 0.97, green: 0.98, blue: 1.0),
        secondaryBackgroundColor: Color(red: 0.92, green: 0.95, blue: 0.98),
        primaryTextColor: Color(red: 0.13, green: 0.13, blue: 0.18),
        secondaryTextColor: Color(red: 0.45, green: 0.45, blue: 0.52),
        destructiveColor: Color(red: 0.85, green: 0.35, blue: 0.35),
        completedColor: Color(red: 0.20, green: 0.72, blue: 0.42),
        primaryFontName: nil, // Use system font for better accessibility
        secondaryFontName: nil
    )

    static let forestGreen = Theme(
        name: "Forest Green",
        primaryAccentColor: Color(red: 0.20, green: 0.65, blue: 0.35), // Natural green
        secondaryAccentColor: Color(red: 0.50, green: 0.80, blue: 0.55),
        primaryBackgroundColor: Color(red: 0.98, green: 0.99, blue: 0.97),
        secondaryBackgroundColor: Color(red: 0.94, green: 0.97, blue: 0.92),
        primaryTextColor: Color(red: 0.13, green: 0.18, blue: 0.13),
        secondaryTextColor: Color(red: 0.45, green: 0.52, blue: 0.45),
        destructiveColor: Color(red: 0.82, green: 0.40, blue: 0.35),
        completedColor: Color(red: 0.15, green: 0.70, blue: 0.30),
        primaryFontName: nil,
        secondaryFontName: nil
    )

     static let sunsetOrange = Theme(
        name: "Sunset Orange",
        primaryAccentColor: Color(red: 0.90, green: 0.50, blue: 0.15), // Warm orange
        secondaryAccentColor: Color(red: 0.95, green: 0.70, blue: 0.40),
        primaryBackgroundColor: Color(red: 0.99, green: 0.97, blue: 0.94),
        secondaryBackgroundColor: Color(red: 0.96, green: 0.93, blue: 0.88),
        primaryTextColor: Color(red: 0.20, green: 0.15, blue: 0.10),
        secondaryTextColor: Color(red: 0.45, green: 0.35, blue: 0.25),
        destructiveColor: Color(red: 0.80, green: 0.25, blue: 0.20),
        completedColor: Color(red: 0.25, green: 0.70, blue: 0.35),
        primaryFontName: nil,
        secondaryFontName: nil
    )

    // Add a Dark Mode Theme Example
    static let midnightDark = Theme(
        name: "Midnight Dark",
        primaryAccentColor: Color(red: 0.7, green: 0.5, blue: 1.0), // Purple accent
        secondaryAccentColor: Color(red: 0.4, green: 0.4, blue: 0.6),
        primaryBackgroundColor: Color(red: 0.1, green: 0.1, blue: 0.15), // Dark background
        secondaryBackgroundColor: Color(red: 0.18, green: 0.18, blue: 0.25), // Slightly lighter dark
        primaryTextColor: Color(red: 0.9, green: 0.9, blue: 0.95), // Light text
        secondaryTextColor: Color(red: 0.6, green: 0.6, blue: 0.7), // Lighter gray text
        destructiveColor: Color(red: 1.0, green: 0.4, blue: 0.4), // Brighter red
        completedColor: Color(red: 0.4, green: 0.8, blue: 0.4), // Brighter green
        primaryFontName: nil, // System default
        secondaryFontName: nil
    )

    // Modern minimal theme
    static let minimalGray = Theme(
        name: "Minimal Gray",
        primaryAccentColor: Color(red: 0.20, green: 0.20, blue: 0.20),
        secondaryAccentColor: Color(red: 0.50, green: 0.50, blue: 0.50),
        primaryBackgroundColor: Color(red: 0.99, green: 0.99, blue: 0.99),
        secondaryBackgroundColor: Color(red: 0.96, green: 0.96, blue: 0.96),
        primaryTextColor: Color(red: 0.15, green: 0.15, blue: 0.15),
        secondaryTextColor: Color(red: 0.55, green: 0.55, blue: 0.55),
        destructiveColor: Color(red: 0.85, green: 0.30, blue: 0.30),
        completedColor: Color(red: 0.30, green: 0.70, blue: 0.30),
        primaryFontName: nil,
        secondaryFontName: nil
    )

    // Warm pink theme for a softer feel
    static let rosePink = Theme(
        name: "Rose Pink",
        primaryAccentColor: Color(red: 0.85, green: 0.40, blue: 0.60),
        secondaryAccentColor: Color(red: 0.90, green: 0.65, blue: 0.75),
        primaryBackgroundColor: Color(red: 0.99, green: 0.96, blue: 0.97),
        secondaryBackgroundColor: Color(red: 0.96, green: 0.92, blue: 0.94),
        primaryTextColor: Color(red: 0.20, green: 0.15, blue: 0.20),
        secondaryTextColor: Color(red: 0.50, green: 0.40, blue: 0.50),
        destructiveColor: Color(red: 0.80, green: 0.35, blue: 0.35),
        completedColor: Color(red: 0.25, green: 0.70, blue: 0.40),
        primaryFontName: nil,
        secondaryFontName: nil
    )


    // List of all available themes for pickers etc.
    static let availableThemes: [Theme] = [
        defaultTheme,
        oceanBlue,
        forestGreen,
        sunsetOrange,
        midnightDark,
        minimalGray,
        rosePink
    ]
    
    // MARK: - Enhanced Modern Themes (defined in ModernThemes.swift)
    // These will be added via extension in ModernThemes.swift

    // Implement Equatable based on name to compare themes
    static func == (lhs: Theme, rhs: Theme) -> Bool {
        lhs.name == rhs.name
    }
}
