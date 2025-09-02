import SwiftUI

struct EventCheckInView: View {
    let event: Event

    @StateObject private var eventService = EventService.shared
    @StateObject private var nfcService = NFCService()
    @ObservedObject private var qrService = QRCodeService.shared
    
    @State private var attendeeCount: Int = 0
    @State private var isLoading = false
    @State private var showErrorAlert = false
    @State private var isPresentingQRScanner = false
    @State private var scannedCode: String? = nil
    @State private var navigateToMatchmaking = false
    @EnvironmentObject var preferences: PreferencesService
    
    private var currentError: String? {
        eventService.errorMessage ?? nfcService.errorMessage ?? qrService.errorMessage
    }
    
    var body: some View {
        // Guard UI with events feature toggle
        Group {
            if !preferences.eventsEnabled {
                VStack(spacing: 12) {
                    Text("Event features are disabled. Enable them in your Profile to use check-ins and matchmaking.")
                        .multilineTextAlignment(.center)
                        .padding()
                    NavigationLink(destination: ProfileView()) {
                        Text("Open Profile")
                    }
                }
            } else {
                VStack(alignment: .leading, spacing: 16) {
                    header
                    stats
                    buttons
                    if let image = qrService.generatedQRImage {
                        Image(uiImage: image)
                            .resizable()
                            .interpolation(.none)
                            .scaledToFit()
                            .frame(maxWidth: 240)
                            .padding(.top, 8)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .navigationTitle("Check In")
        .task { await refreshAttendance() }
        .onChange(of: eventService.errorMessage) { _ in showErrorAlert = currentError != nil }
        .onChange(of: nfcService.errorMessage) { _ in showErrorAlert = currentError != nil }
        .onChange(of: qrService.errorMessage) { _ in showErrorAlert = currentError != nil }
        .onChange(of: eventService.lastCheckInEventId) { id in
            guard let id = id, id == event.id else { return }
            Task { await refreshAttendance() }
            navigateToMatchmaking = true
            eventService.lastCheckInEventId = nil
        }
        .onReceive(eventService.$attendeeCounts) { map in
            if let c = map[event.id] {
                attendeeCount = c
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("EventCheckInSucceeded"))) { notification in
            if let info = notification.userInfo as? [String: Any], let id = info["eventId"] as? String, id == event.id {
                Task { await refreshAttendance() }
                navigateToMatchmaking = true
            }
        }
        .alert("Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) { clearErrors() }
        } message: {
            Text(currentError ?? "")
        }
    }
    
    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(event.name).font(.title2).fontWeight(.semibold)
            if let venue = event.venue, !venue.isEmpty {
                Text(venue).font(.subheadline).foregroundColor(.secondary)
            }
            Text(event.isActive ? "Active now" : "Not active")
                .font(.caption)
                .foregroundColor(event.isActive ? .green : .secondary)
        }
    }
    
    private var stats: some View {
        HStack(spacing: 16) {
            Label("Attendees: \(attendeeCount)", systemImage: "person.3")
            if let max = event.maxAttendees {
                Label("Capacity: \(max)", systemImage: "person.3.sequence")
            }
        }
        .font(.subheadline)
        .foregroundColor(.secondary)
    }
    
    private var buttons: some View {
        VStack(spacing: 12) {
            Button {
                nfcService.scanContext = .eventCheckIn(eventId: event.id)
                nfcService.startScanning()
            } label: {
                Label("Check-in via NFC", systemImage: "wave.3.right")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(!event.isActive)
            
            Button {
                qrService.generateEventCheckInQR(eventId: event.id)
            } label: {
                Label("Show Event QR", systemImage: "qrcode")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!event.isActive)
            
            Button {
                isPresentingQRScanner = true
            } label: {
                Label("Check-in via QR", systemImage: "qrcode.viewfinder")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(!event.isActive)
            .sheet(isPresented: $isPresentingQRScanner) {
                QRCodeScannerView(scannedCode: $scannedCode, isScanning: $isPresentingQRScanner)
                    .onChange(of: scannedCode) { newValue in
                        guard let code = newValue, !code.isEmpty else { return }
                        QRCodeService.shared.processScannedCode(code)
                    }
            }

            NavigationLink {
                MatchmakingView(event: event)
            } label: {
                Label("Find Matches", systemImage: "person.2.wave.2")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Button {
                Task {
                    isLoading = true
                    let ok = await eventService.checkInToEvent(eventId: event.id, method: .manual)
                    if ok {
                        await refreshAttendance()
                        navigateToMatchmaking = true
                    }
                    isLoading = false
                }
            } label: {
                Label("Check-in Now", systemImage: "checkmark.circle")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)
            .disabled(isLoading || !event.isActive)
            
            NavigationLink(isActive: $navigateToMatchmaking) {
                MatchmakingView(event: event)
            } label: { EmptyView() }
        }
    }
    
    private func refreshAttendance() async {
        let count = await eventService.fetchEventAttendeeCount(eventId: event.id)
        attendeeCount = count
    }
    
    private func clearErrors() {
        eventService.errorMessage = nil
        nfcService.errorMessage = nil
        qrService.errorMessage = nil
    }
}


struct EventCheckInView_Previews: PreviewProvider {
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
        NavigationView { EventCheckInView(event: sample) }
            .environmentObject(PreferencesService.shared)
    }
}

