//
//  iOSAdaptivePopups.swift
//  PlannerApp
//
//  iOS-specific popup enhancements and adaptive sizing
//

import SwiftUI

// MARK: - iOS Adaptive View Modifiers

extension View {
    /// Apply iOS-specific popup optimizations including presentation styles and sizing
    func iOSPopupOptimizations() -> some View {
        #if os(iOS)
            self
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
                .interactiveDismissDisabled(false)
        #else
            self
        #endif
    }

    /// Apply adaptive sizing based on device
    func adaptiveFrameSize() -> some View {
        #if os(iOS)
            self
                .frame(maxWidth: .infinity)
                .background(Color(.systemGroupedBackground))
        #else
            self
        #endif
    }

    /// Enhanced touch targets for iOS
    func iOSEnhancedTouchTarget() -> some View {
        #if os(iOS)
            self
                .frame(minWidth: 44, minHeight: 44)
                .contentShape(Rectangle())
        #else
            self
        #endif
    }

    /// iOS-specific keyboard management
    func iOSKeyboardDismiss() -> some View {
        #if os(iOS)
            self
                .onTapGesture {
                    // Dismiss keyboard when tapping outside
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                }
        #else
            self
        #endif
    }
}

// MARK: - iOS Device Type Detection

extension View {
    /// Apply iOS-specific device adaptations
    func adaptiveForIOSDevice() -> some View {
        #if os(iOS)
            Group {
                if UIDevice.current.userInterfaceIdiom == .pad {
                    // iPad optimizations
                    self
                        .frame(maxWidth: 600, maxHeight: 800)
                        .background(Color(.systemGroupedBackground))
                } else {
                    // iPhone optimizations
                    self
                        .frame(maxWidth: .infinity)
                        .background(Color(.systemGroupedBackground))
                }
            }
        #else
            self
        #endif
    }
}

// MARK: - iOS Haptic Feedback Helper

enum HapticManager {
    static func lightImpact() {
        #if os(iOS)
            let impactFeedback = UIImpactFeedbackGenerator(style: .light)
            impactFeedback.impactOccurred()
        #endif
    }

    static func mediumImpact() {
        #if os(iOS)
            let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
            impactFeedback.impactOccurred()
        #endif
    }

    static func selectionChanged() {
        #if os(iOS)
            let selectionFeedback = UISelectionFeedbackGenerator()
            selectionFeedback.selectionChanged()
        #endif
    }

    static func notificationSuccess() {
        #if os(iOS)
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.success)
        #endif
    }

    static func notificationError() {
        #if os(iOS)
            let notificationFeedback = UINotificationFeedbackGenerator()
            notificationFeedback.notificationOccurred(.error)
        #endif
    }
}

// MARK: - iOS-Optimized Form Field

struct iOSFormField<Content: View>: View {
    let label: String
    let content: Content

    init(_ label: String, @ViewBuilder content: () -> Content) {
        self.label = label
        self.content = content()
    }

    private var backgroundColor: Color {
        #if os(iOS)
            Color(.systemBackground)
        #else
            Color.clear
        #endif
    }

    private var strokeColor: Color {
        #if os(iOS)
            Color(.separator).opacity(0.3)
        #else
            Color.gray.opacity(0.3)
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)

            content
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(backgroundColor)
                .cornerRadius(10)
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(strokeColor, lineWidth: 1)
                )
        }
        .padding(.vertical, 4)
    }
}

// MARK: - iOS Button Styles

struct iOSPrimaryButton: ButtonStyle {
    let isDestructive: Bool

    init(isDestructive: Bool = false) {
        self.isDestructive = isDestructive
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body.weight(.semibold))
            .foregroundColor(isDestructive ? .red : .blue)
            .frame(minWidth: 60, minHeight: 44)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct iOSSecondaryButton: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.body)
            .foregroundColor(.primary)
            .frame(minWidth: 60, minHeight: 44)
            .contentShape(Rectangle())
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == iOSPrimaryButton {
    static var iOSPrimary: iOSPrimaryButton { iOSPrimaryButton() }
    static var iOSDestructive: iOSPrimaryButton { iOSPrimaryButton(isDestructive: true) }
}

extension ButtonStyle where Self == iOSSecondaryButton {
    static var iOSSecondary: iOSSecondaryButton { iOSSecondaryButton() }
}
