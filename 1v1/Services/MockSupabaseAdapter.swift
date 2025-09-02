import Foundation
import Supabase

/// Test/debug adapter that implements `SupabaseServicing` and allows tests
/// or the debug UI to simulate connection loss, reconnection, and emit
/// realtime events programmatically.
final class MockSupabaseAdapter: SupabaseServicing {
    private struct Subscriptions {
        let onInsert: ([String: Any]) -> Void
        let onUpdate: (_ payload: [String: Any], _ oldRecord: Any?) -> Void
        let onSubscribed: () -> Void
        let onClosed: () -> Void
    }

    private var subscriptions: [String: Subscriptions] = [:]
    private(set) var isConnected: Bool = true

    func getClient() -> SupabaseClient? { return nil }

    func insert<T: Codable>(into table: String, values: T) async throws {
        // No-op for tests
    }

    func subscribeToDuels(
        for userId: String,
        onInsert: @escaping ([String: Any]) -> Void,
        onUpdate: @escaping (_ payload: [String: Any], _ oldRecord: Any?) -> Void,
        onSubscribed: @escaping () -> Void,
        onClosed: @escaping () -> Void
    ) -> String {
        let id = UUID().uuidString
        subscriptions[id] = Subscriptions(
            onInsert: onInsert,
            onUpdate: onUpdate,
            onSubscribed: onSubscribed,
            onClosed: onClosed
        )

        // Immediately notify subscribed if connected
        if isConnected { onSubscribed() }

        return id
    }

    func unsubscribe(subscriptionId: String) {
        subscriptions.removeValue(forKey: subscriptionId)
    }

    func emitDuelInsert(record: [String: Any]) {
        guard isConnected else { return }
        for s in subscriptions.values { s.onInsert(record) }
    }

    func emitDuelUpdate(record: [String: Any], oldRecord: Any?) {
        guard isConnected else { return }
        for s in subscriptions.values { s.onUpdate(record, oldRecord) }
    }

    // Simulate connection loss by calling onClosed for each subscription
    func simulateConnectionLoss() {
        guard isConnected else { return }
        isConnected = false
        for s in subscriptions.values { s.onClosed() }
    }

    // Simulate reconnection by calling onSubscribed for each subscription
    func reconnect() {
        guard !isConnected else { return }
        isConnected = true
        for s in subscriptions.values { s.onSubscribed() }
    }
}


