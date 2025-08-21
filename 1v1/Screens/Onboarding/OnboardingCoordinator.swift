import SwiftUI

enum OnboardingStep: Int, CaseIterable {
    case auth = 0
    case stats = 1
    case cardGen = 2
    
    var title: String {
        switch self {
        case .auth: return "Authentication"
        case .stats: return "Player Stats"
        case .cardGen: return "Generate Card"
        }
    }
    
    var description: String {
        switch self {
        case .auth: return "Sign in to get started"
        case .stats: return "Tell us about your gaming experience"
        case .cardGen: return "Create your unique player card"
        }
    }
}

class OnboardingCoordinator: ObservableObject {
    @Published var currentStep: OnboardingStep = .auth
    @Published var onboardingData = OnboardingData()
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    var progress: Double {
        Double(currentStep.rawValue) / Double(OnboardingStep.allCases.count - 1)
    }
    
    func nextStep() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex + 1 < OnboardingStep.allCases.count else {
            return
        }
        currentStep = OnboardingStep.allCases[currentIndex + 1]
    }
    
    func previousStep() {
        guard let currentIndex = OnboardingStep.allCases.firstIndex(of: currentStep),
              currentIndex > 0 else {
            return
        }
        currentStep = OnboardingStep.allCases[currentIndex - 1]
    }
    
    func canProceed() -> Bool {
        switch currentStep {
        case .auth:
            return onboardingData.isAuthenticated
        case .stats:
            return onboardingData.hasCompletedStats
        case .cardGen:
            return onboardingData.hasGeneratedCard
        }
    }
}

struct OnboardingData {
    // Auth data
    var isAuthenticated = false
    var username = ""
    var avatarUrl: String?
    
    // Stats data
    var gamingExperience = GamingExperience.beginner
    var favoriteGenres: Set<GameGenre> = []
    var playTimePerWeek = PlayTime.medium
    var skillLevel = SkillLevel.average
    var hasCompletedStats = false
    
    // Card data
    var cardName = ""
    var cardDescription = ""
    var selectedRarity = CardRarity.common
    var hasGeneratedCard = false
    
    func generateStats() -> UserStats {
        let baseWins = gamingExperience.rawValue.count * 10
        let baseLosses = gamingExperience.rawValue.count * 5
        let draws = Int.random(in: 0...baseWins / 4) // Random draws based on wins
        let totalGames = baseWins + baseLosses + draws
        let winRate = totalGames > 0 ? Double(baseWins) / Double(totalGames) : 0.0
        
        let baseScore = skillLevel.rawValue.count * 15
        let averageScore = Double(baseScore)
        let bestScore = baseScore + Int.random(in: 10...50)
        
        let playTimeMinutes = playTimePerWeek.rawValue.count * 60
        
        return UserStats(
            wins: baseWins,
            losses: baseLosses,
            draws: draws,
            totalGames: totalGames,
            winRate: winRate,
            averageScore: averageScore,
            bestScore: bestScore,
            totalPlayTime: playTimeMinutes,
            favoriteGame: favoriteGenres.first?.displayName,
            rank: determineRank(winRate: winRate, totalGames: totalGames)
        )
    }
    
    func generateCardData() -> OnboardingCardData {
        let name = cardName.isEmpty ? generateCardName() : cardName
        let description = cardDescription.isEmpty ? generateCardDescription() : cardDescription
        return OnboardingCardData(name: name, description: description, rarity: selectedRarity)
    }
    
    private func generateCardName() -> String {
        let prefixes = ["Swift", "Elite", "Shadow", "Golden", "Crystal", "Mystic", "Legendary", "Epic"]
        let suffixes = ["Striker", "Defender", "Mage", "Warrior", "Hunter", "Guardian", "Champion", "Master"]
        
        let prefix = prefixes.randomElement() ?? "Swift"
        let suffix = suffixes.randomElement() ?? "Striker"
        
        return "\(prefix) \(suffix)"
    }
    
    private func generateCardDescription() -> String {
        let descriptions = [
            "A skilled player with exceptional reflexes and strategic thinking.",
            "Master of precision and timing, known for clutch plays.",
            "Versatile gamer with expertise across multiple genres.",
            "Tactical genius with a knack for outsmarting opponents.",
            "Speed demon who excels in fast-paced action games.",
            "Patient strategist who plans every move carefully."
        ]
        
        return descriptions.randomElement() ?? descriptions[0]
    }
    
    private func determineRank(winRate: Double, totalGames: Int) -> String {
        if totalGames < 10 {
            return "Bronze"
        }
        
        switch winRate {
        case 0.8...: return "Diamond"
        case 0.6..<0.8: return "Platinum"
        case 0.5..<0.6: return "Gold"
        case 0.4..<0.5: return "Silver"
        default: return "Bronze"
        }
    }
}

enum GamingExperience: String, CaseIterable {
    case beginner = "beginner"
    case casual = "casual"
    case intermediate = "intermediate"
    case advanced = "advanced"
    case expert = "expert"
    
    var displayName: String {
        switch self {
        case .beginner: return "Beginner"
        case .casual: return "Casual"
        case .intermediate: return "Intermediate"
        case .advanced: return "Advanced"
        case .expert: return "Expert"
        }
    }
}

enum GameGenre: String, CaseIterable {
    case action = "action"
    case adventure = "adventure"
    case rpg = "rpg"
    case strategy = "strategy"
    case sports = "sports"
    case racing = "racing"
    case puzzle = "puzzle"
    case shooter = "shooter"
    case fighting = "fighting"
    case simulation = "simulation"
    
    var displayName: String {
        switch self {
        case .action: return "Action"
        case .adventure: return "Adventure"
        case .rpg: return "RPG"
        case .strategy: return "Strategy"
        case .sports: return "Sports"
        case .racing: return "Racing"
        case .puzzle: return "Puzzle"
        case .shooter: return "Shooter"
        case .fighting: return "Fighting"
        case .simulation: return "Simulation"
        }
    }
}

enum PlayTime: String, CaseIterable {
    case low = "low"
    case medium = "medium"
    case high = "high"
    case veryHigh = "very_high"
    
    var displayName: String {
        switch self {
        case .low: return "1-5 hours/week"
        case .medium: return "6-15 hours/week"
        case .high: return "16-30 hours/week"
        case .veryHigh: return "30+ hours/week"
        }
    }
}

enum SkillLevel: String, CaseIterable {
    case novice = "novice"
    case average = "average"
    case skilled = "skilled"
    case expert = "expert"
    case master = "master"
    
    var displayName: String {
        switch self {
        case .novice: return "Novice"
        case .average: return "Average"
        case .skilled: return "Skilled"
        case .expert: return "Expert"
        case .master: return "Master"
        }
    }
}
