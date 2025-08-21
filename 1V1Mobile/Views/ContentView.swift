import SwiftUI

struct ContentView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var navigationManager: NavigationManager
    
    var body: some View {
        Group {
            if authService.isAuthenticated {
                if authService.showOnboarding {
                    OnboardingFlowView()
                } else {
                    MainTabView()
                }
            } else {
                AuthView()
            }
        }
        .animation(.easeInOut, value: authService.isAuthenticated)
        .animation(.easeInOut, value: authService.showOnboarding)
        .sheet(isPresented: $navigationManager.showSharedProfile) {
            if let userId = navigationManager.sharedProfileUserId {
                SharedProfileView(userId: userId)
            }
        }
        .sheet(isPresented: $navigationManager.showDuelChallenge) {
            if let duelId = navigationManager.challengeDuelId {
                DuelChallengeCardView(challengeCard: loadChallengeCard(duelId: duelId))
            }
        }
        .sheet(isPresented: $navigationManager.showScreenshotSubmission) {
            if let duelId = navigationManager.screenshotDuelId {
                ScreenshotCaptureView(
                    duelId: duelId,
                    gameType: "Unknown", // This would be loaded from the duel
                    gameMode: "Unknown"
                )
            }
        }
        .sheet(isPresented: $navigationManager.showVictoryRecap) {
            if let victoryRecap = navigationManager.victoryRecapData {
                VictoryRecapView(victoryRecap: victoryRecap)
            }
        }
    }
    
    private func loadChallengeCard(duelId: String) -> DuelChallengeCard {
        // This would load the actual challenge card data
        // For now, return a placeholder
        return DuelChallengeCard(
            duelId: duelId,
            challengerName: "Player",
            challengerAvatar: nil,
            gameType: "Unknown Game",
            gameMode: "Unknown Mode",
            challengeMessage: "Let's duel!",
            expiresAt: Date().addingTimeInterval(24 * 60 * 60),
            qrCodeData: "",
            shareUrl: "1v1mobile://duel/\(duelId)"
        )
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthService())
    }
}
