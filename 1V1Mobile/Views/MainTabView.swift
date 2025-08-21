import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @StateObject private var duelService = DuelService.shared
    @StateObject private var notificationService = NotificationService.shared
    
    var body: some View {
        TabView {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
            
            DuelListView()
                .tabItem {
                    Image(systemName: "sword.fill")
                    Text("Duels")
                }
                .badge(duelService.pendingDuels.count > 0 ? duelService.pendingDuels.count : nil)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
        }
        .accentColor(.orange)
        .onAppear {
            setupNotifications()
            loadUserDuels()
        }
    }
    
    private func setupNotifications() {
        Task {
            await notificationService.requestAuthorization()
            notificationService.setupNotificationCategories()
        }
    }
    
    private func loadUserDuels() {
        Task {
            guard let userId = authService.currentUser?.id else { return }
            await duelService.loadUserDuels(for: userId)
        }
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AuthService())
    }
}
