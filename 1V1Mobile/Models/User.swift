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
    
    enum CodingKeys: String, CodingKey {
        case id
        case email
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case username
        case avatarUrl = "avatar_url"
        case isOnline = "is_online"
        case lastSeen = "last_seen"
    }
    
    init(id: String, email: String, createdAt: Date? = nil, updatedAt: Date? = nil, username: String? = nil, avatarUrl: String? = nil, isOnline: Bool? = nil, lastSeen: Date? = nil) {
        self.id = id
        self.email = email
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.username = username
        self.avatarUrl = avatarUrl
        self.isOnline = isOnline
        self.lastSeen = lastSeen
    }
}
