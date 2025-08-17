import XCTest
@testable import OneVOneMobile

final class OneVOneMobileTests: XCTestCase {
    
    var authService: AuthService!
    var supabaseService: SupabaseService!
    
    override func setUpWithError() throws {
        authService = AuthService()
        supabaseService = SupabaseService.shared
    }
    
    override func tearDownWithError() throws {
        authService = nil
    }
    
    func testAuthServiceInitialization() throws {
        XCTAssertNotNil(authService)
        XCTAssertFalse(authService.isAuthenticated)
        XCTAssertNil(authService.currentUser)
    }
    
    func testSupabaseServiceInitialization() throws {
        XCTAssertNotNil(supabaseService)
    }
    
    func testUserModel() throws {
        let user = User(
            id: "test-id",
            email: "test@example.com",
            createdAt: Date(),
            username: "testuser"
        )
        
        XCTAssertEqual(user.id, "test-id")
        XCTAssertEqual(user.email, "test@example.com")
        XCTAssertEqual(user.username, "testuser")
    }
    
    func testGameModel() throws {
        let game = Game(
            id: "game-id",
            player1Id: "player1",
            player2Id: "player2",
            status: .active
        )
        
        XCTAssertEqual(game.id, "game-id")
        XCTAssertEqual(game.player1Id, "player1")
        XCTAssertEqual(game.player2Id, "player2")
        XCTAssertEqual(game.status, .active)
    }
    
    func testGameScore() throws {
        let score = GameScore(player1Score: 10, player2Score: 5)
        
        XCTAssertEqual(score.player1Score, 10)
        XCTAssertEqual(score.player2Score, 5)
        XCTAssertEqual(score.winner, 1) // Player 1 wins
    }
    
    func testGameStatusDisplayName() throws {
        XCTAssertEqual(GameStatus.waiting.displayName, "Waiting for Player")
        XCTAssertEqual(GameStatus.active.displayName, "In Progress")
        XCTAssertEqual(GameStatus.completed.displayName, "Completed")
        XCTAssertEqual(GameStatus.cancelled.displayName, "Cancelled")
    }
    
    func testGameStatusColor() throws {
        XCTAssertEqual(GameStatus.waiting.color, "orange")
        XCTAssertEqual(GameStatus.active.color, "green")
        XCTAssertEqual(GameStatus.completed.color, "blue")
        XCTAssertEqual(GameStatus.cancelled.color, "red")
    }
    
    func testPerformanceExample() throws {
        measure {
            // Performance test
            for _ in 0..<1000 {
                _ = User(id: "test", email: "test@example.com")
            }
        }
    }
}
