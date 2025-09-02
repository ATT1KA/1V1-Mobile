import XCTest
import UserNotifications
@testable import OneVOneMobile

final class NotificationActionsTests: XCTestCase {
    override func setUp() {
        super.setUp()
        // Ensure clean singleton navigation state
        NavigationManager.shared.dismissScreenshotSubmission()
        NavigationManager.shared.dismissDisputeReview()
    }

    func testHandleNotificationAction_navigatesToScreenshotSubmission() {
        // Arrange
        let mockSupabase = MockSupabaseAdapter()
        let service = NotificationService(supabaseService: mockSupabase)
        let duelId = "action-duel-screenshot"

        let content = UNMutableNotificationContent()
        content.userInfo = ["duel_id": duelId]
        let request = UNNotificationRequest(identifier: "test-screenshot", content: content, trigger: nil)
        let notification = UNNotification(request: request, date: Date())

        // Act
        let exp = expectation(description: "completion handler called")
        service.handleNotificationAction(identifier: "SUBMIT_SCREENSHOT", notification: notification) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        // Assert: NavigationManager state updated
        XCTAssertTrue(NavigationManager.shared.showScreenshotSubmission)
        XCTAssertEqual(NavigationManager.shared.screenshotDuelId, duelId)
    }

    func testHandleNotificationAction_navigatesToDisputeReview() {
        // Arrange
        let mockSupabase = MockSupabaseAdapter()
        let service = NotificationService(supabaseService: mockSupabase)
        let duelId = "action-duel-dispute"

        let content = UNMutableNotificationContent()
        content.userInfo = ["duel_id": duelId]
        let request = UNNotificationRequest(identifier: "test-dispute", content: content, trigger: nil)
        let notification = UNNotification(request: request, date: Date())

        // Act
        let exp = expectation(description: "completion handler called")
        service.handleNotificationAction(identifier: "REVIEW_DISPUTE", notification: notification) {
            exp.fulfill()
        }
        wait(for: [exp], timeout: 1.0)

        // Assert: NavigationManager state updated
        XCTAssertTrue(NavigationManager.shared.showDisputeReview)
        XCTAssertEqual(NavigationManager.shared.disputeDuelId, duelId)
    }
}


