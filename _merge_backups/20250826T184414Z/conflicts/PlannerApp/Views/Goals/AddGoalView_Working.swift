import Foundation
import SwiftUI

struct AddGoalView: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss
    @Binding var goals: [Goal]

    @State private var title = ""
    @State private var description = ""
    @State private var targetDate = Date()
    @State private var priority: GoalPriority = .medium
    @State private var progress: Double = 0.0

    @FocusState private var isDescriptionFocused: Bool

    private var isFormValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationView {
            Form {
                Section("Goal Details") {
                    TextField("Goal Title", text: $title)
                        .font(themeManager.currentTheme.font(forName: themeManager.currentTheme.primaryFontName, size: 16))
                        .foregroundColor(themeManager.currentTheme.primaryTextColor)

                    VStack(alignment: .leading) {
                        Text("Description")
                            .font(themeManager.currentTheme.font(forName: themeManager.currentTheme.secondaryFontName, size: 14))
                            .foregroundColor(themeManager.currentTheme.secondaryTextColor)

                        TextEditor(text: $description)
                            .frame(height: 100)
                            .font(themeManager.currentTheme.font(forName: themeManager.currentTheme.primaryFontName, size: 16))
                            .foregroundColor(themeManager.currentTheme.primaryTextColor)
                            .focused($isDescriptionFocused)
                    }

                    DatePicker("Target Date", selection: $targetDate, displayedComponents: .date)
                        .font(themeManager.currentTheme.font(forName: themeManager.currentTheme.primaryFontName, size: 16))

                    Picker("Priority", selection: $priority) {
                        ForEach(GoalPriority.allCases, id: \.self) { priority in
                            Text(priority.displayName).tag(priority)
                        }
                    }

                    VStack(alignment: .leading) {
                        Text("Progress: \(Int(progress * 100))%")
                            .font(themeManager.currentTheme.font(forName: themeManager.currentTheme.secondaryFontName, size: 14))
                            .foregroundColor(themeManager.currentTheme.secondaryTextColor)

                        Slider(value: $progress, in: 0 ... 1)
                            .accentColor(themeManager.currentTheme.primaryAccentColor)
                    }
                }
                .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)
            }
            .background(themeManager.currentTheme.primaryBackgroundColor.ignoresSafeArea())
            .scrollContentBackground(.hidden)
            .accentColor(themeManager.currentTheme.primaryAccentColor)
            .navigationTitle("New Goal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(themeManager.currentTheme.primaryAccentColor)
                }

                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Save") {
                        saveGoal()
                        dismiss()
                    }
                    .disabled(!isFormValid)
                    .foregroundColor(isFormValid ? themeManager.currentTheme.primaryAccentColor : themeManager.currentTheme.secondaryTextColor)
                }
            }
        }
    }

    private func saveGoal() {
        let newGoal = Goal(
            title: title.trimmingCharacters(in: .whitespacesAndNewlines),
            description: description.trimmingCharacters(in: .whitespacesAndNewlines),
            targetDate: targetDate,
            priority: priority,
            progress: progress
        )
        goals.append(newGoal)
        GoalDataManager.shared.save(goals: goals)
    }
}

struct AddGoalView_Previews: PreviewProvider {
    static var previews: some View {
        AddGoalView(goals: Binding.constant([]))
            .environmentObject(ThemeManager())
    }
}
