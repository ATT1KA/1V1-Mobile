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
    
    func fetchUserProfile(userId: String) async {
        do {
            _ = try await loadUserProfile(userId: userId)
        } catch {
            print("Error fetching user profile: \(error)")
        }
    }
    
    func loadAllUsers() async throws -> [User] {
        guard let client = supabaseService.getClient() else {
            throw NSError(domain: "UserProfileService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Supabase client not initialized"])
        }
        
        let users: [User] = try await client.database
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
            let profileResponse: [String: Any] = try await client.database
                .from("profiles")
                .select("*, stats")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
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
                let cardResponse: [String: Any] = try await client.database
                    .from("user_cards")
                    .select("*")
                    .eq("id", value: cardId)
                    .single()
                    .execute()
                    .value
                
                let cardJson = try JSONSerialization.data(withJSONObject: cardResponse)
                userCard = try JSONDecoder().decode(UserCard.self, from: cardJson)
            }
            
            // Fetch achievements
            let achievementsResponse: [[String: Any]] = try await client.database
                .from("user_achievements")
                .select("*")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            let achievements = try achievementsResponse.map { achievementData in
                let achievementJson = try JSONSerialization.data(withJSONObject: achievementData)
                return try JSONDecoder().decode(Achievement.self, from: achievementJson)
            }
            
            // Create UserProfile
            let userProfile = UserProfile(
                id: user.id ?? "",
                userId: user.id ?? "",
                username: user.username ?? "Player",
                avatarUrl: user.avatarUrl,
                stats: userStats,
                card: userCard,
                achievements: achievements,
                createdAt: user.createdAt ?? Date(),
                updatedAt: user.updatedAt ?? Date()
            )
            
            return userProfile
            
        } catch let postgrestError as PostgrestError {
            switch postgrestError {
            case .httpError(let httpError):
                if httpError.status == 404 {
                    throw NSError(domain: "UserProfileService", code: 404, userInfo: [NSLocalizedDescriptionKey: "Profile not found"])
                } else {
                    throw NSError(domain: "UserProfileService", code: httpError.status, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch profile: \(httpError.message)"])
                }
            default:
                throw NSError(domain: "UserProfileService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Failed to fetch profile: \(postgrestError.localizedDescription)"])
            }
        } catch {
            throw NSError(domain: "UserProfileService", code: 500, userInfo: [NSLocalizedDescriptionKey: "Unexpected error: \(error.localizedDescription)"])
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
            let profileResponse: [String: Any] = try await client.database
                .from("profiles")
                .select("*, stats")
                .eq("id", value: userId)
                .single()
                .execute()
                .value
            
            // Parse stats
            if let statsData = profileResponse["stats"] as? [String: Any] {
                let statsJson = try JSONSerialization.data(withJSONObject: statsData)
                userStats = try JSONDecoder().decode(UserStats.self, from: statsJson)
            } else {
                userStats = UserStats() // Default stats
            }
            
            // Fetch user card if card_id exists
            if let cardId = profileResponse["card_id"] as? String {
                let cardResponse: [String: Any] = try await client.database
                    .from("user_cards")
                    .select("*")
                    .eq("id", value: cardId)
                    .single()
                    .execute()
                    .value
                
                let cardJson = try JSONSerialization.data(withJSONObject: cardResponse)
                userCard = try JSONDecoder().decode(UserCard.self, from: cardJson)
            }
            
            // Fetch achievements
            let achievementsResponse: [[String: Any]] = try await client.database
                .from("user_achievements")
                .select("*")
                .eq("user_id", value: userId)
                .execute()
                .value
            
            achievements = try achievementsResponse.map { achievementData in
                let achievementJson = try JSONSerialization.data(withJSONObject: achievementData)
                return try JSONDecoder().decode(Achievement.self, from: achievementJson)
            }
            
        } catch let postgrestError as PostgrestError {
            switch postgrestError {
            case .httpError(let httpError):
                if httpError.status == 404 {
                    errorMessage = "Database setup required. Please run the database setup script in Supabase."
                } else {
                    errorMessage = "Failed to fetch profile: \(httpError.message)"
                }
            default:
                errorMessage = "Failed to fetch profile: \(postgrestError.localizedDescription)"
            }
        } catch {
            errorMessage = "Unexpected error: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    func updateDisplayName(_ name: String, userId: String) async -> Bool {
        guard let client = supabaseService.getClient() else {
            errorMessage = "Supabase client not initialized"
            return false
        }
        
        do {
            try await client.database
                .from("profiles")
                .update(["username": name])
                .eq("id", value: userId)
                .execute()
            
            return true
        } catch let postgrestError as PostgrestError {
            switch postgrestError {
            case .httpError(let httpError):
                errorMessage = "Failed to update name: \(httpError.message)"
            default:
                errorMessage = "Failed to update name: \(postgrestError.localizedDescription)"
            }
            return false
        } catch {
            errorMessage = "Unexpected error: \(error.localizedDescription)"
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
