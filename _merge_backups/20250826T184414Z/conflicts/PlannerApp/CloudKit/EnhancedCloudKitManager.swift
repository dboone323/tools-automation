//
//  EnhancedCloudKitManager.swift
//  PlannerApp
//
//  Enhanced CloudKit integration with better sync, conflict resolution, and status reporting
//

import SwiftUI
import CloudKit
import Combine
import Network // For NWPathMonitor

// Import utilities and models
import Foundation

// Typealias to prevent conflict with Task model
typealias AsyncTask = _Concurrency.Task
typealias PlannerTask = Task

@MainActor
class EnhancedCloudKitManager: ObservableObject {
    static let shared = EnhancedCloudKitManager()
    
    @Published var isSignedInToiCloud = false
    @Published var syncStatus: SyncStatus = .idle
    @Published var lastSyncDate: Date?
    @Published var syncProgress: Double = 0.0
    @Published var conflictItems: [SyncConflict] = []
    @Published var errorMessage: String?
    @Published var currentError: CloudKitError?
    @Published var showErrorAlert = false
    
    private let container: CKContainer
    internal let database: CKDatabase // Changed to internal so extensions can access
    private var subscriptions = Set<AnyCancellable>()
    #if os(iOS)
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    #endif
    
    enum SyncStatus: Equatable {
        case idle
        case syncing
        case success
        case error(CloudKitError)
        case conflictResolutionNeeded
        case temporarilyUnavailable
        
        static func == (lhs: SyncStatus, rhs: SyncStatus) -> Bool {
            switch (lhs, rhs) {
            case (.idle, .idle), (.syncing, .syncing), (.success, .success),
                 (.conflictResolutionNeeded, .conflictResolutionNeeded),
                 (.temporarilyUnavailable, .temporarilyUnavailable):
                return true
            case (.error(let lhsError), .error(let rhsError)):
                return lhsError.id == rhsError.id
            default:
                return false
            }
        }
        
        var isActive: Bool {
            switch self {
            case .syncing, .conflictResolutionNeeded:
                return true
            default:
                return false
            }
        }
        
        var description: String {
            switch self {
            case .idle: return "Ready to sync"
            case .syncing: return "Syncing..."
            case .success: return "Sync completed"
            case .error(let error): return "Sync error: \(error.localizedDescription)"
            case .conflictResolutionNeeded: return "Conflicts need resolution"
            case .temporarilyUnavailable: return "Sync temporarily unavailable"
            }
        }
    }
    
    struct SyncConflict: Identifiable {
        let id = UUID()
        let recordID: CKRecord.ID
        let localRecord: CKRecord
        let serverRecord: CKRecord
        let type: ConflictType
        
        enum ConflictType {
            case modified
            case deleted
            case created
        }
    }
    
    // Enhanced CloudKit error types for better user feedback
    enum CloudKitError: Error, Identifiable {
        case notSignedIn
        case networkIssue
        case permissionDenied
        case quotaExceeded
        case deviceBusy
        case serverError
        case accountChanged
        case containerUnavailable
        case conflictDetected
        case unknownError(Error)
        
        var id: String { localizedDescription }
        
        // Provide a user-friendly message
        var localizedDescription: String {
            switch self {
            case .notSignedIn:
                return "You're not signed in to iCloud"
            case .networkIssue:
                return "Network connection issue"
            case .permissionDenied:
                return "iCloud access was denied"
            case .quotaExceeded:
                return "Your iCloud storage is full"
            case .deviceBusy:
                return "Your device is busy"
            case .serverError:
                return "iCloud server issue"
            case .accountChanged:
                return "Your iCloud account has changed"
            case .containerUnavailable:
                return "iCloud container unavailable"
            case .conflictDetected:
                return "Data conflict detected"
            case .unknownError(let error):
                return "Unexpected error: \(error.localizedDescription)"
            }
        }
        
        // Provide a detailed explanation
        var explanation: String {
            switch self {
            case .notSignedIn:
                return "You need to be signed in to iCloud to enable syncing across your devices."
            case .networkIssue:
                return "There seems to be an issue with your internet connection."
            case .permissionDenied:
                return "This app doesn't have permission to access your iCloud data."
            case .quotaExceeded:
                return "You've reached your iCloud storage limit, which prevents syncing new data."
            case .deviceBusy:
                return "Your device is currently busy processing other tasks."
            case .serverError:
                return "Apple's iCloud servers are experiencing technical difficulties."
            case .accountChanged:
                return "Your iCloud account has changed since the last sync."
            case .containerUnavailable:
                return "The app's iCloud container couldn't be accessed."
            case .conflictDetected:
                return "Changes were made to the same data on multiple devices."
            case .unknownError:
                return "An unexpected error occurred while syncing your data."
            }
        }
        
        // Provide a recovery suggestion
        var recoverySuggestion: String {
            switch self {
            case .notSignedIn:
                #if os(iOS)
                return "Go to Settings → Apple ID → iCloud and sign in with your Apple ID."
                #else
                return "Go to System Settings → Apple ID → iCloud and sign in with your Apple ID."
                #endif
            case .networkIssue:
                return "Check your Wi-Fi connection or cellular data. Try syncing again when your connection improves."
            case .permissionDenied:
                #if os(iOS)
                return "Go to Settings → Apple ID → iCloud → Apps Using iCloud and enable this app."
                #else
                return "Go to System Settings → Apple ID → iCloud and ensure this app is enabled."
                #endif
            case .quotaExceeded:
                #if os(iOS)
                return "Go to Settings → Apple ID → iCloud → Manage Storage to free up space or upgrade your storage plan."
                #else
                return "Go to System Settings → Apple ID → iCloud → Manage Storage to free up space."
                #endif
            case .deviceBusy:
                return "Close some other apps and try again. If the issue persists, restart your device."
            case .serverError:
                return "This is a temporary issue with Apple's servers. Please try again after a while."
            case .accountChanged:
                return "Sign in to your current iCloud account in Settings, then restart the app."
            case .containerUnavailable:
                return "Check that iCloud is enabled for this app in Settings. If the issue persists, restart your device."
            case .conflictDetected:
                return "Review the conflicted items and choose which version to keep."
            case .unknownError:
                return "Try restarting the app. If the issue continues, please contact support."
            }
        }
        
        // Suggest an action the user can take
        var actionLabel: String {
            switch self {
            case .notSignedIn:
                return "Open Settings"
            case .networkIssue:
                return "Check Connection"
            case .permissionDenied:
                return "Open iCloud Settings"
            case .quotaExceeded:
                return "Manage Storage"
            case .deviceBusy, .serverError, .containerUnavailable:
                return "Try Again"
            case .accountChanged:
                return "Open Settings"
            case .conflictDetected:
                return "Review Conflicts"
            case .unknownError:
                return "Restart App"
            }
        }
        
        // Convert from CKError to CloudKitError
        static func fromCKError(_ error: Error) -> CloudKitError {
            guard let ckError = error as? CKError else {
                return .unknownError(error)
            }
            
            switch ckError.code {
            case .notAuthenticated, .badContainer:
                return .notSignedIn
            case .networkFailure, .networkUnavailable, .serverRejectedRequest, .serviceUnavailable:
                return .networkIssue
            case .permissionFailure:
                return .permissionDenied
            case .quotaExceeded:
                return .quotaExceeded
            case .zoneBusy, .resultsTruncated:
                return .deviceBusy
            case .serverRecordChanged, .batchRequestFailed, .assetFileNotFound:
                return .serverError
            case .changeTokenExpired, .accountTemporarilyUnavailable:
                return .accountChanged
            default:
                return .unknownError(error)
            }
        }
    }
    
    private init() {
        container = CKContainer.default()
        database = container.privateCloudDatabase
        
        checkiCloudStatus()
        setupSubscriptions()
        monitorAccountStatus()
    }
    
    // MARK: - iCloud Status
    private func checkiCloudStatus() {
        container.accountStatus { [weak self] status, error in
            // This completion handler is already dispatched to main by CloudKit in some cases,
            // but to be safe and explicit, especially if behavior changes or is inconsistent:
            AsyncTask { @MainActor [weak self] in
                guard let self = self else { return }
                self.isSignedInToiCloud = status == .available
                
                if let error = error {
                    self.handleError(CloudKitError.fromCKError(error))
                }
            }
        }
    }
    
    // MARK: - Subscription Setup
    private func setupSubscriptions() {
        // Setup CloudKit subscriptions for real-time updates
        setupTaskSubscription()
        setupGoalSubscription()
        setupEventSubscription()
        setupJournalSubscription()
    }
    
    private func setupTaskSubscription() {
        let predicate = NSPredicate(value: true)
        
        // Using the non-deprecated initializer
        let subscription = CKQuerySubscription(
            recordType: "Task",
            predicate: predicate,
            subscriptionID: "task-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        
        database.save(subscription) { [weak self] _, error in
            if let error = error {
                AsyncTask { @MainActor [weak self] in
                    self?.handleError(error)
                }
            }
        }
    }
    
    private func setupGoalSubscription() {
        let predicate = NSPredicate(value: true)
        
        // Using the non-deprecated initializer
        let subscription = CKQuerySubscription(
            recordType: "Goal",
            predicate: predicate,
            subscriptionID: "goal-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        
        database.save(subscription) { [weak self] _, error in
            if let error = error {
                AsyncTask { @MainActor [weak self] in
                    self?.handleError(error)
                }
            }
        }
    }
    
    private func setupEventSubscription() {
        let predicate = NSPredicate(value: true)
        
        // Using the non-deprecated initializer
        let subscription = CKQuerySubscription(
            recordType: "CalendarEvent",
            predicate: predicate,
            subscriptionID: "event-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        
        database.save(subscription) { [weak self] _, error in
            if let error = error {
                AsyncTask { @MainActor [weak self] in
                    self?.handleError(error)
                }
            }
        }
    }
    
    private func setupJournalSubscription() {
        let predicate = NSPredicate(value: true)
        
        // Using the non-deprecated initializer
        let subscription = CKQuerySubscription(
            recordType: "JournalEntry",
            predicate: predicate,
            subscriptionID: "journal-changes",
            options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
        )
        
        let info = CKSubscription.NotificationInfo()
        info.shouldSendContentAvailable = true
        subscription.notificationInfo = info
        
        database.save(subscription) { [weak self] _, error in
            if let error = error {
                AsyncTask { @MainActor [weak self] in
                    self?.handleError(error)
                }
            }
        }
    }
    
    // MARK: - Enhanced Sync Operations
    func performFullSync() async {
        guard isSignedInToiCloud else {
            handleError(CloudKitError.notSignedIn)
            return
        }
        
        syncStatus = .syncing
        syncProgress = 0.0
        errorMessage = nil
        
        do {
            // Start background task
            beginBackgroundTask()
            
            // Sync in phases
            try await syncTasks()
            syncProgress = 0.25
            
            try await syncGoals()
            syncProgress = 0.50
            
            try await syncEvents()
            syncProgress = 0.75
            
            try await syncJournalEntries()
            syncProgress = 1.0
            
            lastSyncDate = Date()
            syncStatus = .success
            
            // Save sync timestamp
            UserDefaults.standard.set(lastSyncDate, forKey: "LastCloudKitSync")
            
        } catch {
            handleError(error)
        }
        
        endBackgroundTask()
    }
    
    func performSync() async {
        await performFullSync()
    }
    
    private func syncTasks() async throws {
        // Fetch remote tasks
        let query = CKQuery(recordType: "Task", predicate: NSPredicate(value: true))
        let (records, _) = try await database.records(matching: query)
        
        var conflicts: [SyncConflict] = []
        
        for (_, result) in records {
            switch result {
            case .success(let record):
                // Check for conflicts with local data
                if let conflict = checkForTaskConflict(record) {
                    conflicts.append(conflict)
                } else {
                    // Merge non-conflicting changes
                    await mergeTaskRecord(record)
                }
            case .failure(let error):
                handleError(error)
            }
        }
        
        if !conflicts.isEmpty {
            conflictItems.append(contentsOf: conflicts)
            syncStatus = .conflictResolutionNeeded
        }
    }
    
    private func syncGoals() async throws {
        let query = CKQuery(recordType: "Goal", predicate: NSPredicate(value: true))
        let (records, _) = try await database.records(matching: query)
        
        for (_, result) in records {
            switch result {
            case .success(let record):
                if let conflict = checkForGoalConflict(record) {
                    conflictItems.append(conflict)
                } else {
                    await mergeGoalRecord(record)
                }
            case .failure(let error):
                handleError(error)
            }
        }
    }
    
    private func syncEvents() async throws {
        let query = CKQuery(recordType: "CalendarEvent", predicate: NSPredicate(value: true))
        let (records, _) = try await database.records(matching: query)
        
        for (_, result) in records {
            switch result {
            case .success(let record):
                if let conflict = checkForEventConflict(record) {
                    conflictItems.append(conflict)
                } else {
                    await mergeEventRecord(record)
                }
            case .failure(let error):
                handleError(error)
            }
        }
    }
    
    private func syncJournalEntries() async throws {
        let query = CKQuery(recordType: "JournalEntry", predicate: NSPredicate(value: true))
        let (records, _) = try await database.records(matching: query)
        
        for (_, result) in records {
            switch result {
            case .success(let record):
                if let conflict = checkForJournalConflict(record) {
                    conflictItems.append(conflict)
                } else {
                    await mergeJournalRecord(record)
                }
            case .failure(let error):
                handleError(error)
            }
        }
    }
    
    // MARK: - Conflict Detection
    private func checkForTaskConflict(_ record: CKRecord) -> SyncConflict? {
        // Implementation would check local records against CloudKit records
        // Return conflict if modification dates don't match
        return nil
    }
    
    private func checkForGoalConflict(_ record: CKRecord) -> SyncConflict? {
        return nil
    }
    
    private func checkForEventConflict(_ record: CKRecord) -> SyncConflict? {
        return nil
    }
    
    private func checkForJournalConflict(_ record: CKRecord) -> SyncConflict? {
        return nil
    }
    
    // MARK: - Record Merging
    private func mergeTaskRecord(_ record: CKRecord) async {
        // Implementation would merge CloudKit record with local data
    }
    
    private func mergeGoalRecord(_ record: CKRecord) async {
        // Implementation would merge CloudKit record with local data
    }
    
    private func mergeEventRecord(_ record: CKRecord) async {
        // Implementation would merge CloudKit record with local data
    }
    
    private func mergeJournalRecord(_ record: CKRecord) async {
        // Implementation would merge CloudKit record with local data
    }
    
    // MARK: - Conflict Resolution
    func resolveConflict(_ conflict: SyncConflict, useLocal: Bool) async {
        let recordToSave = useLocal ? conflict.localRecord : conflict.serverRecord
        
        do {
            _ = try await database.save(recordToSave)
            
            // Remove resolved conflict
            conflictItems.removeAll { $0.id == conflict.id }
            
            // Check if all conflicts resolved
            if conflictItems.isEmpty {
                syncStatus = .success
            }
        } catch {
            handleError(error)
        }
    }
    
    func resolveAllConflicts(useLocal: Bool) async {
        for conflict in conflictItems {
            await resolveConflict(conflict, useLocal: useLocal)
        }
    }
    
    // MARK: - Background Task Management
    private func beginBackgroundTask() {
        #if os(iOS)
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: "CloudKit Sync") {
            self.endBackgroundTask()
        }
        #endif
    }
    
    private func endBackgroundTask() {
        #if os(iOS)
        if backgroundTask != .invalid {
            UIApplication.shared.endBackgroundTask(backgroundTask)
            backgroundTask = .invalid
        }
        #endif
    }
    
    // MARK: - Auto Sync Configuration
    func configureAutoSync(interval: TimeInterval) {
        Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            
            AsyncTask { @MainActor in
                await self.performFullSync()
            }
        }
    }
    
    // MARK: - Manual Operations
    func forcePushLocalChanges() async {
        // Implementation to force push all local changes to CloudKit
        syncStatus = .syncing
        
        do {
            // Push tasks, goals, events, journal entries
            try await pushLocalTasks()
            try await pushLocalGoals()
            try await pushLocalEvents()
            try await pushLocalJournalEntries()
            
            syncStatus = .success
            lastSyncDate = Date()
        } catch {
            handleError(error)
        }
    }
    
    func requestiCloudAccess() async {
        // Request iCloud access and update status
        syncStatus = .syncing
        
        do {
            let accountStatus = try await container.accountStatus()
            switch accountStatus {
            case .available:
                isSignedInToiCloud = true
                syncStatus = .success
            case .noAccount, .restricted:
                isSignedInToiCloud = false
                syncStatus = .error(.notSignedIn)
            case .couldNotDetermine, .temporarilyUnavailable:
                syncStatus = .temporarilyUnavailable
            @unknown default:
                syncStatus = .error(.unknownError(CKError(CKError.Code.internalError)))
            }
        } catch {
            handleError(error)
        }
    }
    
    func handleNewDeviceLogin() async {
        // Handle setup for new device login
        await performFullSync()
    }
    
    private func pushLocalTasks() async throws {
        // Implementation to push local tasks to CloudKit
    }
    
    private func pushLocalGoals() async throws {
        // Implementation to push local goals to CloudKit
    }
    
    private func pushLocalEvents() async throws {
        // Implementation to push local events to CloudKit
    }
    
    private func pushLocalJournalEntries() async throws {
        // Implementation to push local journal entries to CloudKit
    }
    
    func resetCloudKitData() async {
        // Implementation to clear all CloudKit data
        syncStatus = .syncing
        
        do {
            let query = CKQuery(recordType: "Task", predicate: NSPredicate(value: true))
            let (records, _) = try await database.records(matching: query)
            
            let recordIDs = records.compactMap { _, result in
                switch result {
                case .success(let record):
                    return record.recordID
                case .failure:
                    return nil
                }
            }
            
            if !recordIDs.isEmpty {
                _ = try await database.modifyRecords(saving: [], deleting: recordIDs)
            }
            
            syncStatus = .success
        } catch {
            handleError(error)
        }
    }
    
    // Methods to handle CloudKit errors
    func handleError(_ error: Error) {
        let cloudKitError = CloudKitError.fromCKError(error)
        errorMessage = cloudKitError.localizedDescription
        currentError = cloudKitError
        syncStatus = .error(cloudKitError)
        showErrorAlert = true
        
        // Log error for diagnostics
        print("CloudKit error: \(cloudKitError.localizedDescription) - \(cloudKitError.recoverySuggestion)")
        
        // Take automatic recovery steps based on error type
        switch cloudKitError {
        case .networkIssue:
            scheduleRetryWhenNetworkAvailable()
        case .accountChanged:
            resetSyncState()
        case .quotaExceeded:
            adjustSyncForLowStorage()
        default:
            break
        }
    }
    
    // Auto-retry logic when network becomes available
    private func scheduleRetryWhenNetworkAvailable() {
        // Ensure NetworkMonitor.shared is accessible
        // If NetworkMonitor is in the same module, it should be directly usable.
        if NetworkMonitor.shared.isConnected {
            // Retry immediately if connected
            AsyncTask { @MainActor in
                try? await self.retryFailedOperations()
            }
        } else {
            // Observe network status changes
            NotificationCenter.default.addObserver(forName: .networkStatusChanged, object: nil, queue: .main) { [weak self] _ in
                guard let self = self else { return }
                AsyncTask { @MainActor in
                    await self.checkNetworkAndRetry()
                }
            }
        }
    }
    
    private func checkNetworkAndRetry() async {
        // Implementation would check if network is available and retry sync
        // Note: NetworkMonitor.shared.isConnected would be used here if available
        AsyncTask { @MainActor in
            try? await self.retryFailedOperations()
        }
    }
    
    private func retryFailedOperations() async throws {
        // Implementation would retry operations that failed due to network issues
    }
    
    // Reset sync state when account changes
    private func resetSyncState() {
        // Reset change tokens and other sync state
        AsyncTask { @MainActor in
            await resetSyncTokens()
            await checkAccountStatus()
        }
    }
    
    private func resetSyncTokens() async {
        // Implementation would reset all CloudKit change tokens
    }
    
    // Adjust sync behavior for low storage
    private func adjustSyncForLowStorage() {
        // Prioritize essential data and reduce optional data when storage is low
        // For example, sync text data but skip images/attachments
    }
    
    // Monitor iCloud account changes
    func monitorAccountStatus() {
        NotificationCenter.default.addObserver(forName: .CKAccountChanged, object: nil, queue: .main) { [weak self] _ in
            AsyncTask { @MainActor [weak self] in
                guard let self = self else { return }
                self.currentError = .accountChanged
                self.showErrorAlert = true
                self.syncStatus = .error(.accountChanged)
                await self.accountStatusChanged() // Call the async version
            }
        }
    }
    
    @objc private func accountStatusChanged() async {
        await checkAccountStatus()
    }
    
    func checkAccountStatus() async {
        // Implementation checks account status
        do {
            _ = try await container.accountStatus() // status was unused, marked with _
            // Update local state based on account status
        } catch {
            AsyncTask { @MainActor [weak self] in
                self?.handleError(CloudKitError.fromCKError(error))
            }
        }
    }
    
    func uploadTasks(_ tasks: [Task]) async throws {
        // Stub implementation for task uploading
        print("Uploading \(tasks.count) tasks to CloudKit")
    }
    
    func uploadGoals(_ goals: [Goal]) async throws {
        // Stub implementation for goal uploading
        print("Uploading \(goals.count) goals to CloudKit")
    }
    
    func uploadEvents(_ events: [CalendarEvent]) async throws {
        // Stub implementation for event uploading
        print("Uploading \(events.count) events to CloudKit")
    }
    
    func uploadJournalEntries(_ entries: [JournalEntry]) async throws {
        // Stub implementation for journal entry uploading
        print("Uploading \(entries.count) journal entries to CloudKit")
    }
    
    // Placeholder local fetch/save methods - these should call your DataManagers
    // These need to be implemented properly by interacting with your existing DataManagers
    private func fetchLocalTasks() async throws -> [PlannerTask] {
        return TaskDataManager.shared.load()
    }
    private func saveLocalTasks(_ tasks: [PlannerTask]) async throws {
        TaskDataManager.shared.save(tasks: tasks)
    }
    private func fetchLocalGoals() async throws -> [Goal] {
        return GoalDataManager.shared.load()
    }
    private func saveLocalGoals(_ goals: [Goal]) async throws {
        GoalDataManager.shared.save(goals: goals)
    }
    private func fetchLocalEvents() async throws -> [CalendarEvent] {
        return CalendarDataManager.shared.load()
    }
    private func saveLocalEvents(_ events: [CalendarEvent]) async throws {
        CalendarDataManager.shared.save(events: events)
    }
    private func fetchLocalJournalEntries() async throws -> [JournalEntry] {
        return JournalDataManager.shared.load()
    }
    private func saveLocalJournalEntries(_ entries: [JournalEntry]) async throws {
        JournalDataManager.shared.save(entries: entries)
    }
}

// MARK: - Enhanced Sync Status View
struct EnhancedSyncStatusView: View {
    @ObservedObject var cloudKit = EnhancedCloudKitManager.shared
    @EnvironmentObject var themeManager: ThemeManager
    
    let showLabel: Bool
    let compact: Bool
    
    init(showLabel: Bool = false, compact: Bool = false) {
        self.showLabel = showLabel
        self.compact = compact
    }
    
    var body: some View {
        HStack(spacing: 8) {
            syncIndicator
            
            if showLabel {
                VStack(alignment: .leading, spacing: 2) {
                    Text(statusText)
                        .font(compact ? .caption : .body)
                        .foregroundColor(statusColor)
                    
                    if let lastSync = cloudKit.lastSyncDate {
                        Text("Last sync: \(lastSync, style: .relative)")
                            .font(.caption2)
                            .foregroundColor(themeManager.currentTheme.secondaryTextColor)
                    }
                    
                    if cloudKit.syncStatus.isActive {
                        ProgressView(value: cloudKit.syncProgress)
                            .progressViewStyle(LinearProgressViewStyle())
                            .frame(width: 100)
                    }
                }
            }
        }
        .onTapGesture {
            if case .error = cloudKit.syncStatus {
                AsyncTask { @MainActor in
                    await cloudKit.performFullSync()
                }
            }
        }
    }
    
    private var syncIndicator: some View {
        Group {
            switch cloudKit.syncStatus {
            case .syncing:
                ProgressView()
                    .scaleEffect(0.8)
            case .success:
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            case .error:
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.red)
            case .conflictResolutionNeeded:
                Image(systemName: "arrow.triangle.2.circlepath")
                    .foregroundColor(.orange)
            case .idle:
                Image(systemName: "cloud")
                    .foregroundColor(.secondary)
            case .temporarilyUnavailable:
                Image(systemName: "cloud.slash")
                    .foregroundColor(.orange)
            }
        }
        .font(compact ? .caption : .body)
    }
    
    private var statusText: String {
        if !cloudKit.isSignedInToiCloud {
            return "Not signed into iCloud"
        }
        
        return cloudKit.syncStatus.description
    }
    
    private var statusColor: Color {
        if !cloudKit.isSignedInToiCloud {
            return .secondary
        }
        
        switch cloudKit.syncStatus {
        case .idle:
            return .secondary
        case .syncing:
            return .blue
        case .success:
            return .green
        case .error:
            return .red
        case .conflictResolutionNeeded:
            return .orange
        case .temporarilyUnavailable:
            return .orange
        }
    }
}

#Preview {
    VStack(spacing: 20) {
        EnhancedSyncStatusView(showLabel: true)
        EnhancedSyncStatusView(showLabel: true, compact: true)
        EnhancedSyncStatusView()
    }
    .environmentObject(ThemeManager())
    .padding()
}

// MARK: - CloudKit Batch Processing Extensions
extension EnhancedCloudKitManager {
    /// Upload multiple tasks to CloudKit in efficient batches
    func uploadTasksInBatches(_ tasks: [Task]) async throws {
        let batchSize = 100
        for batch in stride(from: 0, to: tasks.count, by: batchSize) {
            let endIndex = min(batch + batchSize, tasks.count)
            let batchTasks = Array(tasks[batch..<endIndex])
            let records = batchTasks.map { $0.toCKRecord() }
            
            let (_, _) = try await database.modifyRecords(
                saving: records,
                deleting: []
            )
            
            // Process results if needed
            print("Batch uploaded: \(records.count) tasks")
        }
    }
    
    /// Upload multiple goals to CloudKit in efficient batches
    func uploadGoalsInBatches(_ goals: [Goal]) async throws {
        let batchSize = 100
        for batch in stride(from: 0, to: goals.count, by: batchSize) {
            let endIndex = min(batch + batchSize, goals.count)
            let batchGoals = Array(goals[batch..<endIndex])
            let records = batchGoals.map { $0.toCKRecord() }
            
            let (_, _) = try await database.modifyRecords(
                saving: records,
                deleting: []
            )
            
            print("Batch uploaded: \(records.count) goals")
        }
    }
}

// MARK: - CloudKit Zones Extensions
extension EnhancedCloudKitManager {
    /// Create a custom zone for more efficient organization
    func createCustomZone() async throws {
        let customZone = CKRecordZone(zoneName: "PlannerAppData")
        try await database.save(customZone)
        print("Custom zone created: PlannerAppData")
    }
    
    /// Fetch record zones
    func fetchZones() async throws -> [CKRecordZone] {
        let zones = try await database.allRecordZones()
        return zones
    }
    
    /// Delete a zone and all its records
    func deleteZone(named zoneName: String) async throws {
        let zoneID = CKRecordZone.ID(zoneName: zoneName)
        try await database.deleteRecordZone(withID: zoneID)
        print("Zone deleted: \(zoneName)")
    }
}

// MARK: - CloudKit Subscriptions Extensions
extension EnhancedCloudKitManager {
    /// Set up CloudKit subscriptions for silent push notifications when data changes
    func setupCloudKitSubscriptions() async {
        do {
            // Subscription for tasks
            let taskSubscription = CKQuerySubscription(
                recordType: "Task",
                predicate: NSPredicate(value: true),
                subscriptionID: "TaskSubscription",
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )
            
            let notificationInfo = CKSubscription.NotificationInfo()
            notificationInfo.shouldSendContentAvailable = true // Silent push
            taskSubscription.notificationInfo = notificationInfo
            
            try await database.save(taskSubscription)
            
            // Similar subscriptions for Goals, JournalEntries, and CalendarEvents
            let goalSubscription = CKQuerySubscription(
                recordType: "Goal",
                predicate: NSPredicate(value: true),
                subscriptionID: "GoalSubscription",
                options: [.firesOnRecordCreation, .firesOnRecordUpdate, .firesOnRecordDeletion]
            )
            goalSubscription.notificationInfo = notificationInfo
            
            try await database.save(goalSubscription)
            
            print("CloudKit subscriptions set up successfully")
        } catch {
            print("Error setting up CloudKit subscriptions: \(error.localizedDescription)")
        }
    }
    
    /// Handle incoming silent push notification
    func handleDatabaseNotification(_ notification: CKDatabaseNotification) async {
        print("Received database change notification, initiating sync")
        await performFullSync()
    }
}

// MARK: - Device Management Extensions
extension EnhancedCloudKitManager {
    /// Structure to represent a device syncing with iCloud
    struct SyncedDevice: Identifiable {
        let id = UUID()
        let name: String
        let lastSync: Date?
        let isCurrentDevice: Bool
    }
    
    /// Get a list of all devices syncing with this iCloud account
    func getSyncedDevices() async -> [SyncedDevice] {
        // In a real implementation, you would store device information in CloudKit
        // This is a placeholder implementation
        var devices = [SyncedDevice]()
        
        // Add current device
        let currentDevice = SyncedDevice(
            name: Self.deviceName,
            lastSync: lastSyncDate,
            isCurrentDevice: true
        )
        devices.append(currentDevice)
        
        // In a real implementation, fetch other devices from CloudKit
        return devices
    }
    
    /// Get the current device name
    static var deviceName: String {
        #if os(iOS)
        return UIDevice.current.name
        #elseif os(macOS)
        return Host.current().localizedName ?? "Mac"
        #else
        return "Unknown Device"
        #endif
    }
    
    /// Remove a device from the sync list
    func removeDevice(_ deviceID: String) async throws {
        // In a real implementation, you would remove the device record from CloudKit
        print("Removing device: \(deviceID)")
    }
}
