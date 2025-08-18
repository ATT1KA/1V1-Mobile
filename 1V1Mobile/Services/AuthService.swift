import Foundation
import Supabase
import SwiftUI
import AuthenticationServices
import GoogleSignIn

@MainActor
class AuthService: ObservableObject {
    @Published var currentUser: User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showOnboarding = false
    
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
            if let user = session.user {
                currentUser = user
                isAuthenticated = true
                await checkOnboardingStatus()
            } else {
                isAuthenticated = false
                currentUser = nil
                showOnboarding = false
            }
        } catch {
            print("No active session: \(error)")
            isAuthenticated = false
            currentUser = nil
            showOnboarding = false
        }
    }
    
    private func checkOnboardingStatus() async {
        guard let client = supabaseService.getClient(),
              let user = currentUser else { return }
        
        do {
            let profile: [User] = try await client.database
                .from("profiles")
                .select()
                .eq("id", value: user.id)
                .execute()
                .value
            
            if let userProfile = profile.first {
                // Check if user has completed onboarding (has username)
                showOnboarding = userProfile.username == nil || userProfile.username?.isEmpty == true
            } else {
                showOnboarding = true
            }
        } catch {
            print("Error checking onboarding status: \(error)")
            showOnboarding = true
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
                showOnboarding = true
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
                await checkOnboardingStatus()
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
            showOnboarding = false
            
            // Sign out from Google if needed
            GIDSignIn.sharedInstance.signOut()
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
        
        do {
            let request = ASAuthorizationAppleIDProvider().createRequest()
            request.requestedScopes = [.fullName, .email]
            
            let result = try await withCheckedThrowingContinuation { continuation in
                let controller = ASAuthorizationController(authorizationRequests: [request])
                let delegate = AppleSignInDelegate { result in
                    continuation.resume(with: result)
                }
                controller.delegate = delegate
                controller.presentationContextProvider = delegate
                controller.performRequests()
                
                // Store delegate to prevent deallocation
                objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            }
            
            guard let appleIDCredential = result as? ASAuthorizationAppleIDCredential else {
                errorMessage = "Apple Sign In failed"
                isLoading = false
                return false
            }
            
            let idToken = String(data: appleIDCredential.identityToken!, encoding: .utf8)!
            
            let authResponse = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idToken
                )
            )
            
            if let user = authResponse.user {
                currentUser = user
                isAuthenticated = true
                await checkOnboardingStatus()
                isLoading = false
                return true
            } else {
                errorMessage = "Apple Sign In failed"
                isLoading = false
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    func signInWithGoogle() async -> Bool {
        isLoading = true
        errorMessage = nil
        
        guard let client = supabaseService.getClient() else {
            errorMessage = "Supabase client not initialized"
            isLoading = false
            return false
        }
        
        do {
            guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                  let window = windowScene.windows.first else {
                errorMessage = "No window available"
                isLoading = false
                return false
            }
            
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: window)
            
            guard let idToken = result.user.idToken?.tokenString else {
                errorMessage = "Failed to get Google ID token"
                isLoading = false
                return false
            }
            
            let authResponse = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .google,
                    idToken: idToken
                )
            )
            
            if let user = authResponse.user {
                currentUser = user
                isAuthenticated = true
                await checkOnboardingStatus()
                isLoading = false
                return true
            } else {
                errorMessage = "Google Sign In failed"
                isLoading = false
                return false
            }
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
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
    
    func completeOnboarding(username: String, avatarUrl: String? = nil) async -> Bool {
        guard let client = supabaseService.getClient(),
              let user = currentUser else {
            errorMessage = "User not authenticated"
            return false
        }
        
        do {
            // Update profile in database
            try await client.database
                .from("profiles")
                .upsert([
                    "id": user.id,
                    "username": username,
                    "avatar_url": avatarUrl,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .execute()
            
            showOnboarding = false
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
            showOnboarding = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

// MARK: - Apple Sign In Delegate

class AppleSignInDelegate: NSObject, ASAuthorizationControllerDelegate, ASAuthorizationControllerPresentationContextProviding {
    private let completion: (Result<ASAuthorization, Error>) -> Void
    
    init(completion: @escaping (Result<ASAuthorization, Error>) -> Void) {
        self.completion = completion
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available")
        }
        return window
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        completion(.success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
}
