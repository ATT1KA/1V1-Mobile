import Foundation

enum CheckInMethod: String, Codable, CaseIterable {
    case nfc = "nfc"
    case qrCode = "qr_code"
    case manual = "manual"
}

struct EventAttendance: Codable, Identifiable, Hashable {
    let id: String
    let eventId: String
    let userId: String
    let checkedInAt: Date
    let checkInMethod: CheckInMethod
    let isActive: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case eventId = "event_id"
        case userId = "user_id"
        case checkedInAt = "checked_in_at"
        case checkInMethod = "check_in_method"
        case isActive = "is_active"
        case createdAt = "created_at"
    }
    
    // MARK: - Display
    var displayMethod: String {
        switch checkInMethod {
        case .nfc: return "NFC"
        case .qrCode: return "QR Code"
        case .manual: return "Manual"
        }
    }
    
    var formattedCheckInTime: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter.string(from: checkedInAt)
    }
    
    // MARK: - Validation
    func isValid() -> Bool {
        return !id.isEmpty && !eventId.isEmpty && !userId.isEmpty
    }
}


