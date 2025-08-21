import SwiftUI

struct MainTabView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var notificationService: NotificationService
    @StateObject private var duelService = DuelService.shared
    @State private var selectedTab = 0
    @State private var unreadNotificationCount = 0
    
    var body: some View {
        TabView(selection: $selectedTab) {
            HomeView()
                .tabItem {
                    Image(systemName: "house.fill")
                    Text("Home")
                }
                .tag(0)
            
            DuelListView()
                .tabItem {
                    Image(systemName: "sword.fill")
                    Text("Duels")
                }
                .badge(duelService.pendingDuels.count > 0 ? "\(duelService.pendingDuels.count)" : nil)
                .tag(1)
            
            ProfileView()
                .tabItem {
                    Image(systemName: "person.fill")
                    Text("Profile")
                }
                .badge(unreadNotificationCount > 0 ? "\(unreadNotificationCount)" : nil)
                .tag(2)
        }
        .onAppear {
            loadNotificationCount()
        }
        .onReceive(NotificationCenter.default.publisher(for: .NSManagedObjectContextDidSave)) { _ in
            // Refresh notification count when data changes
            loadNotificationCount()
        }
    }
    
    private func loadNotificationCount() {
        Task {
            // Load unread notification count from database
            do {
                let summary = try await notificationService.getUserNotificationSummary()
                await MainActor.run {
                    self.unreadNotificationCount = summary.unreadCount
                }
            } catch {
                print("❌ Error loading notification count: \(error)")
            }
        }
    }
}

// MARK: - Notification Summary Extension
extension NotificationService {
    func getUserNotificationSummary() async throws -> (totalNotifications: Int, unreadCount: Int, pendingChallenges: Int, pendingSubmissions: Int) {
        guard let client = SupabaseService.shared.getClient() else {
            throw NotificationError.notificationFailed
        }
        
        let result = try await client.rpc("get_user_notification_summary").execute()
        
        guard let summary = try? JSONSerialization.jsonObject(with: result.data) as? [String: Any],
              let totalNotifications = summary["total_notifications"] as? Int,
              let unreadCount = summary["unread_count"] as? Int,
              let pendingChallenges = summary["pending_challenges"] as? Int,
              let pendingSubmissions = summary["pending_submissions"] as? Int else {
            throw NotificationError.invalidNotificationData
        }
        
        return (
            totalNotifications: totalNotifications,
            unreadCount: unreadCount,
            pendingChallenges: pendingChallenges,
            pendingSubmissions: pendingSubmissions
        )
    }
}

struct MainTabView_Previews: PreviewProvider {
    static var previews: some View {
        MainTabView()
            .environmentObject(AuthService.shared)
    }
}
