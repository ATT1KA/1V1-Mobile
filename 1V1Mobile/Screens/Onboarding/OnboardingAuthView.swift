import SwiftUI

struct OnboardingAuthView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @EnvironmentObject var authService: AuthService
    @State private var email = ""
    @State private var password = ""
    @State private var isSignUp = false
    @State private var username = ""
    @State private var selectedAvatar: String?
    
    private let avatarOptions = [
        "person.circle.fill",
        "person.crop.circle.fill",
        "person.badge.plus",
        "person.2.fill",
        "person.3.fill",
        "gamecontroller.fill",
        "trophy.fill",
        "star.fill"
    ]
    
    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Text("Welcome to 1V1 Mobile!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Sign in to start your gaming journey")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }
                
                if coordinator.onboardingData.isAuthenticated {
                    // Already authenticated
                    VStack(spacing: 20) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.green)
                        
                        Text("You're signed in!")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if let username = authService.currentUser?.username {
                            Text("Welcome back, \(username)!")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                        }
                    }
                } else {
                    // Authentication form
                    VStack(spacing: 24) {
                        // Toggle between Sign In and Sign Up
                        Picker("Mode", selection: $isSignUp) {
                            Text("Sign In").tag(false)
                            Text("Sign Up").tag(true)
                        }
                        .pickerStyle(SegmentedPickerStyle())
                        .padding(.horizontal)
                        
                        // Email and Password
                        VStack(spacing: 16) {
                            TextField("Email", text: $email)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .disableAutocorrection(true)
                            
                            SecureField("Password", text: $password)
                                .textFieldStyle(RoundedBorderTextFieldStyle())
                        }
                        .padding(.horizontal)
                        
                        // Username (for sign up)
                        if isSignUp {
                            VStack(spacing: 16) {
                                TextField("Username", text: $username)
                                    .textFieldStyle(RoundedBorderTextFieldStyle())
                                    .autocapitalization(.none)
                                    .disableAutocorrection(true)
                                
                                Text("Choose a unique username for your profile")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            .padding(.horizontal)
                        }
                        
                        // Avatar Selection (for sign up)
                        if isSignUp {
                            VStack(spacing: 16) {
                                Text("Choose your avatar")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                
                                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 4), spacing: 12) {
                                    ForEach(avatarOptions, id: \.self) { avatar in
                                        Button(action: { selectedAvatar = avatar }) {
                                            Image(systemName: avatar)
                                                .font(.system(size: 30))
                                                .foregroundColor(selectedAvatar == avatar ? .blue : .gray)
                                                .padding()
                                                .background(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .fill(selectedAvatar == avatar ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                                )
                                                .overlay(
                                                    RoundedRectangle(cornerRadius: 10)
                                                        .stroke(selectedAvatar == avatar ? Color.blue : Color.clear, lineWidth: 2)
                                                )
                                        }
                                    }
                                }
                            }
                            .padding(.horizontal)
                        }
                        
                        // Sign In/Up Button
                        Button(action: handleAuthentication) {
                            HStack {
                                if authService.isLoading {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                        .scaleEffect(0.8)
                                }
                                
                                Text(isSignUp ? "Create Account" : "Sign In")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(isValidForm ? Color.blue : Color.gray)
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        .disabled(authService.isLoading || !isValidForm)
                        .padding(.horizontal)
                        
                        // Social Sign-In
                        VStack(spacing: 16) {
                            Text("Or continue with")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                            
                            HStack(spacing: 20) {
                                Button(action: handleAppleSignIn) {
                                    HStack {
                                        Image(systemName: "applelogo")
                                        Text("Apple")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.black)
                                    .foregroundColor(.white)
                                    .cornerRadius(10)
                                }
                                
                                Button(action: handleGoogleSignIn) {
                                    HStack {
                                        Image(systemName: "globe")
                                        Text("Google")
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.white)
                                    .foregroundColor(.black)
                                    .cornerRadius(10)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                                    )
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                
                // Error Message
                if let errorMessage = authService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer(minLength: 50)
            }
            .padding()
        }
    }
    
    private var isValidForm: Bool {
        if isSignUp {
            return !email.isEmpty && !password.isEmpty && !username.isEmpty && password.count >= 6
        } else {
            return !email.isEmpty && !password.isEmpty
        }
    }
    
    private func handleAuthentication() {
        Task {
            if isSignUp {
                let success = await authService.signUp(email: email, password: password)
                if success {
                    // Update coordinator data
                    coordinator.onboardingData.isAuthenticated = true
                    coordinator.onboardingData.username = username
                    coordinator.onboardingData.avatarUrl = selectedAvatar
                }
            } else {
                let success = await authService.signIn(email: email, password: password)
                if success {
                    coordinator.onboardingData.isAuthenticated = true
                    coordinator.onboardingData.username = authService.currentUser?.username ?? ""
                    coordinator.onboardingData.avatarUrl = authService.currentUser?.avatarUrl
                }
            }
        }
    }
    
    private func handleAppleSignIn() {
        Task {
            let success = await authService.signInWithApple()
            if success {
                coordinator.onboardingData.isAuthenticated = true
                coordinator.onboardingData.username = authService.currentUser?.username ?? ""
                coordinator.onboardingData.avatarUrl = authService.currentUser?.avatarUrl
            }
        }
    }
    
    private func handleGoogleSignIn() {
        Task {
            let success = await authService.signInWithGoogle()
            if success {
                coordinator.onboardingData.isAuthenticated = true
                coordinator.onboardingData.username = authService.currentUser?.username ?? ""
                coordinator.onboardingData.avatarUrl = authService.currentUser?.avatarUrl
            }
        }
    }
}
