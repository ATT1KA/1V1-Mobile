import Foundation
import Combine
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit
import Supabase

@MainActor
class DuelService: ObservableObject {
    static let shared = DuelService()
    
    @Published var activeDuels: [Duel] = []
    @Published var pendingDuels: [Duel] = []
    @Published var completedDuels: [Duel] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var latestVictoryRecap: VictoryRecap?
    
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
            disputeStatus: DisputeStatus.none,
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
        
        guard let client = supabaseService.getClient() else {
            throw DuelError.duelNotFound
        }
        
        try await client
            .from("duels")
            .update([
                "status": "accepted",
                "accepted_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: duelId)
            .execute()
        
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
        
        guard let client = supabaseService.getClient() else {
            throw DuelError.duelNotFound
        }
        
        try await client
            .from("duels")
            .update([
                "status": "declined"
            ])
            .eq("id", value: duelId)
            .execute()
        
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
        
        guard let client = supabaseService.getClient() else {
            throw DuelError.duelNotFound
        }
        
        try await client
            .from("duels")
            .update([
                "status": "in_progress",
                "started_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: duelId)
            .execute()
        
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
        
        guard let client = supabaseService.getClient() else {
            throw DuelError.duelNotFound
        }
        
        try await client
            .from("duels")
            .update([
                "ended_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("id", value: duelId)
            .execute()
        
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
            guard let client = supabaseService.getClient() else {
                errorMessage = "Supabase client not initialized"
                isLoading = false
                return
            }
            
            let duels: [Duel] = try await client
                .from("duels")
                .select()
                .or("challenger_id.eq.\(userId),opponent_id.eq.\(userId)")
                .order("created_at", ascending: false)
                .execute()
                .value
            
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
        guard let client = supabaseService.getClient() else {
            throw DuelError.duelNotFound
        }
        
        let duels: [Duel] = try await client
            .from("duels")
            .select()
            .eq("id", value: duelId)
            .limit(1)
            .execute()
            .value
        
        return duels.first
    }
    
    // MARK: - Challenge Card Generation
    func generateChallengeCard(for duel: Duel, challenger: User) async throws -> DuelChallengeCard {
        let shareUrl = "1v1mobile://duel/\(duel.id)"
        let qrCodeData = try await generateQRCodeForURL(shareUrl)
        
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
            guard let client = supabaseService.getClient() else { return }
            
            let submissions: [DuelSubmission] = try await client
                .from("duel_submissions")
                .select()
                .eq("duel_id", value: duelId)
                .execute()
                .value
            
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
        guard let client = supabaseService.getClient() else {
            throw DuelError.duelNotFound
        }
        
        try await client
            .from("duels")
            .update([
                "verification_status": "forfeited",
                "status": "completed"
            ])
            .eq("id", value: duelId)
            .execute()
        
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
                    guard let client = supabaseService.getClient() else {
            throw DuelError.duelNotFound
        }
        
        try await client
            .from("duels")
            .update([
                "status": "expired"
            ])
            .eq("id", value: duelId)
            .execute()
            
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
        guard let client = supabaseService.getClient() else {
            throw DuelError.duelNotFound
        }
        
        // Check if challenger is not in an active duel
        let challengerActiveDuels: [Duel] = try await client
            .from("duels")
            .select()
            .or("challenger_id.eq.\(challengerId),opponent_id.eq.\(challengerId)")
            .in("status", values: ["accepted", "in_progress"])
            .execute()
            .value
        
        guard challengerActiveDuels.isEmpty else {
            throw DuelError.userAlreadyInDuel(userId: challengerId)
        }
        
        // Check if opponent is not in an active duel
        let opponentActiveDuels: [Duel] = try await client
            .from("duels")
            .select()
            .or("challenger_id.eq.\(opponentId),opponent_id.eq.\(opponentId)")
            .in("status", values: ["accepted", "in_progress"])
            .execute()
            .value
        
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
        guard let client = supabaseService.getClient() else {
            throw DuelError.duelNotFound
        }
        
        try await client
            .from("duels")
            .update([
                "dispute_status": "pending",
                "verification_status": "disputed"
            ])
            .eq("id", value: duelId)
            .execute()
        
        // Create dispute record
        let dispute: [String: AnyJSON] = [
            "id": AnyJSON.string(UUID().uuidString),
            "duel_id": AnyJSON.string(duelId),
            "reported_by": AnyJSON.string(userId),
            "reason": AnyJSON.string(reason),
            "status": AnyJSON.string("pending"),
            "created_at": AnyJSON.string(ISO8601DateFormatter().string(from: Date()))
        ]
        
        try await client
            .from("duel_disputes")
            .insert(dispute)
            .execute()
        
        // Send notification to moderators
        await notificationService.sendDisputeNotification(duelId: duelId, reason: reason)
    }
    
    // MARK: - Statistics Updates (Atomic via RPC)
    func updatePlayerStats(duelId: String) async throws {
        guard let duel = try await getDuel(duelId),
              duel.status == .completed,
              duel.verificationStatus == .verified,
              let winnerId = duel.winnerId,
              let loserId = duel.loserId else {
            throw DuelError.invalidDuelForStatsUpdate
        }

        struct RPCEntry: Codable {
            let user_id: String
            let before: UserStats
            let after: UserStats
        }
        struct UpdateDuelStatsResponse: Codable {
            let winner: RPCEntry
            let loser: RPCEntry
        }

        // Determine scores
        let winnerScore = (duel.challengerId == winnerId ? duel.challengerScore : duel.opponentScore) ?? 0
        let loserScore = (duel.challengerId == loserId ? duel.challengerScore : duel.opponentScore) ?? 0

        // Call atomic RPC
        let rpcParams: [String: Any] = [
            "p_winner_id": winnerId,
            "p_loser_id": loserId,
            "p_winner_score": winnerScore,
            "p_loser_score": loserScore,
            "p_game_type": duel.gameType
        ]

        let rpcResult: UpdateDuelStatsResponse = try await supabaseService.callRPC("update_duel_stats", parameters: rpcParams)

        // Compute deltas
        func computeDelta(userId: String, before: UserStats, after: UserStats) -> UserStatsChange {
            let winsChange = max(0, after.wins - before.wins)
            let lossesChange = max(0, after.losses - before.losses)
            let experienceChange = max(0, after.experience - before.experience)
            let winRateChange = after.winRate - before.winRate
            let levelDelta = after.level > before.level ? (after.level - before.level) : nil
            return UserStatsChange(
                userId: userId,
                winsChange: winsChange,
                lossesChange: lossesChange,
                winRateChange: winRateChange,
                levelChange: levelDelta,
                experienceChange: experienceChange
            )
        }

        let winnerDelta = computeDelta(userId: rpcResult.winner.user_id, before: rpcResult.winner.before, after: rpcResult.winner.after)
        let loserDelta = computeDelta(userId: rpcResult.loser.user_id, before: rpcResult.loser.before, after: rpcResult.loser.after)
        let statsUpdate = StatsUpdate(winnerStatsChange: winnerDelta, loserStatsChange: loserDelta)

        // Load usernames for recap
        guard let client = supabaseService.getClient() else { throw DuelError.duelNotFound }
        let users: [User] = try await client
            .from("profiles")
            .select()
            .in("id", values: [winnerId, loserId])
            .execute()
            .value
        let winnerName = users.first(where: { $0.id == winnerId })?.username ?? "Winner"
        let loserName = users.first(where: { $0.id == loserId })?.username ?? "Opponent"

        // Build recap
        let duration: TimeInterval = {
            if let start = duel.startedAt, let end = duel.endedAt { return end.timeIntervalSince(start) }
            return 0
        }()
        let recap = VictoryRecap(
            duelId: duel.id,
            winnerName: winnerName,
            loserName: loserName,
            winnerScore: winnerScore,
            loserScore: loserScore,
            gameType: duel.gameType,
            gameMode: duel.gameMode,
            matchDuration: duration,
            verificationMethod: duel.verificationMethod ?? .ocr,
            completedAt: duel.endedAt ?? Date(),
            shareableImageUrl: nil,
            statsUpdate: statsUpdate
        )

        // Emit recap for UI
        self.latestVictoryRecap = recap

        // Award points for duel completion (best-effort; do not fail the stats update)
        do {
            try await PointsService.shared.awardDuelPoints(userId: winnerId, duelId: duelId, isWin: true, score: winnerScore)
            try await PointsService.shared.awardDuelPoints(userId: loserId, duelId: duelId, isWin: false, score: loserScore)
        } catch {
            print("Failed to award points for duel \(duelId): \(error)")
        }
    }

    func clearLatestVictoryRecap() {
        latestVictoryRecap = nil
    }
    
    private func updateUserStats(userId: String, isWin: Bool, gameType: String, score: Int?) async throws {
        guard let client = supabaseService.getClient() else {
            throw DuelError.userStatsNotFound
        }
        
        // Fetch current user stats
        let users: [User] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .limit(1)
            .execute()
            .value
        
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
        let statsData = try JSONEncoder().encode(stats)
        let statsString = String(data: statsData, encoding: .utf8) ?? ""
        
        try await client
            .from("profiles")
            .update([
                "stats": statsString
            ])
            .eq("id", value: userId)
            .execute()
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
        let _ = try await generateQRCodeForURL(challengeCard.shareUrl)
        
        // Create shareable content
        let _ = """
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
    
    private func generateQRCodeForURL(_ url: String) async throws -> Data {
        let context = CIContext()
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(url.utf8)
        filter.correctionLevel = "M"
        
        guard let outputImage = filter.outputImage else {
            throw DuelError.verificationFailed
        }
        
        let transform = CGAffineTransform(scaleX: 10, y: 10)
        let scaledImage = outputImage.transformed(by: transform)
        
        guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
            throw DuelError.verificationFailed
        }
        
        let uiImage = UIImage(cgImage: cgImage)
        guard let imageData = uiImage.pngData() else {
            throw DuelError.verificationFailed
        }
        
        return imageData
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
