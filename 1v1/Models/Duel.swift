import Foundation

// MARK: - Duel Model
struct Duel: Codable, Identifiable {
    let id: String
    let challengerId: String
    let opponentId: String
    let gameType: String
    let gameMode: String
    let status: DuelStatus
    let createdAt: Date
    let acceptedAt: Date?
    let startedAt: Date?
    let endedAt: Date?
    let winnerId: String?
    let loserId: String?
    let challengerScore: Int?
    let opponentScore: Int?
    let verificationStatus: VerificationStatus
    let verificationMethod: VerificationMethod?
    let disputeStatus: DisputeStatus?
    let expiresAt: Date
    let challengeMessage: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case challengerId = "challenger_id"
        case opponentId = "opponent_id"
        case gameType = "game_type"
        case gameMode = "game_mode"
        case status
        case createdAt = "created_at"
        case acceptedAt = "accepted_at"
        case startedAt = "started_at"
        case endedAt = "ended_at"
        case winnerId = "winner_id"
        case loserId = "loser_id"
        case challengerScore = "challenger_score"
        case opponentScore = "opponent_score"
        case verificationStatus = "verification_status"
        case verificationMethod = "verification_method"
        case disputeStatus = "dispute_status"
        case expiresAt = "expires_at"
        case challengeMessage = "challenge_message"
    }
}

// MARK: - Duel Status Enum
enum DuelStatus: String, Codable, CaseIterable {
    case proposed = "proposed"
    case accepted = "accepted"
    case declined = "declined"
    case inProgress = "in_progress"
    case ended = "ended"
    case completed = "completed"
    case cancelled = "cancelled"
    case expired = "expired"
    case disputed = "disputed"
    
    var displayName: String {
        switch self {
        case .proposed: return "Proposed"
        case .accepted: return "Accepted"
        case .declined: return "Declined"
        case .inProgress: return "In Progress"
        case .ended: return "Ended"
        case .completed: return "Completed"
        case .cancelled: return "Cancelled"
        case .expired: return "Expired"
        case .disputed: return "Disputed"
        }
    }
    
    var color: String {
        switch self {
        case .proposed: return "#FFA500" // Orange
        case .accepted: return "#4CAF50" // Green
        case .declined: return "#F44336" // Red
        case .inProgress: return "#2196F3" // Blue
        case .ended: return "#3F51B5" // Indigo
        case .completed: return "#9C27B0" // Purple
        case .cancelled: return "#757575" // Gray
        case .expired: return "#FF9800" // Orange
        case .disputed: return "#E91E63" // Pink
        }
    }
}

// MARK: - Verification Status Enum
enum VerificationStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case submitted = "submitted"
    case verified = "verified"
    case failed = "failed"
    case disputed = "disputed"
    case forfeited = "forfeited"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .submitted: return "Submitted"
        case .verified: return "Verified"
        case .failed: return "Failed"
        case .disputed: return "Disputed"
        case .forfeited: return "Forfeited"
        }
    }
}

// MARK: - Verification Method Enum
enum VerificationMethod: String, Codable, CaseIterable {
    case ocr = "ocr"
    case mutual = "mutual"
    case moderator = "moderator"
    
    var displayName: String {
        switch self {
        case .ocr: return "OCR Analysis"
        case .mutual: return "Mutual Confirmation"
        case .moderator: return "Moderator Review"
        }
    }
}

// MARK: - Dispute Status Enum
enum DisputeStatus: String, Codable, CaseIterable {
    case none = "none"
    case pending = "pending"
    case resolved = "resolved"
    case escalated = "escalated"
    
    var displayName: String {
        switch self {
        case .none: return "No Dispute"
        case .pending: return "Pending Review"
        case .resolved: return "Resolved"
        case .escalated: return "Escalated"
        }
    }
}

// MARK: - Duel Submission Model
struct DuelSubmission: Codable, Identifiable {
    let id: String
    let duelId: String
    let userId: String
    let screenshotUrl: String
    let ocrResult: OCRResult?
    let submittedAt: Date
    let verifiedAt: Date?
    let confidence: Double?
    let gameConfigurationVersion: Int?
    
    enum CodingKeys: String, CodingKey {
        case id
        case duelId = "duel_id"
        case userId = "user_id"
        case screenshotUrl = "screenshot_url"
        case ocrResult = "ocr_result"
        case submittedAt = "submitted_at"
        case verifiedAt = "verified_at"
        case confidence
        case gameConfigurationVersion = "game_configuration_version"
    }
}

// MARK: - OCR Result Model
struct OCRResult: Codable {
    let extractedText: String
    let playerIds: [String]
    let scores: [String: Int]
    let confidence: Double
    let processingTime: TimeInterval
    let model: String
    let gameSpecificData: [String: String]?
    let regions: [OCRRegionResult]?
    
    enum CodingKeys: String, CodingKey {
        case extractedText = "extracted_text"
        case playerIds = "player_ids"
        case scores
        case confidence
        case processingTime = "processing_time"
        case model
        case gameSpecificData = "game_specific_data"
        case regions
    }
}

// MARK: - OCR Region Result
struct OCRRegionResult: Codable {
    let regionName: String
    let extractedText: String
    let confidence: Double
    let coordinates: CGRect
    
    enum CodingKeys: String, CodingKey {
        case regionName = "region_name"
        case extractedText = "extracted_text"
        case confidence
        case coordinates
    }
}

// MARK: - Duel Challenge Card Model
struct DuelChallengeCard: Codable {
    let duelId: String
    let challengerName: String
    let challengerAvatar: String?
    let gameType: String
    let gameMode: String
    let challengeMessage: String
    let expiresAt: Date
    let qrCodeData: String
    let shareUrl: String
    
    enum CodingKeys: String, CodingKey {
        case duelId = "duel_id"
        case challengerName = "challenger_name"
        case challengerAvatar = "challenger_avatar"
        case gameType = "game_type"
        case gameMode = "game_mode"
        case challengeMessage = "challenge_message"
        case expiresAt = "expires_at"
        case qrCodeData = "qr_code_data"
        case shareUrl = "share_url"
    }
}

// MARK: - Victory Recap Model
struct VictoryRecap: Codable {
    let duelId: String
    let winnerName: String
    let loserName: String
    let winnerScore: Int
    let loserScore: Int
    let gameType: String
    let gameMode: String
    let matchDuration: TimeInterval
    let verificationMethod: VerificationMethod
    let completedAt: Date
    let shareableImageUrl: String?
    let statsUpdate: StatsUpdate?
    
    enum CodingKeys: String, CodingKey {
        case duelId = "duel_id"
        case winnerName = "winner_name"
        case loserName = "loser_name"
        case winnerScore = "winner_score"
        case loserScore = "loser_score"
        case gameType = "game_type"
        case gameMode = "game_mode"
        case matchDuration = "match_duration"
        case verificationMethod = "verification_method"
        case completedAt = "completed_at"
        case shareableImageUrl = "shareable_image_url"
        case statsUpdate = "stats_update"
    }
}

// MARK: - Stats Update Model
struct StatsUpdate: Codable {
    let winnerStatsChange: UserStatsChange
    let loserStatsChange: UserStatsChange
    
    enum CodingKeys: String, CodingKey {
        case winnerStatsChange = "winner_stats_change"
        case loserStatsChange = "loser_stats_change"
    }
}

struct UserStatsChange: Codable {
    let userId: String
    let winsChange: Int
    let lossesChange: Int
    let winRateChange: Double
    let levelChange: Int?
    let experienceChange: Int
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case winsChange = "wins_change"
        case lossesChange = "losses_change"
        case winRateChange = "win_rate_change"
        case levelChange = "level_change"
        case experienceChange = "experience_change"
    }
}
