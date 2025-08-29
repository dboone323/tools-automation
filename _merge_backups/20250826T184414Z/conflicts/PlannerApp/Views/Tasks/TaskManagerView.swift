// PlannerApp/Views/Tasks/TaskManagerView.swift (Updated with iOS enhancements)
import SwiftUI
import Foundation

#if os(iOS)
import UIKit
#endif

// Type alias to resolve conflict between Swift's built-in Task and our custom Task model
typealias TaskModel = Task

struct TaskManagerView: View {
    // Access shared ThemeManager and data arrays
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.dismiss) var dismiss // Add dismiss capability
    @State private var tasks: [TaskModel] = [] // Holds all tasks loaded from storage
    @State private var newTaskTitle = "" // State for the input field text
    @FocusState private var isInputFieldFocused: Bool // Tracks focus state of the input field

    // Computed properties to filter tasks into incomplete and completed lists
    private var incompleteTasks: [TaskModel] {
        tasks.filter { !$0.isCompleted }.sortedById() // Use helper extension for sorting
    }
    private var completedTasks: [TaskModel] {
        tasks.filter { $0.isCompleted }.sortedById() // Use helper extension for sorting
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header with buttons for better macOS compatibility
            HStack {
                Button("Done") {
                    #if os(iOS)
                    HapticManager.lightImpact()
                    #endif
                    dismiss()
                }
                #if os(iOS)
                .buttonStyle(.iOSSecondary)
                #endif
                .foregroundColor(themeManager.currentTheme.primaryAccentColor)
                
                Spacer()
                
                Text("Task Manager")
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.currentTheme.primaryTextColor)
                
                Spacer()
                
                // Invisible button for balance
                Button("") { }
                    .disabled(true)
                    .opacity(0)
                    #if os(iOS)
                    .frame(minWidth: 60, minHeight: 44)
                    #endif
            }
            .padding()
            .background(themeManager.currentTheme.secondaryBackgroundColor)
            
            // Main container using VStack with no spacing for tight layout control
            VStack(spacing: 0) {
                // --- Input Area ---
                HStack {
                    // Text field for adding new tasks
                    TextField("New Task", text: $newTaskTitle, onCommit: addTask) // Add task on Return key
                        .textFieldStyle(.plain) // Use plain style for custom background/padding
                        .padding(EdgeInsets(top: 8, leading: 12, bottom: 8, trailing: 12)) // Custom padding
                        .background(themeManager.currentTheme.secondaryBackgroundColor) // Themed background
                        .cornerRadius(8) // Rounded corners
                        .focused($isInputFieldFocused) // Link focus state
                        .font(themeManager.currentTheme.font(forName: themeManager.currentTheme.primaryFontName, size: 16))
                        .foregroundColor(themeManager.currentTheme.primaryTextColor)
                        #if os(iOS)
                        .textInputAutocapitalization(.sentences)
                        .submitLabel(.done)
                        .onSubmit {
                            addTask()
                        }
                        #endif

                    // Add Task Button
                    Button(action: {
                        #if os(iOS)
                        HapticManager.notificationSuccess()
                        #endif
                        addTask()
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                            // Color changes based on theme and whether input is empty
                            .foregroundColor(newTaskTitle.isEmpty ? themeManager.currentTheme.secondaryTextColor : themeManager.currentTheme.primaryAccentColor)
                    }
                    #if os(iOS)
                    .buttonStyle(.iOSPrimary)
                    #endif
                    .disabled(newTaskTitle.isEmpty) // Disable button if input is empty
                }
                .padding() // Padding around the input HStack
                // Apply primary theme background to the input section container
                .background(themeManager.currentTheme.primaryBackgroundColor)

                // --- Task List ---
                List {
                    // --- Incomplete Tasks Section ---
                    Section("To Do (\(incompleteTasks.count))") {
                         if incompleteTasks.isEmpty {
                             // Message shown when no incomplete tasks exist
                             Text("No tasks yet!")
                                .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                                .font(themeManager.currentTheme.font(forName: themeManager.currentTheme.secondaryFontName, size: 15))
                         } else {
                             // Iterate over incomplete tasks and display using TaskRow
                             ForEach(incompleteTasks) { task in
                                 TaskRow(taskItem: task, tasks: $tasks) // Pass task and binding to tasks array
                                     .environmentObject(themeManager) // Ensure TaskRow can access theme
                             }
                             .onDelete(perform: deleteTaskIncomplete) // Enable swipe-to-delete
                         }
                    }
                     .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor) // Theme row background
                     .foregroundColor(themeManager.currentTheme.primaryTextColor) // Theme row text color
                     .headerProminence(.increased) // Style section header

                    // --- Completed Tasks Section ---
                    Section("Completed (\(completedTasks.count))") {
                        if completedTasks.isEmpty {
                             // Message shown when no completed tasks exist
                             Text("No completed tasks.")
                                .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                                .font(themeManager.currentTheme.font(forName: themeManager.currentTheme.secondaryFontName, size: 15))
                         } else {
                             // Iterate over completed tasks
                             ForEach(completedTasks) { task in
                                TaskRow(taskItem: task, tasks: $tasks)
                                     .environmentObject(themeManager)
                             }
                             .onDelete(perform: deleteTaskCompleted) // Enable swipe-to-delete
                        }
                    }
                     .listRowBackground(themeManager.currentTheme.secondaryBackgroundColor)
                     .foregroundColor(themeManager.currentTheme.primaryTextColor)
                     .headerProminence(.increased)
                }
                 // Apply theme background color to the List view itself
                .background(themeManager.currentTheme.primaryBackgroundColor)
                // Hide the default List background style (e.g., plain/grouped)
                .scrollContentBackground(.hidden)
                // Add tap gesture to the List to dismiss keyboard when tapping outside the text field
                .onTapGesture {
                    isInputFieldFocused = false
                    #if os(iOS)
                    UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                    #endif
                }
                #if os(iOS)
                .iOSKeyboardDismiss()
                #endif

            } // End main VStack
            // Ensure the primary background extends behind the navigation bar area if needed
            .background(themeManager.currentTheme.primaryBackgroundColor.ignoresSafeArea())
            .navigationTitle("Tasks")
            // Load tasks and perform auto-deletion check when view appears
            .onAppear {
                loadTasks()
                performAutoDeletionIfNeeded() // Check and perform auto-deletion
            }
            .toolbar {
                 // Custom Edit button for macOS list reordering/deletion mode
                 ToolbarItem(placement: .navigation) {
                     Button("Edit") {
                         // Custom edit implementation for macOS
                     }
                 }
                 // Add a "Done" button to the keyboard toolbar
                 ToolbarItem(placement: .keyboard) {
                     HStack {
                         Spacer() // Push button to the right
                         Button("Done") { isInputFieldFocused = false } // Dismiss keyboard on tap
                         // Uses theme accent color automatically
                     }
                 }
            }
            // Apply theme accent color to navigation bar items (Edit, Done buttons)
            .accentColor(themeManager.currentTheme.primaryAccentColor)

        } // End main VStack
        #if os(macOS)
        .frame(minWidth: 500, minHeight: 400)
        #else
        .iOSPopupOptimizations()
        #endif
    }

    // --- Data Functions ---

    // Adds a new task based on the input field text
    private func addTask() {
        let trimmedTitle = newTaskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty else { return } // Don't add empty tasks

        // Create new Task instance. Ensure Task model has necessary initializers.
        // If Task needs `completionDate`, initialize it as nil here.
        let newTask = TaskModel(title: trimmedTitle /*, completionDate: nil */)
        tasks.append(newTask) // Add to the local state array
        newTaskTitle = "" // Clear the input field
        saveTasks() // Persist changes
        isInputFieldFocused = false // Dismiss keyboard
    }

    // Handles deletion from the incomplete tasks section
    private func deleteTaskIncomplete(at offsets: IndexSet) {
        deleteTask(from: incompleteTasks, at: offsets) // Use helper function
    }

    // Handles deletion from the completed tasks section
    private func deleteTaskCompleted(at offsets: IndexSet) {
        deleteTask(from: completedTasks, at: offsets) // Use helper function
    }

    // Helper function to delete tasks based on offsets from a filtered array
    private func deleteTask(from sourceArray: [TaskModel], at offsets: IndexSet) {
         // Get the IDs of the tasks to be deleted from the source (filtered) array
         let idsToDelete = offsets.map { sourceArray[$0].id }
         // Remove tasks with matching IDs from the main `tasks` array
         tasks.removeAll { idsToDelete.contains($0.id) }
         saveTasks() // Persist changes
     }

    // Loads tasks from the data manager
    private func loadTasks() {
        tasks = TaskDataManager.shared.load()
        print("Tasks loaded. Count: \(tasks.count)")
    }

    // Saves the current state of the `tasks` array to the data manager
    private func saveTasks() {
        TaskDataManager.shared.save(tasks: tasks)
        print("Tasks saved.")
    }

    // --- Auto Deletion Logic ---
    // Checks settings and performs auto-deletion if enabled
    private func performAutoDeletionIfNeeded() {
         // Read settings directly using AppStorage within this function scope
         @AppStorage(AppSettingKeys.autoDeleteCompleted) var autoDeleteEnabled: Bool = false
         @AppStorage(AppSettingKeys.autoDeleteDays) var autoDeleteDays: Int = 30

         // Only proceed if auto-delete is enabled
         guard autoDeleteEnabled else {
             print("Auto-deletion skipped (disabled).")
             return
         }

         // Calculate the cutoff date based on the setting
         guard Calendar.current.date(byAdding: .day, value: -autoDeleteDays, to: Date()) != nil else {
             print("Could not calculate cutoff date for auto-deletion.")
             return
         }

         let initialCount = tasks.count
         // IMPORTANT: Requires Task model to have `completionDate: Date?`
         tasks.removeAll { task in
             // Ensure task is completed and has a completion date
             guard task.isCompleted /*, let completionDate = task.completionDate */ else {
                 return false // Keep incomplete or tasks without completion date
             }
             // *** Uncomment the completionDate check above and ensure Task model supports it ***

             // *** Placeholder Warning if completionDate is missing ***
             print("Warning: Task model needs 'completionDate' for accurate auto-deletion based on date. Checking only 'isCompleted' status for now.")
             // If completionDate is missing, this would delete ALL completed tasks immediately
             // return true // DO NOT UNCOMMENT without completionDate check
             return false // Safely keep all tasks if completionDate logic is missing
             // *** End Placeholder ***

             // Actual logic: Remove if completion date is before the cutoff
             // return completionDate < cutoffDate
         }

         // Save only if tasks were actually removed
         if tasks.count < initialCount {
             print("Auto-deleted \(initialCount - tasks.count) tasks older than \(autoDeleteDays) days.")
             saveTasks()
         } else {
             print("No tasks found matching auto-deletion criteria.")
         }
    }
}

// --- TaskRow Subview ---
// Displays a single task item in the list
struct TaskRow: View {
    // Access shared ThemeManager
    @EnvironmentObject var themeManager: ThemeManager
    // The specific task to display
    let taskItem: TaskModel
    // Binding to the main tasks array to allow modification (toggling completion)
    @Binding var tasks: [TaskModel]

    var body: some View {
        HStack {
            // Checkmark icon (filled if completed, empty circle otherwise)
            Image(systemName: taskItem.isCompleted ? "checkmark.circle.fill" : "circle")
                // Apply theme colors based on completion status
                .foregroundColor(taskItem.isCompleted ? themeManager.currentTheme.completedColor : themeManager.currentTheme.secondaryTextColor)
                .font(.title3) // Make icon slightly larger
                .onTapGesture { toggleCompletion() } // Toggle completion on icon tap

            // Task title text
            Text(taskItem.title)
                .font(themeManager.currentTheme.font(forName: themeManager.currentTheme.primaryFontName, size: 16))
                // Apply strikethrough effect if completed
                .strikethrough(taskItem.isCompleted, color: themeManager.currentTheme.secondaryTextColor)
                // Apply theme text color based on completion status
                .foregroundColor(taskItem.isCompleted ? themeManager.currentTheme.secondaryTextColor : themeManager.currentTheme.primaryTextColor)

            Spacer() // Push content to the left
        }
        .contentShape(Rectangle()) // Make the entire HStack tappable
        .onTapGesture { toggleCompletion() } // Toggle completion on row tap
        // Row background color is applied by the parent List section modifier
    }

    // Toggles the completion status of the task and saves changes
    private func toggleCompletion() {
        // Find the index of this task in the main array
        if let index = tasks.firstIndex(where: { $0.id == taskItem.id }) {
            #if os(iOS)
            // Add haptic feedback for task completion
            if tasks[index].isCompleted {
                HapticManager.lightImpact()
            } else {
                HapticManager.notificationSuccess()
            }
            #endif
            
            // Toggle the boolean state
            tasks[index].isCompleted.toggle()
            // ** IMPORTANT: Update completionDate if Task model supports it **
            // tasks[index].completionDate = tasks[index].isCompleted ? Date() : nil
            // Persist the change immediately
            TaskDataManager.shared.save(tasks: tasks)
            print("Toggled task '\(tasks[index].title)' to \(tasks[index].isCompleted)")
        }
    }
}

// --- Helper extension for sorting Task array ---
extension Array where Element == TaskModel {
    // Sorts tasks stably based on their UUID string representation
    func sortedById() -> [TaskModel] {
        self.sorted(by: { $0.id.uuidString < $1.id.uuidString })
    }
}


// --- Preview Provider ---
struct TaskManagerView_Previews: PreviewProvider {
    static var previews: some View {
        TaskManagerView()
            // Provide ThemeManager for the preview
            .environmentObject(ThemeManager())
    }
}
