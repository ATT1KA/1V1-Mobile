import Foundation

struct UserProfile: Codable, Identifiable {
    let id: String
    let userId: String
    let username: String
    let avatarUrl: String?
    let stats: UserStats?
    let card: UserCard?
    let achievements: [Achievement]
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case username
        case avatarUrl = "avatar_url"
        case stats
        case card
        case achievements
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    init(from user: User, stats: UserStats?, card: UserCard?, achievements: [Achievement]) {
        self.id = user.id
        self.userId = user.id
        self.username = user.username ?? "Player"
        self.avatarUrl = user.avatarUrl
        self.stats = stats
        self.card = card
        self.achievements = achievements
        self.createdAt = Date()
        self.updatedAt = Date()
    }
    
    init(id: String, userId: String, username: String, avatarUrl: String?, stats: UserStats?, card: UserCard?, achievements: [Achievement], createdAt: Date, updatedAt: Date) {
        self.id = id
        self.userId = userId
        self.username = username
        self.avatarUrl = avatarUrl
        self.stats = stats
        self.card = card
        self.achievements = achievements
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
    
    // MARK: - Computed Properties
    var displayName: String {
        return username.isEmpty ? "Player" : username
    }
    
    var hasAvatar: Bool {
        return avatarUrl != nil && !avatarUrl!.isEmpty
    }
    
    var totalGames: Int {
        return stats?.totalGames ?? 0
    }
    
    var winRate: Double {
        return stats?.winRate ?? 0.0
    }
    
    var rank: String {
        return stats?.rank ?? "Bronze"
    }
    
    var achievementCount: Int {
        return achievements.count
    }
    
    // MARK: - Sharing Methods
    func toShareableData() -> Data? {
        return try? JSONEncoder().encode(self)
    }
    
    func toShareableString() -> String? {
        guard let data = toShareableData() else { return nil }
        return String(data: data, encoding: .utf8)
    }
    
    // MARK: - Static Methods
    static func from(data: Data) -> UserProfile? {
        return try? JSONDecoder().decode(UserProfile.self, from: data)
    }
    
    static func from(string: String) -> UserProfile? {
        guard let data = string.data(using: .utf8) else { return nil }
        return from(data: data)
    }
}
