import SwiftUI

struct OnboardingFlowView: View {
    @StateObject private var coordinator = OnboardingCoordinator()
    @StateObject private var databaseValidator = DatabaseValidationService.shared
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss
    @State private var showDatabaseSetupAlert = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Progress Bar
                ProgressView(value: coordinator.progress)
                    .progressViewStyle(LinearProgressViewStyle(tint: .blue))
                    .padding(.horizontal)
                    .padding(.top)
                
                // Step Indicator
                HStack {
                    ForEach(OnboardingStep.allCases, id: \.self) { step in
                        VStack(spacing: 4) {
                            Circle()
                                .fill(step.rawValue <= coordinator.currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                                .frame(width: 12, height: 12)
                            
                            Text(step.title)
                                .font(.caption2)
                                .foregroundColor(step.rawValue <= coordinator.currentStep.rawValue ? .primary : .secondary)
                        }
                        .frame(maxWidth: .infinity)
                        
                        if step != OnboardingStep.allCases.last {
                            Rectangle()
                                .fill(step.rawValue < coordinator.currentStep.rawValue ? Color.blue : Color.gray.opacity(0.3))
                                .frame(height: 2)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.top, 20)
                
                // Current Step Content
                TabView(selection: $coordinator.currentStep) {
                    OnboardingAuthView(coordinator: coordinator)
                        .tag(OnboardingStep.auth)
                    
                    OnboardingNotificationPermissionView(coordinator: coordinator)
                        .tag(OnboardingStep.notifications)

                    OnboardingStatsView(coordinator: coordinator)
                        .tag(OnboardingStep.stats)
                    
                    OnboardingCardGenView(coordinator: coordinator)
                        .tag(OnboardingStep.cardGen)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
                .animation(.easeInOut, value: coordinator.currentStep)
                
                // Navigation Buttons
                HStack {
                    if coordinator.currentStep != .auth {
                        Button("Back") {
                            coordinator.previousStep()
                        }
                        .buttonStyle(SecondaryButtonStyle())
                    }
                    
                    Spacer()
                    
                    Button(coordinator.currentStep == .cardGen ? "Complete" : "Next") {
                        if coordinator.currentStep == .cardGen {
                            handleCompleteOnboarding()
                        } else {
                            coordinator.nextStep()
                        }
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(!coordinator.canProceed() || coordinator.isLoading)
                }
                .padding()
            }
            .navigationBarHidden(true)
        }
        .alert("Database Setup Required", isPresented: $showDatabaseSetupAlert) {
            Button("OK") { }
        } message: {
            Text(databaseValidator.getSetupInstructions())
        }
        .onAppear {
            // Check if user is already authenticated
            if authService.isAuthenticated {
                coordinator.onboardingData.isAuthenticated = true
                coordinator.onboardingData.username = authService.currentUser?.username ?? ""
                coordinator.onboardingData.avatarUrl = authService.currentUser?.avatarUrl
            }
            
            // Validate database setup
            Task {
                await databaseValidator.validateDatabase()
                if !databaseValidator.isDatabaseValid {
                    showDatabaseSetupAlert = true
                }
            }
        }
    }
    
    private func handleCompleteOnboarding() {
        Task {
            coordinator.isLoading = true
            let success = await authService.completeOnboarding(
                username: coordinator.onboardingData.username,
                avatarUrl: coordinator.onboardingData.avatarUrl,
                stats: coordinator.onboardingData.generateStats(),
                cardData: coordinator.onboardingData.generateCardData()
            )
            coordinator.isLoading = false
            
            if success {
                dismiss()
            } else {
                coordinator.errorMessage = authService.errorMessage
            }
        }
    }
}


