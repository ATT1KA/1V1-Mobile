import XCTest
@testable import OneVOneMobile

final class AttendeeCountDecodingTests: XCTestCase {
    private func decodeCount(from data: Data) -> Int {
        var count: Int = 0
        // Try the same decoding strategy used in EventService
        if let decodedInt = try? SupabaseService.jsonDecoder.decode(Int.self, from: data) {
            count = decodedInt
        } else if let decodedIntArray = try? SupabaseService.jsonDecoder.decode([Int].self, from: data), let first = decodedIntArray.first {
            count = first
        } else if let decodedDictArray = try? SupabaseService.jsonDecoder.decode([[String: Int]].self, from: data), let firstDict = decodedDictArray.first, let value = firstDict.values.first {
            count = value
        } else if let decodedDict = try? SupabaseService.jsonDecoder.decode([String: Int].self, from: data), let value = decodedDict.values.first {
            count = value
        } else {
            // Fallback to low-level parsing
            if let obj = try? JSONSerialization.jsonObject(with: data, options: []) {
                if let n = obj as? Int {
                    count = n
                } else if let s = obj as? String, let n = Int(s) {
                    count = n
                } else if let arr = obj as? [Any], let first = arr.first {
                    if let n = first as? Int { count = n }
                    else if let dictAny = first as? [String: Any], let anyVal = dictAny.values.first {
                        if let n = anyVal as? Int { count = n }
                        else if let s = anyVal as? String, let n2 = Int(s) { count = n2 }
                    }
                } else if let dictAny = obj as? [String: Any], let anyVal = dictAny.values.first {
                    if let n = anyVal as? Int { count = n }
                    else if let s = anyVal as? String, let n2 = Int(s) { count = n2 }
                }
            }
        }
        return count
    }

    func testDecodePlainInteger() throws {
        let json = "42"
        let data = Data(json.utf8)
        XCTAssertEqual(decodeCount(from: data), 42)
    }

    func testDecodeIntegerArray() throws {
        let json = "[42]"
        let data = Data(json.utf8)
        XCTAssertEqual(decodeCount(from: data), 42)
    }

    func testDecodeObjectArrayWithKey() throws {
        let json = "[{\"get_event_attendee_count\": 42}]"
        let data = Data(json.utf8)
        XCTAssertEqual(decodeCount(from: data), 42)
    }

    func testDecodeObjectWithKey() throws {
        let json = "{\"count\": 42}"
        let data = Data(json.utf8)
        XCTAssertEqual(decodeCount(from: data), 42)
    }

    func testDecodeStringNumberFallback() throws {
        let json = "{\"count\": \"42\"}"
        let data = Data(json.utf8)
        XCTAssertEqual(decodeCount(from: data), 42)
    }
}


