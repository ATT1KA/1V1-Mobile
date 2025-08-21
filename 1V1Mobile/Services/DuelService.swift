import Foundation
import Combine

@MainActor
class DuelService: ObservableObject {
    static let shared = DuelService()
    
    @Published var activeDuels: [Duel] = []
    @Published var pendingDuels: [Duel] = []
    @Published var completedDuels: [Duel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseService = SupabaseService.shared
    private let notificationService = NotificationService.shared
    private let gameConfigService = GameConfigurationService.shared
    private let ocrService = OCRVerificationService.shared
    
    private var verificationTimers: [String: Timer] = [:]
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        setupRealtimeSubscriptions()
    }
    
    deinit {
        // Cancel all timers
        verificationTimers.values.forEach { $0.invalidate() }
        verificationTimers.removeAll()
        
        // Cancel subscriptions
        cancellables.removeAll()
    }
    
    // MARK: - Duel Creation
    func createDuel(
        challengerId: String,
        opponentId: String,
        gameType: String,
        gameMode: String,
        challengeMessage: String = ""
    ) async throws -> Duel {
        
        // Validate game support
        guard await gameConfigService.isGameSupported(gameType: gameType, mode: gameMode) else {
            throw DuelError.unsupportedGame(gameType: gameType, mode: gameMode)
        }
        
        // Check if users are not already in an active duel
        try await validateUsersAvailable(challengerId: challengerId, opponentId: opponentId)
        
        let duel = Duel(
            id: UUID().uuidString,
            challengerId: challengerId,
            opponentId: opponentId,
            gameType: gameType,
            gameMode: gameMode,
            status: .proposed,
            createdAt: Date(),
            acceptedAt: nil,
            startedAt: nil,
            endedAt: nil,
            winnerId: nil,
            loserId: nil,
            challengerScore: nil,
            opponentScore: nil,
            verificationStatus: .pending,
            verificationMethod: nil,
            disputeStatus: .none,
            expiresAt: Date().addingTimeInterval(24 * 60 * 60), // 24 hours
            challengeMessage: challengeMessage.isEmpty ? nil : challengeMessage
        )
        
        try await supabaseService.insert(into: "duels", values: duel)
        
        // Add to pending duels
        pendingDuels.append(duel)
        
        // Send notification to opponent
        await notificationService.sendDuelChallengeNotification(
            to: opponentId,
            from: challengerId,
            gameType: gameType,
            gameMode: gameMode,
            duelId: duel.id
        )
        
        // Set expiration timer
        scheduleExpirationTimer(for: duel.id, expiresAt: duel.expiresAt)
        
        return duel
    }
    
    // MARK: - Duel Acceptance/Decline
    func acceptDuel(_ duelId: String, by userId: String) async throws {
        // Validate duel exists and user is the opponent
        guard let duel = try await getDuel(duelId),
              duel.opponentId == userId,
              duel.status == .proposed else {
            throw DuelError.invalidDuelAction
        }
        
        let updateData: [String: Any] = [
            "status": "accepted",
            "accepted_at": Date()
        ]
        
        try await supabaseService.update(
            in: "duels",
            values: updateData,
            match: ["id": duelId]
        )
        
        // Update local state
        if let index = pendingDuels.firstIndex(where: { $0.id == duelId }) {
            var updatedDuel = pendingDuels[index]
            updatedDuel = Duel(
                id: updatedDuel.id,
                challengerId: updatedDuel.challengerId,
                opponentId: updatedDuel.opponentId,
                gameType: updatedDuel.gameType,
                gameMode: updatedDuel.gameMode,
                status: .accepted,
                createdAt: updatedDuel.createdAt,
                acceptedAt: Date(),
                startedAt: updatedDuel.startedAt,
                endedAt: updatedDuel.endedAt,
                winnerId: updatedDuel.winnerId,
                loserId: updatedDuel.loserId,
                challengerScore: updatedDuel.challengerScore,
                opponentScore: updatedDuel.opponentScore,
                verificationStatus: updatedDuel.verificationStatus,
                verificationMethod: updatedDuel.verificationMethod,
                disputeStatus: updatedDuel.disputeStatus,
                expiresAt: updatedDuel.expiresAt,
                challengeMessage: updatedDuel.challengeMessage
            )
            
            pendingDuels.remove(at: index)
            activeDuels.append(updatedDuel)
        }
        
        // Send notification to challenger
        await notificationService.sendDuelAcceptedNotification(
            to: duel.challengerId,
            from: userId,
            gameType: duel.gameType,
            gameMode: duel.gameMode
        )
        
        // Cancel expiration timer
        cancelExpirationTimer(for: duelId)
    }
    
    func declineDuel(_ duelId: String, by userId: String) async throws {
        // Validate duel exists and user is the opponent
        guard let duel = try await getDuel(duelId),
              duel.opponentId == userId,
              duel.status == .proposed else {
            throw DuelError.invalidDuelAction
        }
        
        let updateData: [String: Any] = [
            "status": "declined"
        ]
        
        try await supabaseService.update(
            in: "duels",
            values: updateData,
            match: ["id": duelId]
        )
        
        // Remove from pending duels
        pendingDuels.removeAll { $0.id == duelId }
        
        // Send notification to challenger
        await notificationService.sendDuelDeclinedNotification(
            to: duel.challengerId,
            from: userId,
            gameType: duel.gameType,
            gameMode: duel.gameMode
        )
        
        // Cancel expiration timer
        cancelExpirationTimer(for: duelId)
    }
    
    // MARK: - Match Management
    func startMatch(_ duelId: String, by userId: String) async throws {
        guard let duel = try await getDuel(duelId),
              (duel.challengerId == userId || duel.opponentId == userId),
              duel.status == .accepted else {
            throw DuelError.invalidDuelAction
        }
        
        let updateData: [String: Any] = [
            "status": "in_progress",
            "started_at": Date()
        ]
        
        try await supabaseService.update(
            in: "duels",
            values: updateData,
            match: ["id": duelId]
        )
        
        // Update local state
        if let index = activeDuels.firstIndex(where: { $0.id == duelId }) {
            var updatedDuel = activeDuels[index]
            updatedDuel = Duel(
                id: updatedDuel.id,
                challengerId: updatedDuel.challengerId,
                opponentId: updatedDuel.opponentId,
                gameType: updatedDuel.gameType,
                gameMode: updatedDuel.gameMode,
                status: .inProgress,
                createdAt: updatedDuel.createdAt,
                acceptedAt: updatedDuel.acceptedAt,
                startedAt: Date(),
                endedAt: updatedDuel.endedAt,
                winnerId: updatedDuel.winnerId,
                loserId: updatedDuel.loserId,
                challengerScore: updatedDuel.challengerScore,
                opponentScore: updatedDuel.opponentScore,
                verificationStatus: updatedDuel.verificationStatus,
                verificationMethod: updatedDuel.verificationMethod,
                disputeStatus: updatedDuel.disputeStatus,
                expiresAt: updatedDuel.expiresAt,
                challengeMessage: updatedDuel.challengeMessage
            )
            activeDuels[index] = updatedDuel
        }
        
        // Send match started notifications
        let otherUserId = duel.challengerId == userId ? duel.opponentId : duel.challengerId
        await notificationService.sendMatchStartedNotification(
            to: otherUserId,
            duelId: duelId,
            gameType: duel.gameType
        )
    }
    
    func endMatch(_ duelId: String, by userId: String) async throws {
        guard let duel = try await getDuel(duelId),
              (duel.challengerId == userId || duel.opponentId == userId),
              duel.status == .inProgress else {
            throw DuelError.invalidDuelAction
        }
        
        let updateData: [String: Any] = [
            "ended_at": Date()
        ]
        
        try await supabaseService.update(
            in: "duels",
            values: updateData,
            match: ["id": duelId]
        )
        
        // Start verification timer (180 seconds)
        startVerificationTimer(for: duelId)
        
        // Send match ended notifications
        await notificationService.sendMatchEndedNotification(
            to: duel.challengerId,
            duelId: duelId
        )
        await notificationService.sendMatchEndedNotification(
            to: duel.opponentId,
            duelId: duelId
        )
    }
    
    // MARK: - Data Loading
    func loadUserDuels(for userId: String) async {
        isLoading = true
        errorMessage = nil
        
        do {
            let duels: [Duel] = try await supabaseService.fetch(
                from: "duels",
                query: supabaseService.getClient()?.database
                    .from("duels")
                    .select()
                    .or("challenger_id.eq.\(userId),opponent_id.eq.\(userId)")
                    .order("created_at", ascending: false)
            )
            
            // Categorize duels
            activeDuels = duels.filter { duel in
                [.accepted, .inProgress].contains(duel.status)
            }
            
            pendingDuels = duels.filter { duel in
                duel.status == .proposed && duel.opponentId == userId
            }
            
            completedDuels = duels.filter { duel in
                [.completed, .declined, .cancelled, .expired].contains(duel.status)
            }
            
        } catch {
            errorMessage = "Failed to load duels: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func getDuel(_ duelId: String) async throws -> Duel? {
        let duels: [Duel] = try await supabaseService.fetch(
            from: "duels",
            query: supabaseService.getClient()?.database
                .from("duels")
                .select()
                .eq("id", value: duelId)
                .limit(1)
        )
        
        return duels.first
    }
    
    // MARK: - Challenge Card Generation
    func generateChallengeCard(for duel: Duel, challenger: User) async throws -> DuelChallengeCard {
        let shareUrl = "1v1mobile://duel/\(duel.id)"
        let qrCodeData = try await QRCodeService.shared.generateQRCode(for: shareUrl)
        
        return DuelChallengeCard(
            duelId: duel.id,
            challengerName: challenger.username ?? "Player",
            challengerAvatar: challenger.avatarUrl,
            gameType: duel.gameType,
            gameMode: duel.gameMode,
            challengeMessage: duel.challengeMessage ?? "Let's duel!",
            expiresAt: duel.expiresAt,
            qrCodeData: qrCodeData.base64EncodedString(),
            shareUrl: shareUrl
        )
    }
    
    // MARK: - Verification Timer Management
    private func startVerificationTimer(for duelId: String) {
        let timer = Timer.scheduledTimer(withTimeInterval: 180.0, repeats: false) { _ in
            Task { @MainActor in
                await self.handleVerificationTimeout(duelId: duelId)
            }
        }
        
        verificationTimers[duelId] = timer
    }
    
    private func cancelVerificationTimer(for duelId: String) {
        verificationTimers[duelId]?.invalidate()
        verificationTimers.removeValue(forKey: duelId)
    }
    
    private func handleVerificationTimeout(duelId: String) async {
        do {
            // Check if both submissions received
            let submissions: [DuelSubmission] = try await supabaseService.fetch(
                from: "duel_submissions",
                query: supabaseService.getClient()?.database
                    .from("duel_submissions")
                    .select()
                    .eq("duel_id", value: duelId)
            )
            
            if submissions.count < 2 {
                // Mark as forfeited if not both submissions received
                try await markDuelAsForfeited(duelId)
            }
            
        } catch {
            print("Error handling verification timeout: \(error)")
        }
        
        // Remove timer
        verificationTimers.removeValue(forKey: duelId)
    }
    
    private func markDuelAsForfeited(_ duelId: String) async throws {
        let updateData: [String: Any] = [
            "verification_status": "forfeited",
            "status": "completed"
        ]
        
        try await supabaseService.update(
            in: "duels",
            values: updateData,
            match: ["id": duelId]
        )
        
        // Move from active to completed
        if let index = activeDuels.firstIndex(where: { $0.id == duelId }) {
            var duel = activeDuels[index]
            duel = Duel(
                id: duel.id,
                challengerId: duel.challengerId,
                opponentId: duel.opponentId,
                gameType: duel.gameType,
                gameMode: duel.gameMode,
                status: .completed,
                createdAt: duel.createdAt,
                acceptedAt: duel.acceptedAt,
                startedAt: duel.startedAt,
                endedAt: Date(),
                winnerId: duel.winnerId,
                loserId: duel.loserId,
                challengerScore: duel.challengerScore,
                opponentScore: duel.opponentScore,
                verificationStatus: .forfeited,
                verificationMethod: duel.verificationMethod,
                disputeStatus: duel.disputeStatus,
                expiresAt: duel.expiresAt,
                challengeMessage: duel.challengeMessage
            )
            
            activeDuels.remove(at: index)
            completedDuels.insert(duel, at: 0)
        }
        
        // Send forfeit notifications
        if let duel = try? await getDuel(duelId) {
            await notificationService.sendDuelForfeitNotification(
                to: duel.challengerId,
                duelId: duelId
            )
            await notificationService.sendDuelForfeitNotification(
                to: duel.opponentId,
                duelId: duelId
            )
        }
    }
    
    // MARK: - Expiration Management
    private func scheduleExpirationTimer(for duelId: String, expiresAt: Date) {
        let timeInterval = expiresAt.timeIntervalSinceNow
        guard timeInterval > 0 else {
            // Already expired
            Task {
                await expireDuel(duelId)
            }
            return
        }
        
        let timer = Timer.scheduledTimer(withTimeInterval: timeInterval, repeats: false) { _ in
            Task { @MainActor in
                await self.expireDuel(duelId)
            }
        }
        
        verificationTimers[duelId] = timer
    }
    
    private func cancelExpirationTimer(for duelId: String) {
        verificationTimers[duelId]?.invalidate()
        verificationTimers.removeValue(forKey: duelId)
    }
    
    private func expireDuel(_ duelId: String) async {
        do {
            let updateData: [String: Any] = [
                "status": "expired"
            ]
            
            try await supabaseService.update(
                in: "duels",
                values: updateData,
                match: ["id": duelId]
            )
            
            // Remove from pending duels
            pendingDuels.removeAll { $0.id == duelId }
            
            // Send expiration notification
            if let duel = try? await getDuel(duelId) {
                await notificationService.sendDuelExpiredNotification(
                    to: duel.challengerId,
                    duelId: duelId
                )
            }
            
        } catch {
            print("Error expiring duel: \(error)")
        }
        
        // Remove timer
        verificationTimers.removeValue(forKey: duelId)
    }
    
    // MARK: - Validation Methods
    private func validateUsersAvailable(challengerId: String, opponentId: String) async throws {
        // Check if challenger is not in an active duel
        let challengerActiveDuels: [Duel] = try await supabaseService.fetch(
            from: "duels",
            query: supabaseService.getClient()?.database
                .from("duels")
                .select()
                .or("challenger_id.eq.\(challengerId),opponent_id.eq.\(challengerId)")
                .in("status", values: ["accepted", "in_progress"])
        )
        
        guard challengerActiveDuels.isEmpty else {
            throw DuelError.userAlreadyInDuel(userId: challengerId)
        }
        
        // Check if opponent is not in an active duel
        let opponentActiveDuels: [Duel] = try await supabaseService.fetch(
            from: "duels",
            query: supabaseService.getClient()?.database
                .from("duels")
                .select()
                .or("challenger_id.eq.\(opponentId),opponent_id.eq.\(opponentId)")
                .in("status", values: ["accepted", "in_progress"])
        )
        
        guard opponentActiveDuels.isEmpty else {
            throw DuelError.userAlreadyInDuel(userId: opponentId)
        }
    }
    
    // MARK: - Realtime Subscriptions
    private func setupRealtimeSubscriptions() {
        // Subscribe to duel updates
        // Implementation depends on Supabase realtime capabilities
        // This would listen for changes to duels table and update local state
    }
    
    // MARK: - Dispute Management
    func reportDispute(duelId: String, reportedBy userId: String, reason: String) async throws {
        let updateData: [String: Any] = [
            "dispute_status": "pending",
            "verification_status": "disputed"
        ]
        
        try await supabaseService.update(
            in: "duels",
            values: updateData,
            match: ["id": duelId]
        )
        
        // Create dispute record
        let dispute = [
            "id": UUID().uuidString,
            "duel_id": duelId,
            "reported_by": userId,
            "reason": reason,
            "status": "pending",
            "created_at": Date()
        ] as [String: Any]
        
        try await supabaseService.insert(into: "duel_disputes", values: dispute)
        
        // Send notification to moderators
        await notificationService.sendDisputeNotification(duelId: duelId, reason: reason)
    }
    
    // MARK: - Statistics Updates
    func updatePlayerStats(duelId: String) async throws {
        guard let duel = try await getDuel(duelId),
              duel.status == .completed,
              duel.verificationStatus == .verified,
              let winnerId = duel.winnerId,
              let loserId = duel.loserId else {
            throw DuelError.invalidDuelForStatsUpdate
        }
        
        // Update winner stats
        try await updateUserStats(
            userId: winnerId,
            isWin: true,
            gameType: duel.gameType,
            score: duel.challengerId == winnerId ? duel.challengerScore : duel.opponentScore
        )
        
        // Update loser stats
        try await updateUserStats(
            userId: loserId,
            isWin: false,
            gameType: duel.gameType,
            score: duel.challengerId == loserId ? duel.challengerScore : duel.opponentScore
        )
    }
    
    private func updateUserStats(userId: String, isWin: Bool, gameType: String, score: Int?) async throws {
        // Fetch current user stats
        let users: [User] = try await supabaseService.fetch(
            from: "profiles",
            query: supabaseService.getClient()?.database
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .limit(1)
        )
        
        guard let user = users.first,
              var stats = user.stats else {
            throw DuelError.userStatsNotFound
        }
        
        // Update stats
        if isWin {
            stats.wins += 1
            stats.experience += 100 + (score ?? 0) * 2
        } else {
            stats.losses += 1
            stats.experience += 25 + (score ?? 0)
        }
        
        // Calculate new win rate
        let totalGames = stats.wins + stats.losses
        stats.winRate = totalGames > 0 ? Double(stats.wins) / Double(totalGames) * 100 : 0
        
        // Check for level up
        let newLevel = calculateLevel(from: stats.experience)
        if newLevel > stats.level {
            stats.level = newLevel
            // Send level up notification
            await notificationService.sendLevelUpNotification(to: userId, newLevel: newLevel)
        }
        
        // Update database
        let updateData: [String: Any] = [
            "stats": try JSONEncoder().encode(stats)
        ]
        
        try await supabaseService.update(
            in: "profiles",
            values: updateData,
            match: ["id": userId]
        )
    }
    
    private func calculateLevel(from experience: Int) -> Int {
        // Level calculation: 100 XP per level for first 10 levels, then 150 XP per level
        if experience < 1000 {
            return experience / 100
        } else {
            return 10 + (experience - 1000) / 150
        }
    }
    
    // MARK: - Challenge Card Sharing
    func shareChallengeCard(_ challengeCard: DuelChallengeCard) async throws {
        // Generate QR code for the challenge
        let qrCodeImage = try await QRCodeService.shared.generateQRCode(for: challengeCard.shareUrl)
        
        // Create shareable content
        let shareText = """
        🎮 Duel Challenge!
        
        \(challengeCard.challengerName) challenges you to:
        \(challengeCard.gameType) - \(challengeCard.gameMode)
        
        "\(challengeCard.challengeMessage)"
        
        Accept the challenge: \(challengeCard.shareUrl)
        
        Expires: \(formatDate(challengeCard.expiresAt))
        
        #1V1Mobile #GamingChallenge
        """
        
        // Share via OnlineSharingService
        // Implementation would integrate with existing sharing system
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Duel Errors
enum DuelError: Error, LocalizedError {
    case unsupportedGame(gameType: String, mode: String)
    case userAlreadyInDuel(userId: String)
    case invalidDuelAction
    case duelNotFound
    case invalidDuelForStatsUpdate
    case userStatsNotFound
    case verificationFailed
    case disputeAlreadyExists
    
    var errorDescription: String? {
        switch self {
        case .unsupportedGame(let gameType, let mode):
            return "Game not supported: \(gameType) - \(mode)"
        case .userAlreadyInDuel(let userId):
            return "User \(userId) is already in an active duel"
        case .invalidDuelAction:
            return "Invalid action for current duel state"
        case .duelNotFound:
            return "Duel not found"
        case .invalidDuelForStatsUpdate:
            return "Duel is not valid for stats update"
        case .userStatsNotFound:
            return "User stats not found"
        case .verificationFailed:
            return "Score verification failed"
        case .disputeAlreadyExists:
            return "A dispute already exists for this duel"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .unsupportedGame:
            return "Choose a supported game from the list"
        case .userAlreadyInDuel:
            return "Complete your current duel before starting a new one"
        case .invalidDuelAction:
            return "Check the duel status and try again"
        case .verificationFailed:
            return "Retake screenshot with clearer scoreboard"
        default:
            return "Try again or contact support"
        }
    }
}
