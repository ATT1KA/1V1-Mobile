import SwiftUI
import UIKit

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var navigationManager: NavigationManager
    @EnvironmentObject var notificationService: NotificationService
    @State private var showNotificationTestPanel = false
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                if authService.currentUser != nil {
                    MainTabView()
                        .sheet(isPresented: $navigationManager.showSharedProfile) {
                            if let userId = navigationManager.sharedProfileUserId {
                                SharedProfileView(userId: userId)
                            }
                        }
                        .sheet(isPresented: $navigationManager.showDuelChallenge) {
                            if let duelId = navigationManager.challengeDuelId {
                                // TODO: Create DuelChallengeCard from duelId
                                Text("Duel Challenge for: \(duelId)")
                            }
                        }
                        .sheet(isPresented: $navigationManager.showScreenshotSubmission) {
                            if let duelId = navigationManager.screenshotDuelId {
                                ScreenshotCaptureView(
                                    duelId: duelId,
                                    gameType: "Call of Duty", // TODO: Get from duel data
                                    gameMode: "Custom Match" // TODO: Get from duel data
                                )
                            }
                        }
                        .sheet(isPresented: $navigationManager.showDisputeReview) {
                            if let duelId = navigationManager.disputeDuelId {
                                // TODO: Implement DisputeReviewView
                                Text("Dispute Review for Duel: \(duelId)")
                            }
                        }
                        .sheet(isPresented: $navigationManager.showVictoryRecap) {
                            if let victoryRecap = navigationManager.victoryRecapData {
                                VictoryRecapView(victoryRecap: victoryRecap)
                            }
                        }
                        .onAppear {
                            setupNotificationHandling()
                        }
                        .onReceive(NotificationCenter.default.publisher(for: UIApplication.didBecomeActiveNotification)) { _ in
                            notificationService.refreshAuthorizationStatus()
                        }
                        .toolbar {
                            ToolbarItem(placement: .navigationBarTrailing) {
#if DEBUG
                                Menu {
                                    Button("Quick Test (5s)") {
                                        Task { @MainActor in
                                            await notificationService.scheduleTestNotificationIn(seconds: 5)
                                        }
                                    }
                                    Button("Match Start Test") {
                                        Task { @MainActor in
                                            await notificationService.sendMatchStartedNotification(
                                                to: AuthService.shared.currentUser?.id ?? "test-user",
                                                duelId: "test-duel",
                                                gameType: "Test Game"
                                            )
                                        }
                                    }
                                    Button("Match End Test") {
                                        Task { @MainActor in
                                            await notificationService.sendMatchEndedNotification(
                                                to: AuthService.shared.currentUser?.id ?? "test-user",
                                                duelId: "test-duel"
                                            )
                                        }
                                    }
                                    Button("Permission Test") {
                                        Task { @MainActor in
                                            _ = await notificationService.requestAuthorization()
                                        }
                                    }
                                    Button("Debug Panel") {
                                        showNotificationTestPanel = true
                                    }
                                } label: {
                                    Text("Notify")
                                }
#endif
                            }
                        }

                        .sheet(isPresented: $showNotificationTestPanel) {
                            NotificationTestView()
                                .environmentObject(notificationService)
                        }
                } else {
                    OnboardingFlowView()
                }
            } else {
                AuthView()
            }
        }
    }
    
    private func setupNotificationHandling() {
        // Set up notification action handling
        UNUserNotificationCenter.current().delegate = NotificationDelegate.shared
        
        // Configure notification categories (actions)
        notificationService.setupNotificationCategories()
    }
}

// MARK: - Notification Delegate
@MainActor
class NotificationDelegate: NSObject, UNUserNotificationCenterDelegate {
    static let shared = NotificationDelegate()
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let identifier = response.actionIdentifier
        
        // Handle notification actions
        Task { @MainActor in
            await NotificationService.shared.handleNotificationAction(
                identifier: identifier,
                notification: response.notification,
                completionHandler: completionHandler
            )
        }
    }
    
    nonisolated func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound, .badge])
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthService.shared)
    }
}
