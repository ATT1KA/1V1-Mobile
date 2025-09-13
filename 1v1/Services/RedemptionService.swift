import Foundation
import Combine
import SwiftUI

@MainActor
class RedemptionService: ObservableObject {
    static let shared = RedemptionService()

    @Published var availableRewards: [RewardItem] = []
    @Published var userUnlocks: [UUID] = []
    @Published var isLoading: Bool = false
    @Published var errorMessage: String?

    private let supabase = SupabaseService.shared

    private init() {}

    func fetchAvailableRewards() async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let client = supabase.getClient() else { return }
            let rewards: [RewardItem] = try await client.from("rewards_catalog").select().order("created_at", ascending: true).execute().value
            availableRewards = rewards
        } catch {
            errorMessage = "Failed to load rewards: \(error)"
        }
    }

    func getUserUnlocks(userId: String) async {
        isLoading = true
        defer { isLoading = false }

        do {
            guard let client = supabase.getClient() else { return }
            let rows: [[String: Any]] = try await client.from("user_unlocked").select().eq("user_id", value: userId).execute().value
            let uuids: [UUID] = rows.compactMap { row in
                if let rewardId = row["reward_id"] as? String { return UUID(uuidString: rewardId) }
                return nil
            }
            userUnlocks = uuids
        } catch {
            errorMessage = "Failed to fetch user unlocks: \(error)"
        }
    }

    func canAffordReward(userBalance: Int, reward: RewardItem) -> Bool {
        return userBalance >= reward.pointsCost
    }

    func redeemReward(userId: String, rewardId: String) async throws {
        guard let client = supabase.getClient() else {
            throw NSError(domain: "Supabase", code: 0, userInfo: [NSLocalizedDescriptionKey: "Supabase client not initialized"]) }

        // Fetch reward to determine cost and validate active
        let rewards: [[String: Any]] = try await client.from("rewards_catalog").select().eq("id", value: rewardId).limit(1).execute().value
        guard let first = rewards.first,
              let cost = first["points_cost"] as? Int,
              let isActive = first["is_active"] as? Bool, isActive else {
            throw NSError(domain: "Redemption", code: 0, userInfo: [NSLocalizedDescriptionKey: "Reward not found or inactive"])
        }

        // Call server RPC to spend and unlock atomically
        do {
            let params: [String: Any] = ["p_user_id": userId, "p_reward_id": rewardId]
            try await client.rpc("spend_and_unlock", params: params).execute()

            // Update client state after successful redemption
            if let uuid = UUID(uuidString: rewardId) {
                userUnlocks.append(uuid)
            }
            await PointsService.shared.fetchUserBalance(userId: userId)
        } catch {
            throw error
        }
    }
}


