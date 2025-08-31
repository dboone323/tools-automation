// DataManagers.swift
// This file contains stub implementations for data managers referenced in CloudKitMigrationHelper

import Foundation

// Task Data Manager
class TaskDataManager {
    static let shared = TaskDataManager()

    var tasks: [Task] = []

    func clearAllTasks() {
        tasks.removeAll()
    }

    private init() {}
}

// Goal Data Manager
class GoalDataManager {
    static let shared = GoalDataManager()

    var goals: [Goal] = []

    func clearAllGoals() {
        goals.removeAll()
    }

    private init() {}
}

// Calendar Data Manager
class CalendarDataManager {
    static let shared = CalendarDataManager()

    var events: [CalendarEvent] = []

    func clearAllEvents() {
        events.removeAll()
    }

    private init() {}
}

// Journal Data Manager
class JournalDataManager {
    static let shared = JournalDataManager()

    var entries: [JournalEntry] = []

    func clearAllEntries() {
        entries.removeAll()
    }

    private init() {}
}

// Stub Model Classes
struct Goal: Identifiable, Codable {
    var id = UUID()
    var title: String
    var description: String
    var targetDate: Date?
    var isCompleted: Bool

    // Default initializer with default values
    init(id: UUID = UUID(), title: String = "", description: String = "", targetDate: Date? = nil, isCompleted: Bool = false) {
        self.id = id
        self.title = title
        self.description = description
        self.targetDate = targetDate
        self.isCompleted = isCompleted
    }
}

struct CalendarEvent: Identifiable, Codable {
    var id = UUID()
    var title: String
    var startTime: Date
    var endTime: Date
    var location: String?
    var notes: String?

    // Default initializer with default values
    init(id: UUID = UUID(), title: String = "", startTime: Date = Date(), endTime: Date = Date().addingTimeInterval(3600), location: String? = nil, notes: String? = nil) {
        self.id = id
        self.title = title
        self.startTime = startTime
        self.endTime = endTime
        self.location = location
        self.notes = notes
    }
}

struct JournalEntry: Identifiable, Codable {
    var id = UUID()
    var title: String
    var content: String
    var date: Date
    var mood: Int?
    var tags: [String]?

    // Default initializer with default values
    init(id: UUID = UUID(), title: String = "", content: String = "", date: Date = Date(), mood: Int? = nil, tags: [String]? = nil) {
        self.id = id
        self.title = title
        self.content = content
        self.date = date
        self.mood = mood
        self.tags = tags
    }
}
