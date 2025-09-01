import SwiftUI

struct SharedProfileView: View {
    let userId: String
    let preloadedProfile: UserProfile?
    @StateObject private var profileService = UserProfileService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLoading = true
    @State private var profile: UserProfile?
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [
                        Color(hex: "#1a1a2e"),
                        Color(hex: "#16213e"),
                        Color(hex: "#0f3460")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                
                if isLoading {
                    VStack(spacing: 16) {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(1.5)
                        
                        Text("Loading Profile...")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                    }
                } else if let profile = profile {
                    ScrollView {
                        VStack(spacing: 24) {
                            // Profile Header
                            profileHeaderView(profile)
                            
                            // Stats Section
                            statsSectionView(profile)
                            
                            // Achievements Section
                            achievementsSectionView(profile)
                            
                            // Action Buttons
                            actionButtonsView(profile)
                        }
                        .padding(20)
                    }
                } else {
                    errorView
                }
            }
            .navigationTitle("Profile")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                    .font(.system(size: 16, weight: .medium))
                }
            }
        }
        .task {
            await loadProfile()
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private func loadProfile() async {
        isLoading = true

        // Use preloaded profile if available
        if let pre = preloadedProfile {
            profile = pre
            isLoading = false
            return
        }

        do {
            // Load profile data from Supabase
            let userProfile = try await profileService.loadUserProfile(userId: userId)
            profile = userProfile
        } catch {
            showError = true
            errorMessage = "Failed to load profile: \(error.localizedDescription)"
        }

        isLoading = false
    }
    
    private func profileHeaderView(_ profile: UserProfile) -> some View {
        VStack(spacing: 16) {
            // Profile Image
            if let avatarUrl = profile.avatarUrl, !avatarUrl.isEmpty {
                AsyncImage(url: URL(string: avatarUrl)) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Image(systemName: "person.circle.fill")
                        .foregroundColor(.gray)
                }
                .frame(width: 120, height: 120)
                .clipShape(Circle())
                .overlay(
                    Circle()
                        .stroke(Color.white.opacity(0.3), lineWidth: 3)
                )
                .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
            } else {
                Image(systemName: "person.circle.fill")
                    .font(.system(size: 120))
                    .foregroundColor(.gray)
            }
            
            // Username
            Text(profile.username)
                .font(.system(size: 28, weight: .bold))
                .foregroundColor(.white)
            
            // Level Badge
            if let rank = profile.stats?.rank {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .foregroundColor(.yellow)
                    Text("Rank \(rank)")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(.white)
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(Color.white.opacity(0.1))
                .cornerRadius(20)
            }
        }
    }
    
    private func statsSectionView(_ profile: UserProfile) -> some View {
        VStack(spacing: 16) {
            Text("Statistics")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                StatCard(title: "Wins", value: "\(profile.stats?.wins ?? 0)", icon: "trophy.fill", color: .yellow)
                StatCard(title: "Losses", value: "\(profile.stats?.losses ?? 0)", icon: "xmark.circle.fill", color: .red)
                StatCard(title: "Win Rate", value: "\(Int((profile.stats?.winRate ?? 0) * 100))%", icon: "chart.line.uptrend.xyaxis", color: .green)
                StatCard(title: "Games", value: "\((profile.stats?.wins ?? 0) + (profile.stats?.losses ?? 0))", icon: "gamecontroller.fill", color: .blue)
            }
        }
    }
    
    private func achievementsSectionView(_ profile: UserProfile) -> some View {
        VStack(spacing: 16) {
            Text("Achievements")
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            if !profile.achievements.isEmpty {
                LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 3), spacing: 12) {
                    ForEach(profile.achievements.prefix(6)) { achievement in
                        AchievementCard(achievement: achievement)
                    }
                }
            } else {
                VStack(spacing: 12) {
                    Image(systemName: "trophy")
                        .font(.system(size: 40))
                        .foregroundColor(.white.opacity(0.5))
                    
                    Text("No achievements yet")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(.vertical, 20)
            }
        }
    }
    
    private func actionButtonsView(_ profile: UserProfile) -> some View {
        VStack(spacing: 12) {
            Button("Challenge Player") {
                // TODO: Implement challenge functionality
                print("🎮 Challenge player: \(profile.username)")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.green.opacity(0.8))
            .cornerRadius(12)
            
            Button("Share Profile") {
                // TODO: Implement sharing functionality
                print("📤 Share profile: \(profile.username)")
            }
            .font(.system(size: 16, weight: .semibold))
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.blue.opacity(0.8))
            .cornerRadius(12)
        }
    }
    
    private var errorView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)
            
            Text("Profile Not Found")
                .font(.system(size: 24, weight: .bold))
                .foregroundColor(.white)
            
            Text("This profile may have been deleted or is no longer available.")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
        .padding(20)
    }
}

// MARK: - Supporting Views

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
            
            Text(value)
                .font(.system(size: 20, weight: .bold))
                .foregroundColor(.white)
            
            Text(title)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.1))
        .cornerRadius(12)
    }
}

struct AchievementCard: View {
    let achievement: Achievement
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: achievement.icon ?? "trophy.fill")
                .font(.system(size: 24))
                .foregroundColor(Color(hex: "#FFD700"))
            
            Text(achievement.title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(Color.white.opacity(0.1))
        .cornerRadius(8)
    }
}

// MARK: - Preview

struct SharedProfileView_Previews: PreviewProvider {
    static var previews: some View {
        SharedProfileView(userId: "preview-user", preloadedProfile: nil)
    }
}


