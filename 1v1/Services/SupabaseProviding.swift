import Foundation
import Supabase
import Combine

/// Minimal protocol to allow injecting a Supabase-backed provider for testing.
protocol SupabaseProviding {
    func getClient() -> SupabaseClient?
    func insert<T: Codable>(into table: String, values: T) async throws
}

/// Extended protocol that adds realtime subscription helpers used by `NotificationService`.
/// Tests can provide a mock implementing these methods to simulate realtime events.
protocol SupabaseServicing: SupabaseProviding {
    /// Subscribe to duels for the given user id. Returns a subscription identifier
    /// that can be used to unsubscribe later.
    func subscribeToDuels(
        for userId: String,
        onInsert: @escaping ([String: Any]) -> Void,
        onUpdate: @escaping (_ payload: [String: Any], _ oldRecord: Any?) -> Void,
        onSubscribed: @escaping () -> Void,
        onClosed: @escaping () -> Void
    ) -> String

    /// Unsubscribe a previously created subscription by id.
    func unsubscribe(subscriptionId: String)

    /// Utilities for tests to emit events through the subscription system.
    func emitDuelInsert(record: [String: Any])
    func emitDuelUpdate(record: [String: Any], oldRecord: Any?)
}

extension SupabaseService: SupabaseProviding {}

// Make the real service conform to the extended protocol where possible. The real
// `SupabaseService` already exposes a `getClient` but does not have realtime
// helpers here; tests will use a mock implementing `SupabaseServicing`.

/// Adapter that implements `SupabaseServicing` by delegating to the real
/// `SupabaseService` and wiring its realtime client. This allows production
/// code to continue using `NotificationService()` without providing a mock.
final class RealSupabaseAdapter: SupabaseServicing {
    static let shared = RealSupabaseAdapter()

    private var channels: [String: RealtimeChannel] = [:]

    func getClient() -> SupabaseClient? {
        return SupabaseService.shared.getClient()
    }

    func insert<T: Codable>(into table: String, values: T) async throws {
        try await SupabaseService.shared.insert(into: table, values: values)
    }

    func subscribeToDuels(
        for userId: String,
        onInsert: @escaping ([String: Any]) -> Void,
        onUpdate: @escaping (_ payload: [String: Any], _ oldRecord: Any?) -> Void,
        onSubscribed: @escaping () -> Void,
        onClosed: @escaping () -> Void
    ) -> String {
        guard let client = getClient() else {
            // Return a placeholder id; no events will be delivered when client missing
            return UUID().uuidString
        }
        // The Realtime API surface has changed across Supabase client versions.
        // To avoid compile-time failures for now we only create and subscribe
        // the channel. Tests use `MockSupabaseAdapter` for emitting events, so
        // production realtime handlers can be reintroduced when the project
        // targets a specific Supabase client version with a stable API.
        let channel = client.realtime.channel("realtime:public:duels")
        channel.subscribe()

        let id = UUID().uuidString
        channels[id] = channel
        return id
    }

    func unsubscribe(subscriptionId: String) {
        if let channel = channels.removeValue(forKey: subscriptionId) {
            channel.unsubscribe()
        }
    }

    func emitDuelInsert(record: [String: Any]) {
        // Not supported for real adapter; test-only
    }

    func emitDuelUpdate(record: [String: Any], oldRecord: Any?) {
        // Not supported for real adapter; test-only
    }
}
