import Foundation

struct User: Codable, Identifiable {
    let id: String
    let email: String
    let createdAt: Date?
    let updatedAt: Date?
    let username: String?
    let avatarUrl: String?
    let isOnline: Bool?
    let lastSeen: Date?
    let stats: UserStats?
    let cardId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case username
        case avatarUrl = "avatar_url"
        case isOnline = "is_online"
        case lastSeen = "last_seen"
        case stats
        case cardId = "card_id"
    }
    
    init(id: String, email: String, createdAt: Date? = nil, updatedAt: Date? = nil, username: String? = nil, avatarUrl: String? = nil, isOnline: Bool? = nil, lastSeen: Date? = nil, stats: UserStats? = nil, cardId: String? = nil) {
        self.id = id
        self.email = email
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.username = username
        self.avatarUrl = avatarUrl
        self.isOnline = isOnline
        self.lastSeen = lastSeen
        self.stats = stats
        self.cardId = cardId
    }
}

struct UserStats: Codable {
    let wins: Int
    let losses: Int
    let draws: Int
    let totalGames: Int
    let winRate: Double
    let averageScore: Double
    let bestScore: Int
    let totalPlayTime: Int // in minutes
    let favoriteGame: String?
    let rank: String?
    
    enum CodingKeys: String, CodingKey {
        case wins
        case losses
        case draws
        case totalGames = "total_games"
        case winRate = "win_rate"
        case averageScore = "average_score"
        case bestScore = "best_score"
        case totalPlayTime = "total_play_time"
        case favoriteGame = "favorite_game"
        case rank
    }
    
    init(wins: Int = 0, losses: Int = 0, draws: Int = 0, totalGames: Int = 0, winRate: Double = 0.0, averageScore: Double = 0.0, bestScore: Int = 0, totalPlayTime: Int = 0, favoriteGame: String? = nil, rank: String? = "Bronze") {
        self.wins = wins
        self.losses = losses
        self.draws = draws
        self.totalGames = totalGames
        self.winRate = winRate
        self.averageScore = averageScore
        self.bestScore = bestScore
        self.totalPlayTime = totalPlayTime
        self.favoriteGame = favoriteGame
        self.rank = rank
    }
    
    var dictionary: [String: Any] {
        return [
            "wins": wins,
            "losses": losses,
            "draws": draws,
            "total_games": totalGames,
            "win_rate": winRate,
            "average_score": averageScore,
            "best_score": bestScore,
            "total_play_time": totalPlayTime,
            "favorite_game": favoriteGame ?? "",
            "rank": rank ?? "Bronze"
        ]
    }
}

struct UserCard: Codable, Identifiable {
    let id: String
    let userId: String
    let cardName: String
    let cardDescription: String
    let cardImage: String?
    let rarity: CardRarity
    let power: Int
    let createdAt: Date?
    let isActive: Bool
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case cardName = "card_name"
        case cardDescription = "card_description"
        case cardImage = "card_image"
        case rarity
        case power
        case createdAt = "created_at"
        case isActive = "is_active"
    }
    
    init(id: String, userId: String, cardName: String, cardDescription: String, cardImage: String? = nil, rarity: CardRarity = .common, power: Int = 50, createdAt: Date? = nil, isActive: Bool = true) {
        self.id = id
        self.userId = userId
        self.cardName = cardName
        self.cardDescription = cardDescription
        self.cardImage = cardImage
        self.rarity = rarity
        self.power = power
        self.createdAt = createdAt
        self.isActive = isActive
    }
}

enum CardRarity: String, CaseIterable, Codable {
    case common = "common"
    case rare = "rare"
    case epic = "epic"
    case legendary = "legendary"
    
    var color: String {
        switch self {
        case .common: return "#9CA3AF"
        case .rare: return "#3B82F6"
        case .epic: return "#8B5CF6"
        case .legendary: return "#F59E0B"
        }
    }
    
    var displayName: String {
        switch self {
        case .common: return "Common"
        case .rare: return "Rare"
        case .epic: return "Epic"
        case .legendary: return "Legendary"
        }
    }
    
    var power: Int {
        switch self {
        case .common: return 50
        case .rare: return 75
        case .epic: return 100
        case .legendary: return 150
        }
    }
}
