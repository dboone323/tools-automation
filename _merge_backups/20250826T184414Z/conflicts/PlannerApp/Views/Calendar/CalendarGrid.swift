// PlannerApp/Views/Calendar/CalendarGrid.swift
import SwiftUI

struct CalendarGrid: View {
    @EnvironmentObject var themeManager: ThemeManager
    @Binding var selectedDate: Date
    let eventDates: Set<Date>
    let goalDates: Set<Date>
    let taskDates: Set<Date>
    let firstDayOfWeek: Int
    
    private var calendar: Calendar {
        var cal = Calendar.current
        cal.firstWeekday = firstDayOfWeek
        return cal
    }
    
    private var monthDates: [Date] {
        guard let monthInterval = calendar.dateInterval(of: .month, for: selectedDate) else {
            return []
        }
        
        let monthStart = monthInterval.start
        let monthEnd = monthInterval.end
        
        // Get the first day of the week that contains the first day of the month
        let firstWeekday = calendar.dateInterval(of: .weekOfYear, for: monthStart)?.start ?? monthStart
        
        // Get all dates from the first weekday to the end of the month's week
        var dates: [Date] = []
        var currentDate = firstWeekday
        
        while currentDate < monthEnd {
            dates.append(currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        // Add extra days to fill the last week if needed
        while dates.count % 7 != 0 {
            dates.append(calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate)
            currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate) ?? currentDate
        }
        
        return dates
    }
    
    private var weekdayHeaders: [String] {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        
        var symbols = formatter.shortWeekdaySymbols!
        
        // Adjust for first day of week setting
        if firstDayOfWeek != 1 { // If not Sunday
            let sundayIndex = firstDayOfWeek - 1
            symbols = Array(symbols[sundayIndex...]) + Array(symbols[..<sundayIndex])
        }
        
        return symbols
    }
    
    var body: some View {
        VStack(spacing: 8) {
            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdayHeaders, id: \.self) { weekday in
                    Text(weekday)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                        .frame(maxWidth: .infinity)
                }
            }
            .padding(.horizontal, 20)
            
            // Calendar grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 7), spacing: 4) {
                ForEach(monthDates, id: \.self) { date in
                    CalendarDayView(
                        date: date,
                        selectedDate: $selectedDate,
                        isCurrentMonth: calendar.isDate(date, equalTo: selectedDate, toGranularity: .month),
                        hasEvent: eventDates.contains(calendar.startOfDay(for: date)),
                        hasGoal: goalDates.contains(calendar.startOfDay(for: date)),
                        hasTask: taskDates.contains(calendar.startOfDay(for: date))
                    )
                    .environmentObject(themeManager)
                }
            }
            .padding(.horizontal, 20)
        }
    }
}

struct CalendarDayView: View {
    @EnvironmentObject var themeManager: ThemeManager
    let date: Date
    @Binding var selectedDate: Date
    let isCurrentMonth: Bool
    let hasEvent: Bool
    let hasGoal: Bool
    let hasTask: Bool
    
    private var calendar: Calendar { Calendar.current }
    
    private var isSelected: Bool {
        calendar.isDate(date, inSameDayAs: selectedDate)
    }
    
    private var isToday: Bool {
        calendar.isDateInToday(date)
    }
    
    private var dayNumber: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "d"
        return formatter.string(from: date)
    }
    
    var body: some View {
        VStack(spacing: 2) {
            // Day number
            Text(dayNumber)
                .font(.system(size: 16, weight: isToday ? .bold : .medium))
                .foregroundColor(dayTextColor)
                .frame(width: 32, height: 32)
                .background(dayBackgroundColor)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(isSelected ? themeManager.currentTheme.primaryAccentColor : Color.clear, lineWidth: 2)
                )
            
            // Indicator dots
            HStack(spacing: 2) {
                if hasEvent {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 4, height: 4)
                }
                if hasGoal {
                    Circle()
                        .fill(Color.green)
                        .frame(width: 4, height: 4)
                }
                if hasTask {
                    Circle()
                        .fill(Color.orange)
                        .frame(width: 4, height: 4)
                }
            }
            .frame(height: 6)
        }
        .frame(height: 44)
        .contentShape(Rectangle())
        .onTapGesture {
            selectedDate = date
        }
    }
    
    private var dayTextColor: Color {
        if isSelected {
            return themeManager.currentTheme.primaryBackgroundColor
        } else if isToday {
            return themeManager.currentTheme.primaryAccentColor
        } else if isCurrentMonth {
            return themeManager.currentTheme.primaryTextColor
        } else {
            return themeManager.currentTheme.secondaryTextColor.opacity(0.5)
        }
    }
    
    private var dayBackgroundColor: Color {
        if isSelected {
            return themeManager.currentTheme.primaryAccentColor
        } else if isToday {
            return themeManager.currentTheme.primaryAccentColor.opacity(0.1)
        } else {
            return Color.clear
        }
    }
}

#Preview {
    CalendarGrid(
        selectedDate: .constant(Date()),
        eventDates: Set([Date()]),
        goalDates: Set([Calendar.current.date(byAdding: .day, value: 1, to: Date())!]),
        taskDates: Set([Calendar.current.date(byAdding: .day, value: 2, to: Date())!]),
        firstDayOfWeek: 1
    )
    .environmentObject(ThemeManager())
    .padding()
}
