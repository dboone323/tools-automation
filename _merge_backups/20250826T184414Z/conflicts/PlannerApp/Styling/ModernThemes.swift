//
//  ModernThemes.swift
//  PlannerApp
//
//  Enhanced modern themes with gradient support and better visual hierarchy
//

import SwiftUI

extension Theme {
    // MARK: - Modern Enhanced Themes

    // Modern productivity theme with better contrast
    static let productivityPro = Theme(
        name: "Productivity Pro",
        primaryAccentColor: Color(red: 0.17, green: 0.35, blue: 0.63), // Professional Blue
        secondaryAccentColor: Color(red: 0.42, green: 0.48, blue: 0.50), // Neutral Gray
        primaryBackgroundColor: Color(red: 0.98, green: 0.98, blue: 0.99),
        secondaryBackgroundColor: Color(red: 0.94, green: 0.95, blue: 0.96),
        primaryTextColor: Color(red: 0.13, green: 0.13, blue: 0.15),
        secondaryTextColor: Color(red: 0.45, green: 0.45, blue: 0.47),
        destructiveColor: Color(red: 0.85, green: 0.30, blue: 0.30),
        completedColor: Color(red: 0.16, green: 0.62, blue: 0.56), // Teal
        primaryFontName: nil,
        secondaryFontName: nil
    )

    // Nature-inspired theme with warm colors
    static let natureInspired = Theme(
        name: "Nature Inspired",
        primaryAccentColor: Color(red: 0.18, green: 0.31, blue: 0.09), // Forest Green
        secondaryAccentColor: Color(red: 0.41, green: 0.69, blue: 0.67), // Sage
        primaryBackgroundColor: Color(red: 0.99, green: 0.98, blue: 0.96), // Cream
        secondaryBackgroundColor: Color(red: 0.96, green: 0.94, blue: 0.91),
        primaryTextColor: Color(red: 0.15, green: 0.20, blue: 0.10),
        secondaryTextColor: Color(red: 0.45, green: 0.50, blue: 0.40),
        destructiveColor: Color(red: 0.80, green: 0.35, blue: 0.25),
        completedColor: Color(red: 0.26, green: 0.67, blue: 0.55), // Mint
        primaryFontName: nil,
        secondaryFontName: nil
    )

    // High contrast theme for better accessibility
    static let highContrast = Theme(
        name: "High Contrast",
        primaryAccentColor: Color(red: 0.0, green: 0.0, blue: 1.0), // Pure Blue
        secondaryAccentColor: Color(red: 0.0, green: 0.0, blue: 0.0), // Black
        primaryBackgroundColor: Color.white,
        secondaryBackgroundColor: Color(red: 0.95, green: 0.95, blue: 0.95),
        primaryTextColor: Color.black,
        secondaryTextColor: Color(red: 0.3, green: 0.3, blue: 0.3),
        destructiveColor: Color.red,
        completedColor: Color(red: 0.0, green: 0.8, blue: 0.0),
        primaryFontName: nil,
        secondaryFontName: nil
    )

    // Modern gradient theme
    static let modernGradient = Theme(
        name: "Modern Gradient",
        primaryAccentColor: Color(red: 0.38, green: 0.42, blue: 0.98), // iOS Blue
        secondaryAccentColor: Color(red: 0.35, green: 0.34, blue: 0.84), // Purple
        primaryBackgroundColor: Color(red: 0.99, green: 0.99, blue: 1.0),
        secondaryBackgroundColor: Color(red: 0.96, green: 0.97, blue: 0.99),
        primaryTextColor: Color(red: 0.11, green: 0.11, blue: 0.12),
        secondaryTextColor: Color(red: 0.43, green: 0.43, blue: 0.45),
        destructiveColor: Color(red: 1.0, green: 0.23, blue: 0.19), // iOS Red
        completedColor: Color(red: 0.19, green: 0.82, blue: 0.35), // iOS Green
        primaryFontName: nil,
        secondaryFontName: nil
    )

    // Updated list including new themes
    static let allAvailableThemes: [Theme] = [
        defaultTheme,
        productivityPro,
        natureInspired,
        modernGradient,
        oceanBlue,
        forestGreen,
        sunsetOrange,
        midnightDark,
        highContrast,
        minimalGray,
        rosePink,
    ]
}

// MARK: - Gradient Support Extensions

extension Color {
    // Create gradient colors for modern effects
    static func gradient(from startColor: Color, to endColor: Color) -> LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: [startColor, endColor]),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    // Glass morphism effect
    var glassMorphism: some View {
        self.opacity(0.7)
            .background(.ultraThinMaterial)
    }
}

// MARK: - Modern Card with Gradient Support

struct GradientCard<Content: View>: View {
    let content: Content
    @EnvironmentObject var themeManager: ThemeManager

    var useGradient: Bool = false

    init(useGradient: Bool = false, @ViewBuilder content: () -> Content) {
        self.useGradient = useGradient
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .background(
                Group {
                    if useGradient {
                        Color.gradient(
                            from: themeManager.currentTheme.primaryAccentColor.opacity(0.1),
                            to: themeManager.currentTheme.secondaryAccentColor.opacity(0.05)
                        )
                    } else {
                        themeManager.currentTheme.secondaryBackgroundColor
                    }
                }
            )
            .cornerRadius(16)
            .shadow(
                color: themeManager.currentTheme.primaryAccentColor.opacity(0.1),
                radius: 8,
                x: 0,
                y: 4
            )
    }
}
