import Foundation
import Combine
import SwiftUI
import Supabase

@MainActor
class LeaderboardService: ObservableObject {
    static let shared = LeaderboardService()

    @Published var globalLeaderboard: [LeaderboardEntry] = []
    @Published var userRank: Int = 0
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let supabase = SupabaseService.shared
    private var leaderboardChannel: RealtimeChannel?
    private var pollingTask: Task<Void, Never>?

    private init() {}

    func fetchGlobalLeaderboard(limit: Int = Constants.Leaderboard.defaultPageSize, offset: Int = 0) async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let client = supabase.getClient() else { throw NSError(domain: "Supabase", code: 0, userInfo: nil) }
            let rows = try await client.rpc("get_points_leaderboard", params: ["p_limit": limit, "p_offset": offset]).execute()
            // The RPC returns JSON; attempt decode
            if let data = rows.data {
                // Decode as array of dictionaries
                if let array = data as? [[String: Any]] {
                    var entries: [LeaderboardEntry] = []
                    for dict in array {
                        if let userIdStr = dict["user_id"] as? String,
                           let total = dict["total_points"] as? Int,
                           let rank = dict["rank"] as? Int {
                            let username = dict["username"] as? String
                            let avatar = dict["avatar_url"] as? String
                            let optIn = dict["leaderboard_opt_in"] as? Bool
                            let isMe = AuthService.shared.currentUser?.id == userIdStr
                            let entry = LeaderboardEntry(userId: userIdStr, username: username, avatarUrl: avatar, totalPoints: total, rank: rank, isCurrentUser: isMe, leaderboardOptIn: optIn)
                            entries.append(entry)
                        }
                    }
                    globalLeaderboard = entries
                }
            }
        } catch {
            errorMessage = "Failed to load leaderboard: \(error)"
        }
    }

    // MARK: - Delta processing for realtime events
    @MainActor
    func receiveProfilePayload(_ payload: [String: Any]) {
        // Expected payload shape: ["id": String, "username": String?, "avatar_url": String?, "total_points": Int]
        guard let idStr = payload["id"] as? String else { return }
        let username = payload["username"] as? String
        let avatar = payload["avatar_url"] as? String
        let total = payload["total_points"] as? Int ?? 0
        let optIn = payload["leaderboard_opt_in"] as? Bool
        if let idx = globalLeaderboard.firstIndex(where: { $0.userId == idStr }) {
            var existing = globalLeaderboard[idx]
            existing = LeaderboardEntry(userId: existing.userId, username: username ?? existing.username, avatarUrl: avatar ?? existing.avatarUrl, totalPoints: total, rank: existing.rank, isCurrentUser: existing.isCurrentUser, leaderboardOptIn: optIn ?? existing.leaderboardOptIn)
            globalLeaderboard[idx] = existing
        } else {
            // Insert new entry; rank will be recomputed
            let entry = LeaderboardEntry(userId: idStr, username: username, avatarUrl: avatar, totalPoints: total, rank: 0, isCurrentUser: AuthService.shared.currentUser?.id == idStr, leaderboardOptIn: optIn)
            globalLeaderboard.append(entry)
        }

        // Re-sort and recompute ranks
        globalLeaderboard.sort { $0.totalPoints > $1.totalPoints }
        for i in 0..<globalLeaderboard.count {
            let e = globalLeaderboard[i]
            globalLeaderboard[i] = LeaderboardEntry(userId: e.userId, username: e.username, avatarUrl: e.avatarUrl, totalPoints: e.totalPoints, rank: i + 1, isCurrentUser: e.isCurrentUser, leaderboardOptIn: e.leaderboardOptIn)
        }
    }

    // Placeholder for real-time subscription
    func subscribeToLeaderboardChanges() {
        guard let client = supabase.getClient() else { return }
        // Create channel (handlers omitted to remain compatible with multiple Supabase SDK versions)
        let channel = client.realtime.channel("realtime:public:profiles")

        // Listen for updates to public.profiles and process payloads into the in-memory leaderboard
        _ = channel.on(
            RealtimeListenTypes.postgresChanges,
            event: .update,
            schema: "public",
            table: "profiles"
        ) { [weak self] payload in
            guard let self = self else { return }
            if let record = payload.new as? [String: Any] {
                Task { @MainActor in
                    await self.receiveProfilePayload(record)
                }
            }
        }

        channel.subscribe()
        leaderboardChannel = channel

        // Start a short-interval polling loop as a reliable fallback to fetch top-N frequently
        pollingTask?.cancel()
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.fetchGlobalLeaderboard(limit: Constants.Leaderboard.defaultPageSize, offset: 0)
                // Poll every few seconds; debounce to avoid excessive requests
                try? await Task.sleep(nanoseconds: UInt64(Constants.Leaderboard.refreshInterval * 1_000_000_000 / 6))
            }
        }
    }

    func unsubscribeFromLeaderboardChanges() {
        leaderboardChannel?.unsubscribe()
        leaderboardChannel = nil
        pollingTask?.cancel()
        pollingTask = nil
    }
}


