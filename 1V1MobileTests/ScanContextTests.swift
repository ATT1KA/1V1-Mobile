import XCTest
@testable import OneVOneMobile

final class ScanContextTests: XCTestCase {
    func testEventCheckInEncodeDecode() throws {
        let eventId = "00000000-0000-0000-0000-000000000000"
        let ctx = ScanContext.eventCheckIn(eventId: eventId)
        guard let payload = ctx.encodedPayloadString() else {
            return XCTFail("No payload")
        }
        let parsed = ScanContext.fromPayloadString(payload)
        XCTAssertEqual(parsed, ctx)
    }

    func testProfileSharingEncodeDecode() throws {
        let user = User(id: "u1", email: "t@e.com", createdAt: Date(), username: "tester")
        let profile = UserProfile(from: user, stats: nil, card: nil, achievements: [])
        let ctx = ScanContext.profileSharing(profile)
        guard let payload = ctx.encodedPayloadString() else {
            return XCTFail("No payload")
        }
        let back = ScanContext.fromPayloadString(payload)
        XCTAssertEqual(back, .profileSharing(profile))
    }
}


