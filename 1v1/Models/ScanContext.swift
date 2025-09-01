import Foundation

enum ScanContext: Codable, Equatable {
    case profileSharing(UserProfile)
    case eventCheckIn(eventId: String)
    
    enum CodingKeys: String, CodingKey { case type, payload }
    enum ContextType: String, Codable { case profileSharing, eventCheckIn }
    
    // MARK: - Codable
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let type = try container.decode(ContextType.self, forKey: .type)
        switch type {
        case .profileSharing:
            let profile = try container.decode(UserProfile.self, forKey: .payload)
            self = .profileSharing(profile)
        case .eventCheckIn:
            let payload = try container.decode([String: String].self, forKey: .payload)
            guard let eventId = payload["eventId"], !eventId.isEmpty else {
                throw DecodingError.dataCorruptedError(forKey: .payload, in: container, debugDescription: "Missing eventId")
            }
            self = .eventCheckIn(eventId: eventId)
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case .profileSharing(let profile):
            try container.encode(ContextType.profileSharing, forKey: .type)
            try container.encode(profile, forKey: .payload)
        case .eventCheckIn(let eventId):
            try container.encode(ContextType.eventCheckIn, forKey: .type)
            try container.encode(["eventId": eventId], forKey: .payload)
        }
    }
    
    // MARK: - UX Text
    var instructions: String {
        switch self {
        case .profileSharing:
            return "Hold near tag or scan QR to share profile"
        case .eventCheckIn:
            return "Hold near tag or scan QR to check into event"
        }
    }
    
    var successMessage: String {
        switch self {
        case .profileSharing:
            return "Profile scanned successfully!"
        case .eventCheckIn:
            return "Event check-in successful!"
        }
    }
    
    // MARK: - Payload Helpers
    func encodedPayloadString() -> String? {
        switch self {
        case .profileSharing(let profile):
            // Wrap the profile JSON in a top-level envelope with `scanType` for robust detection
            guard let profileData = try? JSONEncoder().encode(profile),
                  let profileJson = try? JSONSerialization.jsonObject(with: profileData) else { return nil }
            let envelope: [String: Any] = [
                "scanType": "profileSharing",
                "payload": profileJson
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: envelope, options: []) else { return nil }
            return String(data: data, encoding: .utf8)
        case .eventCheckIn(let eventId):
            let dict: [String: Any] = [
                "scanType": "eventCheckIn",
                "eventId": eventId
            ]
            guard let data = try? JSONSerialization.data(withJSONObject: dict, options: []) else { return nil }
            return String(data: data, encoding: .utf8)
        }
    }
    
    static func fromPayloadString(_ payload: String) -> ScanContext? {
        guard let data = payload.data(using: .utf8) else { return nil }

        // If the payload uses the new envelope, check `scanType` first
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let scanType = json["scanType"] as? String {
            switch scanType {
            case "profileSharing":
                if let payloadObj = json["payload"] {
                    if let profileData = try? JSONSerialization.data(withJSONObject: payloadObj, options: []),
                       let profile = try? JSONDecoder().decode(UserProfile.self, from: profileData) {
                        return .profileSharing(profile)
                    }
                }
            case "eventCheckIn":
                if let eventId = json["eventId"] as? String {
                    return .eventCheckIn(eventId: eventId)
                }
                if let payloadObj = json["payload"] as? [String: Any], let eventId = payloadObj["eventId"] as? String {
                    return .eventCheckIn(eventId: eventId)
                }
            default:
                break
            }
        }

        // Fallback: try decoding legacy formats (profile as raw UserProfile JSON)
        if let profile = try? JSONDecoder().decode(UserProfile.self, from: data) {
            return .profileSharing(profile)
        }

        // Fallback: legacy event payload that used `type` key
        if let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let type = json["type"] as? String, type == "eventCheckIn",
           let eventId = json["eventId"] as? String {
            return .eventCheckIn(eventId: eventId)
        }

        return nil
    }
}


