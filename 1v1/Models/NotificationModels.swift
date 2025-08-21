import Foundation

// MARK: - Notification Models
struct PendingNotification: Codable, Identifiable {
    let id: String
    let userId: String
    let type: NotificationType
    let title: String
    let body: String
    let data: NotificationData
    let scheduledFor: Date
    let expiresAt: Date
    let isRead: Bool
    let deliveredAt: Date?
    let priority: Int
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case title
        case body
        case data
        case scheduledFor = "scheduled_for"
        case expiresAt = "expires_at"
        case isRead = "is_read"
        case deliveredAt = "delivered_at"
        case priority
    }
    
    init(
        id: String = UUID().uuidString,
        userId: String,
        type: NotificationType,
        title: String,
        body: String,
        data: NotificationData,
        scheduledFor: Date = Date(),
        expiresAt: Date,
        isRead: Bool = false,
        deliveredAt: Date? = nil,
        priority: Int = 5
    ) {
        self.id = id
        self.userId = userId
        self.type = type
        self.title = title
        self.body = body
        self.data = data
        self.scheduledFor = scheduledFor
        self.expiresAt = expiresAt
        self.isRead = isRead
        self.deliveredAt = deliveredAt
        self.priority = priority
    }
}

// MARK: - Notification Data
struct NotificationData: Codable {
    let duelId: String?
    let challengerId: String?
    let opponentId: String?
    let gameType: String?
    let gameMode: String?
    let action: String?
    let reason: String?
    let isWinner: Bool?
    let newLevel: Int?
    let pingNumber: Int?
    
    enum CodingKeys: String, CodingKey {
        case duelId = "duel_id"
        case challengerId = "challenger_id"
        case opponentId = "opponent_id"
        case gameType = "game_type"
        case gameMode = "game_mode"
        case action
        case reason
        case isWinner = "is_winner"
        case newLevel = "new_level"
        case pingNumber = "ping_number"
    }
    
    init(
        duelId: String? = nil,
        challengerId: String? = nil,
        opponentId: String? = nil,
        gameType: String? = nil,
        gameMode: String? = nil,
        action: String? = nil,
        reason: String? = nil,
        isWinner: Bool? = nil,
        newLevel: Int? = nil,
        pingNumber: Int? = nil
    ) {
        self.duelId = duelId
        self.challengerId = challengerId
        self.opponentId = opponentId
        self.gameType = gameType
        self.gameMode = gameMode
        self.action = action
        self.reason = reason
        self.isWinner = isWinner
        self.newLevel = newLevel
        self.pingNumber = pingNumber
    }
}

// MARK: - Notification Types
enum NotificationType: String, Codable, CaseIterable {
    case duelChallenge = "duel_challenge"
    case duelAccepted = "duel_accepted"
    case duelDeclined = "duel_declined"
    case matchStarted = "match_started"
    case matchProgress = "match_progress"
    case matchEnded = "match_ended"
    case verificationReminder = "verification_reminder"
    case verificationSuccess = "verification_success"
    case verificationFailed = "verification_failed"
    case duelForfeited = "duel_forfeited"
    case duelExpired = "duel_expired"
    case matchTimeout = "match_timeout"
    case dispute = "dispute"
    case levelUp = "level_up"
    case achievement = "achievement"
    
    var categoryIdentifier: String {
        switch self {
        case .duelChallenge:
            return "DUEL_CHALLENGE_CATEGORY"
        case .matchEnded:
            return "MATCH_ENDED_CATEGORY"
        case .verificationReminder:
            return "VERIFICATION_REMINDER_CATEGORY"
        case .dispute:
            return "DISPUTE_CATEGORY"
        default:
            return "DEFAULT_CATEGORY"
        }
    }
    
    var displayName: String {
        switch self {
        case .duelChallenge: return "Duel Challenge"
        case .duelAccepted: return "Challenge Accepted"
        case .duelDeclined: return "Challenge Declined"
        case .matchStarted: return "Match Started"
        case .matchProgress: return "Match Progress"
        case .matchEnded: return "Match Ended"
        case .verificationReminder: return "Submit Screenshot"
        case .verificationSuccess: return "Verification Success"
        case .verificationFailed: return "Verification Failed"
        case .duelForfeited: return "Duel Forfeited"
        case .duelExpired: return "Challenge Expired"
        case .matchTimeout: return "Match Timeout"
        case .dispute: return "Dispute"
        case .levelUp: return "Level Up"
        case .achievement: return "Achievement"
        }
    }
}

// MARK: - Match Notification State
struct MatchNotificationState {
    let duelId: String
    let gameType: String
    var status: MatchStatus
    let startTime: Date
    var endTime: Date?
    var lastPingTime: Date?
    var pingCount: Int
    
    enum MatchStatus {
        case inProgress
        case ended
        case completed
        case forfeited
    }
}

// MARK: - Notification Data Extension
extension NotificationData {
    func toDictionary() -> [String: Any] {
        var dict: [String: Any] = [:]
        
        if let duelId = duelId { dict["duel_id"] = duelId }
        if let challengerId = challengerId { dict["challenger_id"] = challengerId }
        if let opponentId = opponentId { dict["opponent_id"] = opponentId }
        if let gameType = gameType { dict["game_type"] = gameType }
        if let gameMode = gameMode { dict["game_mode"] = gameMode }
        if let action = action { dict["action"] = action }
        if let reason = reason { dict["reason"] = reason }
        if let isWinner = isWinner { dict["is_winner"] = isWinner }
        if let newLevel = newLevel { dict["new_level"] = newLevel }
        if let pingNumber = pingNumber { dict["ping_number"] = pingNumber }
        
        return dict
    }
}
