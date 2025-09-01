import SwiftUI

struct MatchmakingView: View {
    let event: Event
    
    @StateObject private var service = MatchmakingService.shared
    
    var body: some View {
        List {
            if service.isSearching { ProgressView() }
            if let error = service.errorMessage, !error.isEmpty {
                Text(error).foregroundColor(.red)
            }
            ForEach(service.suggestedMatches, id: \.id) { row in
                HStack(spacing: 12) {
                    Image(systemName: "person.crop.circle")
                        .font(.system(size: 32))
                        .foregroundColor(.blue)
                    VStack(alignment: .leading) {
                        let profile = service.matchedUserProfiles[row.matchedUserId]
                        Text(profile?.username ?? row.matchedUserId).font(.headline)
                        Text("Match Quality: \(Int(row.similarityScore))%  Status: \(row.status.rawValue)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    Button("Accept") {
                        Task { _ = await service.acceptMatch(matchId: row.id) }
                    }
                    .buttonStyle(.borderedProminent)
                    Button("Decline") {
                        Task { _ = await service.declineMatch(matchId: row.id) }
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .navigationTitle("Matchmaking")
        .toolbar { Button("Find") { Task { await service.findSimilarPlayers(eventId: event.id) } } }
        .task { await service.findSimilarPlayers(eventId: event.id) }
    }
}


struct MatchmakingView_Previews: PreviewProvider {
    static var previews: some View {
        let sample = Event(
            id: UUID().uuidString,
            name: "Sample Event",
            description: "Preview description",
            venue: "Preview Venue",
            startTime: Date().addingTimeInterval(-3600),
            endTime: Date().addingTimeInterval(3600),
            maxAttendees: 64,
            eventType: "tournament",
            metadata: [:],
            createdAt: Date().addingTimeInterval(-7200),
            updatedAt: Date()
        )
        NavigationView { MatchmakingView(event: sample) }
    }
}

