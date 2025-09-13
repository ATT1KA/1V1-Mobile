import SwiftUI
import Supabase

struct ProfileView: View {
    @EnvironmentObject var authService: AuthService
    @EnvironmentObject var preferences: PreferencesService
    @State private var showingSignOutAlert = false
    @State private var showingDeleteAccountAlert = false
    @StateObject private var pointsService = PointsService.shared
    @State private var leaderboardOptIn: Bool = false
    
    var body: some View {
        NavigationView {
            List {
                // User Info Section
                Section {
                    HStack {
                        Image(systemName: "person.circle.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.blue)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(authService.currentUser?.email ?? "User")
                                .font(.headline)
                                .fontWeight(.semibold)
                            
                            Text("Member since \(formattedJoinDate)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(.vertical, 8)

                    PointsBalanceView()
                }
                
                // Account Section
                Section("Account") {
                    NavigationLink(destination: Text("Edit Profile")) {
                        Label("Edit Profile", systemImage: "person")
                    }
                    
                    NavigationLink(destination: Text("Change Password")) {
                        Label("Change Password", systemImage: "lock")
                    }
                    
                    NavigationLink(destination: Text("Privacy Settings")) {
                        Label("Privacy Settings", systemImage: "hand.raised")
                    }

                    Toggle(isOn: $leaderboardOptIn) {
                        Label("Show on Leaderboards", systemImage: "trophy.fill")
                    }
                    .task {
                        if let userId = authService.currentUser?.id, let client = SupabaseService.shared.getClient() {
                            if let rows: [[String: Any]] = try? await client.from("profiles").select("leaderboard_opt_in").eq("id", value: userId).limit(1).execute().value,
                               let first = rows.first, let optIn = first["leaderboard_opt_in"] as? Bool {
                                self.leaderboardOptIn = optIn
                            }
                        }
                    }
                    .onChange(of: leaderboardOptIn) { newValue in
                        Task {
                            guard let userId = authService.currentUser?.id, let client = SupabaseService.shared.getClient() else { return }
                            do {
                                try await client.from("profiles").update(["leaderboard_opt_in": newValue]).eq("id", value: userId).execute()
                            } catch {
                                print("Failed to update leaderboard opt-in: \(error)")
                            }
                        }
                    }
                }
                
                // App Section
                Section("App") {
                    NavigationLink(destination: Text("Notifications")) {
                        Label("Notifications", systemImage: "bell")
                    }
                    
                    NavigationLink(destination: Text("App Settings")) {
                        Label("Settings", systemImage: "gear")
                    }
                    
                    NavigationLink(destination: Text("Help & Support")) {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }
                    
                    NavigationLink(destination: Text("About")) {
                        Label("About", systemImage: "info.circle")
                    }
                    
                    Toggle(isOn: $preferences.eventsEnabled) {
                        Label("Enable Event Check-in & Matchmaking", systemImage: "calendar.badge.checkmark")
                    }
                    .onChange(of: preferences.eventsEnabled) { newValue in
                        Task {
                            guard let client = SupabaseService.shared.getClient() else { return }
                            do {
                                let params: [String: AnyJSON] = [
                                    "p_key": AnyJSON.string("events_enabled"),
                                    "p_value": AnyJSON.bool(newValue)
                                ]
                                try await client.rpc("set_user_preference", params: params).execute()
                            } catch {
                                print("Failed to call set_user_preference RPC from ProfileView: \(error)")
                            }
                        }
                    }
                }
                
                // Danger Zone
                Section("Danger Zone") {
                    Button(action: { showingSignOutAlert = true }) {
                        Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                            .foregroundColor(.orange)
                    }
                    
                    Button(action: { showingDeleteAccountAlert = true }) {
                        Label("Delete Account", systemImage: "trash")
                            .foregroundColor(.red)
                    }
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.large)
            .alert("Sign Out", isPresented: $showingSignOutAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Sign Out", role: .destructive) {
                    Task {
                        await authService.signOut()
                    }
                }
            } message: {
                Text("Are you sure you want to sign out?")
            }
            .alert("Delete Account", isPresented: $showingDeleteAccountAlert) {
                Button("Cancel", role: .cancel) { }
                Button("Delete", role: .destructive) {
                    Task {
                        let success = await authService.deleteAccount()
                        if success {
                            // Account deleted successfully
                            print("Account deleted")
                        }
                    }
                }
            } message: {
                Text("This action cannot be undone. All your data will be permanently deleted.")
            }
        }
    }
    
    private var formattedJoinDate: String {
        guard let user = authService.currentUser,
              let createdAt = user.createdAt else {
            return "Unknown"
        }
        
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: createdAt)
    }
}

struct ProfileView_Previews: PreviewProvider {
    static var previews: some View {
        ProfileView()
            .environmentObject(AuthService.shared)
            .environmentObject(PreferencesService.shared)
    }
}
