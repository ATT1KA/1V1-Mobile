import Foundation
import UserNotifications
import Combine

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    @Published var pendingNotifications: [PendingNotification] = []
    
    private let supabaseService = SupabaseService.shared
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        checkAuthorizationStatus()
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
            print("Notification authorization error: \(error)")
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
    
    // MARK: - Duel Challenge Notifications
    func sendDuelChallengeNotification(
        to userId: String,
        from challengerId: String,
        gameType: String,
        gameMode: String,
        duelId: String
    ) async {
        
        // Get challenger info
        guard let challenger = try? await getUserInfo(userId: challengerId) else { return }
        
        let notification = PendingNotification(
            id: UUID().uuidString,
            userId: userId,
            type: .duelChallenge,
            title: "🎮 Duel Challenge!",
            body: "\(challenger.username ?? "A player") challenges you to \(gameType) - \(gameMode)",
            data: [
                "duel_id": duelId,
                "challenger_id": challengerId,
                "game_type": gameType,
                "game_mode": gameMode
            ],
            scheduledFor: Date(),
            expiresAt: Date().addingTimeInterval(24 * 60 * 60)
        )
        
        await sendNotification(notification)
    }
    
    func sendDuelAcceptedNotification(
        to userId: String,
        from opponentId: String,
        gameType: String,
        gameMode: String
    ) async {
        
        guard let opponent = try? await getUserInfo(userId: opponentId) else { return }
        
        let notification = PendingNotification(
            id: UUID().uuidString,
            userId: userId,
            type: .duelAccepted,
            title: "✅ Challenge Accepted!",
            body: "\(opponent.username ?? "Your opponent") accepted your \(gameType) challenge!",
            data: [
                "opponent_id": opponentId,
                "game_type": gameType,
                "game_mode": gameMode
            ],
            scheduledFor: Date(),
            expiresAt: Date().addingTimeInterval(60 * 60)
        )
        
        await sendNotification(notification)
    }
    
    func sendDuelDeclinedNotification(
        to userId: String,
        from opponentId: String,
        gameType: String,
        gameMode: String
    ) async {
        
        guard let opponent = try? await getUserInfo(userId: opponentId) else { return }
        
        let notification = PendingNotification(
            id: UUID().uuidString,
            userId: userId,
            type: .duelDeclined,
            title: "❌ Challenge Declined",
            body: "\(opponent.username ?? "Your opponent") declined your \(gameType) challenge",
            data: [
                "opponent_id": opponentId,
                "game_type": gameType,
                "game_mode": gameMode
            ],
            scheduledFor: Date(),
            expiresAt: Date().addingTimeInterval(60 * 60)
        )
        
        await sendNotification(notification)
    }
    
    // MARK: - Match Notifications
    func sendMatchStartedNotification(
        to userId: String,
        duelId: String,
        gameType: String
    ) async {
        
        let notification = PendingNotification(
            id: UUID().uuidString,
            userId: userId,
            type: .matchStarted,
            title: "🚀 Match Started!",
            body: "Your \(gameType) duel has begun. Good luck!",
            data: [
                "duel_id": duelId,
                "game_type": gameType
            ],
            scheduledFor: Date(),
            expiresAt: Date().addingTimeInterval(30 * 60)
        )
        
        await sendNotification(notification)
    }
    
    func sendMatchEndedNotification(
        to userId: String,
        duelId: String
    ) async {
        
        let notification = PendingNotification(
            id: UUID().uuidString,
            userId: userId,
            type: .matchEnded,
            title: "🏁 Match Ended!",
            body: "Submit your scoreboard screenshot within 180 seconds",
            data: [
                "duel_id": duelId,
                "action": "submit_screenshot"
            ],
            scheduledFor: Date(),
            expiresAt: Date().addingTimeInterval(180) // 3 minutes
        )
        
        await sendNotification(notification)
        
        // Schedule reminder notification
        let reminderNotification = PendingNotification(
            id: UUID().uuidString,
            userId: userId,
            type: .verificationReminder,
            title: "⏰ Submission Reminder",
            body: "Only 60 seconds left to submit your screenshot!",
            data: [
                "duel_id": duelId,
                "action": "submit_screenshot"
            ],
            scheduledFor: Date().addingTimeInterval(120), // 2 minutes after match end
            expiresAt: Date().addingTimeInterval(180)
        )
        
        await scheduleNotification(reminderNotification)
    }
    
    func sendDuelForfeitNotification(
        to userId: String,
        duelId: String
    ) async {
        
        let notification = PendingNotification(
            id: UUID().uuidString,
            userId: userId,
            type: .duelForfeited,
            title: "⚠️ Duel Forfeited",
            body: "The duel was forfeited due to missing score submission",
            data: [
                "duel_id": duelId
            ],
            scheduledFor: Date(),
            expiresAt: Date().addingTimeInterval(60 * 60)
        )
        
        await sendNotification(notification)
    }
    
    func sendDuelExpiredNotification(
        to userId: String,
        duelId: String
    ) async {
        
        let notification = PendingNotification(
            id: UUID().uuidString,
            userId: userId,
            type: .duelExpired,
            title: "⏰ Challenge Expired",
            body: "Your duel challenge has expired",
            data: [
                "duel_id": duelId
            ],
            scheduledFor: Date(),
            expiresAt: Date().addingTimeInterval(60 * 60)
        )
        
        await sendNotification(notification)
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
            id: UUID().uuidString,
            userId: userId,
            type: .verificationSuccess,
            title: title,
            body: body,
            data: [
                "duel_id": duelId,
                "is_winner": isWinner,
                "action": "view_recap"
            ],
            scheduledFor: Date(),
            expiresAt: Date().addingTimeInterval(24 * 60 * 60)
        )
        
        await sendNotification(notification)
    }
    
    func sendVerificationFailedNotification(
        to userId: String,
        duelId: String,
        reason: String
    ) async {
        
        let notification = PendingNotification(
            id: UUID().uuidString,
            userId: userId,
            type: .verificationFailed,
            title: "❌ Verification Failed",
            body: "Score verification failed: \(reason)",
            data: [
                "duel_id": duelId,
                "reason": reason,
                "action": "resubmit_or_dispute"
            ],
            scheduledFor: Date(),
            expiresAt: Date().addingTimeInterval(60 * 60)
        )
        
        await sendNotification(notification)
    }
    
    // MARK: - System Notifications
    func sendLevelUpNotification(to userId: String, newLevel: Int) async {
        let notification = PendingNotification(
            id: UUID().uuidString,
            userId: userId,
            type: .levelUp,
            title: "🎉 Level Up!",
            body: "Congratulations! You've reached level \(newLevel)!",
            data: [
                "new_level": newLevel,
                "action": "view_profile"
            ],
            scheduledFor: Date(),
            expiresAt: Date().addingTimeInterval(24 * 60 * 60)
        )
        
        await sendNotification(notification)
    }
    
    func sendDisputeNotification(duelId: String, reason: String) async {
        // Send to moderator queue
        let notification = PendingNotification(
            id: UUID().uuidString,
            userId: "moderator_queue",
            type: .dispute,
            title: "🚨 Duel Dispute",
            body: "A duel requires moderator review: \(reason)",
            data: [
                "duel_id": duelId,
                "reason": reason,
                "action": "moderate_dispute"
            ],
            scheduledFor: Date(),
            expiresAt: Date().addingTimeInterval(7 * 24 * 60 * 60) // 7 days
        )
        
        await sendNotification(notification)
    }
    
    // MARK: - Notification Delivery
    private func sendNotification(_ notification: PendingNotification) async {
        // Save to database for cross-device sync
        do {
            try await supabaseService.insert(into: "notifications", values: notification)
        } catch {
            print("Error saving notification: \(error)")
        }
        
        // Send local push notification
        await scheduleNotification(notification)
    }
    
    private func scheduleNotification(_ notification: PendingNotification) async {
        guard isAuthorized else { return }
        
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.userInfo = notification.data
        
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
        } catch {
            print("Error scheduling notification: \(error)")
        }
    }
    
    // MARK: - Helper Methods
    private func getUserInfo(userId: String) async throws -> User {
        let users: [User] = try await supabaseService.fetch(
            from: "profiles",
            query: supabaseService.getClient()?.database
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .limit(1)
        )
        
        guard let user = users.first else {
            throw NotificationError.userNotFound
        }
        
        return user
    }
}

// MARK: - Notification Models
struct PendingNotification: Codable, Identifiable {
    let id: String
    let userId: String
    let type: NotificationType
    let title: String
    let body: String
    let data: [String: Any]
    let scheduledFor: Date
    let expiresAt: Date
    let isRead: Bool
    let deliveredAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case title
        case body
        case data
        case scheduledFor = "scheduled_for"
        case expiresAt = "expires_at"
        case isRead = "is_read"
        case deliveredAt = "delivered_at"
    }
    
    init(id: String, userId: String, type: NotificationType, title: String, body: String, data: [String: Any], scheduledFor: Date, expiresAt: Date, isRead: Bool = false, deliveredAt: Date? = nil) {
        self.id = id
        self.userId = userId
        self.type = type
        self.title = title
        self.body = body
        self.data = data
        self.scheduledFor = scheduledFor
        self.expiresAt = expiresAt
        self.isRead = isRead
        self.deliveredAt = deliveredAt
    }
}

enum NotificationType: String, Codable, CaseIterable {
    case duelChallenge = "duel_challenge"
    case duelAccepted = "duel_accepted"
    case duelDeclined = "duel_declined"
    case matchStarted = "match_started"
    case matchEnded = "match_ended"
    case verificationReminder = "verification_reminder"
    case verificationSuccess = "verification_success"
    case verificationFailed = "verification_failed"
    case duelForfeited = "duel_forfeited"
    case duelExpired = "duel_expired"
    case dispute = "dispute"
    case levelUp = "level_up"
    case achievement = "achievement"
    
    var categoryIdentifier: String {
        switch self {
        case .duelChallenge:
            return "DUEL_CHALLENGE_CATEGORY"
        case .matchEnded:
            return "MATCH_ENDED_CATEGORY"
        case .verificationReminder:
            return "VERIFICATION_REMINDER_CATEGORY"
        case .dispute:
            return "DISPUTE_CATEGORY"
        default:
            return "DEFAULT_CATEGORY"
        }
    }
    
    var displayName: String {
        switch self {
        case .duelChallenge: return "Duel Challenge"
        case .duelAccepted: return "Challenge Accepted"
        case .duelDeclined: return "Challenge Declined"
        case .matchStarted: return "Match Started"
        case .matchEnded: return "Match Ended"
        case .verificationReminder: return "Submit Screenshot"
        case .verificationSuccess: return "Verification Success"
        case .verificationFailed: return "Verification Failed"
        case .duelForfeited: return "Duel Forfeited"
        case .duelExpired: return "Challenge Expired"
        case .dispute: return "Dispute"
        case .levelUp: return "Level Up"
        case .achievement: return "Achievement"
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
