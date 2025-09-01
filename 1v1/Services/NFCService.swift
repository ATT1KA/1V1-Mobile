import Foundation
@preconcurrency import CoreNFC
import Supabase

@MainActor
@preconcurrency
class NFCService: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var lastScannedProfile: UserProfile?
    @Published var errorMessage: String?
    var scanContext: ScanContext?
    private var ndefMessageToWrite: NFCNDEFMessage?
    
    private var nfcSession: NFCNDEFReaderSession?
    private var profileToWrite: UserProfile?
    private let supabaseService = SupabaseService.shared
    
    override init() {
        super.init()
    }
    
    deinit {
        Task { @MainActor in
            stopScanning()
        }
    }
    
    // MARK: - Enhanced Error Handling
    private func getUserFriendlyErrorMessage(_ error: Error) -> String {
        if let nfcError = error as? NFCReaderError {
            switch nfcError.code {
            case .readerSessionInvalidationErrorUserCanceled:
                return "NFC scanning cancelled"
            case .readerSessionInvalidationErrorSessionTerminatedUnexpectedly:
                return "NFC session ended unexpectedly"
            case .readerSessionInvalidationErrorSessionTimeout:
                return "NFC session timed out"
            default:
                return "NFC error: \(nfcError.localizedDescription)"
            }
        }
        return "NFC error: \(error.localizedDescription)"
    }
    
    // MARK: - NFC Reading
    func startScanning() {
        guard NFCNDEFReaderSession.readingAvailable else {
            errorMessage = "NFC is not available on this device"
            return
        }
        
        isScanning = true
        errorMessage = nil
        
        nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        if let context = scanContext {
            nfcSession?.alertMessage = context.instructions
        } else {
            nfcSession?.alertMessage = "Hold your device near an NFC tag to scan a profile"
        }
        nfcSession?.begin()
    }
    
    func stopScanning() {
        nfcSession?.invalidate()
        nfcSession = nil
        isScanning = false
        profileToWrite = nil
    }
    
    // MARK: - NFC Writing
    func writeProfileToTag(_ profile: UserProfile) async {
        guard NFCNDEFReaderSession.readingAvailable else {
            errorMessage = "NFC is not available on this device"
            return
        }
        
        isScanning = true
        errorMessage = nil
        self.profileToWrite = profile
        
        nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        nfcSession?.alertMessage = "Hold your device near an NFC tag to write your profile"
        nfcSession?.begin()
    }
    func writeEventCheckInToTag(eventId: String) async {
        guard NFCNDEFReaderSession.readingAvailable else {
            errorMessage = "NFC is not available on this device"
            return
        }
        isScanning = true
        errorMessage = nil
        profileToWrite = nil
        scanContext = .eventCheckIn(eventId: eventId)
        
        // Prepare payload
        guard let payloadString = ScanContext.eventCheckIn(eventId: eventId).encodedPayloadString(),
              let payloadData = payloadString.data(using: .utf8) else {
            errorMessage = "Failed to encode NFC payload"
            return
        }
        let record = NFCNDEFPayload(
            format: .media,
            type: Constants.Events.nfcPayloadPrefix.data(using: .utf8)!,
            identifier: Data(),
            payload: payloadData
        )
        ndefMessageToWrite = NFCNDEFMessage(records: [record])
        
        nfcSession = NFCNDEFReaderSession(delegate: self, queue: nil, invalidateAfterFirstRead: false)
        nfcSession?.alertMessage = scanContext?.instructions ?? "Hold your device near an NFC tag"
        nfcSession?.begin()
    }
    
    // MARK: - Profile Sharing
    func shareProfile(_ profile: UserProfile) async {
        // Build envelope and Supabase client
        guard let envelope = ScanContext.profileSharing(profile).encodedPayloadString() else { return }
        guard let client = supabaseService.getClient() else { return }

        // Convert UserProfile to a native JSON object for `profile_data`
        var rawProfileJSON: Any = ["id": profile.userId]
        if let encodedProfile = try? JSONEncoder().encode(profile),
           let jsonObject = try? JSONSerialization.jsonObject(with: encodedProfile, options: []) as? [String: Any] {
            rawProfileJSON = jsonObject
        } else {
            print("Warning: failed to encode UserProfile to JSON; storing minimal profile info")
        }

        // Convert envelope to JSON if possible so `profile_data_envelope` is stored as native JSON
        var envelopeJSON: Any = envelope
        if let data = envelope.data(using: .utf8),
           let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            envelopeJSON = jsonObject
        }

        // Primary insert: store raw profile JSON in `profile_data` and include `profile_data_envelope` as a separate column
        var insertData: [String: Any] = [
            "user_id": profile.userId,
            "shared_at": ISO8601DateFormatter().string(from: Date()),
            "share_method": "nfc",
            "profile_data": rawProfileJSON,
            "profile_data_envelope": envelopeJSON
        ]

        do {
            let response = try await client
                .from("profile_shares")
                .insert(insertData)
                .execute()
            print("Profile share logged: \(response)")
            return
        } catch {
            // If the DB doesn't have `profile_data_envelope`, retry by nesting the envelope under `_envelope` inside `profile_data`.
            print("Insert with profile_data_envelope failed, retrying by nesting envelope: \(error)")

            var nestedProfileData: Any = rawProfileJSON
            if var dict = rawProfileJSON as? [String: Any] {
                dict["_envelope"] = envelopeJSON
                nestedProfileData = dict
            } else {
                nestedProfileData = ["_raw": rawProfileJSON, "_envelope": envelopeJSON]
            }

            let fallbackInsert: [String: Any] = [
                "user_id": profile.userId,
                "shared_at": ISO8601DateFormatter().string(from: Date()),
                "share_method": "nfc",
                "profile_data": nestedProfileData
            ]

            do {
                let fallbackResponse = try await client
                    .from("profile_shares")
                    .insert(fallbackInsert)
                    .execute()
                print("Profile share logged (fallback): \(fallbackResponse)")
            } catch {
                print("Fallback insert failed: \(error)")
            }
        }
    }
    
    // MARK: - Profile Parsing
    enum ParseResult {
        case profile(UserProfile)
        case event(String)
    }

    private func parseFromNDEFMessage(_ message: NFCNDEFMessage) -> ParseResult? {
        for record in message.records {
            guard let payload = String(data: record.payload, encoding: .utf8) else { continue }

            // 1) Try to parse as JSON profile data
            if let data = payload.data(using: .utf8),
               let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
                return .profile(profile)
            }

            // 2) Try to parse via ScanContext for event check-in
            if let context = ScanContext.fromPayloadString(payload) {
                switch context {
                case .eventCheckIn(let eventId):
                    return .event(eventId)
                case .profileSharing(let profile):
                    return .profile(profile)
                }
            }

            // 3) Try to parse as URL scheme
            if let url = URL(string: payload), url.scheme == "1v1mobile" {
                if url.host == "profile", let profileId = url.pathComponents.last {
                    Task { await fetchProfileFromId(profileId) }
                    continue
                }
                if url.host == "event", let eventId = url.pathComponents.last {
                    return .event(eventId)
                }
            }
        }
        return nil
    }
    
    private func fetchProfileFromId(_ profileId: String) async {
        do {
            let response = try await supabaseService.getClient()?
                .from("profiles")
                .select("*")
                .eq("id", value: profileId)
                .single()
                .execute()
            
            if let data = response?.data,
               let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
                await MainActor.run {
                    self.lastScannedProfile = profile
                }
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to fetch profile: \(error.localizedDescription)"
            }
        }
    }
    
    private func createNDEFMessage(for profile: UserProfile) -> NFCNDEFMessage? {
        do {
            // Use the ScanContext envelope for the profile payload so scanners can detect `scanType` first
            guard let envelope = ScanContext.profileSharing(profile).encodedPayloadString() else { return nil }
            let profileString = envelope
            
            // Validate data size for NFC tag
            if profileString.count > 1000 {
                print("Warning: Profile data may be too large for some NFC tags")
            }
            
            let record = NFCNDEFPayload(
                format: .media,
                type: Constants.Events.profileNfcPayloadPrefix.data(using: .utf8) ?? Data(),
                identifier: Data(),
                payload: profileString.data(using: .utf8)!
            )
            
            return NFCNDEFMessage(records: [record])
        } catch {
            print("Error creating NDEF message: \(error)")
            return nil
        }
    }
}

// MARK: - NFCNDEFReaderSessionDelegate
extension NFCService: NFCNDEFReaderSessionDelegate {
    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didInvalidateWithError error: Error) {
        DispatchQueue.main.async {
            self.isScanning = false
            
            if let readerError = error as? NFCReaderError {
                switch readerError.code {
                case .readerSessionInvalidationErrorUserCanceled:
                    // User cancelled
                    break
                default:
                    self.errorMessage = "NFC Error: \(readerError.localizedDescription)"
                }
            }
        }
    }
    
    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetectNDEFs messages: [NFCNDEFMessage]) {
        guard let message = messages.first else { return }

        DispatchQueue.main.async {
            if let result = self.parseFromNDEFMessage(message) {
                switch result {
                case .profile(let profile):
                    self.lastScannedProfile = profile
                    Task {
                        await self.shareProfile(profile)
                    }
                    session.alertMessage = "Profile scanned successfully!"
                case .event(let eventId):
                    Task { @MainActor in
                        let ok = await EventService.shared.checkInToEvent(eventId: eventId, method: .nfc)
                        if ok {
                            self.errorMessage = nil
                            session.alertMessage = ScanContext.eventCheckIn(eventId: eventId).successMessage
                            NotificationCenter.default.post(name: Notification.Name("EventCheckInSucceeded"), object: nil, userInfo: ["eventId": eventId])
                        }
                    }
                }
            } else {
                self.errorMessage = "Invalid profile data on NFC tag"
            }

            session.invalidate()
        }
    }
    
    nonisolated func readerSession(_ session: NFCNDEFReaderSession, didDetect tags: [NFCNDEFTag]) {
        guard let tag = tags.first else { return }
        
        session.connect(to: tag) { error in
            if let error = error {
                DispatchQueue.main.async {
                    self.errorMessage = "Failed to connect to NFC tag: \(self.getUserFriendlyErrorMessage(error))"
                }
                session.invalidate()
                return
            }
            
            // Check if tag is writable
            tag.queryNDEFStatus { status, capacity, error in
                if let error = error {
                    DispatchQueue.main.async {
                        self.errorMessage = "Failed to query NFC tag: \(self.getUserFriendlyErrorMessage(error))"
                    }
                    session.invalidate()
                    return
                }
                
                // Check if we're writing or reading
                if let profileToWrite = self.profileToWrite {
                    // Writing mode
                    guard let ndefMessage = self.createNDEFMessage(for: profileToWrite) else {
                        DispatchQueue.main.async {
                            self.errorMessage = "Failed to create profile data"
                        }
                        session.invalidate()
                        return
                    }
                    
                    // Check if tag has enough capacity
                    if ndefMessage.length > capacity {
                        DispatchQueue.main.async {
                            self.errorMessage = "NFC tag doesn't have enough capacity for profile data"
                        }
                        session.invalidate()
                        return
                    }
                    
                    tag.writeNDEF(ndefMessage) { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                self.errorMessage = "Failed to write to NFC tag: \(self.getUserFriendlyErrorMessage(error))"
                            } else {
                                self.errorMessage = nil
                                session.alertMessage = "Profile written successfully!"
                            }
                        }
                        session.invalidate()
                    }
                } else if let messageToWrite = self.ndefMessageToWrite {
                    // Writing custom event payload
                    if messageToWrite.length > capacity {
                        DispatchQueue.main.async {
                            self.errorMessage = "NFC tag doesn't have enough capacity for event data"
                        }
                        session.invalidate()
                        return
                    }
                    tag.writeNDEF(messageToWrite) { error in
                        DispatchQueue.main.async {
                            if let error = error {
                                self.errorMessage = "Failed to write to NFC tag: \(self.getUserFriendlyErrorMessage(error))"
                            } else {
                                self.errorMessage = nil
                                session.alertMessage = "Event check-in tag written successfully!"
                            }
                            self.ndefMessageToWrite = nil
                        }
                        session.invalidate()
                    }
                } else {
                    // Reading mode
                    tag.readNDEF { message, error in
                        if let error = error {
                            DispatchQueue.main.async {
                                self.errorMessage = "Failed to read NFC tag: \(self.getUserFriendlyErrorMessage(error))"
                            }
                            session.invalidate()
                            return
                        }

                        if let message = message {
                            DispatchQueue.main.async {
                                if let result = self.parseFromNDEFMessage(message) {
                                    switch result {
                                    case .profile(let profile):
                                        self.lastScannedProfile = profile
                                        Task {
                                            await self.shareProfile(profile)
                                        }
                                        session.alertMessage = ScanContext.profileSharing(profile).successMessage
                                    case .event(let eventId):
                                        Task { @MainActor in
                                            let ok = await EventService.shared.checkInToEvent(eventId: eventId, method: .nfc)
                                            if ok {
                                                self.errorMessage = nil
                                                session.alertMessage = ScanContext.eventCheckIn(eventId: eventId).successMessage
                                            }
                                        }
                                    }
                                } else {
                                    self.errorMessage = "Invalid profile data on NFC tag"
                                }
                            }
                        }

                        session.invalidate()
                    }
                }
            }
        }
        
        // Clear profile to write after operation
        Task { @MainActor in
            self.profileToWrite = nil
            self.ndefMessageToWrite = nil
        }
    }
}

// MARK: - Event NFC Writing
