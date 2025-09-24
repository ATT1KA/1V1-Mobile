import Foundation
import Supabase

@MainActor
class UserProfileService: ObservableObject {
    @Published var userStats: UserStats?
    @Published var userCard: UserCard?
    @Published var achievements: [Achievement] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseService = SupabaseService.shared
    

    
    func loadAllUsers() async throws -> [User] {
        guard let client = supabaseService.getClient() else {
            throw NSError(domain: "UserProfileService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Supabase client not initialized"])
        }
        
        let users: [User] = try await client
            .from("profiles")
            .select()
            .order("username", ascending: true)
            .execute()
            .value
        
        return users
    }
    
    func loadUserProfile(userId: String) async throws -> UserProfile {
        guard let client = supabaseService.getClient() else {
            throw NSError(domain: "UserProfileService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Supabase client not initialized"])
        }

        do {
            // Fetch user profile with stats
            let users: [User] = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            guard let user = users.first else {
                throw NSError(domain: "UserProfileService", code: 404, userInfo: [NSLocalizedDescriptionKey: "User not found"])
            }

            let stats = user.stats

            // Fetch user card if card_id exists
            var userCard: UserCard?
            if let cardId = user.cardId {
                let cards: [UserCard] = try await client
                    .from("user_cards")
                    .select()
                    .eq("id", value: cardId)
                    .single()
                    .execute()
                    .value

                userCard = cards.first
            }

            // Fetch achievements
            let achievements: [Achievement] = try await client
                .from("user_achievements")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            
            // Create UserProfile
            let userProfile = UserProfile(
                id: user.id,
                userId: user.id,
                username: user.username ?? "Player",
                avatarUrl: user.avatarUrl,
                stats: userStats,
                card: userCard,
                achievements: achievements,
                createdAt: user.createdAt ?? Date(),
                updatedAt: user.updatedAt ?? Date()
            )
            
            return userProfile
            
        } catch {
            throw NSError(domain: "UserProfileService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch profile: \(error.localizedDescription)"])
        }
    }
    
    func fetchUserProfile(userId: String) async {
        isLoading = true
        errorMessage = nil
        
        guard let client = supabaseService.getClient() else {
            errorMessage = "Supabase client not initialized"
            isLoading = false
            return
        }
        
        do {
            // Fetch user profile with stats
            let users: [User] = try await client
                .from("profiles")
                .select()
                .eq("id", value: userId)
                .single()
                .execute()
                .value

            guard let user = users.first else {
                errorMessage = "User not found"
                isLoading = false
                return
            }

            // Set user stats
            userStats = user.stats ?? UserStats()

            // Fetch user card if card_id exists
            if let cardId = user.cardId {
                let cards: [UserCard] = try await client
                    .from("user_cards")
                    .select()
                    .eq("id", value: cardId)
                    .single()
                    .execute()
                    .value

                userCard = cards.first
            }

            // Fetch achievements
            achievements = try await client
                .from("user_achievements")
                .select()
                .eq("user_id", value: userId)
                .execute()
                .value
            
        } catch {
            errorMessage = "Failed to fetch profile: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updateDisplayName(_ name: String, userId: String) async -> Bool {
        guard let client = supabaseService.getClient() else {
            errorMessage = "Supabase client not initialized"
            return false
        }
        
        do {
            try await client
                .from("profiles")
                .update(["username": AnyJSON.string(name)])
                .eq("id", value: userId)
                .execute()
            
            return true
        } catch {
            errorMessage = "Failed to update name: \(error.localizedDescription)"
            return false
        }
    }
    
    func syncUserData() async {
        // This can be called periodically to sync data
        // For now, just refetch the profile
        if let userId = AuthService.shared.currentUser?.id {
            await fetchUserProfile(userId: userId)
        }
    }
}
