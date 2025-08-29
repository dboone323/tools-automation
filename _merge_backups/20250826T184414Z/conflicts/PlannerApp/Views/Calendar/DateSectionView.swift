// PlannerApp/Views/Calendar/DateSectionView.swift
import SwiftUI

struct DateSectionView<Content: View>: View {
    @EnvironmentObject var themeManager: ThemeManager
    let title: String
    let color: Color
    @ViewBuilder let content: Content
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Circle()
                    .fill(color)
                    .frame(width: 12, height: 12)
                
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(themeManager.currentTheme.primaryTextColor)
                
                Spacer()
            }
            
            VStack(spacing: 6) {
                content
            }
        }
        .padding(12)
        .background(themeManager.currentTheme.secondaryBackgroundColor)
        .cornerRadius(12)
    }
}

#Preview {
    DateSectionView(title: "Events", color: .blue) {
        Text("Sample Event")
            .foregroundColor(.primary)
        Text("Another Event")
            .foregroundColor(.primary)
    }
    .environmentObject(ThemeManager())
    .padding()
}
