//
//  TaskDataManager.swift
//  PlannerApp
//
//  Created by Daniel Stevens on 4/29/25.
//


// PlannerApp/DataManagers/TaskDataManager.swift
// (New file with error handling - inferred necessity)
import Foundation
import OSLog

class TaskDataManager {
    static let shared = TaskDataManager()
    private let taskKey = "savedTasks"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "TaskDataManager")

    private init() {}

    func save(tasks: [Task]) {
        let encoder = JSONEncoder()
        do {
            let encoded = try encoder.encode(tasks)
            UserDefaults.standard.set(encoded, forKey: taskKey)
            logger.info("Tasks saved successfully.")
        } catch {
            logger.error("Failed to encode tasks: \(error.localizedDescription)")
        }
    }

    func load() -> [Task] {
        guard let savedData = UserDefaults.standard.data(forKey: taskKey) else {
            logger.info("No saved task data found.")
            return []
        }

        let decoder = JSONDecoder()
        do {
            let loadedTasks = try decoder.decode([Task].self, from: savedData)
            logger.info("Tasks loaded successfully.")
            return loadedTasks
        } catch {
            logger.error("Failed to decode tasks: \(error.localizedDescription)")
            return []
        }
    }
}