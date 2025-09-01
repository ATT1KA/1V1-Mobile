import XCTest
@testable import OneVOneMobile

final class ProfileShareJSONTests: XCTestCase {
    func testProfileDataIsStoredAsJSONNotQuotedString() throws {
        // Create a minimal UserProfile
        let now = Date()
        let profile = UserProfile(id: "test-id", userId: "user-123", username: "tester", avatarUrl: nil, stats: nil, card: nil, achievements: [], createdAt: now, updatedAt: now)

        // Create the ScanContext envelope and ensure it decodes as a JSON object
        guard let envelope = ScanContext.profileSharing(profile).encodedPayloadString() else {
            XCTFail("Failed to create envelope")
            return
        }

        let data = Data(envelope.utf8)

        // The envelope should be a JSON object when decoded
        let decoded = try JSONSerialization.jsonObject(with: data, options: [])
        XCTAssert(decoded is [String: Any], "Envelope did not decode to a JSON object")

        // Simulate the app's share payload construction and assert profile_data would be a JSON object
        var profileData: Any = envelope
        if let jsonObject = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
            profileData = jsonObject
        }

        XCTAssert(profileData is [String: Any], "profile_data would be stored as a quoted string instead of JSON")
    }
}


