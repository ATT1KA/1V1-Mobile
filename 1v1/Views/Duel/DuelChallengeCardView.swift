import SwiftUI

struct DuelChallengeCardView: View {
    let challengeCard: DuelChallengeCard
    @StateObject private var duelService = DuelService.shared

    @Environment(\.dismiss) private var dismiss
    
    @State private var isLoading = false
    @State private var showAcceptanceAlert = false
    @State private var showDeclineAlert = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var qrCodeImage: UIImage?
    @State private var showQRCode = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Challenge Card Header
                    cardHeaderView
                    
                    // Challenge Details
                    challengeDetailsView
                    
                    // QR Code Section
                    qrCodeSectionView
                    
                    // Action Buttons
                    actionButtonsView
                }
                .padding(20)
            }
            .background(
                LinearGradient(
                    colors: [
                        Color(hex: "#1a1a2e"),
                        Color(hex: "#16213e"),
                        Color(hex: "#0f3460")
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            .navigationTitle("Duel Challenge")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await shareChallenge()
                        }
                    }) {
                        Image(systemName: "square.and.arrow.up")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .alert("Accept Challenge?", isPresented: $showAcceptanceAlert) {
            Button("Accept") {
                Task {
                    await acceptChallenge()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("Are you ready to face \(challengeCard.challengerName) in \(challengeCard.gameType)?")
        }
        .alert("Decline Challenge?", isPresented: $showDeclineAlert) {
            Button("Decline", role: .destructive) {
                Task {
                    await declineChallenge()
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will decline the challenge from \(challengeCard.challengerName).")
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .onAppear {
            Task {
                await loadQRCode()
            }
        }
    }
    
    private var cardHeaderView: some View {
        VStack(spacing: 20) {
            // Challenge Banner
            HStack {
                Image(systemName: "sword.circle.fill")
                    .font(.title)
                    .foregroundColor(.orange)
                
                Text("DUEL CHALLENGE")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Image(systemName: "sword.circle.fill")
                    .font(.title)
                    .foregroundColor(.orange)
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.orange.opacity(0.2), Color.red.opacity(0.2)],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange, lineWidth: 1)
            )
            
            // Challenger Info
            VStack(spacing: 16) {
                if let avatarUrl = challengeCard.challengerAvatar {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 100, height: 100)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [Color.orange, Color.red],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 4
                            )
                    )
                    .shadow(color: .orange.opacity(0.3), radius: 10)
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.gray)
                        .overlay(
                            Circle()
                                .stroke(Color.orange, lineWidth: 4)
                        )
                }
                
                VStack(spacing: 8) {
                    Text(challengeCard.challengerName)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("challenges you to")
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
        }
    }
    
    private var challengeDetailsView: some View {
        VStack(spacing: 20) {
            // Game Info Card
            VStack(spacing: 16) {
                HStack(spacing: 16) {
                    Image(systemName: gameIcon(for: challengeCard.gameType))
                        .font(.system(size: 40))
                        .foregroundColor(gameColor(for: challengeCard.gameType))
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(challengeCard.gameType)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(challengeCard.gameMode)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                }
                
                if !challengeCard.challengeMessage.isEmpty {
                    Divider()
                        .background(Color.white.opacity(0.3))
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Challenge Message")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(.white.opacity(0.7))
                        
                        Text(challengeCard.challengeMessage)
                            .font(.body)
                            .foregroundColor(.white)
                            .multilineTextAlignment(.leading)
                    }
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.1))
            .cornerRadius(16)
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(gameColor(for: challengeCard.gameType).opacity(0.5), lineWidth: 1)
            )
            
            // Expiration Info
            VStack(spacing: 12) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    
                    Text("Challenge Expires")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                }
                
                Text(timeUntilExpiration)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(isExpiringSoon ? .red : .orange)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(Color.white.opacity(0.1))
                    .cornerRadius(8)
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private var qrCodeSectionView: some View {
        VStack(spacing: 16) {
            Button(action: {
                withAnimation(.spring(response: 0.5, dampingFraction: 0.8)) {
                    showQRCode.toggle()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: showQRCode ? "qrcode.viewfinder" : "qrcode")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    Text(showQRCode ? "Hide QR Code" : "Show QR Code")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Spacer()
                    
                    Image(systemName: showQRCode ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(16)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
            }
            
            if showQRCode {
                VStack(spacing: 12) {
                    if let qrImage = qrCodeImage {
                        Image(uiImage: qrImage)
                            .interpolation(.none)
                            .resizable()
                            .aspectRatio(contentMode: .fit)
                            .frame(width: 200, height: 200)
                            .background(Color.white)
                            .cornerRadius(12)
                            .shadow(color: .black.opacity(0.2), radius: 8)
                    } else {
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.white.opacity(0.1))
                            .frame(width: 200, height: 200)
                            .overlay(
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            )
                    }
                    
                    Text("Scan to accept challenge")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 16) {
            // Accept Button
            Button(action: {
                showAcceptanceAlert = true
            }) {
                HStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title3)
                    }
                    
                    Text("Accept Challenge")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    isExpired ? AnyShapeStyle(Color.gray) :
                    AnyShapeStyle(LinearGradient(
                        colors: [Color.green, Color.green.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    ))
                )
                .cornerRadius(12)
                .shadow(color: isExpired ? .clear : .green.opacity(0.3), radius: 8)
            }
            .disabled(isLoading || isExpired)
            
            // Decline Button
            Button(action: {
                showDeclineAlert = true
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                    
                    Text("Decline Challenge")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    LinearGradient(
                        colors: [Color.red, Color.red.opacity(0.8)],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: .red.opacity(0.3), radius: 8)
            }
            .disabled(isLoading)
            
            // Challenge Details
            if !isExpired {
                VStack(spacing: 8) {
                    Text("Ready to duel?")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(.white.opacity(0.8))
                    
                    Text("Make sure you have \(challengeCard.gameType) ready to play!")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.6))
                        .multilineTextAlignment(.center)
                }
                .padding(.top, 8)
            } else {
                VStack(spacing: 8) {
                    Image(systemName: "clock.badge.xmark")
                        .font(.title2)
                        .foregroundColor(.red)
                    
                    Text("Challenge Expired")
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.red)
                    
                    Text("This challenge is no longer available")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                .padding(16)
                .background(Color.red.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.red.opacity(0.5), lineWidth: 1)
                )
            }
        }
    }
    
    private var timeUntilExpiration: String {
        let timeInterval = challengeCard.expiresAt.timeIntervalSinceNow
        if timeInterval <= 0 {
            return "Expired"
        }
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
    
    private var isExpired: Bool {
        challengeCard.expiresAt.timeIntervalSinceNow <= 0
    }
    
    private var isExpiringSoon: Bool {
        challengeCard.expiresAt.timeIntervalSinceNow <= 60 * 60 // 1 hour
    }
    
    private func gameIcon(for gameType: String) -> String {
        switch gameType.lowercased() {
        case let x where x.contains("call of duty"), let x where x.contains("warzone"):
            return "scope"
        case let x where x.contains("fortnite"):
            return "building.2.crop.circle"
        case let x where x.contains("valorant"):
            return "target"
        case let x where x.contains("apex"):
            return "shield.lefthalf.filled"
        default:
            return "gamecontroller.fill"
        }
    }
    
    private func gameColor(for gameType: String) -> Color {
        switch gameType.lowercased() {
        case let x where x.contains("call of duty"), let x where x.contains("warzone"):
            return Color(hex: "#FF6B35")
        case let x where x.contains("fortnite"):
            return Color(hex: "#7B68EE")
        case let x where x.contains("valorant"):
            return Color(hex: "#FF4655")
        case let x where x.contains("apex"):
            return Color(hex: "#FF6B35")
        default:
            return Color.blue
        }
    }
    
    private func loadQRCode() async {
        do {
            let qrData = Data(base64Encoded: challengeCard.qrCodeData) ?? Data()
            if let uiImage = UIImage(data: qrData) {
                qrCodeImage = uiImage
            } else {
                // Fallback: generate QR code from URL
                let context = CIContext()
                let filter = CIFilter.qrCodeGenerator()
                filter.message = Data(challengeCard.shareUrl.utf8)
                filter.correctionLevel = "M"
                
                guard let outputImage = filter.outputImage else {
                    print("Error generating QR code")
                    return
                }
                
                let transform = CGAffineTransform(scaleX: 10, y: 10)
                let scaledImage = outputImage.transformed(by: transform)
                
                guard let cgImage = context.createCGImage(scaledImage, from: scaledImage.extent) else {
                    print("Error creating QR code image")
                    return
                }
                
                qrCodeImage = UIImage(cgImage: cgImage)
            }
        } catch {
            print("Error loading QR code: \(error)")
        }
    }
    
    private func acceptChallenge() async {
        guard let userId = AuthService.shared.currentUser?.id else {
            showError = true
            errorMessage = "Unable to identify current user"
            return
        }
        
        isLoading = true
        
        do {
            try await duelService.acceptDuel(challengeCard.duelId, by: userId)
            dismiss()
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func declineChallenge() async {
        guard let userId = AuthService.shared.currentUser?.id else {
            showError = true
            errorMessage = "Unable to identify current user"
            return
        }
        
        isLoading = true
        
        do {
            try await duelService.declineDuel(challengeCard.duelId, by: userId)
            dismiss()
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func shareChallenge() async {
        // Create shareable content
        let shareText = """
        🎮 Duel Challenge!
        
        \(challengeCard.challengerName) challenges you to:
        \(challengeCard.gameType) - \(challengeCard.gameMode)
        
        "\(challengeCard.challengeMessage)"
        
        Accept the challenge: \(challengeCard.shareUrl)
        
        Expires: \(formatDate(challengeCard.expiresAt))
        
        #1V1Mobile #GamingChallenge
        """
        
        let activityViewController = UIActivityViewController(
            activityItems: [shareText, qrCodeImage as Any].compactMap { $0 },
            applicationActivities: nil
        )
        
        if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
           let window = windowScene.windows.first,
           let rootViewController = window.rootViewController {
            
            // Configure for iPad
            if let popover = activityViewController.popoverPresentationController {
                popover.sourceView = window
                popover.sourceRect = CGRect(x: window.bounds.midX, y: window.bounds.midY, width: 0, height: 0)
                popover.permittedArrowDirections = []
            }
            
            rootViewController.present(activityViewController, animated: true)
        }
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Preview Provider
struct DuelChallengeCardView_Previews: PreviewProvider {
    static var previews: some View {
        DuelChallengeCardView(
            challengeCard: DuelChallengeCard(
                duelId: "test-duel-id",
                challengerName: "ProGamer123",
                challengerAvatar: nil,
                gameType: "Call of Duty: Warzone",
                gameMode: "1v1 Custom",
                challengeMessage: "Let's see who's the real champion! 🏆",
                expiresAt: Date().addingTimeInterval(60 * 60 * 2), // 2 hours
                qrCodeData: "",
                shareUrl: "1v1mobile://duel/test-duel-id"
            )
        )
    }
}
