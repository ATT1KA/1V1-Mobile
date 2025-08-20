import Foundation
import Supabase

@MainActor
class DatabaseValidationService: ObservableObject {
    @Published var isDatabaseValid = false
    @Published var validationMessage = ""
    @Published var isLoading = false
    
    private let supabaseService = SupabaseService.shared
    
    func validateDatabase() async {
        isLoading = true
        validationMessage = ""
        
        do {
            // Validate all required tables
            let profilesValid = await validateProfilesTable()
            let userCardsValid = await validateUserCardsTable()
            let profileSharesValid = await validateProfileSharesTable()
            
            isDatabaseValid = profilesValid && userCardsValid && profileSharesValid
            
            if isDatabaseValid {
                validationMessage = "Database is properly configured"
            } else {
                validationMessage = "Database setup required. Please run the setup scripts."
            }
        } catch {
            isDatabaseValid = false
            validationMessage = "Database validation failed: \(error.localizedDescription)"
        }
        
        isLoading = false
    }
    
    private func validateProfilesTable() async -> Bool {
        do {
            let response = try await supabaseService.client
                .from("profiles")
                .select("id, username, stats, card_id")
                .limit(1)
                .execute()
            
            // Check if required columns exist by examining the response
            if let data = response.data {
                // If we can query the table and get data, it exists
                return true
            }
            return false
        } catch {
            print("Profiles table validation failed: \(error)")
            return false
        }
    }
    
    private func validateUserCardsTable() async -> Bool {
        do {
            let response = try await supabaseService.client
                .from("user_cards")
                .select("id, user_id, name, description, rarity, power")
                .limit(1)
                .execute()
            
            if let data = response.data {
                return true
            }
            return false
        } catch {
            print("User cards table validation failed: \(error)")
            return false
        }
    }
    
    private func validateProfileSharesTable() async -> Bool {
        do {
            let response = try await supabaseService.client
                .from("profile_shares")
                .select("id, user_id, share_method, shared_at")
                .limit(1)
                .execute()
            
            if let data = response.data {
                return true
            }
            return false
        } catch {
            print("Profile shares table validation failed: \(error)")
            return false
        }
    }
    
    func getSetupInstructions() -> String {
        return """
        Database Setup Required:
        
        1. Run the following SQL scripts in your Supabase SQL editor:
           - supabase_setup.sql (for basic tables)
           - supabase_profile_shares_setup.sql (for sharing functionality)
        
        2. Ensure Row Level Security (RLS) is enabled on all tables
        
        3. Verify that the following tables exist:
           - profiles (with stats and card_id columns)
           - user_cards
           - profile_shares
        
        4. Check that your Supabase credentials are correctly configured in Config.plist
        """
    }
    
    func validateSupabaseConnection() async -> Bool {
        do {
            let response = try await supabaseService.client
                .from("profiles")
                .select("count")
                .limit(1)
                .execute()
            
            return true
        } catch {
            print("Supabase connection validation failed: \(error)")
            return false
        }
    }
}
