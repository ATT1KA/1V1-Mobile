import SwiftUI

struct OnboardingNotificationPermissionView: View {
    @ObservedObject var coordinator: OnboardingCoordinator
    @EnvironmentObject var notificationService: NotificationService
    @State private var isRequesting = false

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                // Header
                VStack(spacing: 16) {
                    Text("Stay in the loop")
                        .font(.title)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)

                    Text("Get notified when opponents challenge you, matches start, and results are ready")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                }

                Image(systemName: "bell.fill")
                    .font(.system(size: 72))
                    .foregroundColor(.orange)
                    .padding(.top, 10)

                // Status message
                if notificationService.isAuthorized {
                    VStack(spacing: 8) {
                        Text("Notifications enabled")
                            .font(.headline)
                        Text("You're all set to receive updates from 1V1 Mobile.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    VStack(spacing: 8) {
                        Text("Enable notifications")
                            .font(.headline)
                        Text("We use notifications to keep you informed about challenges, match starts, and results.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Primary action
                Button(action: {
                    if notificationService.isAuthorized {
                        coordinator.onboardingData.hasHandledNotificationPermissions = true
                    } else {
                        requestAuthorization()
                    }
                }) {
                    HStack {
                        if isRequesting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                .scaleEffect(0.8)
                        }

                        Text(notificationService.isAuthorized ? "Continue" : "Allow Notifications")
                            .fontWeight(.semibold)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                }
                .disabled(isRequesting)
                .buttonStyle(PrimaryButtonStyle())
                .padding(.horizontal)

                // Secondary action
                Button(action: skipForNow) {
                    Text("Skip for Now")
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.gray.opacity(0.1))
                        .foregroundColor(.primary)
                        .cornerRadius(10)
                }
                .buttonStyle(SecondaryButtonStyle())
                .padding(.horizontal)

                Spacer(minLength: 50)
            }
            .padding()
        }
    }

    private func requestAuthorization() {
        Task { @MainActor in
            isRequesting = true
            let _ = await notificationService.requestAuthorization()
            // Mark that user has handled the permission flow regardless of grant/deny
            coordinator.onboardingData.hasHandledNotificationPermissions = true
            isRequesting = false
        }
    }

    private func skipForNow() {
        coordinator.onboardingData.hasHandledNotificationPermissions = true
    }
}

struct OnboardingNotificationPermissionView_Previews: PreviewProvider {
    static var previews: some View {
        OnboardingNotificationPermissionView(coordinator: OnboardingCoordinator())
            .environmentObject(NotificationService.shared)
    }
}


