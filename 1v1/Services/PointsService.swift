import Foundation
import Combine
import SwiftUI

@MainActor
class PointsService: ObservableObject {
    static let shared = PointsService()

    @Published var currentBalance: Int = 0
    @Published var recentTransactions: [PointTransaction] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let supabase = SupabaseService.shared
    private var cancellables = Set<AnyCancellable>()

    private init() {
        // Intentionally empty: call start(for:) after auth available
    }

    // Call this when the current user is known to initialize balance & transactions
    func start(for userId: String) async {
        await fetchUserBalance(userId: userId)
        await fetchRecentTransactions(userId: userId)
    }

    // MARK: - Awarding
    func awardPoints(userId: String, sourceType: PointSourceType, sourceId: String?, points: Int) async throws {
        guard let client = supabase.getClient() else { throw NSError(domain: "Supabase", code: 0, userInfo: nil) }

        let params: [String: Any] = [
            "p_user_id": userId,
            "p_source_type": sourceType.rawValue,
            "p_source_id": sourceId ?? NSNull(),
            "p_points": points
        ]

        try await client.rpc("award_points", params: params).execute()
        // Update local cache
        await fetchUserBalance(userId: userId)
        await fetchRecentTransactions(userId: userId, limit: 10)
    }

    func awardDuelPoints(userId: String, duelId: String, isWin: Bool, score: Int?) async throws {
        let pointsBase = isWin ? Constants.Points.duelWinBase : Constants.Points.duelLossBase
        let multiplier = isWin ? Constants.Points.duelWinScoreMultiplier : 1.0
        let bonus = Int(Double(score ?? 0) * multiplier)
        let total = pointsBase + bonus

        try await awardPoints(userId: userId, sourceType: isWin ? .duelWin : .duelLoss, sourceId: duelId, points: total)
    }

    func awardSharePoints(userId: String, shareId: String, shareMethod: String) async throws {
        // Idempotency note: rely on server-side prevention or source_id uniqueness
        try await awardPoints(userId: userId, sourceType: .profileShare, sourceId: shareId, points: Constants.Points.profileSharePoints)
    }

    // MARK: - Spending
    func spendPoints(userId: String, rewardId: String, points: Int) async throws {
        guard let client = supabase.getClient() else { throw NSError(domain: "Supabase", code: 0, userInfo: nil) }
        let params: [String: Any] = ["p_user_id": userId, "p_reward_id": rewardId, "p_points": points]
        try await client.rpc("spend_points", params: params).execute()
        await fetchUserBalance(userId: userId)
    }

    // MARK: - Fetching
    func fetchUserBalance(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let client = supabase.getClient() else { throw NSError(domain: "Supabase", code: 0, userInfo: nil) }
            let result = try await client.rpc("get_user_points_summary", params: ["p_user_id": userId]).execute()
            if let json = try? JSONSerialization.jsonObject(with: result.data) as? [String: Any],
               let total = json["total_points"] as? Int {
                currentBalance = total
            }
        } catch {
            errorMessage = "Failed to load points: \(error)"
        }
    }

    func fetchRecentTransactions(userId: String, limit: Int = 10) async {
        do {
            guard let client = supabase.getClient() else { return }
            let transactions: [PointTransaction] = try await client.from("user_points").select().eq("user_id", value: userId).order("created_at", ascending: false).limit(limit).execute().value
            recentTransactions = transactions
        } catch {
            print("Failed to fetch transactions: \(error)")
        }
    }
}


