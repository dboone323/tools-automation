// PlannerApp/DataManagers/GoalDataManager.swift
// (Updated with error handling)
import Foundation
import OSLog // Import OSLog for better logging

class GoalDataManager {
    static let shared = GoalDataManager()
    private let goalKey = "savedGoals"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "GoalDataManager")

    private init() {} // Make init private for Singleton

    func save(goals: [Goal]) {
        let encoder = JSONEncoder()
        do {
            let encoded = try encoder.encode(goals)
            UserDefaults.standard.set(encoded, forKey: goalKey)
            logger.info("Goals saved successfully.")
        } catch {
            logger.error("Failed to encode goals: \(error.localizedDescription)")
            // Consider notifying the user or handling the error more gracefully
        }
    }

    func load() -> [Goal] {
        guard let savedData = UserDefaults.standard.data(forKey: goalKey) else {
            logger.info("No saved goal data found.")
            return [] // Return empty array if no data exists
        }

        let decoder = JSONDecoder()
        do {
            let loadedGoals = try decoder.decode([Goal].self, from: savedData)
            logger.info("Goals loaded successfully.")
            return loadedGoals
        } catch {
            logger.error("Failed to decode goals: \(error.localizedDescription)")
            // Consider removing the corrupted data or attempting migration
            // UserDefaults.standard.removeObject(forKey: goalKey)
            return [] // Return empty array on decoding failure
        }
    }
}
