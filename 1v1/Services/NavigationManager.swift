import SwiftUI

@MainActor
class NavigationManager: ObservableObject {
    static let shared = NavigationManager()
    
    @Published var showSharedProfile = false
    @Published var sharedProfileUserId: String?
    
    @Published var showDuelChallenge = false
    @Published var challengeDuelId: String?
    
    @Published var showScreenshotSubmission = false
    @Published var screenshotDuelId: String?
    
    @Published var showDisputeReview = false
    @Published var disputeDuelId: String?
    
    @Published var showVictoryRecap = false
    @Published var victoryRecapData: VictoryRecap?
    
    private init() {} // Ensure singleton pattern
    
    // MARK: - Profile Navigation
    func navigateToSharedProfile(userId: String) {
        sharedProfileUserId = userId
        showSharedProfile = true
    }
    
    func dismissSharedProfile() {
        showSharedProfile = false
        sharedProfileUserId = nil
    }
    
    // MARK: - Duel Navigation
    func navigateToDuelChallenge(duelId: String) {
        challengeDuelId = duelId
        showDuelChallenge = true
    }
    
    func dismissDuelChallenge() {
        showDuelChallenge = false
        challengeDuelId = nil
    }
    
    func navigateToScreenshotSubmission(duelId: String) {
        screenshotDuelId = duelId
        showScreenshotSubmission = true
    }
    
    func dismissScreenshotSubmission() {
        showScreenshotSubmission = false
        screenshotDuelId = nil
    }
    
    func navigateToDisputeReview(duelId: String) {
        disputeDuelId = duelId
        showDisputeReview = true
    }
    
    func dismissDisputeReview() {
        showDisputeReview = false
        disputeDuelId = nil
    }
    
    func navigateToVictoryRecap(victoryRecap: VictoryRecap) {
        victoryRecapData = victoryRecap
        showVictoryRecap = true
    }
    
    func dismissVictoryRecap() {
        showVictoryRecap = false
        victoryRecapData = nil
    }
}
