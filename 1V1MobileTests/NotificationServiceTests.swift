import XCTest
@testable import OneVOneMobile

final class NotificationServiceTests: XCTestCase {
    var mockService: NotificationServicing!

    override func setUpWithError() throws {
        mockService = MockNotificationService()
    }

    override func tearDownWithError() throws {
        mockService = nil
    }

    func testRequestAuthorization() async throws {
        let granted = await mockService.requestAuthorization()
        XCTAssertTrue(granted)
        XCTAssertTrue(mockService.isAuthorized)
    }

    func testMatchStartNotificationQueued() async throws {
        await mockService.sendMatchStartedNotification(to: "test-user", duelId: "duel-1", gameType: "Test")
        XCTAssertTrue(mockService.queuedNotifications.contains { $0.contains("match-start:duel-1") })
    }

    func testMatchEndAndVerificationReminderQueued() async throws {
        await mockService.sendMatchEndedNotification(to: "test-user", duelId: "duel-2")
        await mockService.sendVerificationReminder(duelId: "duel-2")
        XCTAssertTrue(mockService.queuedNotifications.contains { $0.contains("match-end:duel-2") })
        XCTAssertTrue(mockService.queuedNotifications.contains { $0.contains("verification:duel-2") })
    }

    func testDeniedAuthorizationBlocksScheduling() async throws {
        mockService.setAuthorizationStatus(false)

        await mockService.scheduleTestNotificationIn(seconds: 1)
        await mockService.sendMatchStartedNotification(to: "test-user", duelId: "denied-1", gameType: "Test")
        await mockService.sendMatchEndedNotification(to: "test-user", duelId: "denied-1")

        // When authorization is denied, no notifications should be queued
        XCTAssertFalse(mockService.queuedNotifications.contains { $0.contains("match-start:denied-1") })
        XCTAssertEqual(mockService.queuedNotifications.count, 0)
    }

    func testRevokedPermissionsBlockAfterGrant() async throws {
        let granted = await mockService.requestAuthorization()
        XCTAssertTrue(granted)
        XCTAssertTrue(mockService.isAuthorized)

        await mockService.sendMatchStartedNotification(to: "test-user", duelId: "revoked-1", gameType: "Test")
        XCTAssertTrue(mockService.queuedNotifications.contains { $0.contains("match-start:revoked-1") })

        // Revoke permissions and ensure subsequent notifications are blocked
        mockService.setAuthorizationStatus(false)
        await mockService.sendMatchStartedNotification(to: "test-user", duelId: "revoked-2", gameType: "Test")
        XCTAssertFalse(mockService.queuedNotifications.contains { $0.contains("match-start:revoked-2") })
    }
}


