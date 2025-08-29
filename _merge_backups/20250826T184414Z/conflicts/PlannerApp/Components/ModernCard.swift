//
//  ModernCard.swift
//  PlannerApp
//
//  Enhanced card component for better visual design
//

import SwiftUI

struct ModernCard<Content: View>: View {
    let content: Content
    @EnvironmentObject var themeManager: ThemeManager
    
    var shadowRadius: CGFloat = 8
    var cornerRadius: CGFloat = 16
    var padding: CGFloat = 16
    
    init(
        shadowRadius: CGFloat = 8,
        cornerRadius: CGFloat = 16,
        padding: CGFloat = 16,
        @ViewBuilder content: () -> Content
    ) {
        self.shadowRadius = shadowRadius
        self.cornerRadius = cornerRadius
        self.padding = padding
        self.content = content()
    }
    
    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(themeManager.currentTheme.secondaryBackgroundColor)
                    .shadow(
                        color: Color.black.opacity(0.08),
                        radius: shadowRadius,
                        x: 0,
                        y: 2
                    )
            )
    }
}

struct ModernButton: View {
    let title: String
    let action: () -> Void
    @EnvironmentObject var themeManager: ThemeManager
    
    var style: ButtonStyle = .primary
    var size: ButtonSize = .medium
    var isDestructive: Bool = false
    var isDisabled: Bool = false
    
    enum ButtonStyle {
        case primary, secondary, tertiary
    }
    
    enum ButtonSize {
        case small, medium, large
        
        var height: CGFloat {
            switch self {
            case .small: return 32
            case .medium: return 44
            case .large: return 56
            }
        }
        
        var fontSize: CGFloat {
            switch self {
            case .small: return 14
            case .medium: return 16
            case .large: return 18
            }
        }
        
        var padding: CGFloat {
            switch self {
            case .small: return 12
            case .medium: return 16
            case .large: return 20
            }
        }
    }
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: size.fontSize, weight: .medium))
                .foregroundColor(textColor)
                .frame(maxWidth: .infinity)
                .frame(height: size.height)
                .padding(.horizontal, size.padding)
        }
        .background(backgroundColor)
        .cornerRadius(12)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.6 : 1.0)
    }
    
    private var backgroundColor: Color {
        if isDisabled {
            return themeManager.currentTheme.secondaryTextColor.opacity(0.3)
        }
        
        if isDestructive {
            return themeManager.currentTheme.destructiveColor
        }
        
        switch style {
        case .primary:
            return themeManager.currentTheme.primaryAccentColor
        case .secondary:
            return themeManager.currentTheme.secondaryAccentColor
        case .tertiary:
            return Color.clear
        }
    }
    
    private var textColor: Color {
        if isDestructive || style == .primary {
            return Color.white
        }
        
        switch style {
        case .secondary:
            return themeManager.currentTheme.primaryTextColor
        case .tertiary:
            return themeManager.currentTheme.primaryAccentColor
        default:
            return Color.white
        }
    }
}

// Progress indicator component
struct ProgressBar: View {
    let progress: Double // 0.0 to 1.0
    @EnvironmentObject var themeManager: ThemeManager
    
    var height: CGFloat = 8
    var showPercentage: Bool = false
    
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if showPercentage {
                HStack {
                    Spacer()
                    Text("\(Int(progress * 100))%")
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                }
            }
            
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(themeManager.currentTheme.secondaryAccentColor.opacity(0.3))
                        .frame(height: height)
                    
                    RoundedRectangle(cornerRadius: height / 2)
                        .fill(themeManager.currentTheme.primaryAccentColor)
                        .frame(width: geometry.size.width * CGFloat(progress), height: height)
                        .animation(.easeInOut(duration: 0.3), value: progress)
                }
            }
            .frame(height: height)
        }
    }
}

// Enhanced input field
struct ModernTextField: View {
    @Binding var text: String
    let placeholder: String
    @EnvironmentObject var themeManager: ThemeManager
    
    var isSecure: Bool = false
    #if os(iOS)
    var keyboardType: UIKeyboardType = .default
    #endif
    
    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
                    #if os(iOS)
                    .keyboardType(keyboardType)
                    #endif
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(themeManager.currentTheme.secondaryBackgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(themeManager.currentTheme.secondaryAccentColor.opacity(0.3), lineWidth: 1)
                )
        )
        .foregroundColor(themeManager.currentTheme.primaryTextColor)
    }
}

#Preview {
    VStack(spacing: 20) {
        ModernCard {
            VStack(alignment: .leading) {
                Text("Sample Card")
                    .font(.headline)
                Text("This is a sample card with modern styling")
                    .font(.subheadline)
            }
        }
        
        ModernButton(title: "Primary Button") {}
        
        ModernButton(title: "Secondary Button") {}
            .onAppear {
                // Can't directly modify in preview, but showing usage
            }
        
        ProgressBar(progress: 0.7, showPercentage: true)
        
        ModernTextField(text: Binding.constant(""), placeholder: "Enter text")
    }
    .padding()
    .environmentObject(ThemeManager())
}
