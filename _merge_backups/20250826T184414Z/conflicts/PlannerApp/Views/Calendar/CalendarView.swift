// filepath: /Users/danielstevens/Desktop/PlannerApp/Views/Calendar/CalendarView.swift
// PlannerApp/Views/Calendar/CalendarView.swift

import Foundation
import SwiftUI

struct CalendarView: View {
    // Access shared ThemeManager and data
    @EnvironmentObject var themeManager: ThemeManager
    @State private var events: [CalendarEvent] = []
    @State private var goals: [Goal] = []
    @State private var tasks: [Task] = []
    @State private var showAddEvent = false
    @State private var selectedDate = Date()
    @State private var showingDateDetails = false

    // Settings from UserDefaults
    @AppStorage(AppSettingKeys.firstDayOfWeek) private var firstDayOfWeekSetting: Int = Calendar.current.firstWeekday
    @AppStorage(AppSettingKeys.use24HourTime) private var use24HourTime: Bool = false

    // Computed property to group events by the start of their day
    private var groupedEvents: [Date: [CalendarEvent]] {
        var calendar = Calendar.current
        calendar.firstWeekday = firstDayOfWeekSetting
        return Dictionary(grouping: events.sorted(by: { $0.date < $1.date })) { event in
            calendar.startOfDay(for: event.date)
        }
    }

    // Computed property to get dates with goals
    private var goalDates: Set<Date> {
        var calendar = Calendar.current
        calendar.firstWeekday = firstDayOfWeekSetting
        return Set(goals.map { calendar.startOfDay(for: $0.targetDate) })
    }

    // Computed property to get dates with tasks
    private var taskDates: Set<Date> {
        var calendar = Calendar.current
        calendar.firstWeekday = firstDayOfWeekSetting
        return Set(tasks.compactMap { task in
            guard let dueDate = task.dueDate else { return nil }
            return calendar.startOfDay(for: dueDate)
        })
    }

    // Computed property to get dates with events
    private var eventDates: Set<Date> {
        var calendar = Calendar.current
        calendar.firstWeekday = firstDayOfWeekSetting
        return Set(events.map { calendar.startOfDay(for: $0.date) })
    }

    // Get items for selected date
    private var selectedDateItems: (events: [CalendarEvent], goals: [Goal], tasks: [Task]) {
        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: selectedDate)
        let endOfDay = calendar.date(byAdding: .day, value: 1, to: startOfDay) ?? startOfDay

        let dayEvents = events.filter { event in
            event.date >= startOfDay && event.date < endOfDay
        }

        let dayGoals = goals.filter { goal in
            calendar.startOfDay(for: goal.targetDate) == startOfDay
        }

        let dayTasks = tasks.filter { task in
            guard let dueDate = task.dueDate else { return false }
            return calendar.startOfDay(for: dueDate) == startOfDay
        }

        return (dayEvents, dayGoals, dayTasks)
    }

    // Date Formatters
    private var eventTimeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        formatter.locale = Locale(identifier: use24HourTime ? "en_GB" : "en_US")
        return formatter
    }

    private var monthYearFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMMM yyyy"
        return formatter
    }

    private var selectedDateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Calendar Widget
                VStack(spacing: 16) {
                    // Calendar Header
                    HStack {
                        Text(monthYearFormatter.string(from: selectedDate))
                            .font(.title2)
                            .fontWeight(.semibold)
                            .foregroundColor(themeManager.currentTheme.primaryTextColor)

                        Spacer()

                        HStack(spacing: 12) {
                            Button(action: previousMonth) {
                                Image(systemName: "chevron.left")
                                    .foregroundColor(themeManager.currentTheme.primaryAccentColor)
                            }

                            Button(action: nextMonth) {
                                Image(systemName: "chevron.right")
                                    .foregroundColor(themeManager.currentTheme.primaryAccentColor)
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // Calendar Grid
                    CalendarGrid(
                        selectedDate: $selectedDate,
                        eventDates: eventDates,
                        goalDates: goalDates,
                        taskDates: taskDates,
                        firstDayOfWeek: firstDayOfWeekSetting
                    )
                    .environmentObject(themeManager)
                }
                .padding(.vertical, 16)
                .background(themeManager.currentTheme.secondaryBackgroundColor)

                // Selected Date Details
                VStack(alignment: .leading, spacing: 16) {
                    HStack {
                        Text(selectedDateFormatter.string(from: selectedDate))
                            .font(.headline)
                            .foregroundColor(themeManager.currentTheme.primaryTextColor)

                        Spacer()

                        Button(action: { showAddEvent = true }) {
                            Image(systemName: "plus.circle.fill")
                                .foregroundColor(themeManager.currentTheme.primaryAccentColor)
                                .font(.title2)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 16)

                    ScrollView {
                        LazyVStack(spacing: 12) {
                            let items = selectedDateItems

                            // Events Section
                            if !items.events.isEmpty {
                                DateSectionView(title: "Events", color: .blue) {
                                    ForEach(items.events) { event in
                                        EventRowView(event: event)
                                            .environmentObject(themeManager)
                                    }
                                }
                            }

                            // Goals Section
                            if !items.goals.isEmpty {
                                DateSectionView(title: "Goals", color: .green) {
                                    ForEach(items.goals) { goal in
                                        GoalRowView(goal: goal)
                                            .environmentObject(themeManager)
                                    }
                                }
                            }

                            // Tasks Section
                            if !items.tasks.isEmpty {
                                DateSectionView(title: "Tasks", color: .orange) {
                                    ForEach(items.tasks) { task in
                                        TaskRowView(task: task)
                                            .environmentObject(themeManager)
                                    }
                                }
                            }

                            // Empty State
                            if items.events.isEmpty && items.goals.isEmpty && items.tasks.isEmpty {
                                VStack(spacing: 12) {
                                    Image(systemName: "calendar")
                                        .font(.system(size: 40))
                                        .foregroundColor(themeManager.currentTheme.secondaryTextColor)

                                    Text("No items for this date")
                                        .font(.subheadline)
                                        .foregroundColor(themeManager.currentTheme.secondaryTextColor)

                                    Text("Tap + to add an event")
                                        .font(.caption)
                                        .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                                }
                                .padding(.vertical, 40)
                            }
                        }
                        .padding(.horizontal, 20)
                    }
                }
                .background(themeManager.currentTheme.primaryBackgroundColor)
            }
            .background(themeManager.currentTheme.primaryBackgroundColor)
            .navigationTitle("Calendar")
            .sheet(isPresented: $showAddEvent) {
                AddCalendarEventView(events: $events)
                    .environmentObject(themeManager)
                    .onDisappear(perform: saveEvents)
            }
            .onAppear(perform: loadAllData)
            .accentColor(themeManager.currentTheme.primaryAccentColor)
        }
    }

    // MARK: - Calendar Navigation

    private func previousMonth() {
        selectedDate = Calendar.current.date(byAdding: .month, value: -1, to: selectedDate) ?? selectedDate
    }

    private func nextMonth() {
        selectedDate = Calendar.current.date(byAdding: .month, value: 1, to: selectedDate) ?? selectedDate
    }

    // MARK: - Data Functions

    private func loadAllData() {
        events = CalendarDataManager.shared.load()
        goals = GoalDataManager.shared.load()
        tasks = TaskDataManager.shared.load()
        print("Calendar data loaded. Events: \(events.count), Goals: \(goals.count), Tasks: \(tasks.count)")
    }

    private func saveEvents() {
        CalendarDataManager.shared.save(events: events)
        print("Calendar events saved.")
        loadAllData()
    }
}

// MARK: - Calendar Extension

extension Calendar {
    func generateDatesInMonth(for date: Date, firstDayOfWeek: Int) -> [Date] {
        guard let monthInterval = self.dateInterval(of: .month, for: date) else { return [] }

        let monthStart = monthInterval.start
        let firstWeekday = self.component(.weekday, from: monthStart)
        let daysFromPreviousMonth = (firstWeekday - firstDayOfWeek + 7) % 7

        guard let calendarStart = self.date(byAdding: .day, value: -daysFromPreviousMonth, to: monthStart) else { return [] }

        var dates: [Date] = []
        var currentDate = calendarStart

        for _ in 0 ..< 42 {
            dates.append(currentDate)
            guard let nextDate = self.date(byAdding: .day, value: 1, to: currentDate) else { break }
            currentDate = nextDate
        }

        return dates
    }
}

// MARK: - Preview Provider

struct CalendarView_Previews: PreviewProvider {
    static var previews: some View {
        CalendarView()
            .environmentObject(ThemeManager())
    }
}
