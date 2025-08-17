import Foundation
import Supabase
import SwiftUI

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private let supabaseService = SupabaseService.shared
    
    init() {
        Task {
            await checkCurrentSession()
        }
    }
    
    // MARK: - Session Management
    
    func checkCurrentSession() async {
        guard let client = supabaseService.getClient() else {
            errorMessage = "Supabase client not initialized"
            return
        }
        
        do {
            let session = try await client.auth.session
            currentUser = session.user
            isAuthenticated = session.user != nil
        } catch {
            print("No active session: \(error)")
            isAuthenticated = false
            currentUser = nil
        }
    }
    
    // MARK: - Authentication Methods
    
    func signUp(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        guard let client = supabaseService.getClient() else {
            errorMessage = "Supabase client not initialized"
            isLoading = false
            return false
        }
        
        do {
            let response = try await client.auth.signUp(
                email: email,
                password: password
            )
            
            if let user = response.user {
                currentUser = user
                isAuthenticated = true
                isLoading = false
                return true
            } else {
                errorMessage = "Sign up failed"
                isLoading = false
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func signIn(email: String, password: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        guard let client = supabaseService.getClient() else {
            errorMessage = "Supabase client not initialized"
            isLoading = false
            return false
        }
        
        do {
            let response = try await client.auth.signIn(
                email: email,
                password: password
            )
            
            if let user = response.user {
                currentUser = user
                isAuthenticated = true
                isLoading = false
                return true
            } else {
                errorMessage = "Sign in failed"
                isLoading = false
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func signOut() async {
        guard let client = supabaseService.getClient() else {
            errorMessage = "Supabase client not initialized"
            return
        }
        
        do {
            try await client.auth.signOut()
            currentUser = nil
            isAuthenticated = false
        } catch {
            errorMessage = error.localizedDescription
        }
    }
    
    func resetPassword(email: String) async -> Bool {
        isLoading = true
        errorMessage = nil
        
        guard let client = supabaseService.getClient() else {
            errorMessage = "Supabase client not initialized"
            isLoading = false
            return false
        }
        
        do {
            try await client.auth.resetPasswordForEmail(email)
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - Social Authentication
    
    func signInWithApple() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        guard let client = supabaseService.getClient() else {
            errorMessage = "Supabase client not initialized"
            isLoading = false
            return false
        }
        
        // Implementation for Apple Sign In
        // This would require additional setup with Apple Developer account
        isLoading = false
        return false
    }
    
    func signInWithGoogle() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        guard let client = supabaseService.getClient() else {
            errorMessage = "Supabase client not initialized"
            isLoading = false
            return false
        }
        
        // Implementation for Google Sign In
        // This would require additional setup with Google Cloud Console
        isLoading = false
        return false
    }
    
    // MARK: - User Profile Management
    
    func updateProfile(updates: [String: Any]) async -> Bool {
        guard let client = supabaseService.getClient(),
              let user = currentUser else {
            errorMessage = "User not authenticated"
            return false
        }
        
        do {
            try await client.auth.update(user: user, data: updates)
            await checkCurrentSession()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func deleteAccount() async -> Bool {
        guard let client = supabaseService.getClient() else {
            errorMessage = "Supabase client not initialized"
            return false
        }
        
        do {
            try await client.auth.admin.deleteUser(currentUser?.id ?? "")
            currentUser = nil
            isAuthenticated = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}
