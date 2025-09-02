import XCTest
@testable import OneVOneMobile

final class RealtimeEdgeCaseTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Ensure a clean shared auth state
        AuthService.shared.currentUser = nil
    }

    func testDuplicateStatusUpdatesDedupe() async throws {
        // Arrange
        let user = User(id: "dup-user", email: "dup@example.com")
        AuthService.shared.currentUser = user
        let mock = MockSupabaseAdapter()
        let service = NotificationService(supabaseService: mock)

        let duelId = "duel-duplicate"
        let record: [String: Any] = [
            "id": duelId,
            "status": "in_progress",
            "game_type": "EdgeCase",
            "challenger_id": user.id,
            "opponent_id": "opponent"
        ]

        // Act: emit the same in_progress status twice
        await service.receiveDuelPayload(["new": record])
        await service.receiveDuelPayload(["new": record])

        // Assert: only one matchStarted notification queued and state is inProgress
        XCTAssertEqual(service.activeMatchNotifications[duelId]?.status, .inProgress)
        let matchStartedCount = service.pendingNotifications.filter { $0.type == .matchStarted && $0.data.duelId == duelId }.count
        XCTAssertEqual(matchStartedCount, 1, "Duplicate in_progress updates should not enqueue duplicate matchStarted notifications")
    }

    func testSupabaseConnectionLossAndResubscribe() async throws {
        // Arrange
        let user = User(id: "conn-user", email: "conn@example.com")
        AuthService.shared.currentUser = user
        let mock = MockSupabaseAdapter()
        let service = NotificationService(supabaseService: mock)

        // Ensure initial subscription exists by emitting an insert while connected
        let initialDuel: [String: Any] = [
            "id": "duel-initial",
            "challenger_id": "other",
            "opponent_id": user.id,
            "game_type": "EdgeConn",
            "game_mode": "Casual"
        ]
        service.emitRemoteDuelInsert(record: initialDuel)

        // Act: simulate connection loss, then reconnect, then emit a duel insert
        await MainActor.run { service.simulateConnectionLoss() }

        // While disconnected, emits should be ignored
        let ignoredDuel: [String: Any] = [
            "id": "duel-ignored",
            "challenger_id": "other",
            "opponent_id": user.id,
            "game_type": "EdgeConn",
            "game_mode": "Casual"
        ]
        service.emitRemoteDuelInsert(record: ignoredDuel)

        // Now reconnect
        await MainActor.run { service.reconnectSupabase() }

        // After reconnect, emits should be delivered
        let deliveredDuel: [String: Any] = [
            "id": "duel-delivered",
            "challenger_id": "other",
            "opponent_id": user.id,
            "game_type": "EdgeConn",
            "game_mode": "Casual"
        ]
        service.emitRemoteDuelInsert(record: deliveredDuel)

        // Assert: received challenge notification for the delivered duel
        XCTAssertTrue(service.pendingNotifications.contains { $0.type == .duelChallenge && $0.data.duelId == "duel-delivered" })
    }

    func testTwoDuelsIndependentStateAndNotifications() async throws {
        // Arrange
        let user = User(id: "multi-user", email: "multi@example.com")
        AuthService.shared.currentUser = user
        let mock = MockSupabaseAdapter()
        let service = NotificationService(supabaseService: mock)

        let duelA = "duel-A"
        let duelB = "duel-B"

        let recordA: [String: Any] = [
            "id": duelA,
            "status": "in_progress",
            "game_type": "EdgeMulti",
            "challenger_id": user.id,
            "opponent_id": "opponent-A"
        ]

        let recordB: [String: Any] = [
            "id": duelB,
            "status": "in_progress",
            "game_type": "EdgeMulti",
            "challenger_id": user.id,
            "opponent_id": "opponent-B"
        ]

        // Act: start both duels
        await service.receiveDuelPayload(["new": recordA])
        await service.receiveDuelPayload(["new": recordB])

        // Assert: both duels are being monitored and have matchStarted notifications
        XCTAssertEqual(service.activeMatchNotifications[duelA]?.status, .inProgress)
        XCTAssertEqual(service.activeMatchNotifications[duelB]?.status, .inProgress)
        XCTAssertTrue(service.pendingNotifications.contains { $0.type == .matchStarted && $0.data.duelId == duelA })
        XCTAssertTrue(service.pendingNotifications.contains { $0.type == .matchStarted && $0.data.duelId == duelB })

        // End duel A and ensure duel B remains active
        let endedA: [String: Any] = [
            "id": duelA,
            "status": "ended",
            "game_type": "EdgeMulti",
            "challenger_id": user.id,
            "opponent_id": "opponent-A"
        ]
        await service.receiveDuelPayload(["new": endedA])

        XCTAssertEqual(service.activeMatchNotifications[duelA]?.status, .ended)
        XCTAssertEqual(service.activeMatchNotifications[duelB]?.status, .inProgress)

        // Ensure matchEnded + verificationReminder queued for duel A
        XCTAssertTrue(service.pendingNotifications.contains { $0.type == .matchEnded && $0.data.duelId == duelA })
        XCTAssertTrue(service.pendingNotifications.contains { $0.type == .verificationReminder && $0.data.duelId == duelA })
    }
}


