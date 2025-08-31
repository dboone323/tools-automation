import CloudKit
import Foundation

struct CalendarEvent: Identifiable, Codable {
    let id: UUID
    var title: String
    var date: Date
    var createdAt: Date
    var modifiedAt: Date? // Added for CloudKit sync/merge

    init(id: UUID = UUID(), title: String, date: Date, createdAt: Date = Date(), modifiedAt: Date? = Date()) {
        self.id = id
        self.title = title
        self.date = date
        self.createdAt = createdAt
        self.modifiedAt = modifiedAt
    }

    // MARK: - CloudKit Conversion

    /// Convert to CloudKit record for syncing
    func toCKRecord() -> CKRecord {
        let record = CKRecord(recordType: "CalendarEvent", recordID: CKRecord.ID(recordName: id.uuidString))
        record["title"] = title
        record["date"] = date
        record["createdAt"] = createdAt
        record["modifiedAt"] = modifiedAt
        return record
    }

    /// Create a CalendarEvent from CloudKit record
    static func from(ckRecord: CKRecord) throws -> CalendarEvent {
        guard let title = ckRecord["title"] as? String,
              let date = ckRecord["date"] as? Date,
              let id = UUID(uuidString: ckRecord.recordID.recordName)
        else {
            throw NSError(domain: "CalendarEventConversionError", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to convert CloudKit record to CalendarEvent"])
        }

        return CalendarEvent(
            id: id,
            title: title,
            date: date,
            createdAt: ckRecord["createdAt"] as? Date ?? Date(),
            modifiedAt: ckRecord["modifiedAt"] as? Date
        )
    }
}
