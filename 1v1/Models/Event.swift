import Foundation

struct Event: Codable, Identifiable {
    let id: String
    let name: String
    let description: String?
    let venue: String?
    let startTime: Date
    let endTime: Date
    let maxAttendees: Int?
    let eventType: String?
    let metadata: [String: AnyCodable]
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case name
        case description
        case venue
        case startTime = "start_time"
        case endTime = "end_time"
        case maxAttendees = "max_attendees"
        case eventType = "event_type"
        case metadata
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // MARK: - Computed
    var isActive: Bool {
        let now = Date()
        return now >= startTime && now <= endTime
    }
    
    var timeUntilStart: TimeInterval {
        return max(0, startTime.timeIntervalSinceNow)
    }
    
    var duration: TimeInterval {
        return endTime.timeIntervalSince(startTime)
    }
    
    // Placeholder until populated by service
    var attendeeCount: Int { 0 }
    
    // MARK: - Validation
    func isValid() -> Bool {
        return !id.isEmpty && !name.isEmpty && endTime > startTime
    }
}

// Simple AnyCodable to handle metadata jsonb
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) { self.value = value }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let intVal = try? container.decode(Int.self) { self.value = intVal; return }
        if let doubleVal = try? container.decode(Double.self) { self.value = doubleVal; return }
        if let boolVal = try? container.decode(Bool.self) { self.value = boolVal; return }
        if let stringVal = try? container.decode(String.self) { self.value = stringVal; return }
        if let dictVal = try? container.decode([String: AnyCodable].self) { self.value = dictVal; return }
        if let arrayVal = try? container.decode([AnyCodable].self) { self.value = arrayVal; return }
        self.value = NSNull()
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch value {
        case let intVal as Int: try container.encode(intVal)
        case let doubleVal as Double: try container.encode(doubleVal)
        case let boolVal as Bool: try container.encode(boolVal)
        case let stringVal as String: try container.encode(stringVal)
        case let dictVal as [String: AnyCodable]: try container.encode(dictVal)
        case let arrayVal as [AnyCodable]: try container.encode(arrayVal)
        default: try container.encodeNil()
        }
    }
}


