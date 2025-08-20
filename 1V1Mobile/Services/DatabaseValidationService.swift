import Foundation
import Supabase

class DatabaseValidationService: ObservableObject {
    static let shared = DatabaseValidationService()
    private let supabaseService = SupabaseService.shared
    
    @Published var isDatabaseValid = false
    @Published var validationErrors: [String] = []
    
    private init() {}
    
    func validateDatabaseSetup() async -> Bool {
        guard let client = supabaseService.getClient() else {
            validationErrors.append("Supabase client not initialized")
            return false
        }
        
        validationErrors.removeAll()
        
        // Check if profiles table exists and has required columns
        let profilesValid = await validateProfilesTable(client: client)
        
        // Check if user_cards table exists
        let userCardsValid = await validateUserCardsTable(client: client)
        
        isDatabaseValid = profilesValid && userCardsValid
        
        return isDatabaseValid
    }
    
    private func validateProfilesTable(client: SupabaseClient) async -> Bool {
        do {
            // Try to query the profiles table
            let _: [String: Any] = try await client.database
                .from("profiles")
                .select("id, username, avatar_url, stats, card_id")
                .limit(1)
                .execute()
                .value
            
            return true
        } catch let error as PostgrestError {
            switch error {
            case .httpError(let httpError):
                if httpError.status == 404 {
                    validationErrors.append("profiles table not found")
                } else {
                    validationErrors.append("profiles table error: \(httpError.message)")
                }
            default:
                validationErrors.append("profiles table validation failed: \(error.localizedDescription)")
            }
            return false
        } catch {
            validationErrors.append("profiles table validation failed: \(error.localizedDescription)")
            return false
        }
    }
    
    private func validateUserCardsTable(client: SupabaseClient) async -> Bool {
        do {
            // Try to query the user_cards table
            let _: [String: Any] = try await client.database
                .from("user_cards")
                .select("id, user_id, card_name, rarity, power")
                .limit(1)
                .execute()
                .value
            
            return true
        } catch let error as PostgrestError {
            switch error {
            case .httpError(let httpError):
                if httpError.status == 404 {
                    validationErrors.append("user_cards table not found")
                } else {
                    validationErrors.append("user_cards table error: \(httpError.message)")
                }
            default:
                validationErrors.append("user_cards table validation failed: \(error.localizedDescription)")
            }
            return false
        } catch {
            validationErrors.append("user_cards table validation failed: \(error.localizedDescription)")
            return false
        }
    }
    
    func getSetupInstructions() -> String {
        return """
        Database Setup Required
        
        Please run the following SQL script in your Supabase SQL Editor:
        
        1. Go to your Supabase Dashboard
        2. Navigate to SQL Editor
        3. Copy and paste the contents of 'supabase_database_setup.sql'
        4. Click "Run" to execute the script
        
        This will create the required tables and columns for the onboarding system.
        """
    }
}
