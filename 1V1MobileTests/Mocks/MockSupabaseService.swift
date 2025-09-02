import Foundation
import Supabase
import Combine
import XCTest
@testable import OneVOneMobile

final class MockSupabaseService: SupabaseServicing {
    private struct Subscription {
        let id: String
        let onInsert: ([String: Any]) -> Void
        let onUpdate: ([String: Any], Any?) -> Void
        let onSubscribed: () -> Void
        let onClosed: () -> Void
    }

    private var subscriptions: [String: Subscription] = [:]
    private var duelsById: [String: [String: Any]] = [:]

    // MARK: - SupabaseProviding
    func getClient() -> SupabaseClient? { return nil }

    func insert<T: Codable>(into table: String, values: T) async throws {
        // For tests we don't need to persist; no-op
    }

    // MARK: - SupabaseServicing
    func subscribeToDuels(
        for userId: String,
        onInsert: @escaping ([String: Any]) -> Void,
        onUpdate: @escaping (_ payload: [String: Any], _ oldRecord: Any?) -> Void,
        onSubscribed: @escaping () -> Void,
        onClosed: @escaping () -> Void
    ) -> String {
        let id = UUID().uuidString
        let sub = Subscription(id: id, onInsert: onInsert, onUpdate: onUpdate, onSubscribed: onSubscribed, onClosed: onClosed)
        subscriptions[id] = sub
        // Immediately signal subscribed for deterministic tests
        DispatchQueue.main.async { sub.onSubscribed() }
        return id
    }

    func unsubscribe(subscriptionId: String) {
        if let sub = subscriptions.removeValue(forKey: subscriptionId) {
            // Signal closed
            DispatchQueue.main.async { sub.onClosed() }
        }
    }

    func emitDuelInsert(record: [String: Any]) {
        guard let id = record["id"] as? String else { return }
        duelsById[id] = record
        for sub in subscriptions.values {
            sub.onInsert(record)
        }
    }

    func emitDuelUpdate(record: [String: Any], oldRecord: Any?) {
        guard let id = record["id"] as? String else { return }
        let previous = duelsById[id]
        duelsById[id] = record
        for sub in subscriptions.values {
            sub.onUpdate(record, previous as Any?)
        }
    }
}


