//
//  CalendarDataManager.swift
//  PlannerApp
//
//  Created by Daniel Stevens on 4/29/25.
//

// PlannerApp/DataManagers/CalendarDataManager.swift
// (New file with error handling)
import Foundation
import OSLog

class CalendarDataManager {
    static let shared = CalendarDataManager()
    private let eventKey = "savedCalendarEvents"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "CalendarDataManager")

    private init() {}

    func save(events: [CalendarEvent]) {
        let encoder = JSONEncoder()
        do {
            let encoded = try encoder.encode(events)
            UserDefaults.standard.set(encoded, forKey: eventKey)
            logger.info("Calendar events saved successfully.")
        } catch {
            logger.error("Failed to encode calendar events: \(error.localizedDescription)")
        }
    }

    func load() -> [CalendarEvent] {
        guard let savedData = UserDefaults.standard.data(forKey: eventKey) else {
            logger.info("No saved calendar event data found.")
            return []
        }

        let decoder = JSONDecoder()
        do {
            let loadedEvents = try decoder.decode([CalendarEvent].self, from: savedData)
            logger.info("Calendar events loaded successfully.")
            return loadedEvents
        } catch {
            logger.error("Failed to decode calendar events: \(error.localizedDescription)")
            return []
        }
    }
}
