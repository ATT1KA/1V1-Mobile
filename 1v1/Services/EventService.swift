import Foundation
import Supabase

class EventService: ObservableObject {
    static let shared = EventService()
    
    @Published var events: [Event] = []
    @Published var currentEvent: Event?
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var lastCheckInEventId: String?
    
    private let supabaseService = SupabaseService.shared
    private var cachedEvents: (data: [Event], fetchedAt: Date)?
    // Lightweight attendee count cache: eventId -> (count, fetchedAt)
    private var attendeeCountCache: [String: (count: Int, fetchedAt: Date)] = [:]
    @Published var attendeeCounts: [String: Int] = [:]
    
    private init() {}
    
    // MARK: - Fetch Events
    func fetchEvents() async {
        let cacheFreshInterval: TimeInterval = 120
        let now = Date()
        // Serve cache if fresh
        if let cache = cachedEvents, now.timeIntervalSince(cache.fetchedAt) < cacheFreshInterval {
            await MainActor.run {
                self.events = cache.data
            }
            // Refresh in background
            Task { await self.refreshEventsFromServer() }
            return
        }
        // Otherwise fetch synchronously
        await refreshEventsFromServer()
    }

    private func refreshEventsFromServer() async {
        await MainActor.run {
            self.isLoading = true
            self.errorMessage = nil
        }
        guard let client = supabaseService.getClient() else {
            await MainActor.run { self.errorMessage = "Supabase client not initialized" }
            await MainActor.run { self.isLoading = false }
            return
        }
        do {
            let response = try await client
                .from("events")
                .select("*")
                .order("start_time", ascending: true)
                .execute()
            let list = try SupabaseService.jsonDecoder.decode([Event].self, from: response.data)
            await MainActor.run { self.events = list }
            self.cachedEvents = (data: list, fetchedAt: Date())
        } catch {
            await MainActor.run { self.errorMessage = "Failed to load events: \(error.localizedDescription)" }
        }
        await MainActor.run { self.isLoading = false }
    }
    
    // MARK: - Attendance
    func fetchMyAttendance(eventId: String) async -> [EventAttendance] {
        // Keep for potential detailed views; not used for counts after RPC change
        guard let client = supabaseService.getClient() else {
            await MainActor.run { self.errorMessage = "Supabase client not initialized" }
            return []
        }
        do {
            let response = try await client
                .from("event_attendance")
                .select("*")
                .eq("event_id", value: eventId)
                .order("checked_in_at", ascending: false)
                .execute()
            let list = try SupabaseService.jsonDecoder.decode([EventAttendance].self, from: response.data)
            return list
        } catch {
            await MainActor.run { self.errorMessage = "Failed to load attendance: \(error.localizedDescription)" }
            return []
        }
    }

    /// Fetch full attendee rows for an event using server-side RPC `get_event_attendees`.
    /// This RPC is SECURITY DEFINER and may return full attendee lists when permitted.
    func fetchEventAttendees(eventId: String) async -> [EventAttendance] {
        guard let client = supabaseService.getClient() else {
            await MainActor.run { self.errorMessage = "Supabase client not initialized" }
            return []
        }
        do {
            let resp = try await client.rpc("get_event_attendees", params: ["p_event_id": AnyJSON.string(eventId)]).execute()
            let list = try SupabaseService.jsonDecoder.decode([EventAttendance].self, from: resp.data)
            return list
        } catch {
            await MainActor.run { self.errorMessage = "Failed to load attendees: \(error.localizedDescription)" }
            return []
        }
    }

    func fetchEventAttendeeCount(eventId: String) async -> Int {
        // Return cached value if fresh
        let cacheFreshInterval: TimeInterval = 15 // seconds
        if let cached = attendeeCountCache[eventId], Date().timeIntervalSince(cached.fetchedAt) < cacheFreshInterval {
            return cached.count
        }

        guard let client = supabaseService.getClient() else {
            errorMessage = "Supabase client not initialized"
            return 0
        }
        do {
            let resp = try await client.rpc("get_event_attendee_count", params: ["p_event_id": AnyJSON.string(eventId)]).execute()
            let data = resp.data
            var count: Int = 0

            // Try a few plausible response shapes from PostgREST/Supabase RPCs:
            // 1) Plain integer (e.g. 42)
            // 2) Array of integers (e.g. [42])
            // 3) Array of single-key objects (e.g. [{"get_event_attendee_count":42}])
            // 4) Single object with a numeric value (e.g. {"count":42})
            // 5) Fallback to JSONSerialization parsing for unexpected shapes
            if let decodedInt = try? SupabaseService.jsonDecoder.decode(Int.self, from: data) {
                count = decodedInt
            } else if let decodedIntArray = try? SupabaseService.jsonDecoder.decode([Int].self, from: data), let first = decodedIntArray.first {
                count = first
            } else if let decodedDictArray = try? SupabaseService.jsonDecoder.decode([[String: Int]].self, from: data), let firstDict = decodedDictArray.first, let value = firstDict.values.first {
                count = value
            } else if let decodedDict = try? SupabaseService.jsonDecoder.decode([String: Int].self, from: data), let value = decodedDict.values.first {
                count = value
            } else {
                // Try low-level parsing as a last resort
                if let obj = try? JSONSerialization.jsonObject(with: data, options: []) {
                    if let n = obj as? Int {
                        count = n
                    } else if let s = obj as? String, let n = Int(s) {
                        count = n
                    } else if let arr = obj as? [Any], let first = arr.first {
                        if let n = first as? Int {
                            count = n
                        } else if let dictAny = first as? [String: Any], let anyVal = dictAny.values.first {
                            if let n = anyVal as? Int { count = n }
                            else if let s = anyVal as? String, let n2 = Int(s) { count = n2 }
                        }
                    } else if let dictAny = obj as? [String: Any], let anyVal = dictAny.values.first {
                        if let n = anyVal as? Int { count = n }
                        else if let s = anyVal as? String, let n2 = Int(s) { count = n2 }
                    }
                }
            }

            // Update cache and published map
            attendeeCountCache[eventId] = (count: count, fetchedAt: Date())
            await MainActor.run { [weak self] in
                self?.attendeeCounts[eventId] = count
            }
            return count
        } catch {
            await MainActor.run { self.errorMessage = "Failed to load attendee count: \(error.localizedDescription)" }
            return 0
        }
    }

    /// Force-refresh attendee count from server and update cache/published value.
    func refreshAttendeeCount(eventId: String) async {
        let count = await fetchEventAttendeeCount(eventId: eventId)
        await MainActor.run { [weak self] in
            self?.attendeeCounts[eventId] = count
        }
    }
    
    // MARK: - Check-in
    func checkInToEvent(eventId: String, method: CheckInMethod) async -> Bool {
        await MainActor.run { self.errorMessage = nil }
        
        guard let client = supabaseService.getClient() else {
            await MainActor.run { self.errorMessage = "Supabase client not initialized" }
            return false
        }
        
        guard let _ = AuthService.shared.currentUser?.id else {
            await MainActor.run { self.errorMessage = "User not authenticated" }
            return false
        }
        
        // Load event details
        var event: Event?
        event = events.first(where: { $0.id == eventId })
        if event == nil {
            do {
                let response = try await client
                    .from("events")
                    .select("*")
                    .eq("id", value: eventId)
                    .single()
                    .execute()
                event = try SupabaseService.jsonDecoder.decode(Event.self, from: response.data)
            } catch {
                await MainActor.run { self.errorMessage = "Event not found" }
                return false
            }
        }
        
        guard let selectedEvent = event else {
            await MainActor.run { self.errorMessage = "Event not found" }
            return false
        }
        
        // Server-side check-in via RPC (handles window, capacity, and unique constraints under RLS)
        do {
            let params: [String: AnyJSON] = [
                "p_event_id": AnyJSON.string(eventId),
                "p_method": AnyJSON.string(method.rawValue)
            ]
            let resp = try await client.rpc("attempt_event_check_in", params: params).execute()
            struct RPCResult: Decodable { let ok: Bool; let message: String }
            if let result = try? SupabaseService.jsonDecoder.decode([RPCResult].self, from: resp.data).first {
                if result.ok {
                    // Invalidate local cache and force a refresh from server so counts are authoritative
                    attendeeCountCache[eventId] = nil
                    Task { await self.refreshAttendeeCount(eventId: eventId) }
                    await MainActor.run { self.lastCheckInEventId = eventId }
                    return true
                }
                await MainActor.run { self.errorMessage = result.message }
                return false
            }
            // Fallback: attempt to parse single object
            if let result: RPCResult = try? resp.value {
                if result.ok {
                    // Invalidate local cache and force a refresh from server so counts are authoritative
                    attendeeCountCache[eventId] = nil
                    Task { await self.refreshAttendeeCount(eventId: eventId) }
                    await MainActor.run { self.lastCheckInEventId = eventId }
                    return true
                }
                await MainActor.run { self.errorMessage = result.message }
                return false
            }
            await MainActor.run { self.errorMessage = "Unexpected RPC response" }
            return false
        } catch {
            errorMessage = "Check-in failed: \(error.localizedDescription)"
            return false
        }
    }
    
    // MARK: - QR
    func generateEventQRCode(eventId: String) -> String? {
        return ScanContext.eventCheckIn(eventId: eventId).encodedPayloadString()
    }
    
    // MARK: - Helpers
    private func extractDatabaseErrorCode(from httpError: PostgrestHTTPError) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: httpError.data) as? [String: Any] else { return nil }
        // PostgREST error format may include details.code or code
        if let code = json["code"] as? String { return code }
        if let details = json["details"] as? [String: Any], let code = details["code"] as? String { return code }
        return nil
    }
}


