import Foundation

struct Achievement: Codable, Identifiable {
    let id: String
    let user_id: String
    let achievement_id: String
    let title: String
    let description: String?
    let icon: String?
    let unlocked_at: Date?
    let rarity: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case user_id
        case achievement_id
        case title
        case description
        case icon
        case unlocked_at
        case rarity
    }
    
    init(id: String, user_id: String, achievement_id: String, title: String, description: String? = nil, icon: String? = nil, unlocked_at: Date? = nil, rarity: String? = nil) {
        self.id = id
        self.user_id = user_id
        self.achievement_id = achievement_id
        self.title = title
        self.description = description
        self.icon = icon
        self.unlocked_at = unlocked_at
        self.rarity = rarity
    }
}
