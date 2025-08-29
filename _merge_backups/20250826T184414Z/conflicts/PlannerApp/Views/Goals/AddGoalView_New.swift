// PlannerApp/Views/Goals/AddGoalView.swift
import SwiftUI
import Foundation

struct AddGoalView: View {
    // Access shared ThemeManager and dismiss action
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    // Binding to the goals array in the parent view (GoalsView)
    @Binding var goals: [Goal]

    // State variables for the form fields
    @State private var title = ""
    @State private var description = ""
    @State private var targetDate = Date()
    // Focus state to manage keyboard for the TextEditor
    @FocusState private var isDescriptionFocused: Bool

    // Computed property to check if the form is valid for saving
    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with buttons for better macOS compatibility
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(themeManager.currentTheme.primaryAccentColor)
                
                Spacer()
                
                Text("Add Goal")
                    .font(.headline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.currentTheme.primaryTextColor)
                
                Spacer()
                
                Button("Save") {
                    // Create the new goal
                    let newGoal = Goal(
                        title: title.trimmingCharacters(in: .whitespacesAndNewlines),
                        description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                        targetDate: targetDate
                    )
                    
                    // Append the new goal to the array
                    goals.append(newGoal)
                    
                    // Save goals to the data manager
                    GoalDataManager.shared.save(goals: goals)
                    
                    // Dismiss the sheet
                    dismiss()
                }
                .disabled(!isFormValid)
                .foregroundColor(isFormValid ? themeManager.currentTheme.primaryAccentColor : themeManager.currentTheme.secondaryTextColor)
            }
            .padding()
            .background(themeManager.currentTheme.secondaryBackgroundColor)
            
            // Use Form for standard iOS settings/input layout
            Form {
                // Section for the main goal details
                Section("Goal Details") {
                    // TextField for the goal title
                    TextField("Goal Title", text: $title)
                        .font(themeManager.currentTheme.font(forName: themeManager.currentTheme.primaryFontName, size: 16))
                        .foregroundColor(themeManager.currentTheme.primaryTextColor)
                    
                    // TextEditor for the goal description
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Description")
                            .font(.caption)
                            .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                        
                        TextEditor(text: $description)
                            .frame(minHeight: 80)
                            .font(themeManager.currentTheme.font(forName: themeManager.currentTheme.secondaryFontName, size: 15))
                            .foregroundColor(themeManager.currentTheme.primaryTextColor)
                            .focused($isDescriptionFocused)
                    }
                    
                    // DatePicker for the target date
                    DatePicker("Target Date", selection: $targetDate, displayedComponents: .date)
                        .font(themeManager.currentTheme.font(forName: themeManager.currentTheme.primaryFontName, size: 16))
                        .foregroundColor(themeManager.currentTheme.primaryTextColor)
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)
            }
            .background(themeManager.currentTheme.primaryBackgroundColor)
            .scrollContentBackground(.hidden)
        }
        .background(themeManager.currentTheme.primaryBackgroundColor)
    }
}

// --- Preview Provider ---
struct AddGoalView_Previews: PreviewProvider {
    static var previews: some View {
        AddGoalView(goals: Binding.constant([]))
            .environmentObject(ThemeManager())
    }
}
