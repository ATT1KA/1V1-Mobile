import SwiftUI

struct LeaderboardView: View {
    @StateObject private var leaderboardService = LeaderboardService.shared
    @EnvironmentObject var authService: AuthService
    @State private var selectedSegment = 0

    var body: some View {
        VStack {
            // Only the global leaderboard is implemented at the moment.
            // Future: replace this with a segmented picker when other tabs are implemented.
            Text("Global Leaderboard")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()

            if leaderboardService.isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                List(leaderboardService.globalLeaderboard) { entry in
                    HStack {
                        Text("\(entry.rank)")
                            .font(.headline)
                            .frame(width: 40, alignment: .leading)
                        VStack(alignment: .leading) {
                            Text(entry.leaderboardOptIn == true || entry.isCurrentUser == true ? (entry.username ?? Constants.Leaderboard.anonymousPlayerPrefix + "####") : Constants.Leaderboard.anonymousPlayerPrefix + "####")
                                .font(.subheadline)
                            Text("\(entry.totalPoints) pts")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        if let idStr = authService.currentUser?.id, entry.userId == idStr {
                            Text("You")
                                .font(.caption)
                                .foregroundColor(.accentColor)
                        }
                    }
                }
                .refreshable {
                    await leaderboardService.fetchGlobalLeaderboard()
                }
            }
        }
        .navigationTitle("Leaderboard")
        .onAppear {
            LeaderboardService.shared.subscribeToLeaderboardChanges()
            Task { await leaderboardService.fetchGlobalLeaderboard() }
        }
        .onDisappear {
            LeaderboardService.shared.unsubscribeFromLeaderboardChanges()
        }
    }
}

struct LeaderboardView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView { LeaderboardView() }
            .environmentObject(AuthService.shared)
    }
}


