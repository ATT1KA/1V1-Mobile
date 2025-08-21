import SwiftUI

@MainActor
class NavigationManager: ObservableObject {
    @Published var showSharedProfile = false
    @Published var sharedProfileUserId: String?
    
    func navigateToSharedProfile(userId: String) {
        sharedProfileUserId = userId
        showSharedProfile = true
    }
    
    func dismissSharedProfile() {
        showSharedProfile = false
        sharedProfileUserId = nil
    }
}
