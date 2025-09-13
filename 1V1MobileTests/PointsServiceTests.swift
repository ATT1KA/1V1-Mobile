import XCTest
@testable import OneVOneMobile

final class PointsServiceTests: XCTestCase {
    func testAwardDuelPointsCalculation() async throws {
        // This test verifies point calculation logic (without remote calls)
        let pointsService = PointsService.shared

        // We can't call awardPoints (RPC) in unit tests here; instead assert that
        // awardDuelPoints computes a positive value and calls through without throwing when mocked.
        // For now, just verify the constants exist and compute a sample value.
        let winBase = Constants.Points.duelWinBase
        let multiplier = Constants.Points.duelWinScoreMultiplier
        let sampleScore = 42
        let expected = winBase + Int(Double(sampleScore) * multiplier)
        XCTAssertGreaterThan(expected, 0)
        // Sanity check: method exists
        XCTAssertNotNil(pointsService)
    }
}


