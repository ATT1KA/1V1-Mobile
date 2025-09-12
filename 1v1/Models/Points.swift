import Foundation

// MARK: - Point Models

public enum PointSourceType: String, Codable {
    case duelWin = "duel_win"
    case duelLoss = "duel_loss"
    case profileShare = "profile_share"
    case achievementUnlock = "achievement_unlock"
    case dailyBonus = "daily_bonus"
}

public struct PointTransaction: Identifiable, Codable {
    public let id: UUID
    public let userId: UUID
    public let sourceType: PointSourceType
    public let sourceId: String?
    public let pointsAwarded: Int
    public let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case sourceType = "source_type"
        case sourceId = "source_id"
        case pointsAwarded = "points_awarded"
        case createdAt = "created_at"
    }
}

public struct LeaderboardEntry: Identifiable, Codable {
    public var id: String { userId }
    public let userId: String
    public let username: String?
    public let avatarUrl: String?
    public let totalPoints: Int
    public let rank: Int
    public let isCurrentUser: Bool?
    public let leaderboardOptIn: Bool?
}

public struct PointRedemption: Identifiable, Codable {
    public let id: UUID
    public let userId: UUID
    public let rewardId: UUID
    public let pointsSpent: Int
    public let redeemedAt: Date
}

public enum RewardType: String, Codable {
    case avatar
    case cardSkin
    case feature
    case badge
}

public struct RewardItem: Identifiable, Codable {
    public let id: UUID
    public let name: String
    public let description: String?
    public let pointsCost: Int
    public let rewardType: RewardType
    public let unlockData: [String: String]?
    public let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id, name, description
        case pointsCost = "points_cost"
        case rewardType = "reward_type"
        case unlockData = "unlock_data"
        case isActive = "is_active"
    }
}

public struct PointsBalance: Codable {
    public let totalPoints: Int
    public let availablePoints: Int
    public let pendingPoints: Int
}


