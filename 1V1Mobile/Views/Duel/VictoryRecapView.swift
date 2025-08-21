import SwiftUI

struct VictoryRecapView: View {
    let victoryRecap: VictoryRecap
    @StateObject private var sharingService = OnlineSharingService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showSharing = false
    @State private var animatedStats = false
    @State private var showFullStats = false
    @State private var celebrationPhase = 0
    @State private var shareableImage: UIImage?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Victory Header with Animation
                    victoryHeaderView
                    
                    // Match Results Card
                    matchResultsView
                    
                    // Animated Stats Update
                    if let statsUpdate = victoryRecap.statsUpdate {
                        animatedStatsView(statsUpdate: statsUpdate)
                    }
                    
                    // Achievement Unlocks (if any)
                    achievementUnlocksView
                    
                    // Share Actions
                    shareActionsView
                }
                .padding(20)
            }
            .background(
                ZStack {
                    // Base gradient
                    LinearGradient(
                        colors: [
                            Color(hex: "#1a1a2e"),
                            Color(hex: "#16213e"),
                            Color(hex: "#0f3460")
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    
                    // Victory confetti effect
                    if animatedStats {
                        VictoryConfettiView()
                    }
                }
            )
            .navigationTitle("Victory Recap")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        Task {
                            await generateShareableImage()
                        }
                    }) {
                        Image(systemName: "camera.circle.fill")
                            .foregroundColor(.white)
                    }
                }
            }
        }
        .sheet(isPresented: $showSharing) {
            VictorySharingView(victoryRecap: victoryRecap, shareableImage: shareableImage)
        }
        .onAppear {
            startVictoryAnimation()
        }
    }
    
    private var victoryHeaderView: some View {
        VStack(spacing: 20) {
            // Trophy with pulsing animation
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [
                                Color(hex: "#FFD700").opacity(0.3),
                                Color(hex: "#FFA500").opacity(0.1),
                                Color.clear
                            ],
                            center: .center,
                            startRadius: 10,
                            endRadius: 80
                        )
                    )
                    .frame(width: 160, height: 160)
                    .scaleEffect(animatedStats ? 1.2 : 1.0)
                    .opacity(animatedStats ? 0.7 : 0.3)
                
                Image(systemName: "trophy.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [
                                Color(hex: "#FFD700"),
                                Color(hex: "#FFA500"),
                                Color(hex: "#FF8C00")
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .scaleEffect(animatedStats ? 1.1 : 1.0)
                    .rotationEffect(.degrees(celebrationPhase == 1 ? 10 : celebrationPhase == 2 ? -10 : 0))
                    .shadow(color: Color(hex: "#FFD700").opacity(0.5), radius: 20)
            }
            
            // Victory Text
            VStack(spacing: 8) {
                Text(victoryRecap.winnerName)
                    .font(.title)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .scaleEffect(animatedStats ? 1.05 : 1.0)
                
                Text("VICTORY!")
                    .font(.title2)
                    .fontWeight(.heavy)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .scaleEffect(animatedStats ? 1.1 : 1.0)
            }
        }
    }
    
    private var matchResultsView: some View {
        VStack(spacing: 20) {
            // Game Info
            HStack(spacing: 16) {
                Image(systemName: gameIcon(for: victoryRecap.gameType))
                    .font(.title2)
                    .foregroundColor(gameColor(for: victoryRecap.gameType))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(victoryRecap.gameType)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(victoryRecap.gameMode)
                        .font(.subheadline)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            
            // Score Display
            HStack(spacing: 40) {
                // Winner Score
                VStack(spacing: 12) {
                    Text(victoryRecap.winnerName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    ZStack {
                        Circle()
                            .fill(
                                LinearGradient(
                                    colors: [Color(hex: "#FFD700"), Color(hex: "#FFA500")],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .frame(width: 80, height: 80)
                            .scaleEffect(animatedStats ? 1.1 : 1.0)
                        
                        Text("\(victoryRecap.winnerScore)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                    
                    Text("WINNER")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#FFD700"))
                }
                
                // VS Divider
                VStack(spacing: 8) {
                    Text("VS")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Rectangle()
                        .fill(Color.white.opacity(0.3))
                        .frame(width: 2, height: 40)
                }
                
                // Loser Score
                VStack(spacing: 12) {
                    Text(victoryRecap.loserName)
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                    
                    ZStack {
                        Circle()
                            .fill(Color.white.opacity(0.2))
                            .frame(width: 80, height: 80)
                        
                        Text("\(victoryRecap.loserScore)")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Text("RUNNER-UP")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            .padding(20)
            .background(Color.white.opacity(0.05))
            .cornerRadius(16)
            
            // Match Details
            HStack(spacing: 20) {
                VStack(spacing: 4) {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Duration")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(formatDuration(victoryRecap.matchDuration))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                Divider()
                    .background(Color.white.opacity(0.3))
                    .frame(height: 40)
                
                VStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    
                    Text("Verified")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(victoryRecap.verificationMethod.displayName)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
                
                Divider()
                    .background(Color.white.opacity(0.3))
                    .frame(height: 40)
                
                VStack(spacing: 4) {
                    Image(systemName: "calendar")
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text("Completed")
                        .font(.caption2)
                        .foregroundColor(.white.opacity(0.7))
                    
                    Text(formatTime(victoryRecap.completedAt))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
        }
    }
    
    private func animatedStatsView(statsUpdate: StatsUpdate) -> some View {
        VStack(spacing: 16) {
            Text("Stats Updated")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Winner Stats
            VStack(spacing: 12) {
                Text("🏆 \(victoryRecap.winnerName)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(Color(hex: "#FFD700"))
                
                HStack(spacing: 16) {
                    AnimatedStatCard(
                        title: "Wins",
                        value: "+\(statsUpdate.winnerStatsChange.winsChange)",
                        icon: "trophy.fill",
                        color: Color(hex: "#FFD700"),
                        animated: animatedStats
                    )
                    
                    AnimatedStatCard(
                        title: "Win Rate",
                        value: "+\(String(format: "%.1f", statsUpdate.winnerStatsChange.winRateChange))%",
                        icon: "chart.line.uptrend.xyaxis",
                        color: .green,
                        animated: animatedStats
                    )
                    
                    if let levelChange = statsUpdate.winnerStatsChange.levelChange, levelChange > 0 {
                        AnimatedStatCard(
                            title: "Level",
                            value: "+\(levelChange)",
                            icon: "star.fill",
                            color: .purple,
                            animated: animatedStats
                        )
                    }
                }
            }
            
            // Loser Stats (if showing full stats)
            if showFullStats {
                VStack(spacing: 12) {
                    Text("💪 \(victoryRecap.loserName)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.white.opacity(0.8))
                    
                    HStack(spacing: 16) {
                        AnimatedStatCard(
                            title: "Experience",
                            value: "+\(statsUpdate.loserStatsChange.experienceChange)",
                            icon: "plus.circle.fill",
                            color: .blue,
                            animated: animatedStats
                        )
                        
                        if let levelChange = statsUpdate.loserStatsChange.levelChange, levelChange > 0 {
                            AnimatedStatCard(
                                title: "Level",
                                value: "+\(levelChange)",
                                icon: "star.fill",
                                color: .purple,
                                animated: animatedStats
                            )
                        }
                    }
                }
            }
            
            // Toggle Full Stats
            Button(action: {
                withAnimation(.spring()) {
                    showFullStats.toggle()
                }
            }) {
                Text(showFullStats ? "Hide Details" : "Show All Stats")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var achievementUnlocksView: some View {
        // Placeholder for achievement unlocks
        // This would show any new achievements earned from this victory
        VStack(spacing: 12) {
            if hasNewAchievements {
                VStack(spacing: 16) {
                    HStack {
                        Image(systemName: "star.circle.fill")
                            .foregroundColor(.yellow)
                            .font(.title3)
                        
                        Text("New Achievements!")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Spacer()
                    }
                    
                    // Sample achievements
                    AchievementUnlockRow(
                        title: "First Victory",
                        description: "Win your first duel",
                        icon: "trophy.fill",
                        color: .yellow
                    )
                }
                .padding(16)
                .background(Color.yellow.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.yellow.opacity(0.5), lineWidth: 1)
                )
            }
        }
    }
    
    private var shareActionsView: some View {
        VStack(spacing: 16) {
            Text("Share Your Victory")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            HStack(spacing: 12) {
                Button(action: {
                    showSharing = true
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Online")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.blue, Color.purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .blue.opacity(0.3), radius: 8)
                }
                
                Button(action: {
                    Task {
                        await saveToPhotos()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "square.and.arrow.down")
                        Text("Save Image")
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        LinearGradient(
                            colors: [Color.green, Color.teal],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .cornerRadius(12)
                    .shadow(color: .green.opacity(0.3), radius: 8)
                }
            }
            
            // Quick Share Buttons
            HStack(spacing: 12) {
                QuickShareButton(
                    platform: "Twitter",
                    icon: "bubble.left.and.bubble.right.fill",
                    color: Color(hex: "#1DA1F2")
                ) {
                    // Quick Twitter share
                }
                
                QuickShareButton(
                    platform: "Discord",
                    icon: "message.fill",
                    color: Color(hex: "#5865F2")
                ) {
                    // Quick Discord share
                }
                
                QuickShareButton(
                    platform: "Messages",
                    icon: "message.circle.fill",
                    color: Color(hex: "#007AFF")
                ) {
                    // Quick iMessage share
                }
            }
        }
    }
    
    private var hasNewAchievements: Bool {
        // This would check if any new achievements were unlocked
        // For now, show if it's a first win or significant milestone
        return victoryRecap.statsUpdate?.winnerStatsChange.winsChange == 1 ||
               victoryRecap.statsUpdate?.winnerStatsChange.levelChange != nil
    }
    
    private func startVictoryAnimation() {
        // Phase 1: Initial celebration
        withAnimation(.easeInOut(duration: 1.0)) {
            animatedStats = true
            celebrationPhase = 1
        }
        
        // Phase 2: Trophy shake
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            withAnimation(.easeInOut(duration: 0.3)) {
                celebrationPhase = 2
            }
        }
        
        // Phase 3: Settle
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.3) {
            withAnimation(.easeInOut(duration: 0.5)) {
                celebrationPhase = 0
            }
        }
    }
    
    private func generateShareableImage() async {
        // Generate a shareable image of the victory recap
        let renderer = ImageRenderer(content: shareableRecapView)
        renderer.scale = 3.0 // High resolution
        
        if let image = renderer.uiImage {
            shareableImage = image
        }
    }
    
    private var shareableRecapView: some View {
        VStack(spacing: 20) {
            // Header
            Text("🏆 VICTORY RECAP")
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            // Score
            HStack(spacing: 20) {
                VStack {
                    Text(victoryRecap.winnerName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(victoryRecap.winnerScore)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(Color(hex: "#FFD700"))
                }
                
                Text("VS")
                    .font(.title2)
                    .foregroundColor(.white.opacity(0.7))
                
                VStack {
                    Text(victoryRecap.loserName)
                        .font(.headline)
                        .foregroundColor(.white)
                    Text("\(victoryRecap.loserScore)")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                        .foregroundColor(.white.opacity(0.7))
                }
            }
            
            // Game Info
            Text("\(victoryRecap.gameType) - \(victoryRecap.gameMode)")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
            
            // App Branding
            Text("1V1 Mobile")
                .font(.caption)
                .foregroundColor(.white.opacity(0.6))
        }
        .padding(40)
        .frame(width: 400, height: 400)
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
    }
    
    private func saveToPhotos() async {
        guard let image = shareableImage ?? await generateShareableImageSync() else { return }
        
        UIImageWriteToSavedPhotosAlbum(image, nil, nil, nil)
    }
    
    private func generateShareableImageSync() async -> UIImage? {
        await generateShareableImage()
        return shareableImage
    }
    
    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
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
}

// MARK: - Supporting Views
struct AnimatedStatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color
    let animated: Bool
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)
                .scaleEffect(animated ? 1.2 : 1.0)
                .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: animated)
            
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
                .scaleEffect(animated ? 1.1 : 1.0)
            
            Text(title)
                .font(.caption)
                .foregroundColor(.white.opacity(0.7))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(color.opacity(0.5), lineWidth: 1)
        )
    }
}

struct AchievementUnlockRow: View {
    let title: String
    let description: String
    let icon: String
    let color: Color
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(color)
                .frame(width: 30)
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                
                Text(description)
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.7))
            }
            
            Spacer()
            
            Text("NEW!")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(color)
                .cornerRadius(6)
        }
    }
}

struct QuickShareButton: View {
    let platform: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundColor(.white)
                
                Text(platform)
                    .font(.caption2)
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(color)
            .cornerRadius(8)
        }
    }
}

struct VictoryConfettiView: View {
    @State private var confettiItems: [ConfettiItem] = []
    
    var body: some View {
        ZStack {
            ForEach(confettiItems, id: \.id) { item in
                Circle()
                    .fill(item.color)
                    .frame(width: item.size, height: item.size)
                    .position(x: item.x, y: item.y)
                    .opacity(item.opacity)
            }
        }
        .onAppear {
            createConfetti()
        }
    }
    
    private func createConfetti() {
        let colors: [Color] = [.yellow, .orange, .red, .purple, .blue, .green]
        
        for i in 0..<50 {
            let item = ConfettiItem(
                id: i,
                x: CGFloat.random(in: 0...UIScreen.main.bounds.width),
                y: CGFloat.random(in: -50...0),
                size: CGFloat.random(in: 4...12),
                color: colors.randomElement() ?? .yellow,
                opacity: Double.random(in: 0.5...1.0)
            )
            
            confettiItems.append(item)
            
            // Animate falling
            withAnimation(.linear(duration: Double.random(in: 2...4))) {
                if let index = confettiItems.firstIndex(where: { $0.id == item.id }) {
                    confettiItems[index].y = UIScreen.main.bounds.height + 50
                    confettiItems[index].opacity = 0
                }
            }
        }
        
        // Clean up after animation
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            confettiItems.removeAll()
        }
    }
}

struct ConfettiItem {
    let id: Int
    var x: CGFloat
    var y: CGFloat
    let size: CGFloat
    let color: Color
    var opacity: Double
}

// MARK: - Victory Sharing View
struct VictorySharingView: View {
    let victoryRecap: VictoryRecap
    let shareableImage: UIImage?
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Text("Share Your Victory!")
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                // Preview of shareable content
                if let image = shareableImage {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(12)
                        .shadow(radius: 8)
                }
                
                // Share options would go here
                // Integration with existing OnlineSharingService
                
                Spacer()
            }
            .padding(20)
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
            .navigationTitle("Share Victory")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

// MARK: - Preview Provider
struct VictoryRecapView_Previews: PreviewProvider {
    static var previews: some View {
        VictoryRecapView(
            victoryRecap: VictoryRecap(
                duelId: "test-duel-id",
                winnerName: "ProGamer123",
                loserName: "Challenger456",
                winnerScore: 15,
                loserScore: 8,
                gameType: "Call of Duty: Warzone",
                gameMode: "1v1 Custom",
                matchDuration: 450, // 7.5 minutes
                verificationMethod: .ocr,
                completedAt: Date(),
                shareableImageUrl: nil,
                statsUpdate: StatsUpdate(
                    winnerStatsChange: UserStatsChange(
                        userId: "winner-id",
                        winsChange: 1,
                        lossesChange: 0,
                        winRateChange: 2.5,
                        levelChange: 1,
                        experienceChange: 150
                    ),
                    loserStatsChange: UserStatsChange(
                        userId: "loser-id",
                        winsChange: 0,
                        lossesChange: 1,
                        winRateChange: -1.2,
                        levelChange: nil,
                        experienceChange: 50
                    )
                )
            )
        )
    }
}
