import Foundation
import Supabase
import SwiftUI
import AuthenticationServices
import GoogleSignIn

@MainActor
class AuthService: ObservableObject {
    static let shared = AuthService()
    
    @Published var currentUser: User?
    private var supabaseUser: Auth.User?
    @Published var isAuthenticated = false
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var showOnboarding = false
    
    private let supabaseService = SupabaseService.shared
    
    private init() {
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
            let user = session.user
            supabaseUser = user
            await loadUserProfile(userId: user.id.uuidString)
            isAuthenticated = true
            await checkOnboardingStatus()
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
            let profile: [User] = try await client.from("profiles")
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
    
    private func loadUserProfile(userId: String) async {
        guard let client = supabaseService.getClient() else { return }
        
        do {
            let profiles: [User] = try await client.from("profiles")
                .select()
                .eq("id", value: userId)
                .execute()
                .value
            
            if let profile = profiles.first {
                currentUser = profile
                // Load preferences into the shared PreferencesService
                await PreferencesService.shared.loadFromServer()
            } else {
                // Create a basic user profile if none exists
                currentUser = User(id: userId, email: supabaseUser?.email ?? "")
                // Ensure preferences default is set
                await PreferencesService.shared.loadFromServer()
            }
        } catch {
            print("Error loading user profile: \(error)")
            // Create a basic user profile on error
            currentUser = User(id: userId, email: supabaseUser?.email ?? "")
            // Ensure preferences default is set
            await PreferencesService.shared.loadFromServer()
        }
    }

    // MARK: - Preferences Sync

    // Preference syncing is handled by PreferencesService.loadFromServer()
    
    // MARK: - Authentication
    
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
            
            let user = response.user
            supabaseUser = user
            currentUser = User(id: user.id.uuidString, email: user.email ?? "")
            isAuthenticated = true
            showOnboarding = true
            isLoading = false
            return true
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
            
            let user = response.user
            supabaseUser = user
            await loadUserProfile(userId: user.id.uuidString)
            isAuthenticated = true
            await checkOnboardingStatus()
            isLoading = false
            return true
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
                let delegate = AppleSignInDelegate { result in
                    continuation.resume(with: result)
                }
                
                let controller = ASAuthorizationController(authorizationRequests: [request])
                controller.delegate = delegate
                controller.presentationContextProvider = delegate
                controller.performRequests()
                
                // Store delegate to prevent deallocation
                objc_setAssociatedObject(controller, "delegate", delegate, .OBJC_ASSOCIATION_RETAIN)
            }
            
            guard let credential = result.credential as? ASAuthorizationAppleIDCredential,
                  let idToken = credential.identityToken,
                  let idTokenString = String(data: idToken, encoding: .utf8) else {
                errorMessage = "Apple Sign In failed"
                isLoading = false
                return false
            }
            
            let authResponse = try await client.auth.signInWithIdToken(
                credentials: .init(
                    provider: .apple,
                    idToken: idTokenString
                )
            )
            
            let user = authResponse.user
            supabaseUser = user
            await loadUserProfile(userId: user.id.uuidString)
            isAuthenticated = true
            await checkOnboardingStatus()
            isLoading = false
            return true
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
                  let window = windowScene.windows.first,
                  let rootViewController = window.rootViewController else {
                errorMessage = "No window available"
                isLoading = false
                return false
            }
            
            let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: rootViewController)
            
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
            
            let user = authResponse.user
            supabaseUser = user
            await loadUserProfile(userId: user.id.uuidString)
            isAuthenticated = true
            await checkOnboardingStatus()
            isLoading = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            isLoading = false
            return false
        }
    }
    
    // MARK: - Profile Management
    
    func completeOnboarding(username: String, avatarUrl: String? = nil, stats: UserStats? = nil, cardData: OnboardingCardData? = nil) async -> Bool {
        guard let client = supabaseService.getClient(),
              let user = currentUser else {
            errorMessage = "User not authenticated"
            return false
        }
        
        do {
            // Update profile in database with typed payload
            struct ProfileUpsert: Encodable {
                let id: String
                let username: String
                let avatar_url: String
                let stats: UserStats?
                let updated_at: String
            }
            let profilePayload = ProfileUpsert(
                id: user.id,
                username: username,
                avatar_url: avatarUrl ?? "",
                stats: stats,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            try await client
                .from("profiles")
                .upsert(profilePayload)
                .execute()
            
            // Create user card if provided
            if let cardData = cardData {
                let cardId = UUID().uuidString
                
                do {
                    struct UserCardInsert: Encodable {
                        let id: String
                        let user_id: String
                        let card_name: String
                        let card_description: String
                        let rarity: String
                        let power: Int
                        let is_active: Bool
                    }
                    let cardPayload = UserCardInsert(
                        id: cardId,
                        user_id: user.id,
                        card_name: cardData.name,
                        card_description: cardData.description,
                        rarity: cardData.rarity.rawValue,
                        power: cardData.rarity.power + Int.random(in: 0...20),
                        is_active: true
                    )
                    try await client
                        .from("user_cards")
                        .insert(cardPayload)
                        .execute()
                    
                    // Update profile with card ID
                    try await client
                        .from("profiles")
                        .update(["card_id": cardId])
                        .eq("id", value: user.id)
                        .execute()
                        
                } catch {
                    errorMessage = "Failed to create card: \(error.localizedDescription)"
                    return false
                }
            }
            
            showOnboarding = false
            return true
        } catch {
            errorMessage = "Failed to update profile: \(error.localizedDescription)"
            return false
        }
    }
    
    func deleteAccount() async -> Bool {
        guard let client = supabaseService.getClient() else {
            errorMessage = "Supabase client not initialized"
            return false
        }
        
        do {
            if let userId = currentUser?.id, let uuid = UUID(uuidString: userId) {
                try await client.auth.admin.deleteUser(id: uuid)
            }
            currentUser = nil
            isAuthenticated = false
            showOnboarding = false
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
    
    func updateProfileImage(_ image: UIImage) async -> Bool {
        guard let client = supabaseService.getClient(),
              let userId = currentUser?.id else {
            errorMessage = "User not authenticated"
            return false
        }
        
        do {
            // Compress image
            guard let imageData = image.jpegData(compressionQuality: 0.7) else {
                errorMessage = "Failed to process image"
                return false
            }
            
            // Generate unique filename
            let filename = "\(userId)_\(UUID().uuidString).jpg"
            
            // Upload to Supabase Storage
            try await client.storage
                .from("avatars")
                .upload(
                    filename,
                    data: imageData,
                    options: FileOptions(contentType: "image/jpeg")
                )
            
            // Get public URL
            let publicURL = try client.storage
                .from("avatars")
                .getPublicURL(path: filename)
            
            // Update profile with new avatar URL
            try await client
                .from("profiles")
                .update(["avatar_url": publicURL.absoluteString])
                .eq("id", value: userId)
                .execute()
            
            // Update local user profile
            if var updatedUser = currentUser {
                updatedUser.avatarUrl = publicURL.absoluteString
                currentUser = updatedUser
            }
            
            return true
        } catch {
            errorMessage = "Failed to upload image: \(error.localizedDescription)"
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
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithAuthorization authorization: ASAuthorization) {
        completion(.success(authorization))
    }
    
    func authorizationController(controller: ASAuthorizationController, didCompleteWithError error: Error) {
        completion(.failure(error))
    }
    
    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            fatalError("No window available")
        }
        return window
    }
}

// MARK: - Supporting Types

struct OnboardingCardData {
    let name: String
    let description: String
    let rarity: CardRarity
}
