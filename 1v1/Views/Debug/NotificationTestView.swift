import SwiftUI

struct NotificationTestView: View {
    @EnvironmentObject var notificationService: NotificationService
    @EnvironmentObject var authService: AuthService
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            List {
                Section(header: Text("Manual Triggers")) {
                    Button("Quick Test (5s)") {
                        Task { @MainActor in
                            await notificationService.scheduleTestNotificationIn(seconds: 5)
                        }
                    }

                    Button("Trigger Match Start") {
                        Task { @MainActor in
                            await notificationService.sendMatchStartedNotification(
                                to: authService.currentUser?.id ?? "test-user",
                                duelId: "test-duel",
                                gameType: "Test Game"
                            )
                        }
                    }

                    Button("Trigger Match End") {
                        Task { @MainActor in
                            await notificationService.sendMatchEndedNotification(
                                to: authService.currentUser?.id ?? "test-user",
                                duelId: "test-duel"
                            )
                        }
                    }

                    Button("Trigger Verification Reminder") {
                        Task { @MainActor in
                            await notificationService.sendVerificationReminder(duelId: "test-duel")
                        }
                    }
                }

                Section(header: Text("Permissions & State")) {
                    Toggle(isOn: Binding(get: { notificationService.isAuthorized }, set: { new in
                        Task { @MainActor in
                            await notificationService.setAuthorizationStatus(new)
                        }
                    })) {
                        Text("Simulate Authorized")
                    }

                    HStack {
                        Text("Authorized")
                        Spacer()
                        Text(notificationService.isAuthorized ? "Yes" : "No")
                            .foregroundColor(notificationService.isAuthorized ? .green : .red)
                    }

                    Button("Request Authorization") {
                        Task { @MainActor in
                            _ = await notificationService.requestAuthorization()
                        }
                    }
                }

                Section(header: Text("Realtime & Debug")) {
                    Text("Active Matches: \(notificationService.activeMatchNotifications.count)")
                    Text("Pending Notifications: \(notificationService.pendingNotifications.count)")
                    Button("Simulate Connection Loss") {
                        Task { @MainActor in
                            await notificationService.simulateConnectionLoss()
                        }
                    }

                    Button("Reconnect") {
                        Task { @MainActor in
                            await notificationService.reconnectSupabase()
                        }
                    }

                    Button("Emit Remote Event") {
                        Task { @MainActor in
                            let record: [String: Any] = [
                                "id": "remote-\(UUID().uuidString)",
                                "challenger_id": AuthService.shared.currentUser?.id ?? "test-user",
                                "opponent_id": "other-user",
                                "status": "in_progress",
                                "game_type": "Debug Game",
                                "game_mode": "Casual"
                            ]
                            await notificationService.emitRemoteDuelInsert(record: record)
                        }
                    }

                    Button("Cross-Device Event") {
                        Task { @MainActor in
                            await notificationService.emitCrossDeviceEvent()
                        }
                    }

                    Section(header: Text("Event Log")) {
                        List(notificationService.debugLog, id: \.self) { entry in
                            Text(entry)
                                .font(.caption)
                                .lineLimit(2)
                        }
                    }
                }
            }
            .navigationTitle("Notification Tester")
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
        }
    }
}

struct NotificationTestView_Previews: PreviewProvider {
    static var previews: some View {
        NotificationTestView()
            .environmentObject(NotificationService.shared)
            .environmentObject(AuthService.shared)
    }
}


