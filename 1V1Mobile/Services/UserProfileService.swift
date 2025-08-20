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
