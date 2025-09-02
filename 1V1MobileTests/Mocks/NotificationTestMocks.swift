import Foundation
import XCTest
@testable import OneVOneMobile

final class MockNotificationService: ObservableObject, NotificationServicing {
    @Published var isAuthorized: Bool = false
    @Published var queuedNotifications: [String] = []

    func requestAuthorization() async -> Bool {
        // Simulate asking the system — default test helper behavior is to grant
        isAuthorized = true
        return isAuthorized
    }

    /// Test helper to simulate the system granting or revoking notification permission
    func setAuthorizationStatus(_ status: Bool) {
        isAuthorized = status
    }

    func scheduleTestNotificationIn(seconds: TimeInterval = 5) async {
        guard isAuthorized else { return }
        queuedNotifications.append("test-\(Date().timeIntervalSince1970)")
    }

    func sendMatchStartedNotification(to userId: String, duelId: String, gameType: String) async {
        guard isAuthorized else { return }
        queuedNotifications.append("match-start:\(duelId)")
    }

    func sendMatchEndedNotification(to userId: String, duelId: String) async {
        guard isAuthorized else { return }
        queuedNotifications.append("match-end:\(duelId)")
    }

    func sendVerificationReminder(duelId: String) async {
        guard isAuthorized else { return }
        queuedNotifications.append("verification:\(duelId)")
    }
}

struct TestDuelFactory {
    static func makeTestDuel(duelId: String = "test-duel") -> Duel {
        return Duel(id: duelId, challengerId: "a", opponentId: "b", gameType: "Test Game", gameMode: "Casual", status: "waiting")
    }
}

struct TestUserFactory {
    static func makeTestUser(id: String = "test-user") -> User {
        return User(id: id, email: "test@example.com", createdAt: Date(), username: "testuser")
    }
}


