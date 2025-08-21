import SwiftUI
import Supabase
import GoogleSignIn

@main
struct OneVOneMobileApp: App {
    @StateObject private var authService = AuthService()
    @StateObject private var navigationManager = NavigationManager()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .environmentObject(navigationManager)
                .onAppear {
                    setupSupabase()
                    setupGoogleSignIn()
                }
                .onOpenURL { url in
                    handleURL(url)
                }
        }
    }
    
    private func setupSupabase() {
        // Supabase configuration will be loaded from Config.plist
        // This is handled in SupabaseService.swift
    }
    
    private func setupGoogleSignIn() {
        // Configure Google Sign-In
        guard let path = Bundle.main.path(forResource: "Info", ofType: "plist"),
              let plist = NSDictionary(contentsOfFile: path),
              let clientId = plist["GIDClientID"] as? String else {
            print("Error: Could not find GIDClientID in Info.plist")
            return
        }
        
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientId)
    }
    
    private func handleURL(_ url: URL) {
        // Handle Google Sign-In URL callback
        GIDSignIn.sharedInstance.handle(url)
        
        // Handle custom URL schemes
        if url.scheme == "1v1mobile" {
            handleCustomURL(url)
        }
    }
    
    private func handleCustomURL(_ url: URL) {
        switch url.host {
        case "profile":
            handleProfileURL(url)
        case "duel":
            handleDuelURL(url)
        default:
            print("Unknown URL host: \(url.host ?? "nil")")
        }
    }
    
    private func handleProfileURL(_ url: URL) {
        let pathComponents = url.pathComponents
        if pathComponents.count >= 2 {
            let userId = pathComponents[1]
            print("📱 Opening profile for user: \(userId)")
            
            // Navigate to shared profile view
            navigationManager.navigateToSharedProfile(userId: userId)
        }
    }
    
    private func handleDuelURL(_ url: URL) {
        let pathComponents = url.pathComponents
        if pathComponents.count >= 2 {
            let duelId = pathComponents[1]
            print("⚔️ Opening duel challenge: \(duelId)")
            
            // Navigate to duel challenge view
            navigationManager.navigateToDuelChallenge(duelId: duelId)
        }
    }
}
