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
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AuthService())
    }
}
