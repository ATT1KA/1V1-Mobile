import SwiftUI

struct DuelListView: View {
    @StateObject private var duelService = DuelService.shared
    @StateObject private var authService = AuthService.shared
    @State private var selectedTab = 0
    @State private var showDuelProposal = false
    @State private var showDuelDetails: Duel?
    @State private var refreshing = false
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Custom Tab Selector
                tabSelectorView
                
                // Content based on selected tab
                TabView(selection: $selectedTab) {
                    // Active Duels
                    activeDuelsView
                        .tag(0)
                    
                    // Pending Challenges
                    pendingDuelsView
                        .tag(1)
                    
                    // Completed Duels
                    completedDuelsView
                        .tag(2)
                }
                .tabViewStyle(PageTabViewStyle(indexDisplayMode: .never))
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
            .navigationTitle("Duels")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: {
                        showDuelProposal = true
                    }) {
                        Image(systemName: "plus.circle.fill")
                            .foregroundColor(.orange)
                            .font(.title2)
                    }
                }
            }
        }
        .sheet(isPresented: $showDuelProposal) {
            DuelProposalView()
        }
        .sheet(item: $showDuelDetails) { duel in
            DuelDetailsView(duel: duel)
        }
        .refreshable {
            await refreshDuels()
        }
        .onAppear {
            Task {
                await loadDuels()
            }
        }
    }
    
    private var tabSelectorView: some View {
        HStack(spacing: 0) {
            TabButton(
                title: "Active",
                count: duelService.activeDuels.count,
                isSelected: selectedTab == 0
            ) {
                withAnimation(.spring()) {
                    selectedTab = 0
                }
            }
            
            TabButton(
                title: "Pending",
                count: duelService.pendingDuels.count,
                isSelected: selectedTab == 1
            ) {
                withAnimation(.spring()) {
                    selectedTab = 1
                }
            }
            
            TabButton(
                title: "History",
                count: duelService.completedDuels.count,
                isSelected: selectedTab == 2
            ) {
                withAnimation(.spring()) {
                    selectedTab = 2
                }
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 16)
        .background(Color.white.opacity(0.05))
    }
    
    private var activeDuelsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if duelService.activeDuels.isEmpty {
                    EmptyStateView(
                        icon: "sword.circle",
                        title: "No Active Duels",
                        subtitle: "Start a new challenge to begin dueling!",
                        actionTitle: "Propose Duel",
                        action: {
                            showDuelProposal = true
                        }
                    )
                } else {
                    ForEach(duelService.activeDuels) { duel in
                        DuelCard(duel: duel, currentUserId: authService.currentUser?.id ?? "") {
                            showDuelDetails = duel
                        }
                    }
                }
            }
            .padding(20)
        }
    }
    
    private var pendingDuelsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if duelService.pendingDuels.isEmpty {
                    EmptyStateView(
                        icon: "clock.circle",
                        title: "No Pending Challenges",
                        subtitle: "You'll see incoming challenges here",
                        actionTitle: "Challenge Someone",
                        action: {
                            showDuelProposal = true
                        }
                    )
                } else {
                    ForEach(duelService.pendingDuels) { duel in
                        PendingDuelCard(duel: duel, currentUserId: authService.currentUser?.id ?? "") {
                            showDuelDetails = duel
                        }
                    }
                }
            }
            .padding(20)
        }
    }
    
    private var completedDuelsView: some View {
        ScrollView {
            LazyVStack(spacing: 16) {
                if duelService.completedDuels.isEmpty {
                    EmptyStateView(
                        icon: "trophy.circle",
                        title: "No Completed Duels",
                        subtitle: "Your duel history will appear here",
                        actionTitle: "Start Your First Duel",
                        action: {
                            showDuelProposal = true
                        }
                    )
                } else {
                    ForEach(duelService.completedDuels) { duel in
                        CompletedDuelCard(duel: duel, currentUserId: authService.currentUser?.id ?? "") {
                            showDuelDetails = duel
                        }
                    }
                }
            }
            .padding(20)
        }
    }
    
    private func loadDuels() async {
        guard let userId = authService.currentUser?.id else { return }
        await duelService.loadUserDuels(for: userId)
    }
    
    private func refreshDuels() async {
        refreshing = true
        await loadDuels()
        refreshing = false
    }
}

// MARK: - Tab Button
struct TabButton: View {
    let title: String
    let count: Int
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.body)
                        .fontWeight(isSelected ? .semibold : .medium)
                    
                    if count > 0 {
                        Text("\(count)")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(isSelected ? Color.orange : Color.white.opacity(0.3))
                            .cornerRadius(8)
                    }
                }
                .foregroundColor(isSelected ? .white : .white.opacity(0.7))
                
                Rectangle()
                    .fill(isSelected ? Color.orange : Color.clear)
                    .frame(height: 2)
            }
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Duel Cards
struct DuelCard: View {
    let duel: Duel
    let currentUserId: String
    let onTap: () -> Void
    
    private var isChallenger: Bool {
        duel.challengerId == currentUserId
    }
    
    private var opponent: String {
        isChallenger ? "Opponent" : "Challenger"
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                // Header
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(duel.gameType)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(duel.gameMode)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    DuelStatusBadge(status: duel.status)
                }
                
                // Players
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(isChallenger ? "You" : opponent)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text("vs \(isChallenger ? opponent : "You")")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    if duel.status == .inProgress {
                        VStack(spacing: 4) {
                            Image(systemName: "gamecontroller.fill")
                                .foregroundColor(.green)
                                .font(.title3)
                            
                            Text("In Game")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(.green)
                        }
                    }
                }
                
                // Action needed indicator
                if needsAction {
                    HStack {
                        Image(systemName: "exclamationmark.circle.fill")
                            .foregroundColor(.orange)
                        
                        Text(actionNeededText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                        
                        Spacer()
                    }
                    .padding(.top, 8)
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(
                        needsAction ? Color.orange : Color.white.opacity(0.2),
                        lineWidth: needsAction ? 2 : 1
                    )
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var needsAction: Bool {
        switch duel.status {
        case .accepted:
            return true // Can start match
        case .inProgress:
            return duel.endedAt != nil // Can submit screenshot
        default:
            return false
        }
    }
    
    private var actionNeededText: String {
        switch duel.status {
        case .accepted:
            return "Ready to start match"
        case .inProgress:
            return duel.endedAt != nil ? "Submit screenshot" : "Match in progress"
        default:
            return ""
        }
    }
}

struct PendingDuelCard: View {
    let duel: Duel
    let currentUserId: String
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Challenge from Challenger")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text("\(duel.gameType) - \(duel.gameMode)")
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    DuelStatusBadge(status: duel.status)
                }
                
                if let message = duel.challengeMessage {
                    HStack {
                        Text("\"\(message)\"")
                            .font(.body)
                            .italic()
                            .foregroundColor(.white.opacity(0.9))
                        
                        Spacer()
                    }
                }
                
                // Expiration info
                HStack {
                    Image(systemName: "clock.fill")
                        .foregroundColor(.orange)
                    
                    Text("Expires \(timeUntilExpiration)")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Spacer()
                    
                    Text("Tap to respond")
                        .font(.caption)
                        .foregroundColor(.blue)
                }
            }
            .padding(16)
            .background(Color.orange.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.orange, lineWidth: 2)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var timeUntilExpiration: String {
        let timeInterval = duel.expiresAt.timeIntervalSinceNow
        if timeInterval <= 0 {
            return "now"
        }
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 0 {
            return "in \(hours)h \(minutes)m"
        } else {
            return "in \(minutes)m"
        }
    }
}

struct CompletedDuelCard: View {
    let duel: Duel
    let currentUserId: String
    let onTap: () -> Void
    
    private var isWinner: Bool {
        duel.winnerId == currentUserId
    }
    
    private var resultText: String {
        switch duel.status {
        case .completed:
            if duel.verificationStatus == .forfeited {
                return "Forfeited"
            } else {
                return isWinner ? "Victory" : "Defeat"
            }
        case .declined:
            return "Declined"
        case .cancelled:
            return "Cancelled"
        case .expired:
            return "Expired"
        default:
            return "Unknown"
        }
    }
    
    private var resultColor: Color {
        switch duel.status {
        case .completed:
            if duel.verificationStatus == .forfeited {
                return .orange
            } else {
                return isWinner ? .green : .red
            }
        case .declined, .cancelled, .expired:
            return .gray
        default:
            return .white
        }
    }
    
    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(duel.gameType)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        Text(duel.gameMode)
                            .font(.subheadline)
                            .foregroundColor(.white.opacity(0.8))
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(resultText)
                            .font(.body)
                            .fontWeight(.bold)
                            .foregroundColor(resultColor)
                        
                        if duel.status == .completed && duel.verificationStatus != .forfeited {
                            Text("\(duel.challengerScore ?? 0) - \(duel.opponentScore ?? 0)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                    }
                }
                
                HStack {
                    Text(formatDate(duel.createdAt))
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.6))
                    
                    Spacer()
                    
                    if duel.status == .completed && isWinner {
                        HStack(spacing: 4) {
                            Image(systemName: "trophy.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            
                            Text("Victory")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(.yellow)
                        }
                    }
                }
            }
            .padding(16)
            .background(Color.white.opacity(0.05))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(resultColor.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Supporting Views
struct DuelStatusBadge: View {
    let status: DuelStatus
    
    var body: some View {
        Text(status.displayName)
            .font(.caption2)
            .fontWeight(.bold)
            .foregroundColor(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Color(hex: status.color))
            .cornerRadius(6)
    }
}

struct EmptyStateView: View {
    let icon: String
    let title: String
    let subtitle: String
    let actionTitle: String
    let action: () -> Void
    
    var body: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: icon)
                .font(.system(size: 60))
                .foregroundColor(.white.opacity(0.5))
            
            VStack(spacing: 8) {
                Text(title)
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                Text(subtitle)
                    .font(.body)
                    .foregroundColor(.white.opacity(0.7))
                    .multilineTextAlignment(.center)
            }
            
            Button(action: action) {
                Text(actionTitle)
                    .font(.body)
                    .fontWeight(.semibold)
                    .foregroundColor(.white)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
                    .background(Color.orange)
                    .cornerRadius(8)
            }
            
            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(40)
    }
}

// MARK: - Duel Details View
struct DuelDetailsView: View {
    let duel: Duel
    @StateObject private var duelService = DuelService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showScreenshotCapture = false
    @State private var showError = false
    @State private var errorMessage = ""
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Duel Info
                    duelInfoView
                    
                    // Players Info
                    playersInfoView
                    
                    // Status and Actions
                    statusAndActionsView
                    
                    // Timeline
                    timelineView
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
            .navigationTitle("Duel Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showScreenshotCapture) {
            ScreenshotCaptureView(
                duelId: duel.id,
                gameType: duel.gameType,
                gameMode: duel.gameMode
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
    }
    
    private var duelInfoView: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: gameIcon(for: duel.gameType))
                    .font(.title)
                    .foregroundColor(gameColor(for: duel.gameType))
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(duel.gameType)
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text(duel.gameMode)
                        .font(.body)
                        .foregroundColor(.white.opacity(0.8))
                }
                
                Spacer()
                
                DuelStatusBadge(status: duel.status)
            }
            
            if let message = duel.challengeMessage {
                Divider()
                    .background(Color.white.opacity(0.3))
                
                HStack {
                    Text("\"\(message)\"")
                        .font(.body)
                        .italic()
                        .foregroundColor(.white.opacity(0.9))
                    
                    Spacer()
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.1))
        .cornerRadius(16)
    }
    
    private var playersInfoView: some View {
        VStack(spacing: 16) {
            Text("Players")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            HStack(spacing: 20) {
                // Challenger
                PlayerInfoCard(
                    title: "Challenger",
                    userId: duel.challengerId,
                    score: duel.challengerScore,
                    isWinner: duel.winnerId == duel.challengerId,
                    isCurrentUser: duel.challengerId == AuthService.shared.currentUser?.id
                )
                
                Text("VS")
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.white.opacity(0.7))
                
                // Opponent
                PlayerInfoCard(
                    title: "Opponent",
                    userId: duel.opponentId,
                    score: duel.opponentScore,
                    isWinner: duel.winnerId == duel.opponentId,
                    isCurrentUser: duel.opponentId == AuthService.shared.currentUser?.id
                )
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var statusAndActionsView: some View {
        VStack(spacing: 16) {
            // Current Status
            VStack(spacing: 12) {
                Text("Status")
                    .font(.headline)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                
                VStack(spacing: 8) {
                    DuelStatusBadge(status: duel.status)
                    
                    if duel.verificationStatus != .pending {
                        Text("Verification: \(duel.verificationStatus.displayName)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                }
            }
            
            // Action Buttons
            actionButtonsView
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 12) {
            switch duel.status {
            case .accepted:
                Button("Start Match") {
                    Task {
                        await startMatch()
                    }
                }
                .buttonStyle(PrimaryButtonStyle())
                
            case .inProgress:
                if duel.endedAt != nil {
                    Button("Submit Screenshot") {
                        showScreenshotCapture = true
                    }
                    .buttonStyle(PrimaryButtonStyle())
                } else {
                    Button("End Match") {
                        Task {
                            await endMatch()
                        }
                    }
                    .buttonStyle(SecondaryButtonStyle())
                }
                
            case .completed:
                if duel.winnerId == AuthService.shared.currentUser?.id {
                    Button("View Victory Recap") {
                        // Navigate to victory recap
                    }
                    .buttonStyle(PrimaryButtonStyle())
                }
                
            default:
                EmptyView()
            }
        }
    }
    
    private var timelineView: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Timeline")
                .font(.headline)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            VStack(alignment: .leading, spacing: 12) {
                TimelineItem(
                    icon: "plus.circle.fill",
                    title: "Challenge Proposed",
                    time: duel.createdAt,
                    isCompleted: true
                )
                
                if let acceptedAt = duel.acceptedAt {
                    TimelineItem(
                        icon: "checkmark.circle.fill",
                        title: "Challenge Accepted",
                        time: acceptedAt,
                        isCompleted: true
                    )
                }
                
                if let startedAt = duel.startedAt {
                    TimelineItem(
                        icon: "play.circle.fill",
                        title: "Match Started",
                        time: startedAt,
                        isCompleted: true
                    )
                }
                
                if let endedAt = duel.endedAt {
                    TimelineItem(
                        icon: "stop.circle.fill",
                        title: "Match Ended",
                        time: endedAt,
                        isCompleted: true
                    )
                }
                
                if duel.status == .completed {
                    TimelineItem(
                        icon: "flag.checkered.circle.fill",
                        title: "Duel Completed",
                        time: duel.endedAt ?? Date(),
                        isCompleted: true
                    )
                }
            }
        }
        .padding(20)
        .background(Color.white.opacity(0.05))
        .cornerRadius(16)
    }
    
    private func startMatch() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        do {
            try await duelService.startMatch(duel.id, by: userId)
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
    }
    
    private func endMatch() async {
        guard let userId = AuthService.shared.currentUser?.id else { return }
        
        do {
            try await duelService.endMatch(duel.id, by: userId)
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
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

// MARK: - Supporting Components
struct PlayerInfoCard: View {
    let title: String
    let userId: String
    let score: Int?
    let isWinner: Bool
    let isCurrentUser: Bool
    
    @State private var user: User?
    
    var body: some View {
        VStack(spacing: 12) {
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.white.opacity(0.7))
            
            VStack(spacing: 8) {
                // Avatar
                if let avatarUrl = user?.avatarUrl {
                    AsyncImage(url: URL(string: avatarUrl)) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Image(systemName: "person.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .frame(width: 50, height: 50)
                    .clipShape(Circle())
                    .overlay(
                        Circle()
                            .stroke(isWinner ? Color.yellow : Color.white.opacity(0.3), lineWidth: 2)
                    )
                } else {
                    Image(systemName: "person.circle.fill")
                        .font(.system(size: 50))
                        .foregroundColor(.gray)
                }
                
                // Name
                Text(isCurrentUser ? "You" : (user?.username ?? "Player"))
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(.white)
                
                // Score
                if let score = score {
                    Text("\(score)")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(isWinner ? Color.yellow : .white)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .onAppear {
            Task {
                await loadUser()
            }
        }
    }
    
    private func loadUser() async {
        // Load user info
        // This would fetch user data from UserProfileService
    }
}

struct TimelineItem: View {
    let icon: String
    let title: String
    let time: Date
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(isCompleted ? .green : .white.opacity(0.5))
                .font(.body)
                .frame(width: 20)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.body)
                    .fontWeight(.medium)
                    .foregroundColor(isCompleted ? .white : .white.opacity(0.7))
                
                Text(formatTime(time))
                    .font(.caption)
                    .foregroundColor(.white.opacity(0.6))
            }
            
            Spacer()
        }
    }
    
    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }
}

// MARK: - Button Styles
struct PrimaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                LinearGradient(
                    colors: [Color.orange, Color.red],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

struct SecondaryButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(Color.white.opacity(0.2))
            .cornerRadius(8)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: configuration.isPressed)
    }
}

// MARK: - Preview Provider
struct DuelListView_Previews: PreviewProvider {
    static var previews: some View {
        DuelListView()
    }
}
