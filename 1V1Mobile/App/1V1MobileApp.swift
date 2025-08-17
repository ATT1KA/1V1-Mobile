import SwiftUI
import Supabase

@main
struct OneVOneMobileApp: App {
    @StateObject private var authService = AuthService()
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(authService)
                .onAppear {
                    setupSupabase()
                }
        }
    }
    
    private func setupSupabase() {
        // Supabase configuration will be loaded from Config.plist
        // This is handled in SupabaseService.swift
    }
}
