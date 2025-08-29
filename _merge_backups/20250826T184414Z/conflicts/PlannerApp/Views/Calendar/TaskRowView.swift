// PlannerApp/Views/Calendar/TaskRowView.swift
import SwiftUI

struct TaskRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let task: Task
    
    private var priorityColor: Color {
        switch task.priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .green
        }
    }
    
    private var priorityText: String {
        switch task.priority {
        case .high:
            return "High"
        case .medium:
            return "Medium"
        case .low:
            return "Low"
        }
    }
    
    private var isOverdue: Bool {
        guard let dueDate = task.dueDate else { return false }
        return !task.isCompleted && dueDate < Date()
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Priority and status indicator
            VStack(alignment: .center, spacing: 2) {
                if task.isCompleted {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.title3)
                } else if isOverdue {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.title3)
                } else {
                    Circle()
                        .fill(priorityColor)
                        .frame(width: 8, height: 8)
                }
                
                Text(priorityText)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(task.isCompleted ? .green : (isOverdue ? .red : priorityColor))
            }
            .frame(width: 50)
            
            // Task details
            VStack(alignment: .leading, spacing: 2) {
                Text(task.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(task.isCompleted ? 
                        themeManager.currentTheme.secondaryTextColor : 
                        themeManager.currentTheme.primaryTextColor)
                    .strikethrough(task.isCompleted)
                    .lineLimit(2)
                
                if !task.description.isEmpty {
                    Text(task.description)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                        .lineLimit(1)
                }
                
                // Due date indicator
                if let dueDate = task.dueDate {
                    HStack(spacing: 4) {
                        Image(systemName: "clock")
                            .font(.caption2)
                            .foregroundColor(isOverdue ? .red : themeManager.currentTheme.secondaryTextColor)
                        
                        Text("Due: \(dueDateFormatter.string(from: dueDate))")
                            .font(.caption2)
                            .foregroundColor(isOverdue ? .red : themeManager.currentTheme.secondaryTextColor)
                    }
                }
            }
            
            Spacer()
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
    
    private var dueDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter
    }
}

#Preview {
    VStack {
        TaskRowView(task: Task(
            id: UUID(),
            title: "Review Pull Request",
            description: "Check the new feature implementation",
            isCompleted: false,
            priority: .high,
            dueDate: Date()
        ))
        
        TaskRowView(task: Task(
            id: UUID(),
            title: "Buy Groceries",
            description: "Get items for dinner party",
            isCompleted: false,
            priority: .medium,
            dueDate: Calendar.current.date(byAdding: .hour, value: -2, to: Date())
        ))
        
        TaskRowView(task: Task(
            id: UUID(),
            title: "Completed Task",
            description: "This task is done",
            isCompleted: true,
            priority: .low,
            dueDate: Date()
        ))
    }
    .environmentObject(ThemeManager())
    .padding()
}
