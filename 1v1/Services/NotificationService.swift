import Foundation
import UserNotifications
import Combine
import Supabase

@MainActor
class NotificationService: ObservableObject {
    static let shared = NotificationService()
    
    @Published var isAuthorized = false
    @Published var pendingNotifications: [PendingNotification] = []
    @Published var activeMatchNotifications: [String: MatchNotificationState] = [:]
    
    private let supabaseService = SupabaseService.shared
    private var cancellables = Set<AnyCancellable>()
    private var realtimeSubscriptions: [String: RealtimeChannel] = [:]
    private var matchEndTimers: [String: Timer] = [:]
    private var matchMonitoringTasks: [String: Task<Void, Never>] = [:]
    private var verificationReminderTasks: [String: Task<Void, Never>] = [:]
    private var notificationDeliveryQueue: [PendingNotification] = []
    // Flag to indicate intentional unsubscribe to avoid duplicate resubscribe attempts
    private var intentionallyUnsubscribed: Bool = false
    // Short-lived dedupe map for update events to avoid double-firing between parallel handlers
    private var updateDedupeTimestamps: [String: Date] = [:]
    private let updateDedupeInterval: TimeInterval = 2.0 // seconds
    // Resubscribe/backoff state for realtime channels
    private var realtimeResubscribeDelay: TimeInterval = 1.0
    private let realtimeResubscribeMaxDelay: TimeInterval = 32.0
    
    private init() {
        checkAuthorizationStatus()
        // Wire realtime subscriptions to auth state changes
        authCancellable = AuthService.shared.$currentUser.sink { [weak self] user in
            Task { await self?.authStateChanged(user: user) }
        }
        startNotificationDeliveryQueue()
    }

    private var authCancellable: AnyCancellable?
    
    // deinit intentionally omitted; singleton lives app lifetime
    
    // MARK: - Resource Management
    private func cleanupResources() {
        // Mark that we're intentionally unsubscribing to prevent the channel .closed handler
        // from attempting to resubscribe during an explicit cleanup (e.g., on sign-out).
        intentionallyUnsubscribed = true

        // Unsubscribe from any active realtime channels
        for (key, channel) in realtimeSubscriptions {
            print("ℹ️ Unsubscribing realtime channel: \(key)")
            channel.unsubscribe()
        }
        realtimeSubscriptions.removeAll()
        matchEndTimers.values.forEach { $0.invalidate() }
        matchMonitoringTasks.values.forEach { $0.cancel() }

        // Cancel any pending verification reminder tasks (prevents reminders firing post sign-out)
        verificationReminderTasks.values.forEach { $0.cancel() }
        verificationReminderTasks.removeAll()
    }

    private func authStateChanged(user: User?) async {
        if user != nil {
            // Ensure we start fresh. Reset intentional unsubscribe so new sessions can resubscribe.
            // Do NOT call cleanupResources here since it marks intentionallyUnsubscribed = true.
            intentionallyUnsubscribed = false
            setupRealtimeSubscriptions()
        } else {
            // Unsubscribe/cleanup on sign-out
            cleanupResources()
        }
    }
    
    // MARK: - Authorization
    func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        
        do {
            let granted = try await center.requestAuthorization(options: [.alert, .sound, .badge])
            await MainActor.run {
                self.isAuthorized = granted
            }
            return granted
        } catch {
            print("❌ Notification authorization error: \(error)")
            return false
        }
    }
    
    private func checkAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            DispatchQueue.main.async {
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }

    // Public method to refresh authorization status without requesting permission
    @MainActor
    func refreshAuthorizationStatus() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            Task { @MainActor in
                self.isAuthorized = settings.authorizationStatus == .authorized
            }
        }
    }
    
    // MARK: - Real-time Match Monitoring
    private func setupRealtimeSubscriptions() {
        guard let client = supabaseService.getClient() else {
            print("⚠️ Supabase client not initialized; realtime disabled")
            return
        }

        guard let currentUserId = AuthService.shared.currentUser?.id else {
            print("⚠️ No signed-in user; skipping realtime duel subscription")
            return
        }

        // If an existing duels channel exists (from a previous subscribe attempt), clear it
        // to avoid overlapping channels when resubscribing.
        if let existing = realtimeSubscriptions["duels"] {
            print("ℹ️ Clearing existing duels channel before (re)subscribing")
            existing.unsubscribe()
            realtimeSubscriptions.removeValue(forKey: "duels")
        }

        // We're explicitly (re)subscribing now; clear the intentional unsubscribe flag so
        // the .closed handler knows resubscribe attempts are allowed.
        intentionallyUnsubscribed = false

        let channel = client.realtime.channel("realtime:public:duels")

        // Register two filtered handlers (one per player column) using inline postgresChange closures.
        // Filter for challenger changes
        let challengerFilter = "challenger_id=eq.\(currentUserId)"
        channel.postgresChange(event: .insert, schema: "public", table: "duels", filter: challengerFilter) { [weak self] payload in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard let raw = payload.record else { return }
                guard let record = Self.coerceRecord(raw) else { return }

                guard let challengerId = record["challenger_id"] as? String,
                      let opponentId = record["opponent_id"] as? String,
                      [challengerId, opponentId].contains(currentUserId) else { return }

                await self.handleDuelInsert(["new": record])
            }
        }

        channel.postgresChange(event: .update, schema: "public", table: "duels", filter: challengerFilter) { [weak self] payload in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard let raw = payload.record else { return }
                guard let record = Self.coerceRecord(raw) else { return }
                await self.processUpdateRecord(record: record, oldRaw: payload.oldRecord)
            }
        }

        // Filter for opponent changes
        let opponentFilter = "opponent_id=eq.\(currentUserId)"
        channel.postgresChange(event: .insert, schema: "public", table: "duels", filter: opponentFilter) { [weak self] payload in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard let raw = payload.record else { return }
                guard let record = Self.coerceRecord(raw) else { return }

                guard let challengerId = record["challenger_id"] as? String,
                      let opponentId = record["opponent_id"] as? String,
                      [challengerId, opponentId].contains(currentUserId) else { return }

                await self.handleDuelInsert(["new": record])
            }
        }

        channel.postgresChange(event: .update, schema: "public", table: "duels", filter: opponentFilter) { [weak self] payload in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                guard let raw = payload.record else { return }
                guard let record = Self.coerceRecord(raw) else { return }
                await self.processUpdateRecord(record: record, oldRaw: payload.oldRecord)
            }
        }

        // Log channel errors and closures
        channel.on(.error) { info in
            print("❌ Duels channel error: \(info)")
        }

        // Reset backoff only when we receive a confirmed subscribed/join event on the channel —
        // this avoids resetting the delay prematurely when subscribe() is called but
        // the connection fails. Use `.subscribed` (join confirmation) if available.
        channel.on(.subscribed) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                print("✅ Duels channel subscribed; resetting resubscribe backoff")
                self.realtimeResubscribeDelay = 1.0
            }
        }

        channel.on(.closed) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }

                // If we intentionally unsubscribed (cleanupResources), don't attempt to resubscribe.
                if self.intentionallyUnsubscribed {
                    print("ℹ️ Duels channel closed intentionally; skipping resubscribe")
                    return
                }

                print("⚠️ Duels channel closed; attempting resubscribe… (delay: \(self.realtimeResubscribeDelay)s)")
                // Clear any lingering channel reference to avoid overlapping channels
                if let existing = self.realtimeSubscriptions["duels"] {
                    print("ℹ️ Clearing lingering duels channel before resubscribe")
                    existing.unsubscribe()
                    self.realtimeSubscriptions.removeValue(forKey: "duels")
                }
                // Wait with simple exponential backoff, then try to re-setup subscriptions
                let delayNs = UInt64(self.realtimeResubscribeDelay * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delayNs)

                // Only attempt resubscribe if a user is still signed in
                guard AuthService.shared.currentUser != nil else {
                    print("ℹ️ No signed-in user after channel closed; skipping resubscribe")
                    return
                }

                self.setupRealtimeSubscriptions()

                // Increase backoff for subsequent attempts, capped
                self.realtimeResubscribeDelay = min(self.realtimeResubscribeDelay * 2, self.realtimeResubscribeMaxDelay)
            }
        }

        channel.subscribe()
        realtimeSubscriptions["duels"] = channel

        print("✅ Realtime subscriptions for duels (user-filtered) initialized for user: \(currentUserId)")
    }
    
    // Centralized processing for update payloads to avoid duplicated logic across parallel handlers
    private func processUpdateRecord(record: [String: Any], oldRaw: Any?) async {
        guard let currentUserId = AuthService.shared.currentUser?.id else { return }
        // Basic players check
        guard let challengerId = record["challenger_id"] as? String,
              let opponentId = record["opponent_id"] as? String,
              [challengerId, opponentId].contains(currentUserId) else { return }

        // Ensure status exists and is one we care about; fallback when oldRecord is absent
        guard let status = record["status"] as? String,
              ["in_progress", "ended", "completed"].contains(status) else { return }

        // Note: dedupe removed — rely on old-vs-new status equality check below

        // If an old record is available, compare statuses and ignore updates where status didn't change
        if let rawOld = oldRaw,
           let oldRecord = Self.coerceRecord(rawOld),
           let oldStatus = oldRecord["status"] as? String,
           let newStatus = record["status"] as? String,
           oldStatus == newStatus {
            print("ℹ️ Duel status unchanged for duel \(record["id"] as? String ?? "unknown"); ignoring")
            return
        }

        await self.handleDuelUpdate(["new": record])
    }

    // Extracted central status-change processor to reduce branching duplication
    private func processDuelStatusChange(duelId: String, newStatus: String, record: [String: Any]) async {
        print("🔄 Duel update received: \(duelId) - Status: \(newStatus)")

        switch newStatus {
        case "in_progress":
            // If we're already monitoring this duel, ignore duplicate in_progress updates
            if let state = activeMatchNotifications[duelId], state.status == .inProgress {
                print("ℹ️ Duplicate in_progress for duel \(duelId); ignoring")
                return
            }
            await startMatchMonitoring(duelId: duelId, record: record)

        case "ended":
            // Avoid re-triggering if already marked ended
            if activeMatchNotifications[duelId]?.status == .ended {
                print("ℹ️ Duplicate ended for duel \(duelId); ignoring")
                return
            }

            // Ensure minimal state exists for fast status transitions that may have skipped in_progress
            if activeMatchNotifications[duelId] == nil {
                let gameType = record["game_type"] as? String ?? "unknown"
                activeMatchNotifications[duelId] = MatchNotificationState(
                    duelId: duelId,
                    gameType: gameType,
                    status: .ended,
                    startTime: Date(),
                    endTime: Date(),
                    lastPingTime: nil,
                    pingCount: 0
                )
            }

            await handleMatchEnded(duelId: duelId, record: record)

        case "completed":
            // If we aren't monitoring the duel, treat as already stopped
            if activeMatchNotifications[duelId] == nil {
                print("ℹ️ Completed for duel \(duelId) but no active monitoring; ignoring")
                return
            }
            await stopMatchMonitoring(duelId: duelId)

            // Notify the signed-in user that the match completed
            if let me = AuthService.shared.currentUser?.id {
                await sendMatchCompletedNotification(to: me, duelId: duelId)
            }

        default:
            print("ℹ️ Unhandled duel status: \(newStatus)")
        }
    }

    private func handleDuelUpdate(_ payload: [String: Any]) async {
        guard let record = payload["new"] as? [String: Any],
              let duelId = record["id"] as? String,
              let status = record["status"] as? String else {
            print("⚠️ Invalid duel update payload")
            return
        }

        await processDuelStatusChange(duelId: duelId, newStatus: status, record: record)
    }
    
    private func handleDuelInsert(_ payload: [String: Any]) async {
        guard let record = payload["new"] as? [String: Any],
              let duelId = record["id"] as? String,
              let challengerId = record["challenger_id"] as? String,
              let opponentId = record["opponent_id"] as? String,
              let gameType = record["game_type"] as? String,
              let gameMode = record["game_mode"] as? String else { 
            print("⚠️ Invalid duel insert payload")
            return 
        }
        
        print("🆕 New duel created: \(duelId)")
        
        // Send challenge notification to opponent
        guard let me = AuthService.shared.currentUser?.id else { return }
        if opponentId == me {
            await sendDuelChallengeNotification(
                to: opponentId,
                from: challengerId,
                gameType: gameType,
                gameMode: gameMode,
                duelId: duelId
            )
        }
    }
    
    // MARK: - Match Monitoring
    private func startMatchMonitoring(duelId: String, record: [String: Any]) async {
        guard let gameType = record["game_type"] as? String,
              let challengerId = record["challenger_id"] as? String,
              let opponentId = record["opponent_id"] as? String else { 
            print("⚠️ Invalid match data for monitoring")
            return 
        }
        
        print("🎮 Starting match monitoring for duel: \(duelId)")
        
        // Update state
        activeMatchNotifications[duelId] = MatchNotificationState(
            duelId: duelId,
            gameType: gameType,
            status: .inProgress,
            startTime: Date(),
            endTime: nil,
            lastPingTime: nil,
            pingCount: 0
        )
        
        // Start monitoring task
        let monitoringTask = Task {
            await monitorMatchProgress(duelId: duelId, challengerId: challengerId, opponentId: opponentId)
        }
        
        matchMonitoringTasks[duelId] = monitoringTask
        
        // Send match started notification only to the signed-in user on this device
        guard let me = AuthService.shared.currentUser?.id else { return }
        await sendMatchStartedNotification(to: me, duelId: duelId, gameType: gameType)
    }
    
    private func stopMatchMonitoring(duelId: String) async {
        print("⏹️ Stopping match monitoring for duel: \(duelId)")
        
        // Cancel monitoring task
        matchMonitoringTasks[duelId]?.cancel()
        matchMonitoringTasks.removeValue(forKey: duelId)
        
        // Invalidate timer
        matchEndTimers[duelId]?.invalidate()
        matchEndTimers.removeValue(forKey: duelId)
        
        // Cancel any pending verification reminder task
        verificationReminderTasks[duelId]?.cancel()
        verificationReminderTasks.removeValue(forKey: duelId)
        
        // Update state
        activeMatchNotifications.removeValue(forKey: duelId)
    }
    
    private func handleMatchEnded(duelId: String, record: [String: Any]) async {
        guard let challengerId = record["challenger_id"] as? String,
              let opponentId = record["opponent_id"] as? String else { 
            print("⚠️ Invalid match end data")
            return 
        }
        
        print("🏁 Match ended for duel: \(duelId)")
        
        // Send "Match Ended?" notification only to the signed-in user on this device
        guard let me = AuthService.shared.currentUser?.id else { return }
        await sendMatchEndedNotification(to: me, duelId: duelId)
        
        // Start verification timer
        startVerificationTimer(for: duelId)
        
        // Update state
        if var state = activeMatchNotifications[duelId] {
            state.status = .ended
            state.endTime = Date()
            activeMatchNotifications[duelId] = state
        }
    }
    
    // MARK: - Match Progress Monitoring
    private func monitorMatchProgress(duelId: String, challengerId: String, opponentId: String) async {
        let pingInterval: TimeInterval = 30 // Ping every 30 seconds
        let maxPingDuration: TimeInterval = 300 // Max 5 minutes of pinging
        
        guard let me = AuthService.shared.currentUser?.id else { return }

        var pingCount = 0
        let maxPings = Int(maxPingDuration / pingInterval)
        
        while pingCount < maxPings {
            do {
                try await Task.sleep(nanoseconds: UInt64(pingInterval * 1_000_000_000))
                
                // Check if match is still active
                guard let state = activeMatchNotifications[duelId],
                      state.status == .inProgress else {
                    print("🛑 Match monitoring stopped for duel: \(duelId)")
                    break
                }
                
                pingCount += 1
                
                // Send periodic "Match in Progress" ping only to the signed-in user on this device
                await sendMatchProgressPing(
                    to: me,
                    duelId: duelId,
                    pingNumber: pingCount
                )
                
                // Update last ping time
                if var updatedState = activeMatchNotifications[duelId] {
                    updatedState.lastPingTime = Date()
                    updatedState.pingCount = pingCount
                    activeMatchNotifications[duelId] = updatedState
                }
                
            } catch {
                print("❌ Error in match monitoring: \(error)")
                break
            }
        }
        
        // If we reach max pings, send a final reminder
        if pingCount >= maxPings {
            await sendMatchTimeoutWarning(to: me, duelId: duelId)
        }
    }
    
    // MARK: - Verification Timer
    private func startVerificationTimer(for duelId: String) {
        let verificationDuration: TimeInterval = 180 // 3 minutes
        
        let timer = Timer.scheduledTimer(withTimeInterval: verificationDuration, repeats: false) { [weak self] _ in
            Task { @MainActor in
                await self?.handleVerificationTimeout(duelId: duelId)
            }
        }
        
        matchEndTimers[duelId] = timer
        
        // Send reminder at 60 seconds using a cancellable Task
        // Cancel any existing reminder for this duel before scheduling a new one
        verificationReminderTasks[duelId]?.cancel()
        let reminderTask = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: UInt64(60 * 1_000_000_000))
                // Only send reminder if duel is still marked ended
                if let state = self.activeMatchNotifications[duelId], state.status == .ended {
                    await self.sendVerificationReminder(duelId: duelId)
                }
            } catch {
                // Task was cancelled or failed; ignore silently
                print("ℹ️ Verification reminder task cancelled/failed for duel: \(duelId) - \(error)")
            }
        }
        verificationReminderTasks[duelId] = reminderTask
    }
    
    private func handleVerificationTimeout(duelId: String) async {
        print("⏰ Verification timeout for duel: \(duelId)")
        
        // Check if both submissions received
        do {
            guard let client = supabaseService.getClient() else { return }
            let submissions: [DuelSubmission] = try await client
                .from("duel_submissions")
                .select()
                .eq("duel_id", value: duelId)
                .execute()
                .value
            if submissions.count < 2 {
                await markDuelAsForfeited(duelId)
            }
        } catch {
            print("❌ Error checking submissions: \(error)")
        }
        
        // Clean up
        matchEndTimers.removeValue(forKey: duelId)
    }
    
    // MARK: - Notification Delivery Queue
    private func startNotificationDeliveryQueue() {
        Task {
            while true {
                await processNotificationQueue()
                try await Task.sleep(nanoseconds: 5_000_000_000) // 5 seconds
            }
        }
    }
    
    // MARK: - Test Helpers
    func scheduleTestNotificationIn(seconds: TimeInterval = 5) async {
        let notification = PendingNotification(
            userId: AuthService.shared.currentUser?.id ?? "test-user",
            type: .achievement,
            title: "Test Notification",
            body: "This is a test notification.",
            data: NotificationData(action: "test"),
            expiresAt: Date().addingTimeInterval(3600)
        )
        await queueNotification(notification)
    }
    
    private func processNotificationQueue() async {
        guard !notificationDeliveryQueue.isEmpty else { return }
        
        let notifications = notificationDeliveryQueue
        notificationDeliveryQueue.removeAll()
        
        for notification in notifications {
            await deliverNotification(notification)
        }
    }
    
    private func deliverNotification(_ notification: PendingNotification) async {
        // Decide whether to persist remotely. Policy:
        // - If `persistRemotely` is explicitly set, obey it.
        // - If `persistRemotely` is nil, persist only when the notification is not targeted
        //   at the signed-in user on this device (i.e., cross-device sync only).
        let shouldPersistRemotely: Bool
        if let explicit = notification.persistRemotely {
            shouldPersistRemotely = explicit
        } else {
            shouldPersistRemotely = notification.userId != AuthService.shared.currentUser?.id
        }

        if shouldPersistRemotely {
            // Save to database for cross-device sync
            do {
                try await supabaseService.insert(into: "notifications", values: notification)
                print("✅ Notification saved to database: \(notification.id)")
            } catch {
                print("❌ Error saving notification: \(error)")
                // Re-queue for retry
                notificationDeliveryQueue.append(notification)
                return
            }
        } else {
            print("ℹ️ Skipping remote persistence for device-local notification: \(notification.id)")
        }
        
        // Send local push notification
        await scheduleNotification(notification)
    }
    
    private func scheduleNotification(_ notification: PendingNotification) async {
        guard isAuthorized else {
            print("⚠️ Notifications not authorized")
            return
        }

        // Only schedule local notifications for the signed-in user on this device
        guard notification.userId == AuthService.shared.currentUser?.id else {
            // Notification persisted remotely for cross-device sync; skip local scheduling here
            print("ℹ️ Skipping local schedule for cross-user notification: \(notification.id)")
            return
        }
        
        let content = UNMutableNotificationContent()
        content.title = notification.title
        content.body = notification.body
        content.sound = .default
        content.userInfo = notification.data.toDictionary()
        
        // Add category for actionable notifications
        content.categoryIdentifier = notification.type.categoryIdentifier
        
        let timeInterval = notification.scheduledFor.timeIntervalSinceNow
        let trigger = UNTimeIntervalNotificationTrigger(
            timeInterval: max(timeInterval, 1),
            repeats: false
        )
        
        let request = UNNotificationRequest(
            identifier: notification.id,
            content: content,
            trigger: trigger
        )
        
        do {
            try await UNUserNotificationCenter.current().add(request)
            print("✅ Notification scheduled: \(notification.id)")
        } catch {
            print("❌ Error scheduling notification: \(error)")
        }
    }
    
    // MARK: - Duel Challenge Notifications
    func sendDuelChallengeNotification(
        to userId: String,
        from challengerId: String,
        gameType: String,
        gameMode: String,
        duelId: String
    ) async {
        
        // Get challenger info
        guard let challenger = try? await getUserInfo(userId: challengerId) else { 
            print("⚠️ Could not get challenger info")
            return 
        }
        
        let notification = PendingNotification(
            userId: userId,
            type: .duelChallenge,
            title: "🎮 Duel Challenge!",
            body: "\(challenger.username ?? "A player") challenges you to \(gameType) - \(gameMode)",
            data: NotificationData(
                duelId: duelId,
                challengerId: challengerId,
                gameType: gameType,
                gameMode: gameMode
            ),
            expiresAt: Date().addingTimeInterval(24 * 60 * 60),
            priority: 1
        )
        
        await queueNotification(notification)
    }
    
    func sendDuelAcceptedNotification(
        to userId: String,
        from opponentId: String,
        gameType: String,
        gameMode: String
    ) async {
        
        guard let opponent = try? await getUserInfo(userId: opponentId) else { return }
        
        let notification = PendingNotification(
            userId: userId,
            type: .duelAccepted,
            title: "✅ Challenge Accepted!",
            body: "\(opponent.username ?? "Your opponent") accepted your \(gameType) challenge!",
            data: NotificationData(
                opponentId: opponentId,
                gameType: gameType,
                gameMode: gameMode
            ),
            expiresAt: Date().addingTimeInterval(60 * 60)
        )
        
        await queueNotification(notification)
    }
    
    func sendDuelDeclinedNotification(
        to userId: String,
        from opponentId: String,
        gameType: String,
        gameMode: String
    ) async {
        
        guard let opponent = try? await getUserInfo(userId: opponentId) else { return }
        
        let notification = PendingNotification(
            userId: userId,
            type: .duelDeclined,
            title: "❌ Challenge Declined",
            body: "\(opponent.username ?? "Your opponent") declined your \(gameType) challenge",
            data: NotificationData(
                opponentId: opponentId,
                gameType: gameType,
                gameMode: gameMode
            ),
            expiresAt: Date().addingTimeInterval(60 * 60)
        )
        
        await queueNotification(notification)
    }
    
    // MARK: - Match Notifications
    func sendMatchStartedNotification(
        to userId: String,
        duelId: String,
        gameType: String
    ) async {
        
        let notification = PendingNotification(
            userId: userId,
            type: .matchStarted,
            title: "🚀 Match Started!",
            body: "Your \(gameType) duel has begun. Good luck!",
            data: NotificationData(
                duelId: duelId,
                gameType: gameType,
                action: "start_match"
            ),
            expiresAt: Date().addingTimeInterval(30 * 60)
        )
        
        await queueNotification(notification)
    }
    
    func sendMatchProgressPing(
        to userId: String,
        duelId: String,
        pingNumber: Int
    ) async {
        
        let notification = PendingNotification(
            userId: userId,
            type: .matchProgress,
            title: "⚔️ Match in Progress",
            body: "Your duel is still active. Don't forget to submit your score!",
            data: NotificationData(
                duelId: duelId,
                action: "continue_match",
                pingNumber: pingNumber
            ),
            expiresAt: Date().addingTimeInterval(60),
            priority: 3
        )
        
        await queueNotification(notification)
    }
    
    func sendMatchEndedNotification(
        to userId: String,
        duelId: String
    ) async {
        
        let notification = PendingNotification(
            userId: userId,
            type: .matchEnded,
            title: "🏁 Match Ended!",
            body: "Submit your scoreboard screenshot within 180 seconds",
            data: NotificationData(
                duelId: duelId,
                action: "submit_screenshot"
            ),
            expiresAt: Date().addingTimeInterval(180), // 3 minutes
            priority: 1
        )
        
        await queueNotification(notification)
        
        // Schedule reminder notification
        let reminderNotification = PendingNotification(
            userId: userId,
            type: .verificationReminder,
            title: "⏰ Submission Reminder",
            body: "Only 60 seconds left to submit your screenshot!",
            data: NotificationData(
                duelId: duelId,
                action: "submit_screenshot"
            ),
            scheduledFor: Date().addingTimeInterval(120), // 2 minutes after match end
            expiresAt: Date().addingTimeInterval(180),
            priority: 1
        )
        
        await queueNotification(reminderNotification)
    }

    func sendMatchCompletedNotification(
        to userId: String,
        duelId: String
    ) async {
        let notification = PendingNotification(
            userId: userId,
            type: .matchEnded,
            title: "✅ Match Completed!",
            body: "The match has completed. View the results in the app.",
            data: NotificationData(
                duelId: duelId,
                action: "view_results"
            ),
            expiresAt: Date().addingTimeInterval(24 * 60 * 60),
            priority: 1
        )

        await queueNotification(notification)
    }
    
    func sendVerificationReminder(
        duelId: String
    ) async {
        
        // Get both players for the duel
        do {
            guard let client = supabaseService.getClient() else { return }
            let duels: [Duel] = try await client
                .from("duels")
                .select()
                .eq("id", value: duelId)
                .execute()
                .value
            guard let duel = duels.first else { return }

            // Only a single participant device should persist (publish) the reminders to avoid duplicates.
            // Choose a deterministic publisher by taking the lexicographically smaller user id.
            let publisherId = min(duel.challengerId, duel.opponentId)
            guard AuthService.shared.currentUser?.id == publisherId else {
                // Another device will publish the reminders; skip on this device.
                return
            }

            // Publisher persists reminders for both players
            await sendVerificationReminderNotification(to: duel.challengerId, duelId: duelId)
            await sendVerificationReminderNotification(to: duel.opponentId, duelId: duelId)
            
        } catch {
            print("❌ Error sending verification reminder: \(error)")
        }
    }
    
    private func sendVerificationReminderNotification(
        to userId: String,
        duelId: String
    ) async {
        
        let notification = PendingNotification(
            userId: userId,
            type: .verificationReminder,
            title: "⏰ Submission Reminder",
            body: "Only 60 seconds left to submit your screenshot!",
            data: NotificationData(
                duelId: duelId,
                action: "submit_screenshot"
            ),
            expiresAt: Date().addingTimeInterval(120),
            priority: 1
        )
        
        await queueNotification(notification)
    }
    
    func sendMatchTimeoutWarning(
        to userId: String,
        duelId: String
    ) async {
        
        let notification = PendingNotification(
            userId: userId,
            type: .matchTimeout,
            title: "⚠️ Match Timeout Warning",
            body: "Your match has been running for a while. Consider ending it soon.",
            data: NotificationData(
                duelId: duelId,
                action: "end_match"
            ),
            expiresAt: Date().addingTimeInterval(60 * 5),
            priority: 2
        )
        
        await queueNotification(notification)
    }
    
    func sendDuelForfeitNotification(
        to userId: String,
        duelId: String
    ) async {
        
        let notification = PendingNotification(
            userId: userId,
            type: .duelForfeited,
            title: "⚠️ Duel Forfeited",
            body: "The duel was forfeited due to missing score submission",
            data: NotificationData(duelId: duelId),
            expiresAt: Date().addingTimeInterval(60 * 60)
        )
        
        await queueNotification(notification)
    }
    
    func sendDuelExpiredNotification(
        to userId: String,
        duelId: String
    ) async {
        
        let notification = PendingNotification(
            userId: userId,
            type: .duelExpired,
            title: "⏰ Challenge Expired",
            body: "Your duel challenge has expired",
            data: NotificationData(duelId: duelId),
            expiresAt: Date().addingTimeInterval(60 * 60)
        )
        
        await queueNotification(notification)
    }
    
    // MARK: - Verification Notifications
    func sendVerificationSuccessNotification(
        to userId: String,
        duelId: String,
        isWinner: Bool
    ) async {
        
        let title = isWinner ? "🏆 Victory!" : "💪 Good Fight!"
        let body = isWinner ? "You won the duel! Check your victory recap." : "Better luck next time! Your stats have been updated."
        
        let notification = PendingNotification(
            userId: userId,
            type: .verificationSuccess,
            title: title,
            body: body,
            data: NotificationData(
                duelId: duelId,
                action: "view_recap",
                isWinner: isWinner
            ),
            expiresAt: Date().addingTimeInterval(24 * 60 * 60)
        )
        
        await queueNotification(notification)
    }
    
    func sendVerificationFailedNotification(
        to userId: String,
        duelId: String,
        reason: String
    ) async {
        
        let notification = PendingNotification(
            userId: userId,
            type: .verificationFailed,
            title: "❌ Verification Failed",
            body: "Score verification failed: \(reason)",
            data: NotificationData(
                duelId: duelId,
                action: "resubmit_or_dispute",
                reason: reason
            ),
            expiresAt: Date().addingTimeInterval(60 * 60)
        )
        
        await queueNotification(notification)
    }
    
    // MARK: - System Notifications
    func sendLevelUpNotification(to userId: String, newLevel: Int) async {
        let notification = PendingNotification(
            userId: userId,
            type: .levelUp,
            title: "🎉 Level Up!",
            body: "Congratulations! You've reached level \(newLevel)!",
            data: NotificationData(
                action: "view_profile",
                newLevel: newLevel
            ),
            expiresAt: Date().addingTimeInterval(24 * 60 * 60)
        )
        
        await queueNotification(notification)
    }
    
    func sendDisputeNotification(duelId: String, reason: String) async {
        // Send to moderator queue
        let notification = PendingNotification(
            userId: "moderator_queue",
            type: .dispute,
            title: "🚨 Duel Dispute",
            body: "A duel requires moderator review: \(reason)",
            data: NotificationData(
                duelId: duelId,
                action: "moderate_dispute",
                reason: reason
            ),
            expiresAt: Date().addingTimeInterval(7 * 24 * 60 * 60), // 7 days
            priority: 1
        )
        
        await queueNotification(notification)
    }
    
    // MARK: - Helper Methods
    private func queueNotification(_ notification: PendingNotification) async {
        notificationDeliveryQueue.append(notification)
        print("📬 Notification queued: \(notification.type.rawValue) for user \(notification.userId)")
    }
    
    private func getUserInfo(userId: String) async throws -> User {
        guard let client = supabaseService.getClient() else { throw NotificationError.userNotFound }
        let users: [User] = try await client
            .from("profiles")
            .select()
            .eq("id", value: userId)
            .execute()
            .value
        guard let user = users.first else {
            throw NotificationError.userNotFound
        }
        return user
    }
    
    private func markDuelAsForfeited(_ duelId: String) async {
        do {
            let updateData: [String: AnyJSON] = [
                "verification_status": AnyJSON.string("forfeited"),
                "status": AnyJSON.string("completed")
            ]
            
            guard let client = supabaseService.getClient() else { return }
            try await client
                .from("duels")
                .update(updateData)
                .eq("id", value: duelId)
                .execute()
            
            // Send forfeit notifications for this duel only
            let duels: [Duel] = try await client
                .from("duels")
                .select()
                .eq("id", value: duelId)
                .execute()
                .value
            if let duel = duels.first {
                await sendDuelForfeitNotification(to: duel.challengerId, duelId: duelId)
                await sendDuelForfeitNotification(to: duel.opponentId, duelId: duelId)
            }
            
        } catch {
            print("❌ Error marking duel as forfeited: \(error)")
        }
    }

    // Helper to coerce various payload record shapes into [String: Any]
    private static func coerceRecord(_ raw: Any?) -> [String: Any]? {
        // Recursive helper to convert AnyJSON / nested containers into Foundation types
        func convertValue(_ value: Any) -> Any {
            // Unwrap AnyJSON wrappers
            if let anyJson = value as? AnyJSON {
                return convertValue(anyJson.rawValue)
            }

            // Dictionary with AnyJSON values
            if let dictAnyJSON = value as? [String: AnyJSON] {
                var out: [String: Any] = [:]
                for (k, v) in dictAnyJSON {
                    out[k] = convertValue(v)
                }
                return out
            }

            // Dictionary with Any values (may contain nested AnyJSON)
            if let dictAny = value as? [String: Any] {
                var out: [String: Any] = [:]
                for (k, v) in dictAny {
                    out[k] = convertValue(v)
                }
                return out
            }

            // Array of AnyJSON
            if let arrAnyJSON = value as? [AnyJSON] {
                return arrAnyJSON.map { convertValue($0) }
            }

            // Array of Any (may contain nested AnyJSON)
            if let arrAny = value as? [Any] {
                return arrAny.map { convertValue($0) }
            }

            // Fallback: return the value as-is
            return value
        }

        if let r = raw as? [String: Any] {
            return r
        }

        if let r = raw as? [String: AnyJSON] {
            var out: [String: Any] = [:]
            for (k, v) in r {
                out[k] = convertValue(v)
            }
            return out
        }

        return nil
    }
}



// MARK: - Notification Categories Setup
extension NotificationService {
    func setupNotificationCategories() {
        let center = UNUserNotificationCenter.current()
        
        // Duel Challenge Category
        let acceptAction = UNNotificationAction(
            identifier: "ACCEPT_DUEL",
            title: "Accept",
            options: [.foreground]
        )
        let declineAction = UNNotificationAction(
            identifier: "DECLINE_DUEL",
            title: "Decline",
            options: []
        )
        let duelChallengeCategory = UNNotificationCategory(
            identifier: "DUEL_CHALLENGE_CATEGORY",
            actions: [acceptAction, declineAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Match Ended Category
        let submitAction = UNNotificationAction(
            identifier: "SUBMIT_SCREENSHOT",
            title: "Submit Screenshot",
            options: [.foreground]
        )
        let matchEndedCategory = UNNotificationCategory(
            identifier: "MATCH_ENDED_CATEGORY",
            actions: [submitAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Verification Reminder Category
        let submitReminderAction = UNNotificationAction(
            identifier: "SUBMIT_SCREENSHOT_REMINDER",
            title: "Submit Now",
            options: [.foreground]
        )
        let verificationReminderCategory = UNNotificationCategory(
            identifier: "VERIFICATION_REMINDER_CATEGORY",
            actions: [submitReminderAction],
            intentIdentifiers: [],
            options: []
        )
        
        // Dispute Category
        let reviewAction = UNNotificationAction(
            identifier: "REVIEW_DISPUTE",
            title: "Review",
            options: [.foreground]
        )
        let disputeCategory = UNNotificationCategory(
            identifier: "DISPUTE_CATEGORY",
            actions: [reviewAction],
            intentIdentifiers: [],
            options: []
        )
        
        center.setNotificationCategories([
            duelChallengeCategory,
            matchEndedCategory,
            verificationReminderCategory,
            disputeCategory
        ])
    }
    
    func handleNotificationAction(
        identifier: String,
        notification: UNNotification,
        completionHandler: @escaping () -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        
        switch identifier {
        case "ACCEPT_DUEL":
            if let duelId = userInfo["duel_id"] as? String {
                Task {
                    try? await DuelService.shared.acceptDuel(duelId, by: AuthService.shared.currentUser?.id ?? "")
                    completionHandler()
                }
            }
            
        case "DECLINE_DUEL":
            if let duelId = userInfo["duel_id"] as? String {
                Task {
                    try? await DuelService.shared.declineDuel(duelId, by: AuthService.shared.currentUser?.id ?? "")
                    completionHandler()
                }
            }
            
        case "SUBMIT_SCREENSHOT", "SUBMIT_SCREENSHOT_REMINDER":
            if let duelId = userInfo["duel_id"] as? String {
                // Navigate to screenshot submission
                NavigationManager.shared.navigateToScreenshotSubmission(duelId: duelId)
                completionHandler()
            }
            
        case "REVIEW_DISPUTE":
            if let duelId = userInfo["duel_id"] as? String {
                // Navigate to dispute review
                NavigationManager.shared.navigateToDisputeReview(duelId: duelId)
                completionHandler()
            }
            
        default:
            completionHandler()
        }
    }
}

// MARK: - Notification Errors
enum NotificationError: Error, LocalizedError {
    case authorizationDenied
    case userNotFound
    case notificationFailed
    case invalidNotificationData
    
    var errorDescription: String? {
        switch self {
        case .authorizationDenied:
            return "Notification authorization denied"
        case .userNotFound:
            return "User not found for notification"
        case .notificationFailed:
            return "Failed to send notification"
        case .invalidNotificationData:
            return "Invalid notification data"
        }
    }
}
