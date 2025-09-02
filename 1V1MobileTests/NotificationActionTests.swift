import XCTest
import UserNotifications
@testable import OneVOneMobile

final class NotificationActionTests: XCTestCase {

    override func setUpWithError() throws {
        // Reset navigation manager state before each test
        Task { @MainActor in
            NavigationManager.shared.dismissSharedProfile()
            NavigationManager.shared.dismissDuelChallenge()
            NavigationManager.shared.dismissScreenshotSubmission()
            NavigationManager.shared.dismissDisputeReview()
            NavigationManager.shared.dismissVictoryRecap()
        }
    }

    func makeResponse(duelId: String, actionIdentifier: String) -> UNNotificationResponse {
        let content = UNMutableNotificationContent()
        content.userInfo = ["duel_id": duelId]
        let request = UNNotificationRequest(identifier: "test-notification", content: content, trigger: nil)
        let notification = UNNotification(request: request, date: Date())
        let response = UNNotificationResponse(notification: notification, actionIdentifier: actionIdentifier)
        return response
    }

    func testAcceptAndDeclineInvokeCompletion() {
        let acceptExp = expectation(description: "accept completion called")
        let declineExp = expectation(description: "decline completion called")

        let acceptResponse = makeResponse(duelId: "duel-accept-1", actionIdentifier: "ACCEPT_DUEL")
        NotificationDelegate.shared.userNotificationCenter(UNUserNotificationCenter.current(), didReceive: acceptResponse) {
            acceptExp.fulfill()
        }

        let declineResponse = makeResponse(duelId: "duel-decline-1", actionIdentifier: "DECLINE_DUEL")
        NotificationDelegate.shared.userNotificationCenter(UNUserNotificationCenter.current(), didReceive: declineResponse) {
            declineExp.fulfill()
        }

        wait(for: [acceptExp, declineExp], timeout: 2.0)
    }

    func testSubmitScreenshotNavigatesAndCallsCompletion() {
        let duelId = "screenshot-duel-1"
        let exp = expectation(description: "submit screenshot completion called")

        let response = makeResponse(duelId: duelId, actionIdentifier: "SUBMIT_SCREENSHOT")
        NotificationDelegate.shared.userNotificationCenter(UNUserNotificationCenter.current(), didReceive: response) {
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)

        // Assert navigation manager updated
        XCTAssertTrue(NavigationManager.shared.showScreenshotSubmission, "Screenshot sheet should be shown")
        XCTAssertEqual(NavigationManager.shared.screenshotDuelId, duelId)
    }

    func testDefaultTapDoesNotNavigateButCallsCompletion() {
        let exp = expectation(description: "default tap completion called")
        let response = makeResponse(duelId: "none", actionIdentifier: UNNotificationDefaultActionIdentifier)

        // Ensure no navigation state before
        XCTAssertFalse(NavigationManager.shared.showScreenshotSubmission)
        XCTAssertFalse(NavigationManager.shared.showDuelChallenge)
        XCTAssertFalse(NavigationManager.shared.showDisputeReview)

        NotificationDelegate.shared.userNotificationCenter(UNUserNotificationCenter.current(), didReceive: response) {
            exp.fulfill()
        }

        wait(for: [exp], timeout: 2.0)

        // Navigation should remain unchanged
        XCTAssertFalse(NavigationManager.shared.showScreenshotSubmission)
        XCTAssertFalse(NavigationManager.shared.showDuelChallenge)
        XCTAssertFalse(NavigationManager.shared.showDisputeReview)
    }
}


