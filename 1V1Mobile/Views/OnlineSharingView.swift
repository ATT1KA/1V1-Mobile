import SwiftUI
import UIKit

struct OnlineSharingView: View {
    let profile: UserProfile
    @StateObject private var sharingService = OnlineSharingService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var isLoading = false
    @State private var selectedPlatform: OnlineSharingService.ModernSharingPlatform?
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var shareContent: ShareContent?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerView
                
                // Profile Preview Card
                profilePreviewCard
                
                // Sharing Platforms
                sharingPlatformsView
                
                Spacer()
            }
            .background(
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.9),
                        Color.purple.opacity(0.3),
                        Color.black.opacity(0.9)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationBarHidden(true)
            .alert("Sharing Error", isPresented: $showError) {
                Button("OK") { }
            } message: {
                Text(errorMessage)
            }
        }
        .task {
            await loadShareContent()
        }
    }
    
    // MARK: - Header View
    
    private var headerView: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Cancel") {
                    dismiss()
                }
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
                
                Spacer()
                
                Text("Share Profile")
                    .font(.system(size: 20, weight: .bold))
                    .foregroundColor(.white)
                
                Spacer()
                
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.white)
                .font(.system(size: 16, weight: .medium))
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            
            Divider()
                .background(Color.white.opacity(0.3))
        }
    }
    
    // MARK: - Profile Preview Card
    
    private var profilePreviewCard: some View {
        VStack(spacing: 16) {
            Text("Preview")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            VStack(spacing: 12) {
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
                    .frame(width: 80, height: 80)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.3), lineWidth: 2)
                    )
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 80))
                        .foregroundColor(.gray)
                }
                
                // Username
                Text(profile.username ?? "Player")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)
                
                // Stats
                HStack(spacing: 20) {
                    StatPreviewItem(
                        icon: "gamecontroller.fill",
                        value: "\(profile.stats?.level ?? 0)",
                        label: "Level"
                    )
                    
                    StatPreviewItem(
                        icon: "trophy.fill",
                        value: "\(profile.achievements?.count ?? 0)",
                        label: "Trophies"
                    )
                    
                    StatPreviewItem(
                        icon: "flame.fill",
                        value: "\(profile.stats?.wins ?? 0)",
                        label: "Wins"
                    )
                }
                
                // QR Code Preview
                if let shareContent = shareContent,
                   let qrImage = shareContent.qrCodeImage {
                    VStack(spacing: 8) {
                        Text("QR Code")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(.white.opacity(0.8))
                        
                        Image(uiImage: qrImage)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 120, height: 120)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.white.opacity(0.1))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Sharing Platforms View
    
    private var sharingPlatformsView: some View {
        VStack(spacing: 20) {
            Text("Share to")
                .font(.system(size: 18, weight: .semibold))
                .foregroundColor(.white)
            
            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 2), spacing: 16) {
                ForEach(OnlineSharingService.ModernSharingPlatform.allCases, id: \.self) { platform in
                    SharingPlatformButton(
                        platform: platform,
                        isLoading: isLoading && selectedPlatform == platform,
                        action: {
                            await shareToPlatform(platform)
                        }
                    )
                }
            }
            .padding(.horizontal, 20)
        }
    }
    
    // MARK: - Helper Methods
    
    private func loadShareContent() async {
        shareContent = await sharingService.generateModernShareContent(for: profile, platform: .general)
    }
    
    private func shareToPlatform(_ platform: OnlineSharingService.ModernSharingPlatform) async {
        isLoading = true
        selectedPlatform = platform
        
        do {
            let success: Bool
            
            switch platform {
            case .twitter:
                success = await sharingService.shareToTwitter(profile: profile)
            case .discord:
                success = await sharingService.shareToDiscord(profile: profile)
            case .imessage:
                success = await sharingService.shareToIMessage(profile: profile)
            case .whatsapp:
                success = await sharingService.shareToWhatsApp(profile: profile)
            case .telegram:
                success = await sharingService.shareToTelegram(profile: profile)
            case .general:
                success = await sharingService.shareToGeneral(profile: profile)
            }
            
            if success {
                await sharingService.logShareEvent(profile: profile, platform: platform)
                print("✅ Successfully shared to \(platform.displayName)")
            } else {
                showError = true
                errorMessage = "Failed to share to \(platform.displayName). Please try again."
            }
        } catch {
            showError = true
            errorMessage = "An error occurred while sharing: \(error.localizedDescription)"
        }
        
        isLoading = false
        selectedPlatform = nil
    }
}

// MARK: - Supporting Views

struct StatPreviewItem: View {
    let icon: String
    let value: String
    let label: String
    
    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 20))
                .foregroundColor(.yellow)
            
            Text(value)
                .font(.system(size: 18, weight: .bold))
                .foregroundColor(.white)
            
            Text(label)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.white.opacity(0.7))
        }
    }
}

struct SharingPlatformButton: View {
    let platform: OnlineSharingService.ModernSharingPlatform
    let isLoading: Bool
    let action: () async -> Void
    
    var body: some View {
        Button {
            Task {
                await action()
            }
        } label: {
            HStack(spacing: 12) {
                if isLoading {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Image(systemName: platform.icon)
                        .font(.system(size: 20, weight: .medium))
                        .foregroundColor(.white)
                }
                
                Text(platform.displayName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(.white)
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color(platform.color).opacity(0.8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(Color.white.opacity(0.2), lineWidth: 1)
                    )
            )
            .shadow(color: Color(platform.color).opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isLoading)
        .opacity(isLoading ? 0.7 : 1.0)
    }
}

// MARK: - Preview

struct OnlineSharingView_Previews: PreviewProvider {
    static var previews: some View {
        OnlineSharingView(profile: UserProfile(
            userId: "preview-user",
            username: "PreviewPlayer",
            avatarUrl: nil,
            stats: UserStats(level: 25, wins: 150, losses: 50, winRate: 0.75),
            card: UserCard(name: "Preview Card", rarity: .epic, description: "A preview card"),
            achievements: [
                Achievement(id: "1", name: "First Win", description: "Win your first game", icon: "trophy.fill", unlockedAt: Date()),
                Achievement(id: "2", name: "Level 10", description: "Reach level 10", icon: "star.fill", unlockedAt: Date())
            ]
        ))
    }
}
