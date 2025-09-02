import Foundation
import Combine
import Supabase
import SwiftUI

@MainActor
class PreferencesService: ObservableObject {
    static let shared = PreferencesService()

    @Published var eventsEnabled: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private let supabase = SupabaseService.shared
    private let auth = AuthService.shared
    private var isUpdatingRemote = false

    private init() {
        // Load initial value for the current user
        Task { await loadFromServer() }

        // Reload when authentication/user changes
        auth.$currentUser
            .sink { [weak self] _ in
                Task { await self?.loadFromServer() }
            }
            .store(in: &cancellables)

        // When the published value changes locally, push it to the server
        $eventsEnabled
            .dropFirst()
            .sink { [weak self] enabled in
                guard let self = self else { return }
                Task { await self.updateRemote(enabled: enabled) }
            }
            .store(in: &cancellables)
    }

    /// Loads `profiles.preferences.events_enabled` for the authenticated user
    /// and updates the local `eventsEnabled` property.
    func loadFromServer() async {
        guard let client = supabase.getClient(), let userId = auth.currentUser?.id else {
            await MainActor.run { self.eventsEnabled = false }
            return
        }

        do {
            let result = try await client.from("profiles")
                .select("preferences")
                .eq("id", value: userId)
                .execute()

            let parsed = try JSONSerialization.jsonObject(with: result.data) as? [[String: Any]]
            if let first = parsed?.first,
               let prefs = first["preferences"] as? [String: Any],
               let value = prefs["events_enabled"] as? Bool {
                await MainActor.run { self.eventsEnabled = value }
            } else {
                await MainActor.run { self.eventsEnabled = false }
            }
        } catch {
            print("Failed to load preferences: \(error)")
            await MainActor.run { self.eventsEnabled = false }
        }
    }

    /// Convenience wrapper to fetch and apply `events_enabled` preference.
    /// Call this on login/app start to ensure `eventsEnabled` is in sync.
    func fetchAndSetEventsEnabled() async {
        await loadFromServer()
    }

    /// Updates the user's preference on the server via the `set_user_preference` RPC.
    private func updateRemote(enabled: Bool) async {
        guard !isUpdatingRemote, let client = supabase.getClient(), auth.currentUser != nil else { return }
        isUpdatingRemote = true
        defer { isUpdatingRemote = false }

        do {
            let params: [String: AnyJSON] = [
                "p_key": AnyJSON.string("events_enabled"),
                "p_value": AnyJSON.bool(enabled)
            ]
            try await client.rpc("set_user_preference", params: params).execute()
        } catch {
            print("Failed to update events_enabled via RPC: \(error)")
        }
    }
}


