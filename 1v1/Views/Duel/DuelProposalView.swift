import SwiftUI

struct DuelProposalView: View {
    @StateObject private var duelService = DuelService.shared
    @StateObject private var userService = UserProfileService()
    @StateObject private var gameConfigService = GameConfigurationService.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedOpponent: User?
    @State private var selectedGameType = "Call of Duty: Warzone"
    @State private var selectedGameMode = "1v1 Custom"
    @State private var challengeMessage = ""
    @State private var isLoading = false
    @State private var showGameSelection = false
    @State private var showOpponentSelection = false
    @State private var showError = false
    @State private var errorMessage = ""
    @State private var showSuccess = false
    @State private var createdDuel: Duel?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    headerView
                    
                    // Opponent Selection
                    opponentSelectionView
                    
                    // Game Selection
                    gameSelectionView
                    
                    // Challenge Message
                    challengeMessageView
                    
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
            .navigationTitle("Propose Duel")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(true)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .sheet(isPresented: $showOpponentSelection) {
            OpponentSelectionView(selectedOpponent: $selectedOpponent)
        }
        .sheet(isPresented: $showGameSelection) {
            GameSelectionView(
                selectedGameType: $selectedGameType,
                selectedGameMode: $selectedGameMode
            )
        }
        .alert("Error", isPresented: $showError) {
            Button("OK") { }
        } message: {
            Text(errorMessage)
        }
        .alert("Challenge Sent!", isPresented: $showSuccess) {
            Button("OK") {
                dismiss()
            }
        } message: {
            Text("Your duel challenge has been sent to \(selectedOpponent?.username ?? "your opponent")!")
        }
        .onAppear {
            Task {
                await gameConfigService.loadAllConfigurations()
            }
        }
    }
    
    private var headerView: some View {
        VStack(spacing: 16) {
            Image(systemName: "sword.circle.fill")
                .font(.system(size: 70))
                .foregroundStyle(
                    LinearGradient(
                        colors: [Color.orange, Color.red],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .shadow(color: .orange.opacity(0.3), radius: 10)
            
            Text("Challenge a Player")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
            
            Text("Propose a 1v1 duel and share the challenge")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.7))
                .multilineTextAlignment(.center)
        }
    }
    
    private var opponentSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Opponent")
                .font(.headline)
                .foregroundColor(.white)
            
            Button(action: {
                showOpponentSelection = true
            }) {
                HStack(spacing: 16) {
                    if let opponent = selectedOpponent {
                        AsyncImage(url: URL(string: opponent.avatarUrl ?? "")) { image in
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
                                .stroke(Color.orange, lineWidth: 2)
                        )
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text(opponent.username ?? "Player")
                                .font(.body)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                            
                            HStack(spacing: 8) {
                                Image(systemName: "star.fill")
                                    .foregroundColor(.yellow)
                                    .font(.caption)
                                
                                Text("Level \(opponent.stats?.level ?? 0)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                                
                                if let winRate = opponent.stats?.winRate {
                                    Text("• \(String(format: "%.1f", winRate))% WR")
                                        .font(.caption)
                                        .foregroundColor(.white.opacity(0.7))
                                }
                            }
                        }
                        
                        Spacer()
                        
                        Image(systemName: "chevron.right")
                            .foregroundColor(.white.opacity(0.5))
                    } else {
                        HStack(spacing: 16) {
                            Image(systemName: "person.badge.plus")
                                .font(.title2)
                                .foregroundColor(.white)
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Select Opponent")
                                    .font(.body)
                                    .fontWeight(.medium)
                                    .foregroundColor(.white)
                                
                                Text("Choose who to challenge")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                            
                            Spacer()
                            
                            Image(systemName: "chevron.right")
                                .foregroundColor(.white.opacity(0.5))
                        }
                    }
                }
                .padding(16)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(selectedOpponent != nil ? Color.orange : Color.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    private var gameSelectionView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Game & Mode")
                .font(.headline)
                .foregroundColor(.white)
            
            Button(action: {
                showGameSelection = true
            }) {
                HStack(spacing: 16) {
                    Image(systemName: gameIcon(for: selectedGameType))
                        .font(.title2)
                        .foregroundColor(.white)
                        .frame(width: 30)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(selectedGameType)
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.white)
                        
                        Text(selectedGameMode)
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.7))
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .foregroundColor(.white.opacity(0.5))
                }
                .padding(16)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.2), lineWidth: 1)
                )
            }
        }
    }
    
    private var challengeMessageView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Challenge Message")
                .font(.headline)
                .foregroundColor(.white)
            
            Group {
                if #available(iOS 16.0, *) {
                    TextField("Enter your challenge message...", text: $challengeMessage, axis: .vertical)
                        .lineLimit(3...6)
                } else {
                    TextField("Enter your challenge message...", text: $challengeMessage)
                        .lineLimit(6)
                }
            }
            .textFieldStyle(PlainTextFieldStyle())
            .foregroundColor(.white)
            .padding(16)
            .background(Color.white.opacity(0.1))
            .cornerRadius(12)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.2), lineWidth: 1)
            )
            .placeholder(when: challengeMessage.isEmpty) {
                Text("Let's see what you've got! 🎮")
                    .foregroundColor(.white.opacity(0.5))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 16)
            }
        }
    }
    
    private var actionButtonsView: some View {
        VStack(spacing: 16) {
            // Direct Challenge Button
            Button(action: {
                Task {
                    await proposeDuel()
                }
            }) {
                HStack(spacing: 12) {
                    if isLoading {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Image(systemName: "paperplane.fill")
                            .font(.body)
                    }
                    
                    Text("Send Challenge")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    selectedOpponent != nil && !isLoading ? 
                    LinearGradient(
                        colors: [Color.orange, Color.red],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) : 
                    LinearGradient(
                        colors: [Color.gray, Color.gray],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: selectedOpponent != nil ? .orange.opacity(0.3) : .clear, radius: 8)
            }
            .disabled(selectedOpponent == nil || isLoading)
            
            // Share Challenge Card Button
            Button(action: {
                Task {
                    await createAndShareChallenge()
                }
            }) {
                HStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.up")
                        .font(.body)
                    
                    Text("Create & Share Challenge Card")
                        .font(.body)
                        .fontWeight(.semibold)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(
                    selectedOpponent != nil && !isLoading ?
                    LinearGradient(
                        colors: [Color.blue, Color.purple],
                        startPoint: .leading,
                        endPoint: .trailing
                    ) :
                    LinearGradient(
                        colors: [Color.gray, Color.gray],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(12)
                .shadow(color: selectedOpponent != nil ? .blue.opacity(0.3) : .clear, radius: 8)
            }
            .disabled(selectedOpponent == nil || isLoading)
            
            // Game Info
            if !gameConfigService.availableGames.isEmpty {
                VStack(spacing: 8) {
                    Text("Supported Games")
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                    
                    HStack(spacing: 8) {
                        ForEach(gameConfigService.getSupportedGames().prefix(3), id: \.self) { game in
                            Text(game)
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.white.opacity(0.8))
                        }
                        
                        if gameConfigService.getSupportedGames().count > 3 {
                            Text("+\(gameConfigService.getSupportedGames().count - 3) more")
                                .font(.caption2)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.white.opacity(0.1))
                                .cornerRadius(8)
                                .foregroundColor(.white.opacity(0.8))
                        }
                    }
                }
                .padding(.top, 8)
            }
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
    
    private func proposeDuel() async {
        guard let opponent = selectedOpponent,
              let challengerId = AuthService.shared.currentUser?.id else { 
            showError = true
            errorMessage = "Unable to identify current user"
            return 
        }
        
        isLoading = true
        
        do {
            let duel = try await duelService.createDuel(
                challengerId: challengerId,
                opponentId: opponent.id ?? "",
                gameType: selectedGameType,
                gameMode: selectedGameMode,
                challengeMessage: challengeMessage
            )
            
            createdDuel = duel
            showSuccess = true
            
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
    
    private func createAndShareChallenge() async {
        guard let opponent = selectedOpponent,
              let challenger = AuthService.shared.currentUser else { 
            showError = true
            errorMessage = "Unable to identify users"
            return 
        }
        
        isLoading = true
        
        do {
            // First create the duel
            let duel = try await duelService.createDuel(
                challengerId: challenger.id ?? "",
                opponentId: opponent.id ?? "",
                gameType: selectedGameType,
                gameMode: selectedGameMode,
                challengeMessage: challengeMessage
            )
            
            // Generate challenge card
            let challengeCard = try await duelService.generateChallengeCard(
                for: duel,
                challenger: challenger
            )
            
            // Share the challenge card
            try await duelService.shareChallengeCard(challengeCard)
            
            createdDuel = duel
            showSuccess = true
            
        } catch {
            showError = true
            errorMessage = error.localizedDescription
        }
        
        isLoading = false
    }
}

// MARK: - Opponent Selection View
struct OpponentSelectionView: View {
    @Binding var selectedOpponent: User?
    @StateObject private var userService = UserProfileService()
    @Environment(\.dismiss) private var dismiss
    
    @State private var searchText = ""
    @State private var users: [User] = []
    @State private var isLoading = false
    
    var filteredUsers: [User] {
        if searchText.isEmpty {
            return users
        } else {
            return users.filter { user in
                user.username?.localizedCaseInsensitiveContains(searchText) ?? false
            }
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search Bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.white.opacity(0.7))
                    
                    TextField("Search players...", text: $searchText)
                        .textFieldStyle(PlainTextFieldStyle())
                        .foregroundColor(.white)
                }
                .padding(16)
                .background(Color.white.opacity(0.1))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .padding(.top, 20)
                
                // Users List
                if isLoading {
                    Spacer()
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(1.2)
                    Spacer()
                } else {
                    List(filteredUsers, id: \.id) { user in
                        OpponentRow(user: user, isSelected: selectedOpponent?.id == user.id) {
                            selectedOpponent = user
                            dismiss()
                        }
                        .listRowBackground(Color.clear)
                    }
                    .listStyle(PlainListStyle())
                    .modifier(HideListBackgroundIfAvailable())
                }
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
            .navigationTitle("Select Opponent")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
        .onAppear {
            Task {
                await loadUsers()
            }
        }
    }
    
    private func loadUsers() async {
        isLoading = true
        
        do {
            // Load all users except current user
            let allUsers: [User] = try await userService.loadAllUsers()
            let currentUserId = AuthService.shared.currentUser?.id
            
            users = allUsers.filter { $0.id != currentUserId }
        } catch {
            print("Error loading users: \(error)")
        }
        
        isLoading = false
    }
}

struct OpponentRow: View {
    let user: User
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                AsyncImage(url: URL(string: user.avatarUrl ?? "")) { image in
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
                        .stroke(isSelected ? Color.orange : Color.white.opacity(0.3), lineWidth: 2)
                )
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(user.username ?? "Player")
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    HStack(spacing: 12) {
                        HStack(spacing: 4) {
                            Image(systemName: "star.fill")
                                .foregroundColor(.yellow)
                                .font(.caption)
                            
                            Text("Level \(user.stats?.level ?? 0)")
                                .font(.caption)
                                .foregroundColor(.white.opacity(0.7))
                        }
                        
                        if let winRate = user.stats?.winRate {
                            HStack(spacing: 4) {
                                Image(systemName: "chart.line.uptrend.xyaxis")
                                    .foregroundColor(.green)
                                    .font(.caption)
                                
                                Text("\(String(format: "%.1f", winRate))% WR")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                        
                        if let wins = user.stats?.wins, wins > 0 {
                            HStack(spacing: 4) {
                                Image(systemName: "trophy.fill")
                                    .foregroundColor(.orange)
                                    .font(.caption)
                                
                                Text("\(wins) wins")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.7))
                            }
                        }
                    }
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                }
            }
            .padding(.vertical, 8)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Game Selection View
struct GameSelectionView: View {
    @Binding var selectedGameType: String
    @Binding var selectedGameMode: String
    @StateObject private var gameConfigService = GameConfigurationService.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                ForEach(gameConfigService.getSupportedGames(), id: \.self) { gameType in
                    Section(gameType) {
                        ForEach(gameConfigService.getSupportedModes(for: gameType), id: \.self) { mode in
                            GameModeRow(
                                gameType: gameType,
                                gameMode: mode,
                                isSelected: selectedGameType == gameType && selectedGameMode == mode
                            ) {
                                selectedGameType = gameType
                                selectedGameMode = mode
                                dismiss()
                            }
                        }
                    }
                }
            }
            .listStyle(InsetGroupedListStyle())
            .modifier(HideListBackgroundIfAvailable())
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
            .navigationTitle("Select Game")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                    .foregroundColor(.white)
                }
            }
        }
    }
}

struct GameModeRow: View {
    let gameType: String
    let gameMode: String
    let isSelected: Bool
    let onSelect: () -> Void
    
    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 16) {
                Image(systemName: gameIcon(for: gameType))
                    .font(.title3)
                    .foregroundColor(gameColor(for: gameType))
                    .frame(width: 30)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(gameMode)
                        .font(.body)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                    
                    Text(gameType)
                        .font(.caption)
                        .foregroundColor(.white.opacity(0.7))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.orange)
                        .font(.title3)
                }
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(PlainButtonStyle())
        .listRowBackground(
            Color.white.opacity(isSelected ? 0.15 : 0.05)
        )
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

// MARK: - Extensions
extension View {
    func placeholder<Content: View>(
        when shouldShow: Bool,
        alignment: Alignment = .leading,
        @ViewBuilder placeholder: () -> Content) -> some View {

        ZStack(alignment: alignment) {
            placeholder().opacity(shouldShow ? 1 : 0)
            self
        }
    }
}

// Helper modifier to hide list background on iOS 16+, no-op on iOS 15
struct HideListBackgroundIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        Group {
            if #available(iOS 16.0, *) {
                content.scrollContentBackground(.hidden)
            } else {
                content
            }
        }
    }
}


