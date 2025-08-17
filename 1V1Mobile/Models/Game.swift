import Foundation

struct Game: Codable, Identifiable {
    let id: String
    let player1Id: String
    let player2Id: String?
    let status: GameStatus
    let createdAt: Date
    let updatedAt: Date
    let winnerId: String?
    let score: GameScore?
    let duration: TimeInterval?
    
    enum CodingKeys: String, CodingKey {
        case id
        case player1Id = "player1_id"
        case player2Id = "player2_id"
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case winnerId = "winner_id"
        case score
        case duration
    }
    
    init(id: String, player1Id: String, player2Id: String? = nil, status: GameStatus = .waiting, createdAt: Date = Date(), updatedAt: Date = Date(), winnerId: String? = nil, score: GameScore? = nil, duration: TimeInterval? = nil) {
        self.id = id
        self.player1Id = player1Id
        self.player2Id = player2Id
        self.status = status
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.winnerId = winnerId
        self.score = score
        self.duration = duration
    }
}

enum GameStatus: String, Codable, CaseIterable {
    case waiting = "waiting"
    case active = "active"
    case completed = "completed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .waiting:
            return "Waiting for Player"
        case .active:
            return "In Progress"
        case .completed:
            return "Completed"
        case .cancelled:
            return "Cancelled"
        }
    }
    
    var color: String {
        switch self {
        case .waiting:
            return "orange"
        case .active:
            return "green"
        case .completed:
            return "blue"
        case .cancelled:
            return "red"
        }
    }
}

struct GameScore: Codable {
    let player1Score: Int
    let player2Score: Int
    
    enum CodingKeys: String, CodingKey {
        case player1Score = "player1_score"
        case player2Score = "player2_score"
    }
    
    init(player1Score: Int, player2Score: Int) {
        self.player1Score = player1Score
        self.player2Score = player2Score
    }
    
    var winner: Int {
        if player1Score > player2Score {
            return 1
        } else if player2Score > player1Score {
            return 2
        } else {
            return 0 // Tie
        }
    }
}
