import Foundation
import CloudKit

enum GoalPriority: String, CaseIterable, Codable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    
    var displayName: String {
        switch self {
        case .low: return "Low"
        case .medium: return "Medium"
        case .high: return "High"
        }
    }
}

struct Goal: Identifiable, Codable {
    let id: UUID
    var title: String
    var description: String
    var targetDate: Date
    var createdAt: Date
    var modifiedAt: Date?  // Added for CloudKit sync/merge
    var isCompleted: Bool  // Adding completion status for goals
    var priority: GoalPriority  // Goal priority
    var progress: Double  // Goal progress (0.0 to 1.0)
    
    init(id: UUID = UUID(), title: String, description: String, targetDate: Date, createdAt: Date = Date(), modifiedAt: Date? = Date(), isCompleted: Bool = false, priority: GoalPriority = .medium, progress: Double = 0.0) {
        self.id = id
        self.title = title
        self.description = description
        self.targetDate = targetDate
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
        self.isCompleted = isCompleted
        self.priority = priority
        self.progress = progress
    }
    
    // MARK: - CloudKit Conversion
    
    /// Convert to CloudKit record for syncing
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "Goal", recordID: CKRecord.ID(recordName: id.uuidString))
        record["title"] = title
        record["description"] = description
        record["targetDate"] = targetDate
        record["createdAt"] = createdAt
        record["modifiedAt"] = modifiedAt
        record["isCompleted"] = isCompleted
        record["priority"] = priority.rawValue
        record["progress"] = progress
        return record
    }
    
    /// Create a Goal from CloudKit record
    static func from(ckRecord: CKRecord) throws -> Goal {
        guard let title = ckRecord["title"] as? String,
              let targetDate = ckRecord["targetDate"] as? Date,
              let id = UUID(uuidString: ckRecord.recordID.recordName)
        else {
            throw NSError(domain: "GoalConversionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert CloudKit record to Goal"])
        }
        
        let priorityString = ckRecord["priority"] as? String ?? "medium"
        let priority = GoalPriority(rawValue: priorityString) ?? .medium
        
        return Goal(
            id: id,
            title: title,
            description: ckRecord["description"] as? String ?? "",
            targetDate: targetDate,
            createdAt: ckRecord["createdAt"] as? Date ?? Date(),
            modifiedAt: ckRecord["modifiedAt"] as? Date,
            isCompleted: ckRecord["isCompleted"] as? Bool ?? false,
            priority: priority,
            progress: ckRecord["progress"] as? Double ?? 0.0
        )
    }
}
