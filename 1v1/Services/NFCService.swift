import Foundation
@preconcurrency import CoreNFC
import Supabase

@MainActor
@preconcurrency
class NFCService: NSObject, ObservableObject {
    @Published var isScanning = false
    @Published var lastScannedProfile: UserProfile?
    @Published var errorMessage: String?
    
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
            case .readerSessionInvalidationErrorFirstNDEFTagRead:
                return "NFC tag read successfully"
                            case .readerSessionInvalidationErrorUserCanceled:
                return "NFC scanning cancelled"
            case .readerSessionInvalidationErrorUserCanceled:
                return "NFC scanning cancelled by user"
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
        nfcSession?.alertMessage = "Hold your device near an NFC tag to scan a profile"
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
    
    // MARK: - Profile Sharing
    func shareProfile(_ profile: UserProfile) async {
        do {
            // Log the sharing event to Supabase
            _ = [
                "user_id": profile.userId,
                "shared_at": ISO8601DateFormatter().string(from: Date()),
                "share_method": "nfc",
                "profile_data": try JSONEncoder().encode(profile)
            ]
            
            guard let client = supabaseService.getClient() else { return }
            let response = try await client
                .from("profile_shares")
                .insert([
                    "user_id": profile.userId,
                    "shared_at": ISO8601DateFormatter().string(from: Date()),
                    "share_method": "nfc",
                    "profile_data": String(data: try JSONEncoder().encode(profile), encoding: .utf8) ?? ""
                ])
                .execute()
            
            print("Profile share logged: \(response)")
        } catch {
            print("Error logging profile share: \(error)")
        }
    }
    
    // MARK: - Profile Parsing
    private func parseProfileFromNDEFMessage(_ message: NFCNDEFMessage) -> UserProfile? {
        for record in message.records {
            guard record.typeNameFormat == .absoluteURI || record.typeNameFormat == .nfcWellKnown,
                  let payload = String(data: record.payload, encoding: .utf8) else {
                continue
            }
            
            // Try to parse as JSON profile data
            if let data = payload.data(using: .utf8),
               let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
                return profile
            }
            
            // Try to parse as URL with profile ID
            if let url = URL(string: payload),
               url.scheme == "1v1mobile",
               let profileId = url.host {
                // Fetch profile from Supabase using ID
                Task {
                    await fetchProfileFromId(profileId)
                }
                return nil
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
            let profileData = try JSONEncoder().encode(profile)
            let profileString = String(data: profileData, encoding: .utf8) ?? ""
            
            // Validate data size for NFC tag
            if profileString.count > 1000 {
                print("Warning: Profile data may be too large for some NFC tags")
            }
            
            let record = NFCNDEFPayload(
                format: .absoluteURI,
                type: "application/1v1mobile.profile".data(using: .utf8)!,
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
                case .readerSessionInvalidationErrorFirstNDEFTagRead:
                    // Successfully read a tag
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
            if let profile = self.parseProfileFromNDEFMessage(message) {
                self.lastScannedProfile = profile
                Task {
                    await self.shareProfile(profile)
                }
                session.alertMessage = "Profile scanned successfully!"
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
                                if let profile = self.parseProfileFromNDEFMessage(message) {
                                    self.lastScannedProfile = profile
                                    Task {
                                        await self.shareProfile(profile)
                                    }
                                    session.alertMessage = "Profile scanned successfully!"
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
        }
    }
}
