//
//  ThemePreviewView.swift
//  PlannerApp
//
//  Interactive theme preview and selection
//

import SwiftUI

struct ThemePreviewView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.presentationMode) var presentationMode
    @State private var selectedTheme: Theme = Theme.defaultTheme
    
    let sampleTasks = [
        "Complete project proposal",
        "Review quarterly reports", 
        "Schedule team meeting",
        "Update documentation"
    ]
    
    let sampleGoals = [
        "Read 12 books this year",
        "Exercise 3x per week",
        "Learn Swift programming"
    ]
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Theme Selection Grid
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                        ForEach(Theme.availableThemes, id: \.name) { theme in
                            ThemePreviewCard(
                                theme: theme,
                                isSelected: selectedTheme.name == theme.name
                            ) {
                                selectedTheme = theme
                                // Apply haptic feedback if enabled
                                #if os(iOS)
                                let impactFeedback = UIImpactFeedbackGenerator(style: .light)
                                impactFeedback.impactOccurred()
                                #endif
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Divider()
                        .padding(.horizontal)
                    
                    // Live Preview Section
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Preview")
                            .font(.title2.bold())
                            .foregroundColor(selectedTheme.primaryTextColor)
                            .padding(.horizontal)
                        
                        // Sample Dashboard Card
                        ModernCard {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Today's Tasks")
                                        .font(.headline)
                                        .foregroundColor(selectedTheme.primaryTextColor)
                                    Spacer()
                                    Text("4")
                                        .font(.title2.bold())
                                        .foregroundColor(selectedTheme.primaryAccentColor)
                                }
                                
                                ForEach(sampleTasks.prefix(3), id: \.self) { task in
                                    HStack {
                                        Image(systemName: "circle")
                                            .foregroundColor(selectedTheme.secondaryAccentColor)
                                        Text(task)
                                            .font(.body)
                                            .foregroundColor(selectedTheme.primaryTextColor)
                                        Spacer()
                                    }
                                }
                                
                                ProgressBar(progress: 0.6, showPercentage: true)
                                    .environmentObject(createThemeManager(for: selectedTheme))
                            }
                        }
                        .environmentObject(createThemeManager(for: selectedTheme))
                        .padding(.horizontal)
                        
                        // Sample Buttons
                        VStack(spacing: 12) {
                            ModernButton(title: "Primary Action") {}
                                .environmentObject(createThemeManager(for: selectedTheme))
                            
                            HStack(spacing: 12) {
                                ModernButton(title: "Secondary") {}
                                    .environmentObject(createThemeManager(for: selectedTheme))
                                
                                ModernButton(title: "Destructive") {}
                                    .environmentObject(createThemeManager(for: selectedTheme))
                            }
                        }
                        .padding(.horizontal)
                        
                        // Sample Goals Section
                        ModernCard {
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Goals Progress")
                                    .font(.headline)
                                    .foregroundColor(selectedTheme.primaryTextColor)
                                
                                ForEach(Array(sampleGoals.enumerated()), id: \.offset) { index, goal in
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(goal)
                                            .font(.body)
                                            .foregroundColor(selectedTheme.primaryTextColor)
                                        ProgressBar(progress: Double(index + 1) * 0.3)
                                            .environmentObject(createThemeManager(for: selectedTheme))
                                    }
                                }
                            }
                        }
                        .environmentObject(createThemeManager(for: selectedTheme))
                        .padding(.horizontal)
                    }
                }
                .padding(.vertical)
            }
            .background(selectedTheme.primaryBackgroundColor.ignoresSafeArea())
            .navigationTitle("Theme Preview")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        presentationMode.wrappedValue.dismiss()
                    }
                }
                
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply") {
                        themeManager.setTheme(selectedTheme)
                        presentationMode.wrappedValue.dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
        .onAppear {
            selectedTheme = themeManager.currentTheme
        }
    }
    
    private func createThemeManager(for theme: Theme) -> ThemeManager {
        let manager = ThemeManager()
        manager.setTheme(theme)
        return manager
    }
}

struct ThemePreviewCard: View {
    let theme: Theme
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 12) {
                // Theme color swatches
                HStack(spacing: 8) {
                    Circle()
                        .fill(theme.primaryAccentColor)
                        .frame(width: 24, height: 24)
                    Circle()
                        .fill(theme.secondaryAccentColor)
                        .frame(width: 20, height: 20)
                    Circle()
                        .fill(theme.completedColor)
                        .frame(width: 16, height: 16)
                    Spacer()
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(theme.name)
                        .font(.headline)
                        .foregroundColor(theme.primaryTextColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    
                    Text("Sample text")
                        .font(.caption)
                        .foregroundColor(theme.secondaryTextColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Spacer()
            }
            .padding()
            .frame(height: 100)
            .background(theme.secondaryBackgroundColor)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        isSelected ? theme.primaryAccentColor : Color.clear,
                        lineWidth: 2
                    )
            )
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

#Preview {
    ThemePreviewView()
        .environmentObject(ThemeManager())
}
