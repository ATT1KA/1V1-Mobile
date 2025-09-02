import Foundation
import XCTest
@testable import OneVOneMobile

enum NotificationTestUtilities {
    static func makeDuelRecord(duelId: String = "test-duel", challengerId: String = "a", opponentId: String = "b", gameType: String = "Test Game", gameMode: String = "Casual", status: String = "waiting") -> [String: Any] {
        return [
            "id": duelId,
            "challenger_id": challengerId,
            "opponent_id": opponentId,
            "game_type": gameType,
            "game_mode": gameMode,
            "status": status
        ]
    }

    static func makeUser(id: String = "test-user", username: String = "testuser", email: String = "test@example.com") -> User {
        return User(id: id, email: email, createdAt: Date(), username: username)
    }

    static func assertPendingNotificationContains(_ pending: PendingNotification, titleContains: String? = nil, bodyContains: String? = nil, file: StaticString = #file, line: UInt = #line) {
        if let titleContains = titleContains {
            XCTAssertTrue(pending.title.contains(titleContains), "Expected title to contain '\(titleContains)' but was '\(pending.title)'", file: file, line: line)
        }
        if let bodyContains = bodyContains {
            XCTAssertTrue(pending.body.contains(bodyContains), "Expected body to contain '\(bodyContains)' but was '\(pending.body)'", file: file, line: line)
        }
    }
}


