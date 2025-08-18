import SwiftUI

struct HomeView: View {
    @EnvironmentObject var authService: AuthService
    @State private var isLoading = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Welcome Section
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Welcome back!")
                            .font(.title)
                            .fontWeight(.bold)
                        
                        Text("Ready for your next 1V1 challenge?")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                    
                    // Quick Actions
                    LazyVGrid(columns: [
                        GridItem(.flexible()),
                        GridItem(.flexible())
                    ], spacing: 16) {
                        QuickActionCard(
                            title: "Find Match",
                            subtitle: "Start a new game",
                            icon: "gamecontroller.fill",
                            color: .green
                        ) {
                            // Handle find match action
                        }
                        
                        QuickActionCard(
                            title: "History",
                            subtitle: "View past games",
                            icon: "clock.fill",
                            color: .orange
                        ) {
                            // Handle history action
                        }
                        
                        QuickActionCard(
                            title: "Leaderboard",
                            subtitle: "See rankings",
                            icon: "trophy.fill",
                            color: .yellow
                        ) {
                            // Handle leaderboard action
                        }
                        
                        QuickActionCard(
                            title: "Settings",
                            subtitle: "App preferences",
                            icon: "gear",
                            color: .gray
                        ) {
                            // Handle settings action
                        }
                    }
                    
                    // Recent Activity
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Recent Activity")
                            .font(.headline)
                            .fontWeight(.semibold)
                        
                        ForEach(0..<3) { index in
                            ActivityRow(
                                title: "Game #\(1000 + index)",
                                subtitle: "Completed 2 hours ago",
                                result: index % 2 == 0 ? "Victory" : "Defeat",
                                isVictory: index % 2 == 0
                            )
                        }
                    }
                    .padding()
                    .background(Color(.systemGray6))
                    .cornerRadius(12)
                }
                .padding()
            }
            .navigationTitle("Home")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                // Handle pull to refresh
                await refreshData()
            }
        }
    }
    
    private func refreshData() async {
        isLoading = true
        // Simulate data refresh
        try? await Task.sleep(nanoseconds: 1_000_000_000)
        isLoading = false
    }
}

struct QuickActionCard: View {
    let title: String
    let subtitle: String
    let icon: String
    let color: Color
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            VStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(color)
                
                VStack(spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .fontWeight(.semibold)
                    
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .cornerRadius(12)
            .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

struct ActivityRow: View {
    let title: String
    let subtitle: String
    let result: String
    let isVictory: Bool
    
    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            Text(result)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(isVictory ? .green : .red)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background((isVictory ? Color.green : Color.red).opacity(0.2))
                .cornerRadius(6)
        }
        .padding(.vertical, 4)
    }
}

struct HomeView_Previews: PreviewProvider {
    static var previews: some View {
        HomeView()
            .environmentObject(AuthService())
    }
}
