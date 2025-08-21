import SwiftUI

struct OnboardingView: View {
    @State private var username = ""
    @State private var selectedAvatar: String?
    @State private var showingImagePicker = false
    @EnvironmentObject var authService: AuthService
    
    private let avatarOptions = [
        "person.circle.fill",
        "person.crop.circle.fill",
        "person.badge.plus",
        "person.2.fill",
        "person.3.fill"
    ]
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Text("Welcome to 1V1 Mobile!")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text("Let's set up your profile")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                // Avatar Selection
                VStack(spacing: 16) {
                    Text("Choose your avatar")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 16) {
                        ForEach(avatarOptions, id: \.self) { avatar in
                            Button(action: { selectedAvatar = avatar }) {
                                Image(systemName: avatar)
                                    .font(.system(size: 40))
                                    .foregroundColor(selectedAvatar == avatar ? .blue : .gray)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .fill(selectedAvatar == avatar ? Color.blue.opacity(0.1) : Color.gray.opacity(0.1))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(selectedAvatar == avatar ? Color.blue : Color.clear, lineWidth: 2)
                                    )
                            }
                        }
                    }
                }
                .padding(.horizontal)
                
                // Username Input
                VStack(spacing: 16) {
                    Text("Choose a username")
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    TextField("Username", text: $username)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .autocapitalization(.none)
                        .disableAutocorrection(true)
                    
                    Text("This will be your display name in the app")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                
                // Complete Button
                Button(action: handleCompleteOnboarding) {
                    HStack {
                        if authService.isLoading {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }
                        
                        Text("Complete Setup")
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
                
                // Error Message
                if let errorMessage = authService.errorMessage {
                    Text(errorMessage)
                        .foregroundColor(.red)
                        .font(.caption)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }
                
                Spacer()
            }
            .padding()
            .navigationBarHidden(true)
        }
    }
    
    private var isValidForm: Bool {
        return !username.isEmpty && username.count >= 3 && selectedAvatar != nil
    }
    
    private func handleCompleteOnboarding() {
        Task {
            let success = await authService.completeOnboarding(
                username: username,
                avatarUrl: selectedAvatar
            )
            if success {
                print("Onboarding completed successfully")
            }
        }
    }
}

struct OnboardingView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingView()
            .environmentObject(AuthService.shared)
    }
}
