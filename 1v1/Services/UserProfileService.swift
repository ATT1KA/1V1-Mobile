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
            let profileData = try await client
                .from("profiles")
                .select("*, stats")
                .eq("id", value: userId)
                .single()
                .execute()
            
            guard let profileResponse = profileData.value as? [String: Any] else {
                throw NSError(domain: "UserProfileService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid profile data format"])
            }
            
            // Parse user data
            let userJson = try JSONSerialization.data(withJSONObject: profileResponse)
            let user = try JSONDecoder().decode(User.self, from: userJson)
            
            // Parse stats
            var userStats: UserStats?
            if let statsData = profileResponse["stats"] as? [String: Any] {
                let statsJson = try JSONSerialization.data(withJSONObject: statsData)
                userStats = try JSONDecoder().decode(UserStats.self, from: statsJson)
            }
            
            // Fetch user card if card_id exists
            var userCard: UserCard?
            if let cardId = profileResponse["card_id"] as? String {
                let cardData = try await client
                    .from("user_cards")
                    .select("*")
                    .eq("id", value: cardId)
                    .single()
                    .execute()
                
                guard let cardResponse = cardData.value as? [String: Any] else {
                    throw NSError(domain: "UserProfileService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid card data format"])
                }
                
                let cardJson = try JSONSerialization.data(withJSONObject: cardResponse)
                userCard = try JSONDecoder().decode(UserCard.self, from: cardJson)
            }
            
            // Fetch achievements
            let achievementsData = try await client
                .from("user_achievements")
                .select("*")
                .eq("user_id", value: userId)
                .execute()
            
            guard let achievementsResponse = achievementsData.value as? [[String: Any]] else {
                throw NSError(domain: "UserProfileService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Invalid achievements data format"])
            }
            
            let achievements = try achievementsResponse.map { achievementData in
                let achievementJson = try JSONSerialization.data(withJSONObject: achievementData)
                return try JSONDecoder().decode(Achievement.self, from: achievementJson)
            }
            
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
            let profileData = try await client
                .from("profiles")
                .select("*, stats")
                .eq("id", value: userId)
                .single()
                .execute()
            
            guard let profileResponse = profileData.value as? [String: Any] else {
                errorMessage = "Invalid profile data format"
                isLoading = false
                return
            }
            
            // Parse stats
            if let statsData = profileResponse["stats"] as? [String: Any] {
                let statsJson = try JSONSerialization.data(withJSONObject: statsData)
                userStats = try JSONDecoder().decode(UserStats.self, from: statsJson)
            } else {
                userStats = UserStats() // Default stats
            }
            
            // Fetch user card if card_id exists
            if let cardId = profileResponse["card_id"] as? String {
                let cardData = try await client
                    .from("user_cards")
                    .select("*")
                    .eq("id", value: cardId)
                    .single()
                    .execute()
                
                guard let cardResponse = cardData.value as? [String: Any] else {
                    errorMessage = "Invalid card data format"
                    isLoading = false
                    return
                }
                
                let cardJson = try JSONSerialization.data(withJSONObject: cardResponse)
                userCard = try JSONDecoder().decode(UserCard.self, from: cardJson)
            }
            
            // Fetch achievements
            let achievementsData = try await client
                .from("user_achievements")
                .select("*")
                .eq("user_id", value: userId)
                .execute()
            
            guard let achievementsResponse = achievementsData.value as? [[String: Any]] else {
                errorMessage = "Invalid achievements data format"
                isLoading = false
                return
            }
            
            achievements = try achievementsResponse.map { achievementData in
                let achievementJson = try JSONSerialization.data(withJSONObject: achievementData)
                return try JSONDecoder().decode(Achievement.self, from: achievementJson)
            }
            
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
