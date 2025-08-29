import Foundation
import CloudKit
import CoreTransferable

enum TaskPriority: String, CaseIterable, Codable {
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

struct Task: Identifiable, Codable, Transferable {
    let id: UUID
    var title: String
    var description: String
    var isCompleted: Bool
    var priority: TaskPriority
    var dueDate: Date?
    var createdAt: Date
    var modifiedAt: Date?  // Added for CloudKit sync/merge
    
    init(id: UUID = UUID(), title: String, description: String = "", isCompleted: Bool = false, priority: TaskPriority = .medium, dueDate: Date? = nil, createdAt: Date = Date(), modifiedAt: Date? = Date()) {
        self.id = id
        self.title = title
        self.description = description
        self.isCompleted = isCompleted
        self.priority = priority
        self.dueDate = dueDate
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }
    
    // MARK: - CloudKit Conversion
    
    /// Convert to CloudKit record for syncing
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "Task", recordID: CKRecord.ID(recordName: id.uuidString))
        record["title"] = title
        record["description"] = description
        record["isCompleted"] = isCompleted
        record["priority"] = priority.rawValue
        record["dueDate"] = dueDate
        record["createdAt"] = createdAt
        record["modifiedAt"] = modifiedAt
        return record
    }
    
    /// Create a Task from CloudKit record
    static func from(ckRecord: CKRecord) throws -> Task {
        guard
            let title = ckRecord["title"] as? String,
            let createdAt = ckRecord["createdAt"] as? Date,
            let idString = ckRecord.recordID.recordName.components(separatedBy: "/").last,
            let id = UUID(uuidString: idString)
        else {
            throw NSError(domain: "TaskConversionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert CloudKit record to Task"])
        }
        
        return Task(
            id: id,
            title: title,
            description: ckRecord["description"] as? String ?? "",
            isCompleted: ckRecord["isCompleted"] as? Bool ?? false,
            priority: TaskPriority(rawValue: ckRecord["priority"] as? String ?? "medium") ?? .medium,
            dueDate: ckRecord["dueDate"] as? Date,
            createdAt: createdAt,
            modifiedAt: ckRecord["modifiedAt"] as? Date
        )
    }
    
    // MARK: - Transferable Implementation
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}
