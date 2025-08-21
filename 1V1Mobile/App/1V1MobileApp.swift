import SwiftUI
import Supabase
import GoogleSignIn

@main
struct OneVOneMobileApp: App {
    @StateObject private var authService = AuthService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
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
        
        // Handle custom URL schemes for profile sharing
        if url.scheme == "1v1mobile" {
            handleProfileURL(url)
        }
    }
    
    private func handleProfileURL(_ url: URL) {
        guard url.host == "profile" else { return }
        
        let pathComponents = url.pathComponents
        if pathComponents.count >= 2 {
            let userId = pathComponents[1]
            print("📱 Opening profile for user: \(userId)")
            
            // TODO: Navigate to profile view
            // This would typically involve setting up a navigation state
            // to show the profile of the shared user
        }
    }
}
