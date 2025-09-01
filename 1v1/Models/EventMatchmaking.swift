import Foundation

enum MatchStatus: String, Codable, CaseIterable {
    case pending
    case accepted
    case declined
    case expired
}

struct EventMatchmaking: Codable, Identifiable, Hashable {
    let id: String
    let eventId: String
    let userId: String
    let matchedUserId: String
    var similarityScore: Double
    var status: MatchStatus
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case matchedUserId = "matched_user_id"
        case similarityScore = "similarity_score"
        case status
        case createdAt = "created_at"
    }
    
    // MARK: - Computed
    var qualityDescription: String {
        switch similarityScore {
        case 80...: return "Excellent Match"
        case 60..<80: return "Good Match"
        case 40..<60: return "Fair Match"
        default: return "Low Match"
        }
    }
    
    func timeRemaining(expiryInterval: TimeInterval = 600) -> TimeInterval {
        let expiryDate = createdAt.addingTimeInterval(expiryInterval)
        return max(0, expiryDate.timeIntervalSinceNow)
    }
}


