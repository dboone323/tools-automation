// PlannerApp/Views/Calendar/GoalRowView.swift
import SwiftUI

struct GoalRowView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let goal: Goal
    
    private var priorityColor: Color {
        switch goal.priority {
        case .high:
            return .red
        case .medium:
            return .orange
        case .low:
            return .green
        }
    }
    
    private var priorityText: String {
        switch goal.priority {
        case .high:
            return "High"
        case .medium:
            return "Medium"
        case .low:
            return "Low"
        }
    }
    
    private var progressPercentage: Double {
        return goal.progress
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Priority indicator
            VStack(alignment: .center, spacing: 2) {
                Circle()
                    .fill(priorityColor)
                    .frame(width: 8, height: 8)
                
                Text(priorityText)
                    .font(.caption2)
                    .fontWeight(.medium)
                    .foregroundColor(priorityColor)
            }
            .frame(width: 50)
            
            // Goal details
            VStack(alignment: .leading, spacing: 4) {
                Text(goal.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(themeManager.currentTheme.primaryTextColor)
                    .lineLimit(2)
                
                if !goal.description.isEmpty {
                    Text(goal.description)
                        .font(.caption)
                        .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                        .lineLimit(1)
                }
                
                // Progress bar
                if progressPercentage > 0 {
                    VStack(alignment: .leading, spacing: 2) {
                        HStack {
                            Text("Progress")
                                .font(.caption2)
                                .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                            Spacer()
                            Text("\(Int(progressPercentage * 100))%")
                                .font(.caption2)
                                .fontWeight(.medium)
                                .foregroundColor(.green)
                        }
                        
                        ProgressView(value: progressPercentage)
                            .progressViewStyle(LinearProgressViewStyle(tint: .green))
                            .scaleEffect(y: 0.8)
                    }
                }
            }
            
            Spacer()
            
            // Completion status
            if goal.isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title3)
            } else {
                Image(systemName: "target")
                    .foregroundColor(.green)
                    .font(.title3)
            }
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
    }
}

#Preview {
    VStack {
        GoalRowView(goal: Goal(
            id: UUID(),
            title: "Learn SwiftUI",
            description: "Complete advanced SwiftUI course",
            targetDate: Date(),
            isCompleted: false,
            priority: .high,
            progress: 0.75
        ))
        
        GoalRowView(goal: Goal(
            id: UUID(),
            title: "Read 50 Books",
            description: "Annual reading challenge",
            targetDate: Date(),
            isCompleted: true,
            priority: .medium,
            progress: 1.0
        ))
    }
    .environmentObject(ThemeManager())
    .padding()
}
