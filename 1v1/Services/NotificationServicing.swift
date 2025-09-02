import Foundation

@MainActor
protocol NotificationServicing: AnyObject {
    var isAuthorized: Bool { get set }
    /// Test helper view of queued notifications for test assertions
    var queuedNotifications: [String] { get }

    func requestAuthorization() async -> Bool
    func setAuthorizationStatus(_ status: Bool)

    // Test helpers / debug
    func scheduleTestNotificationIn(seconds: TimeInterval) async

    // Duel / match notifications
    func sendMatchStartedNotification(to userId: String, duelId: String, gameType: String) async
    func sendMatchEndedNotification(to userId: String, duelId: String) async
    func sendVerificationReminder(duelId: String) async
}


