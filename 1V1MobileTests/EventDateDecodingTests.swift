import XCTest
@testable import OneVOneMobile

final class EventDateDecodingTests: XCTestCase {
    func testDecodeSampleEventsJSON() throws {
        let bundle = Bundle(for: type(of: self))
        guard let url = bundle.url(forResource: "mock_bay_area_events", withExtension: "json") else {
            return XCTFail("Missing sample events JSON")
        }
        let data = try Data(contentsOf: url)
        do {
            let events = try SupabaseService.jsonDecoder.decode([Event].self, from: data)
            XCTAssertFalse(events.isEmpty, "Expected at least one event")
        } catch {
            XCTFail("Failed to decode events: \(error)")
        }
    }
}


