import Foundation
import UserNotifications
import Combine
import Supabase

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    @Published var pendingNotifications: [PendingNotification] = []
    @Published var activeMatchNotifications: [String: MatchNotificationState] = [:]
    
    private let supabaseService = SupabaseService.shared
    private var cancellables = Set<AnyCancellable>()
    private var realtimeSubscriptions: [String: Any] = [:]
    private var matchEndTimers: [String: Timer] = [:]
    private var matchMonitoringTasks: [String: Task<Void, Never>] = [:]
    private var notificationDeliveryQueue: [PendingNotification] = []
    
    private init() {
        checkAuthorizationStatus()
        setupRealtimeSubscriptions()
        startNotificationDeliveryQueue()
    }
    
    // deinit intentionally omitted; singleton lives app lifetime
    
    // MARK: - Resource Management
    private func cleanupResources() {
        realtimeSubscriptions.removeAll()
        matchEndTimers.values.forEach { $0.invalidate() }
        matchMonitoringTasks.values.forEach { $0.cancel() }
    }
    
    // MARK: - Authorization
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("❌ Notification authorization error: \(error)")
            return false
        }
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Real-time Match Monitoring
    private func setupRealtimeSubscriptions() {
        // Basic realtime subscription to duels table for inserts/updates
        guard let client = supabaseService.getClient() else {
            print("⚠️ Supabase client not initialized; realtime disabled")
            return
        }
        // TODO: Implement Supabase Realtime subscription using supabase-swift API once confirmed.
        print("ℹ️ Realtime setup placeholder initialized")
    }
    
    private func handleDuelUpdate(_ payload: [String: Any]) async {
        guard let record = payload["new"] as? [String: Any],
              let duelId = record["id"] as? String,
              let status = record["status"] as? String else { 
            print("⚠️ Invalid duel update payload")
            return 
        }
        
        print("🔄 Duel update received: \(duelId) - Status: \(status)")
        
        switch status {
        case "in_progress":
            await startMatchMonitoring(duelId: duelId, record: record)
        case "completed":
            await stopMatchMonitoring(duelId: duelId)
        case "ended":
            await handleMatchEnded(duelId: duelId, record: record)
        default:
            print("ℹ️ Unhandled duel status: \(status)")
        }
    }
    
    private func handleDuelInsert(_ payload: [String: Any]) async {
        guard let record = payload["new"] as? [String: Any],
              let duelId = record["id"] as? String,
              let challengerId = record["challenger_id"] as? String,
              let opponentId = record["opponent_id"] as? String,
              let gameType = record["game_type"] as? String,
              let gameMode = record["game_mode"] as? String else { 
            print("⚠️ Invalid duel insert payload")
            return 
        }
        
        print("🆕 New duel created: \(duelId)")
        
        // Send challenge notification to opponent
        await sendDuelChallengeNotification(
            to: opponentId,
            from: challengerId,
            gameType: gameType,
            gameMode: gameMode,
            duelId: duelId
        )
    }
    
    // MARK: - Match Monitoring
    private func startMatchMonitoring(duelId: String, record: [String: Any]) async {
        guard let gameType = record["game_type"] as? String,
              let challengerId = record["challenger_id"] as? String,
              let opponentId = record["opponent_id"] as? String else { 
            print("⚠️ Invalid match data for monitoring")
            return 
        }
        
        print("🎮 Starting match monitoring for duel: \(duelId)")
        
        // Update state
        activeMatchNotifications[duelId] = MatchNotificationState(
            duelId: duelId,
            gameType: gameType,
            status: .inProgress,
            startTime: Date(),
            endTime: nil,
            lastPingTime: nil,
            pingCount: 0
        )
        
        // Start monitoring task
        let monitoringTask = Task {
            await monitorMatchProgress(duelId: duelId, challengerId: challengerId, opponentId: opponentId)
        }
        
        matchMonitoringTasks[duelId] = monitoringTask
        
        // Send match started notifications
        await sendMatchStartedNotification(to: challengerId, duelId: duelId, gameType: gameType)
        await sendMatchStartedNotification(to: opponentId, duelId: duelId, gameType: gameType)
    }
    
    private func stopMatchMonitoring(duelId: String) async {
        print("⏹️ Stopping match monitoring for duel: \(duelId)")
        
        // Cancel monitoring task
        matchMonitoringTasks[duelId]?.cancel()
        matchMonitoringTasks.removeValue(forKey: duelId)
        
        // Invalidate timer
        matchEndTimers[duelId]?.invalidate()
        matchEndTimers.removeValue(forKey: duelId)
        
        // Update state
        activeMatchNotifications.removeValue(forKey: duelId)
    }
    
    private func handleMatchEnded(duelId: String, record: [String: Any]) async {
        guard let challengerId = record["challenger_id"] as? String,
              let opponentId = record["opponent_id"] as? String else { 
            print("⚠️ Invalid match end data")
            return 
        }
        
        print("🏁 Match ended for duel: \(duelId)")
        
        // Send "Match Ended?" notifications to both players
        await sendMatchEndedNotification(to: challengerId, duelId: duelId)
        await sendMatchEndedNotification(to: opponentId, duelId: duelId)
        
        // Start verification timer
        startVerificationTimer(for: duelId)
        
        // Update state
        if var state = activeMatchNotifications[duelId] {
            state.status = .ended
            state.endTime = Date()
            activeMatchNotifications[duelId] = state
        }
    }
    
    // MARK: - Match Progress Monitoring
    private func monitorMatchProgress(duelId: String, challengerId: String, opponentId: String) async {
        let pingInterval: TimeInterval = 30 // Ping every 30 seconds
        let maxPingDuration: TimeInterval = 300 // Max 5 minutes of pinging
        
        var pingCount = 0
        let maxPings = Int(maxPingDuration / pingInterval)
        
        while pingCount < maxPings {
            do {
                try await Task.sleep(nanoseconds: UInt64(pingInterval * 1_000_000_000))
                
                // Check if match is still active
                guard let state = activeMatchNotifications[duelId],
                      state.status == .inProgress else {
                    print("🛑 Match monitoring stopped for duel: \(duelId)")
                    break
                }
                
                pingCount += 1
                
                // Send periodic "Match in Progress" ping
                await sendMatchProgressPing(
                    to: challengerId,
                    duelId: duelId,
                    pingNumber: pingCount
                )
                await sendMatchProgressPing(
                    to: opponentId,
                    duelId: duelId,
                    pingNumber: pingCount
                )
                
                // Update last ping time
                if var updatedState = activeMatchNotifications[duelId] {
                    updatedState.lastPingTime = Date()
                    updatedState.pingCount = pingCount
                    activeMatchNotifications[duelId] = updatedState
                }
                
            } catch {
                print("❌ Error in match monitoring: \(error)")
                break
            }
        }
        
        // If we reach max pings, send a final reminder
        if pingCount >= maxPings {
            await sendMatchTimeoutWarning(to: challengerId, duelId: duelId)
            await sendMatchTimeoutWarning(to: opponentId, duelId: duelId)
        }
    }
    
    // MARK: - Verification Timer
    private func startVerificationTimer(for duelId: String) {
        let verificationDuration: TimeInterval = 180 // 3 minutes
        
        let timer = Timer.scheduledTimer(withTimeInterval: verificationDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.handleVerificationTimeout(duelId: duelId)
            }
        }
        
        matchEndTimers[duelId] = timer
        
        // Send reminder at 60 seconds
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in
            Task { @MainActor in
                await self?.sendVerificationReminder(duelId: duelId)
            }
        }
    }
    
    private func handleVerificationTimeout(duelId: String) async {
        print("⏰ Verification timeout for duel: \(duelId)")
        
        // Check if both submissions received
        do {
            let submissions: [DuelSubmission] = try await supabaseService.fetch(from: "duel_submissions")
            
            if submissions.count < 2 {
                // Mark as forfeited
                await markDuelAsForfeited(duelId)
            }
            
        } catch {
            print("❌ Error checking submissions: \(error)")
        }
        
        // Clean up
        matchEndTimers.removeValue(forKey: duelId)
    }
    
    // MARK: - Notification Delivery Queue
    private func startNotificationDeliveryQueue() {
        Task {
            while true {
                await processNotificationQueue()
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }
    }
    
    // MARK: - Test Helpers
    func scheduleTestNotificationIn(seconds: TimeInterval = 5) async {
        let notification = PendingNotification(
            userId: AuthService.shared.currentUser?.id ?? "test-user",
            type: .achievement,
            title: "Test Notification",
            body: "This is a test notification.",
            data: NotificationData(action: "test"),
            expiresAt: Date().addingTimeInterval(3600)
        )
        await queueNotification(notification)
    }
    
    private func processNotificationQueue() async {
        guard !notificationDeliveryQueue.isEmpty else { return }
        
        let notifications = notificationDeliveryQueue
        notificationDeliveryQueue.removeAll()
        
        for notification in notifications {
            await deliverNotification(notification)
        }
    }
    
    private func deliverNotification(_ notification: PendingNotification) async {
        // Save to database for cross-device sync
        do {
            try await supabaseService.insert(into: "notifications", values: notification)
            print("✅ Notification saved to database: \(notification.id)")
        } catch {
            print("❌ Error saving notification: \(error)")
            // Re-queue for retry
            notificationDeliveryQueue.append(notification)
            return
        }
        
        // Send local push notification
        await scheduleNotification(notification)
    }
    
    private func scheduleNotification(_ notification: PendingNotification) async {
        guard isAuthorized else { 
            print("⚠️ Notifications not authorized")
            return 
        }
        
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.userInfo = notification.data.toDictionary()
        
        // Add category for actionable notifications
        content.categoryIdentifier = notification.type.categoryIdentifier
        
        let timeInterval = notification.scheduledFor.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(timeInterval, 1),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Notification scheduled: \(notification.id)")
        } catch {
            print("❌ Error scheduling notification: \(error)")
        }
    }
    
    // MARK: - Duel Challenge Notifications
    func sendDuelChallengeNotification(
        to userId: String,
        from challengerId: String,
        gameType: String,
        gameMode: String,
        duelId: String
    ) async {
        
        // Get challenger info
        guard let challenger = try? await getUserInfo(userId: challengerId) else { 
            print("⚠️ Could not get challenger info")
            return 
        }
        
        let notification = PendingNotification(
            userId: userId,
            type: .duelChallenge,
            title: "🎮 Duel Challenge!",
            body: "\(challenger.username ?? "A player") challenges you to \(gameType) - \(gameMode)",
            data: NotificationData(
                duelId: duelId,
                challengerId: challengerId,
                gameType: gameType,
                gameMode: gameMode
            ),
            expiresAt: Date().addingTimeInterval(24 * 60 * 60),
            priority: 1
        )
        
        await queueNotification(notification)
    }
    
    func sendDuelAcceptedNotification(
        to userId: String,
        from opponentId: String,
        gameType: String,
        gameMode: String
    ) async {
        
        guard let opponent = try? await getUserInfo(userId: opponentId) else { return }
        
        let notification = PendingNotification(
            userId: userId,
            type: .duelAccepted,
            title: "✅ Challenge Accepted!",
            body: "\(opponent.username ?? "Your opponent") accepted your \(gameType) challenge!",
            data: NotificationData(
                opponentId: opponentId,
                gameType: gameType,
                gameMode: gameMode
            ),
            expiresAt: Date().addingTimeInterval(60 * 60)
        )
        
        await queueNotification(notification)
    }
    
    func sendDuelDeclinedNotification(
        to userId: String,
        from opponentId: String,
        gameType: String,
        gameMode: String
    ) async {
        
        guard let opponent = try? await getUserInfo(userId: opponentId) else { return }
        
        let notification = PendingNotification(
            userId: userId,
            type: .duelDeclined,
            title: "❌ Challenge Declined",
            body: "\(opponent.username ?? "Your opponent") declined your \(gameType) challenge",
            data: NotificationData(
                opponentId: opponentId,
                gameType: gameType,
                gameMode: gameMode
            ),
            expiresAt: Date().addingTimeInterval(60 * 60)
        )
        
        await queueNotification(notification)
    }
    
    // MARK: - Match Notifications
    func sendMatchStartedNotification(
        to userId: String,
        duelId: String,
        gameType: String
    ) async {
        
        let notification = PendingNotification(
            userId: userId,
            type: .matchStarted,
            title: "🚀 Match Started!",
            body: "Your \(gameType) duel has begun. Good luck!",
            data: NotificationData(
                duelId: duelId,
                gameType: gameType,
                action: "start_match"
            ),
            expiresAt: Date().addingTimeInterval(30 * 60)
        )
        
        await queueNotification(notification)
    }
    
    func sendMatchProgressPing(
        to userId: String,
        duelId: String,
        pingNumber: Int
    ) async {
        
        let notification = PendingNotification(
            userId: userId,
            type: .matchProgress,
            title: "⚔️ Match in Progress",
            body: "Your duel is still active. Don't forget to submit your score!",
            data: NotificationData(
                duelId: duelId,
                action: "continue_match",
                pingNumber: pingNumber
            ),
            expiresAt: Date().addingTimeInterval(60),
            priority: 3
        )
        
        await queueNotification(notification)
    }
    
    func sendMatchEndedNotification(
        to userId: String,
        duelId: String
    ) async {
        
        let notification = PendingNotification(
            userId: userId,
            type: .matchEnded,
            title: "🏁 Match Ended!",
            body: "Submit your scoreboard screenshot within 180 seconds",
            data: NotificationData(
                duelId: duelId,
                action: "submit_screenshot"
            ),
            expiresAt: Date().addingTimeInterval(180), // 3 minutes
            priority: 1
        )
        
        await queueNotification(notification)
        
        // Schedule reminder notification
        let reminderNotification = PendingNotification(
            userId: userId,
            type: .verificationReminder,
            title: "⏰ Submission Reminder",
            body: "Only 60 seconds left to submit your screenshot!",
            data: NotificationData(
                duelId: duelId,
                action: "submit_screenshot"
            ),
            scheduledFor: Date().addingTimeInterval(120), // 2 minutes after match end
            expiresAt: Date().addingTimeInterval(180),
            priority: 1
        )
        
        await queueNotification(reminderNotification)
    }
    
    func sendVerificationReminder(
        duelId: String
    ) async {
        
        // Get both players for the duel
        do {
            guard let client = supabaseService.getClient() else { return }
            let duels: [Duel] = try await client
                .from("duels")
                .select()
                .eq("id", value: duelId)
                .execute()
                .value
            guard let duel = duels.first else { return }
            // Send reminder to both players
            await sendVerificationReminderNotification(to: duel.challengerId, duelId: duelId)
            await sendVerificationReminderNotification(to: duel.opponentId, duelId: duelId)
            
        } catch {
            print("❌ Error sending verification reminder: \(error)")
        }
    }
    
    private func sendVerificationReminderNotification(
        to userId: String,
        duelId: String
    ) async {
        
        let notification = PendingNotification(
            userId: userId,
            type: .verificationReminder,
            title: "⏰ Submission Reminder",
            body: "Only 60 seconds left to submit your screenshot!",
            data: NotificationData(
                duelId: duelId,
                action: "submit_screenshot"
            ),
            expiresAt: Date().addingTimeInterval(120),
            priority: 1
        )
        
        await queueNotification(notification)
    }
    
    func sendMatchTimeoutWarning(
        to userId: String,
        duelId: String
    ) async {
        
        let notification = PendingNotification(
            userId: userId,
            type: .matchTimeout,
            title: "⚠️ Match Timeout Warning",
            body: "Your match has been running for a while. Consider ending it soon.",
            data: NotificationData(
                duelId: duelId,
                action: "end_match"
            ),
            expiresAt: Date().addingTimeInterval(60 * 5),
            priority: 2
        )
        
        await queueNotification(notification)
    }
    
    func sendDuelForfeitNotification(
        to userId: String,
        duelId: String
    ) async {
        
        let notification = PendingNotification(
            userId: userId,
            type: .duelForfeited,
            title: "⚠️ Duel Forfeited",
            body: "The duel was forfeited due to missing score submission",
            data: NotificationData(duelId: duelId),
            expiresAt: Date().addingTimeInterval(60 * 60)
        )
        
        await queueNotification(notification)
    }
    
    func sendDuelExpiredNotification(
        to userId: String,
        duelId: String
    ) async {
        
        let notification = PendingNotification(
            userId: userId,
            type: .duelExpired,
            title: "⏰ Challenge Expired",
            body: "Your duel challenge has expired",
            data: NotificationData(duelId: duelId),
            expiresAt: Date().addingTimeInterval(60 * 60)
        )
        
        await queueNotification(notification)
    }
    
    // MARK: - Verification Notifications
    func sendVerificationSuccessNotification(
        to userId: String,
        duelId: String,
        isWinner: Bool
    ) async {
        
        let title = isWinner ? "🏆 Victory!" : "💪 Good Fight!"
        let body = isWinner ? "You won the duel! Check your victory recap." : "Better luck next time! Your stats have been updated."
        
        let notification = PendingNotification(
            userId: userId,
            type: .verificationSuccess,
            title: title,
            body: body,
            data: NotificationData(
                duelId: duelId,
                action: "view_recap",
                isWinner: isWinner
            ),
            expiresAt: Date().addingTimeInterval(24 * 60 * 60)
        )
        
        await queueNotification(notification)
    }
    
    func sendVerificationFailedNotification(
        to userId: String,
        duelId: String,
        reason: String
    ) async {
        
        let notification = PendingNotification(
            userId: userId,
            type: .verificationFailed,
            title: "❌ Verification Failed",
            body: "Score verification failed: \(reason)",
            data: NotificationData(
                duelId: duelId,
                action: "resubmit_or_dispute",
                reason: reason
            ),
            expiresAt: Date().addingTimeInterval(60 * 60)
        )
        
        await queueNotification(notification)
    }
    
    // MARK: - System Notifications
    func sendLevelUpNotification(to userId: String, newLevel: Int) async {
        let notification = PendingNotification(
            userId: userId,
            type: .levelUp,
            title: "🎉 Level Up!",
            body: "Congratulations! You've reached level \(newLevel)!",
            data: NotificationData(
                action: "view_profile",
                newLevel: newLevel
            ),
            expiresAt: Date().addingTimeInterval(24 * 60 * 60)
        )
        
        await queueNotification(notification)
    }
    
    func sendDisputeNotification(duelId: String, reason: String) async {
        // Send to moderator queue
        let notification = PendingNotification(
            userId: "moderator_queue",
            type: .dispute,
            title: "🚨 Duel Dispute",
            body: "A duel requires moderator review: \(reason)",
            data: NotificationData(
                duelId: duelId,
                action: "moderate_dispute",
                reason: reason
            ),
            expiresAt: Date().addingTimeInterval(7 * 24 * 60 * 60), // 7 days
            priority: 1
        )
        
        await queueNotification(notification)
    }
    
    // MARK: - Helper Methods
    private func queueNotification(_ notification: PendingNotification) async {
        notificationDeliveryQueue.append(notification)
        print("📬 Notification queued: \(notification.type.rawValue) for user \(notification.userId)")
    }
    
    private func getUserInfo(userId: String) async throws -> User {
        guard let client = supabaseService.getClient() else { throw NotificationError.userNotFound }
        let users: [User] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .execute()
            .value
        guard let user = users.first else {
            throw NotificationError.userNotFound
        }
        return user
    }
    
    private func markDuelAsForfeited(_ duelId: String) async {
        do {
            let updateData: [String: AnyJSON] = [
                "verification_status": AnyJSON.string("forfeited"),
                "status": AnyJSON.string("completed")
            ]
            
            guard let client = supabaseService.getClient() else { return }
            try await client
                .from("duels")
                .update(updateData)
                .eq("id", value: duelId)
                .execute()
            
            // Send forfeit notifications for this duel only
            let duels: [Duel] = try await client
                .from("duels")
                .select()
                .eq("id", value: duelId)
                .execute()
                .value
            if let duel = duels.first {
                await sendDuelForfeitNotification(to: duel.challengerId, duelId: duelId)
                await sendDuelForfeitNotification(to: duel.opponentId, duelId: duelId)
            }
            
        } catch {
            print("❌ Error marking duel as forfeited: \(error)")
        }
    }
}



// MARK: - Notification Categories Setup
extension NotificationService {
    func setupNotificationCategories() {
        let center = UNUserNotificationCenter.current()
        
        // Duel Challenge Category
        let acceptAction = UNNotificationAction(
            identifier: "ACCEPT_DUEL",
            title: "Accept",
            options: [.foreground]
        )
        let declineAction = UNNotificationAction(
            identifier: "DECLINE_DUEL",
            title: "Decline",
            options: []
        )
        let duelChallengeCategory = UNNotificationCategory(
            identifier: "DUEL_CHALLENGE_CATEGORY",
            actions: [acceptAction, declineAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Match Ended Category
        let submitAction = UNNotificationAction(
            identifier: "SUBMIT_SCREENSHOT",
            title: "Submit Screenshot",
            options: [.foreground]
        )
        let matchEndedCategory = UNNotificationCategory(
            identifier: "MATCH_ENDED_CATEGORY",
            actions: [submitAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Verification Reminder Category
        let submitReminderAction = UNNotificationAction(
            identifier: "SUBMIT_SCREENSHOT_REMINDER",
            title: "Submit Now",
            options: [.foreground]
        )
        let verificationReminderCategory = UNNotificationCategory(
            identifier: "VERIFICATION_REMINDER_CATEGORY",
            actions: [submitReminderAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Dispute Category
        let reviewAction = UNNotificationAction(
            identifier: "REVIEW_DISPUTE",
            title: "Review",
            options: [.foreground]
        )
        let disputeCategory = UNNotificationCategory(
            identifier: "DISPUTE_CATEGORY",
            actions: [reviewAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([
            duelChallengeCategory,
            matchEndedCategory,
            verificationReminderCategory,
            disputeCategory
        ])
    }
    
    func handleNotificationAction(
        identifier: String,
        notification: UNNotification,
        completionHandler: @escaping () -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        
        switch identifier {
        case "ACCEPT_DUEL":
            if let duelId = userInfo["duel_id"] as? String {
                Task {
                    try? await DuelService.shared.acceptDuel(duelId, by: AuthService.shared.currentUser?.id ?? "")
                    completionHandler()
                }
            }
            
        case "DECLINE_DUEL":
            if let duelId = userInfo["duel_id"] as? String {
                Task {
                    try? await DuelService.shared.declineDuel(duelId, by: AuthService.shared.currentUser?.id ?? "")
                    completionHandler()
                }
            }
            
        case "SUBMIT_SCREENSHOT", "SUBMIT_SCREENSHOT_REMINDER":
            if let duelId = userInfo["duel_id"] as? String {
                // Navigate to screenshot submission
                NavigationManager.shared.navigateToScreenshotSubmission(duelId: duelId)
                completionHandler()
            }
            
        case "REVIEW_DISPUTE":
            if let duelId = userInfo["duel_id"] as? String {
                // Navigate to dispute review
                NavigationManager.shared.navigateToDisputeReview(duelId: duelId)
                completionHandler()
            }
            
        default:
            completionHandler()
        }
    }
}

// MARK: - Notification Errors
enum NotificationError: Error, LocalizedError {
    case authorizationDenied
    case userNotFound
    case notificationFailed
    case invalidNotificationData
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Notification authorization denied"
        case .userNotFound:
            return "User not found for notification"
        case .notificationFailed:
            return "Failed to send notification"
        case .invalidNotificationData:
            return "Invalid notification data"
        }
    }
}
