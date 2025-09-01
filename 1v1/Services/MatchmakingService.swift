import Foundation
import Supabase
import Combine

class MatchmakingService: ObservableObject {
    static let shared = MatchmakingService()
    
    @Published var suggestedMatches: [EventMatchmaking] = []
    @Published var matchedUserProfiles: [String: ProfileSummary] = [:] // matched_user_id -> ProfileSummary
    @Published var isSearching = false
    @Published var errorMessage: String?
    
    private let supabaseService = SupabaseService.shared
    private var matchmakingChannel: RealtimeChannel?
    private var authCancellable: AnyCancellable?
    
    private init() {
        // Subscribe to auth changes and (re)subscribe/unsubscribe realtime accordingly
        authCancellable = AuthService.shared.$currentUser.sink { [weak self] user in
            Task { await self?.authStateChanged(user: user) }
        }
    }

    deinit {
        // Best-effort cleanup
        matchmakingChannel?.unsubscribe()
        matchmakingChannel = nil
    }
    
    struct SimilarPlayerRow: Decodable, Hashable {
        let id: String
        let matched_user_id: String
        let similarity_score: Double
        let status: String?
        let created_at: Date?
    }

    struct ProfileSummary: Decodable {
        let id: String
        let username: String?
        let avatar_url: String?
    }
    
    // MARK: - Find Similar Players (RPC)
    func findSimilarPlayers(eventId: String, limit: Int = 10) async {
        await MainActor.run {
            self.isSearching = true
            self.errorMessage = nil
            self.suggestedMatches = []
        }
        
        guard let client = supabaseService.getClient() else {
            await MainActor.run { self.errorMessage = "Supabase client not initialized" }
            await MainActor.run { self.isSearching = false }
            return
        }
        guard let userId = AuthService.shared.currentUser?.id else {
            await MainActor.run { self.errorMessage = "User not authenticated" }
            await MainActor.run { self.isSearching = false }
            return
        }
        
        do {
            let params: [String: AnyJSON] = [
                "p_event_id": AnyJSON.string(eventId),
                "p_limit": AnyJSON.number(Decimal(limit))
            ]
            let response = try await client.rpc("find_similar_players", params: params).execute()
            let results = try SupabaseService.jsonDecoder.decode([SimilarPlayerRow].self, from: response.data)
            let rows = results
            let now = Date()
            let basic = rows.map {
                EventMatchmaking(
                    id: $0.id,
                    eventId: eventId,
                    userId: userId,
                    matchedUserId: $0.matched_user_id,
                    similarityScore: $0.similarity_score,
                    status: MatchStatus(rawValue: $0.status ?? "pending") ?? .pending,
                    createdAt: $0.created_at ?? now
                )
            }
            // Set immediately while we enrich profiles in background
            await MainActor.run { self.suggestedMatches = basic }
            // Enrich in background
            Task { [basic] in
                if let profileMap = try? await self.fetchProfilesMap(userIds: Array(Set(basic.map { $0.matchedUserId }))) {
                    await MainActor.run {
                        self.matchedUserProfiles = profileMap
                    }
                }
            }
        } catch {
            await MainActor.run { self.errorMessage = "Failed to find similar players: \(error.localizedDescription)" }
        }
        
        await MainActor.run { self.isSearching = false }
    }

    // MARK: - Realtime Subscriptions (INSERT/UPDATE on event_matchmaking)
    private func setupRealtimeSubscriptions() {
        guard let client = supabaseService.getClient() else { return }
        // Create a Postgres change channel for event_matchmaking in public schema
        let channel = client.realtime.channel("realtime:public:event_matchmaking")

        channel.postgresChange(event: .insert, schema: "public", table: "event_matchmaking") { [weak self] payload in
            Task { [weak self] in
                guard let self = self else { return }
                guard let record = payload.record else { return }
                if let em = self.decodeEventMatchmaking(from: record) {
                    let currentUserId = AuthService.shared.currentUser?.id
                    if em.userId == currentUserId || em.matchedUserId == currentUserId {
                        await self.mergeSuggested(em)
                    }
                }
            }
        }

        channel.postgresChange(event: .update, schema: "public", table: "event_matchmaking") { [weak self] payload in
            Task { [weak self] in
                guard let self = self else { return }
                guard let record = payload.record else { return }
                if let em = self.decodeEventMatchmaking(from: record) {
                    await self.mergeSuggested(em)
                }
            }
        }

        channel.subscribe()
        self.matchmakingChannel = channel
    }

    private func authStateChanged(user: User?) async {
        if user != nil {
            // Ensure we are subscribed after sign-in
            setupRealtimeSubscriptions()
        } else {
            // Unsubscribe on sign-out
            matchmakingChannel?.unsubscribe()
            matchmakingChannel = nil
        }
    }

    private func decodeEventMatchmaking(from anyRecord: Any?) -> EventMatchmaking? {
        // Support records as [String: AnyJSON] or [String: Any]
        if let record = anyRecord as? [String: Any] {
            if let data = try? JSONSerialization.data(withJSONObject: record),
               let obj = try? SupabaseService.jsonDecoder.decode(EventMatchmaking.self, from: data) {
                return obj
            }
        }
        if let record = anyRecord as? [String: AnyJSON] {
            let raw = record.mapValues { $0.rawValue }
            if let data = try? JSONSerialization.data(withJSONObject: raw),
               let obj = try? SupabaseService.jsonDecoder.decode(EventMatchmaking.self, from: data) {
                return obj
            }
        }
        return nil
    }

    @MainActor
    private func mergeSuggested(_ newItem: EventMatchmaking) {
        if let idx = suggestedMatches.firstIndex(where: { $0.id == newItem.id }) {
            suggestedMatches[idx] = newItem
        } else {
            suggestedMatches.insert(newItem, at: 0)
        }
    }

    private func fetchProfilesMap(userIds: [String]) async throws -> [String: ProfileSummary] {
        guard !userIds.isEmpty else { return [:] }
        guard let client = supabaseService.getClient() else { return [:] }
        let response = try await client
            .from("profiles")
            .select("id, username, avatar_url")
            .in("id", values: userIds)
            .execute()
        let summaries = try SupabaseService.jsonDecoder.decode([ProfileSummary].self, from: response.data)
        return Dictionary(uniqueKeysWithValues: summaries.map { ($0.id, $0) })
    }

    // MARK: - Persisted Match Actions
    func createMatchSuggestion(eventId: String, matchedUserId: String, similarityScore: Double) async -> Bool {
        guard let client = supabaseService.getClient() else {
            await MainActor.run { self.errorMessage = "Supabase client not initialized" }
            return false
        }
        guard let userId = AuthService.shared.currentUser?.id else {
            await MainActor.run { self.errorMessage = "User not authenticated" }
            return false
        }
        let payload: [String: AnyJSON] = [
            "event_id": AnyJSON.string(eventId),
            "user_id": AnyJSON.string(userId),
            "matched_user_id": AnyJSON.string(matchedUserId),
            "similarity_score": AnyJSON.number(Decimal(similarityScore))
        ]
        do {
            // Insert and request the inserted row back
            let resp = try await client
                .from("event_matchmaking")
                .insert(payload)
                .select()
                .single()
                .execute()

            if let data = resp.data,
               let em = try? SupabaseService.jsonDecoder.decode(EventMatchmaking.self, from: data) {
                await MainActor.run { self.suggestedMatches.append(em) }
                return true
            }

            return false
        } catch {
            await MainActor.run { self.errorMessage = "Failed to create match suggestion: \(error.localizedDescription)" }
            return false
        }
    }
    
    // MARK: - Accept / Decline
    func acceptMatch(matchId: String) async -> Bool {
        return await updateMatchStatus(matchId: matchId, status: "accepted")
    }
    
    func declineMatch(matchId: String) async -> Bool {
        return await updateMatchStatus(matchId: matchId, status: "declined")
    }
    
    private func updateMatchStatus(matchId: String, status: String) async -> Bool {
        guard let client = supabaseService.getClient() else {
            await MainActor.run { self.errorMessage = "Supabase client not initialized" }
            return false
        }
        
        do {
            try await client
                .from("event_matchmaking")
                .update(["status": AnyJSON.string(status)])
                .eq("id", value: matchId)
                .execute()
            return true
        } catch {
            await MainActor.run { self.errorMessage = "Failed to update match: \(error.localizedDescription)" }
            return false
        }
    }
}


