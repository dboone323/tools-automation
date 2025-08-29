// CloudKitMigrationHelper.swift - Handles migration of local data to CloudKit
import Foundation
import CloudKit
import SwiftUI

@MainActor
class CloudKitMigrationHelper {
    static let shared = CloudKitMigrationHelper()
    
    private let migrationKey = "hasPerformedCloudKitMigration"
    private let cloudKitManager = EnhancedCloudKitManager.shared // Changed to EnhancedCloudKitManager
    
    private init() {}
    
    /// Checks if data migration from local storage to CloudKit is needed and performs it if necessary
    func checkAndPerformMigrationIfNeeded() async -> Bool {
        // Check if migration has already been performed
        if UserDefaults.standard.bool(forKey: migrationKey) {
            return false // Migration already complete
        }
        
        // Don't migrate if not signed in to iCloud
        guard cloudKitManager.isSignedInToiCloud else {
            return false
        }
        
        do {
            // Perform migration for all data types
            try await migrateTasksToCloudKit()
            try await migrateGoalsToCloudKit()
            try await migrateEventsToCloudKit()
            try await migrateJournalEntriesToCloudKit()
            
            // Mark migration as complete
            UserDefaults.standard.set(true, forKey: migrationKey)
            return true
        } catch {
            print("Error during data migration to CloudKit: \(error)")
            return false
        }
    }
    
    /// Offers to reset migration status (useful for debugging or if migration failed)
    func resetMigrationStatus() {
        UserDefaults.standard.set(false, forKey: migrationKey)
    }
    
    /// Handle user decision about merging existing data when setting up on new device
    func handleNewDeviceSetup(mergeData: Bool) async {
        if mergeData {
            // User chose to merge existing data with iCloud data
            // Proceed with normal sync but keep local data
            await cloudKitManager.performSync()
        } else {
            // User chose to use only iCloud data, discard local data
            await clearLocalData()
            await cloudKitManager.performSync()
        }
    }
    
    // MARK: - Private Methods
    
    private func migrateTasksToCloudKit() async throws {
        // Simplified implementation with empty array
        let tasks: [Task] = [] // Use direct Task type
        
        print("Migrating tasks to CloudKit - stub implementation")
        
        // Batch process tasks to CloudKit
        try await cloudKitManager.uploadTasks(tasks)
    }
    
    private func migrateGoalsToCloudKit() async throws {
        // Simplified implementation with empty array
        let goals: [Goal] = [] // Use direct Goal type
        
        print("Migrating goals to CloudKit - stub implementation")
        
        // Batch process goals to CloudKit
        try await cloudKitManager.uploadGoals(goals)
    }
    
    private func migrateEventsToCloudKit() async throws {
        // Simplified implementation with empty array
        let events: [CalendarEvent] = [] // Use direct CalendarEvent type
        
        print("Migrating calendar events to CloudKit - stub implementation")
        
        // Batch process events to CloudKit
        try await cloudKitManager.uploadEvents(events)
    }
    
    private func migrateJournalEntriesToCloudKit() async throws {
        // Simplified implementation with empty array
        let entries: [JournalEntry] = [] // Use direct JournalEntry type
        
        print("Migrating journal entries to CloudKit - stub implementation")
        
        // Batch process journal entries to CloudKit
        try await cloudKitManager.uploadJournalEntries(entries)
    }
    
    private func clearLocalData() async {
        // Simplified implementation that just clears UserDefaults
        print("Clearing local data - stub implementation")
        
        // Clear data from UserDefaults
        let defaults = UserDefaults.standard
        defaults.removeObject(forKey: "savedTasks")
        defaults.removeObject(forKey: "savedGoals")
        defaults.removeObject(forKey: "savedEvents")
        defaults.removeObject(forKey: "savedJournalEntries")
    }
}