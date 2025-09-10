// PlannerApp/ViewModels/DashboardViewModel.swift (Updated)
import Combine
import Foundation
import SwiftUI // Needed for @AppStorage

// MARK: - Data Structures

struct DashboardActivity: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let timestamp: Date
}

struct UpcomingItem: Identifiable {
    let id = UUID()
    let title: String
    let subtitle: String?
    let date: Date
    let icon: String
    let color: Color
}

// ObservableObject makes this class publish changes to its @Published properties.
class DashboardViewModel: ObservableObject {

    // --- Published Properties for View Updates ---
    // These arrays hold the data to be displayed on the dashboard, limited by user settings.
    @Published var todaysEvents: [CalendarEvent] = []
    @Published var incompleteTasks: [Task] = []
    @Published var upcomingGoals: [Goal] = []

    // These hold the *total* counts before the limit is applied.
    // Useful for displaying accurate "...and X more" messages.
    @Published var totalTodaysEventsCount: Int = 0
    @Published var totalIncompleteTasksCount: Int = 0
    @Published var totalUpcomingGoalsCount: Int = 0

    // Modern Dashboard Properties
    @Published var recentActivities: [DashboardActivity] = []
    @Published var upcomingItems: [UpcomingItem] = []

    // Full data arrays for Add* views to bind to
    @Published var allGoals: [Goal] = []
    @Published var allEvents: [CalendarEvent] = []
    @Published var allJournalEntries: [JournalEntry] = []

    // Quick Stats Properties
    @Published var totalTasks: Int = 0
    @Published var completedTasks: Int = 0
    @Published var totalGoals: Int = 0
    @Published var completedGoals: Int = 0
    @Published var todayEvents: Int = 0

    // --- AppStorage Links ---
    // Read settings directly from UserDefaults using @AppStorage.
    // The view model automatically uses the latest setting value.
    @AppStorage(AppSettingKeys.dashboardItemLimit) private var dashboardItemLimit: Int = 3 // Default limit
    @AppStorage(AppSettingKeys.firstDayOfWeek) private var firstDayOfWeekSetting: Int = Calendar.current.firstWeekday

    // --- Data Fetching and Filtering ---
    // This function loads data from managers, filters it based on dates/status,
    // applies the user's limit, and updates the @Published properties.
    func fetchDashboardData() {
        print("Fetching dashboard data...") // Debugging log

        // Load all data from the respective data managers.
        let allEvents = CalendarDataManager.shared.load()
        let allTasks = TaskDataManager.shared.load()
        let allGoals = GoalDataManager.shared.load()

        // Get the current calendar and configure it with the user's setting for the first day of the week.
        var calendar = Calendar.current
        calendar.firstWeekday = firstDayOfWeekSetting

        // Calculate date ranges needed for filtering (today, next week).
        let today = Date()
        let startOfToday = calendar.startOfDay(for: today)
        // Use guard to safely unwrap optional dates. If calculation fails, reset data.
        guard let endOfToday = calendar.date(byAdding: .day, value: 1, to: startOfToday),
              let endOfWeek = calendar.date(byAdding: .day, value: 7, to: startOfToday)
        else {
            print("Error calculating date ranges for dashboard.")
            resetData() // Clear displayed data if dates are invalid
            return
        }

        // --- Filter Data ---
        // Filter events happening today.
        let filteredTodaysEvents = allEvents.filter { event in
            event.date >= startOfToday && event.date < endOfToday
        }.sorted(by: { $0.date < $1.date }) // Sort today's events by time

        // Filter tasks that are not completed.
        let filteredIncompleteTasks = allTasks.filter { !$0.isCompleted }
        // .sorted(...) // Optional: Add sorting if needed

        // Filter goals due between today and the end of the next 7 days.
        let filteredUpcomingGoals = allGoals.filter { goal in
            // Compare using the start of the day for the goal's target date for consistency.
            let goalTargetStartOfDay = calendar.startOfDay(for: goal.targetDate)
            return goalTargetStartOfDay >= startOfToday && goalTargetStartOfDay < endOfWeek
        }.sorted(by: { $0.targetDate < $1.targetDate }) // Sort upcoming goals by target date

        // --- Update Total Counts ---
        // Store the counts *before* applying the display limit.
        self.totalTodaysEventsCount = filteredTodaysEvents.count
        self.totalIncompleteTasksCount = filteredIncompleteTasks.count
        self.totalUpcomingGoalsCount = filteredUpcomingGoals.count

        // --- Update Full Data Arrays ---
        // Store complete arrays for Add* views to bind to
        self.allEvents = allEvents
        self.allGoals = allGoals
        // Load journal entries
        self.allJournalEntries = JournalDataManager.shared.load()

        // --- Apply Limit and Update Published Arrays ---
        // Get the current limit value from @AppStorage.
        let limit = self.dashboardItemLimit
        // Take only the first `limit` items from each filtered array.
        self.todaysEvents = Array(filteredTodaysEvents.prefix(limit))
        self.incompleteTasks = Array(filteredIncompleteTasks.prefix(limit))
        self.upcomingGoals = Array(filteredUpcomingGoals.prefix(limit))

        print("Dashboard data fetched. Limit: \(limit). Today: \(totalTodaysEventsCount), Tasks: \(totalIncompleteTasksCount), Goals: \(totalUpcomingGoalsCount)") // Debugging log
    }

    // New method for modern dashboard
    @MainActor
    func refreshData() async {
        // Call existing method
        fetchDashboardData()

        // Update quick stats
        updateQuickStats()

        // Generate recent activities
        generateRecentActivities()

        // Generate upcoming items
        generateUpcomingItems()

        print("Dashboard refresh completed") // Debugging log
    }

    private func updateQuickStats() {
        let allTasks = TaskDataManager.shared.load()
        let allGoals = GoalDataManager.shared.load()

        self.totalTasks = allTasks.count
        self.completedTasks = allTasks.filter(\.isCompleted).count
        self.totalGoals = allGoals.count
        self.completedGoals = 0 // Goal completion not yet implemented
        self.todayEvents = self.totalTodaysEventsCount
    }

    private func generateRecentActivities() {
        var activities: [DashboardActivity] = []

        // Add completed tasks from last few days
        let allTasks = TaskDataManager.shared.load()
        let recentCompletedTasks = allTasks.filter { task in
            // Only include tasks that are actually completed AND were created or completed recently
            task.isCompleted &&
                (Calendar.current.isDateInYesterday(task.createdAt) ||
                    Calendar.current.isDateInToday(task.createdAt))
        }.prefix(3)

        for task in recentCompletedTasks {
            activities.append(DashboardActivity(
                title: "Completed Task",
                subtitle: task.title,
                icon: "checkmark.circle.fill",
                color: .green,
                timestamp: task.createdAt
            ))
        }

        // Add recent events
        let allEvents = CalendarDataManager.shared.load()
        let recentEvents = allEvents.filter { event in
            Calendar.current.isDateInYesterday(event.date) || Calendar.current.isDateInToday(event.date)
        }.prefix(2)

        for event in recentEvents {
            activities.append(DashboardActivity(
                title: "Event",
                subtitle: event.title,
                icon: "calendar",
                color: .orange,
                timestamp: event.date
            ))
        }

        self.recentActivities = activities.sorted { $0.timestamp > $1.timestamp }
    }

    private func generateUpcomingItems() {
        var items: [UpcomingItem] = []

        // Add upcoming events
        let allEvents = CalendarDataManager.shared.load()
        let futureEvents = allEvents.filter { $0.date > Date() }.prefix(3)

        for event in futureEvents {
            items.append(UpcomingItem(
                title: event.title,
                subtitle: "Event",
                date: event.date,
                icon: "calendar",
                color: .orange
            ))
        }

        // Add upcoming goals
        let allGoals = GoalDataManager.shared.load()
        let futureGoals = allGoals.filter { $0.targetDate > Date() }.prefix(2)

        for goal in futureGoals {
            items.append(UpcomingItem(
                title: goal.title,
                subtitle: "Goal deadline",
                date: goal.targetDate,
                icon: "target",
                color: .green
            ))
        }

        self.upcomingItems = items.sorted { $0.date < $1.date }
    }

    // Helper function to clear all published data, typically used on error.
    private func resetData() {
        self.todaysEvents = []
        self.incompleteTasks = []
        self.upcomingGoals = []
        self.totalTodaysEventsCount = 0
        self.totalIncompleteTasksCount = 0
        self.totalUpcomingGoalsCount = 0

        // Reset modern dashboard data
        self.recentActivities = []
        self.upcomingItems = []

        // Reset full data arrays
        self.allGoals = []
        self.allEvents = []
        self.allJournalEntries = []

        self.totalTasks = 0
        self.completedTasks = 0
        self.totalGoals = 0
        self.completedGoals = 0
        self.todayEvents = 0

        print("Dashboard data reset.") // Debugging log
    }
}
