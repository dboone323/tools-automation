//
//  JournalDataManager.swift
//  PlannerApp
//
//  Created by Daniel Stevens on 4/29/25.
//

// PlannerApp/DataManagers/JournalDataManager.swift
// (New file with error handling - inferred necessity)
import Foundation
import OSLog

class JournalDataManager {
    static let shared = JournalDataManager()
    private let entryKey = "savedJournalEntries"
    private let logger = Logger(subsystem: Bundle.main.bundleIdentifier!, category: "JournalDataManager")

    private init() {}

    func save(entries: [JournalEntry]) {
        let encoder = JSONEncoder()
        do {
            let encoded = try encoder.encode(entries)
            UserDefaults.standard.set(encoded, forKey: entryKey)
            logger.info("Journal entries saved successfully.")
        } catch {
            logger.error("Failed to encode journal entries: \(error.localizedDescription)")
        }
    }

    func load() -> [JournalEntry] {
        guard let savedData = UserDefaults.standard.data(forKey: entryKey) else {
            logger.info("No saved journal entry data found.")
            return []
        }

        let decoder = JSONDecoder()
        do {
            let loadedEntries = try decoder.decode([JournalEntry].self, from: savedData)
            logger.info("Journal entries loaded successfully.")
            return loadedEntries
        } catch {
            logger.error("Failed to decode journal entries: \(error.localizedDescription)")
            return []
        }
    }
}
