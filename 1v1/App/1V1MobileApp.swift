import SwiftUI
import Supabase
import GoogleSignIn

@main
struct _1V1MobileApp: App {
    @StateObject private var authService = AuthService.shared
    @StateObject private var navigationManager = NavigationManager.shared
    @StateObject private var notificationService = NotificationService.shared
    
    init() {
        // Configure Google Sign-In
        guard let path = Bundle.main.path(forResource: "Config", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["GoogleSignInClientID"] as? String else {
            fatalError("GoogleSignInClientID not found in Config.plist")
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
        
        // Initialize notification categories
        notificationService.setupNotificationCategories()
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(navigationManager)
                .environmentObject(notificationService)
                .onOpenURL { url in
                    // Let Google Sign-In try to handle first
                    if GIDSignIn.sharedInstance.handle(url) {
                        return
                    }
                    handleURL(url)
                }
        }
    }
    
    private func handleURL(_ url: URL) {
        print("🔗 Handling URL: \(url)")
        
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true),
              let host = components.host else {
            print("❌ Invalid URL format")
            return
        }
        
        switch host {
        case "profile":
            if let userId = components.url?.pathComponents.last {
                print("👤 Navigating to profile: \(userId)")
                navigationManager.navigateToSharedProfile(userId: userId)
            }
            
        case "duel":
            if let duelId = components.url?.pathComponents.last {
                print("⚔️ Navigating to duel: \(duelId)")
                navigationManager.navigateToDuelChallenge(duelId: duelId)
            }
            
        default:
            print("⚠️ Unknown URL host: \(host)")
        }
    }
}
