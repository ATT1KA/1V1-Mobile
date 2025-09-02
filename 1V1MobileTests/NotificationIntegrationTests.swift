import XCTest
@testable import OneVOneMobile

// Minimal mock Supabase provider for tests
final class MockSupabaseService: SupabaseServicing {
    private(set) var inserted: [(table: String, json: Data)] = []

    func getClient() -> SupabaseClient? { return nil }

    func insert<T: Codable>(into table: String, values: T) async throws {
        let data = try JSONEncoder().encode(values)
        inserted.append((table: table, json: data))
    }

    func subscribeToDuels(
        for userId: String,
        onInsert: @escaping ([String: Any]) -> Void,
        onUpdate: @escaping (_ payload: [String: Any], _ oldRecord: Any?) -> Void,
        onSubscribed: @escaping () -> Void,
        onClosed: @escaping () -> Void
    ) -> String {
        // No-op subscription for tests; return a placeholder id
        return UUID().uuidString
    }

    func unsubscribe(subscriptionId: String) {
        // No-op
    }

    func emitDuelInsert(record: [String: Any]) {
        // No-op: tests using this mock do not rely on internal emission
    }

    func emitDuelUpdate(record: [String: Any], oldRecord: Any?) {
        // No-op: tests using this mock do not rely on internal emission
    }
}

final class NotificationIntegrationTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Ensure a clean shared auth state
        AuthService.shared.currentUser = nil
    }

    func testNotificationServiceRealtimeFlow() async throws {
        // Arrange
        let user = User(id: "test-user", email: "test@example.com")
        AuthService.shared.currentUser = user
        let mockSupabase = MockSupabaseAdapter()
        let service = NotificationService(supabaseService: mockSupabase)

        let duelId = "duel-e2e"

        // Act: simulate in_progress (match started)
        let startRecord: [String: Any] = [
            "id": duelId,
            "status": "in_progress",
            "game_type": "Integration",
            "challenger_id": user.id,
            "opponent_id": "opponent"
        ]
        await service.receiveDuelPayload(["new": startRecord])

        // Assert: active match state updated and a matchStarted notification queued
        XCTAssertEqual(service.activeMatchNotifications[duelId]?.status, .inProgress)
        XCTAssertTrue(service.pendingNotifications.contains { $0.type == .matchStarted && $0.data.duelId == duelId })

        // Act: simulate ended
        let endedRecord: [String: Any] = [
            "id": duelId,
            "status": "ended",
            "game_type": "Integration",
            "challenger_id": user.id,
            "opponent_id": "opponent"
        ]
        await service.receiveDuelPayload(["new": endedRecord])

        // Assert: state moved to ended and queued matchEnded + verificationReminder
        XCTAssertEqual(service.activeMatchNotifications[duelId]?.status, .ended)
        XCTAssertTrue(service.pendingNotifications.contains { $0.type == .matchEnded && $0.data.duelId == duelId })
        XCTAssertTrue(service.pendingNotifications.contains { $0.type == .verificationReminder && $0.data.duelId == duelId })

        // Act: simulate completed
        let completedRecord: [String: Any] = [
            "id": duelId,
            "status": "completed",
            "game_type": "Integration",
            "challenger_id": user.id,
            "opponent_id": "opponent"
        ]
        await service.receiveDuelPayload(["new": completedRecord])

        // Assert: monitoring stopped and match removed
        XCTAssertNil(service.activeMatchNotifications[duelId])
        XCTAssertTrue(service.pendingNotifications.contains { $0.type == .matchEnded && $0.data.duelId == duelId })

        // Test: handleNotificationAction calls completion handler
        let content = UNMutableNotificationContent()
        content.userInfo = ["duel_id": duelId]
        let request = UNNotificationRequest(identifier: "test", content: content, trigger: nil)
        let notification = UNNotification(request: request, date: Date())

        let exp = expectation(description: "completion handler called")
        service.handleNotificationAction(identifier: "SUBMIT_SCREENSHOT", notification: notification) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)
    }

    func testSupabaseReconnectIgnoresDisconnectedUpdatesAndPreventsDuplicates() async throws {
        // Arrange
        let user = User(id: "reconnect-user", email: "reconnect@example.com")
        AuthService.shared.currentUser = user
        let mockSupabase = MockSupabaseAdapter()
        let service = NotificationService(supabaseService: mockSupabase)

        let duelId = "duel-reconnect"

        // Register a test subscription that forwards events into the service
        _ = mockSupabase.subscribeToDuels(
            for: user.id,
            onInsert: { record in
                Task { @MainActor in await service.receiveDuelPayload(["new": record]) }
            },
            onUpdate: { record, _ in
                Task { @MainActor in await service.receiveDuelPayload(["new": record]) }
            },
            onSubscribed: {
                // no-op for test
            },
            onClosed: {
                // no-op for test
            }
        )

        // Act: emit insert -> should start match and queue matchStarted once
        let startRecord: [String: Any] = [
            "id": duelId,
            "status": "in_progress",
            "game_type": "Integration",
            "challenger_id": user.id,
            "opponent_id": "opponent"
        ]
        mockSupabase.emitDuelInsert(record: startRecord)
        try await Task.sleep(nanoseconds: 100_000_000) // allow async handling

        XCTAssertEqual(service.activeMatchNotifications[duelId]?.status, .inProgress)
        XCTAssertEqual(service.pendingNotifications.filter { $0.type == .matchStarted && $0.data.duelId == duelId }.count, 1)

        // Simulate connection loss; any updates emitted now should be ignored
        await service.simulateConnectionLoss()

        let spuriousUpdateWhileDown: [String: Any] = [
            "id": duelId,
            "status": "ended",
            "game_type": "Integration",
            "challenger_id": user.id,
            "opponent_id": "opponent"
        ]
        mockSupabase.emitDuelUpdate(record: spuriousUpdateWhileDown, oldRecord: startRecord)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Reconnect and emit the legitimate update -> should transition to ended once
        await service.reconnectSupabase()
        try await Task.sleep(nanoseconds: 50_000_000)

        let endedRecord: [String: Any] = [
            "id": duelId,
            "status": "ended",
            "game_type": "Integration",
            "challenger_id": user.id,
            "opponent_id": "opponent"
        ]
        mockSupabase.emitDuelUpdate(record: endedRecord, oldRecord: startRecord)
        try await Task.sleep(nanoseconds: 100_000_000)

        // Assert: ended state and only single matchEnded + verificationReminder produced
        XCTAssertEqual(service.activeMatchNotifications[duelId]?.status, .ended)

        let matchEndedCount = service.pendingNotifications.filter { $0.type == .matchEnded && $0.data.duelId == duelId }.count
        XCTAssertEqual(matchEndedCount, 1)

        let reminderCount = service.pendingNotifications.filter { $0.type == .verificationReminder && $0.data.duelId == duelId }.count
        XCTAssertEqual(reminderCount, 1)

        // Ensure we didn't produce duplicate matchStarted notifications either
        let startedCount = service.pendingNotifications.filter { $0.type == .matchStarted && $0.data.duelId == duelId }.count
        XCTAssertEqual(startedCount, 1)
    }

    func testQueueLocalAndRemoteNotifications() async throws {
        // Arrange
        let user = User(id: "local-user", email: "local@example.com")
        AuthService.shared.currentUser = user
        let mockSupabase = MockSupabaseService()
        let service = NotificationService(supabaseService: mockSupabase)

        // Ensure we can schedule local notifications in this test run
        await service.setAuthorizationStatus(true)

        // Act: queue a device-local notification for the current user
        await service.scheduleTestNotificationIn(seconds: 1)

        // Act: queue a notification for a different user which should be persisted remotely
        await service.sendLevelUpNotification(to: "remote-user", newLevel: 5)

        // Allow the service's delivery loop to process queued notifications (loop sleeps 5s)
        try await Task.sleep(nanoseconds: 6_000_000_000)

        // Assert: both notifications were added to the public pending list
        XCTAssertTrue(service.pendingNotifications.contains { $0.userId == user.id })
        XCTAssertTrue(service.pendingNotifications.contains { $0.userId == "remote-user" })

        // Assert: remote persistence attempted exactly once for the remote user
        let notificationInserts = mockSupabase.inserted.filter { $0.table == "notifications" }
        XCTAssertEqual(notificationInserts.count, 1)

        if let inserted = notificationInserts.first {
            let decoded = try JSONDecoder().decode(PendingNotification.self, from: inserted.json)
            XCTAssertEqual(decoded.userId, "remote-user")
        } else {
            XCTFail("Expected a persisted notification for remote user")
        }
    }

    func testSeparateAdaptersDoNotCrossDuplicateDeviceLocalNotifications() async throws {
        // Arrange: single user, two devices (A and B) with separate Supabase adapters
        let user = User(id: "multi-device", email: "multi@example.com")
        AuthService.shared.currentUser = user

        let adapterA = MockSupabaseAdapter()
        let adapterB = MockSupabaseAdapter()

        let serviceA = NotificationService(supabaseService: adapterA)
        let serviceB = NotificationService(supabaseService: adapterB)

        // Ensure both services can schedule local notifications
        await serviceA.setAuthorizationStatus(true)
        await serviceB.setAuthorizationStatus(true)

        // Wire the mock adapters to forward events into their respective services
        _ = adapterA.subscribeToDuels(
            for: user.id,
            onInsert: { record in
                Task { @MainActor in await serviceA.receiveDuelPayload(["new": record]) }
            },
            onUpdate: { record, _ in
                Task { @MainActor in await serviceA.receiveDuelPayload(["new": record]) }
            },
            onSubscribed: {},
            onClosed: {}
        )

        _ = adapterB.subscribeToDuels(
            for: user.id,
            onInsert: { record in
                Task { @MainActor in await serviceB.receiveDuelPayload(["new": record]) }
            },
            onUpdate: { record, _ in
                Task { @MainActor in await serviceB.receiveDuelPayload(["new": record]) }
            },
            onSubscribed: {},
            onClosed: {}
        )

        // Act: emit an insert + update on adapterA only
        let duelId = "duel-multi-1"
        let startRecord: [String: Any] = [
            "id": duelId,
            "status": "in_progress",
            "game_type": "Integration",
            "challenger_id": user.id,
            "opponent_id": "opponent"
        ]
        adapterA.emitDuelInsert(record: startRecord)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(serviceA.activeMatchNotifications[duelId]?.status, .inProgress)
        XCTAssertTrue(serviceA.pendingNotifications.contains { $0.type == .matchStarted && $0.data.duelId == duelId })

        // Ensure service B saw no local scheduling for this event
        XCTAssertNil(serviceB.activeMatchNotifications[duelId])
        XCTAssertFalse(serviceB.pendingNotifications.contains { $0.type == .matchStarted && $0.data.duelId == duelId })

        // Now emit an ended update on adapterA and ensure only A processes it
        let endedRecord: [String: Any] = [
            "id": duelId,
            "status": "ended",
            "game_type": "Integration",
            "challenger_id": user.id,
            "opponent_id": "opponent"
        ]
        adapterA.emitDuelUpdate(record: endedRecord, oldRecord: startRecord)
        try await Task.sleep(nanoseconds: 100_000_000)

        XCTAssertEqual(serviceA.activeMatchNotifications[duelId]?.status, .ended)
        XCTAssertTrue(serviceA.pendingNotifications.contains { $0.type == .matchEnded && $0.data.duelId == duelId })
        XCTAssertTrue(serviceA.pendingNotifications.contains { $0.type == .verificationReminder && $0.data.duelId == duelId })

        XCTAssertNil(serviceB.activeMatchNotifications[duelId])
        XCTAssertFalse(serviceB.pendingNotifications.contains { $0.type == .matchEnded && $0.data.duelId == duelId })
    }
}


