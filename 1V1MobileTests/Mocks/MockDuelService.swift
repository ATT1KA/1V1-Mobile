import Foundation
import XCTest
@testable import OneVOneMobile

final class MockDuelService {
    private let supabase: MockSupabaseService
    private var duels: [String: [String: Any]] = [:]

    init(supabase: MockSupabaseService) {
        self.supabase = supabase
    }

    func createDuel(duelId: String = UUID().uuidString,
                    challengerId: String,
                    opponentId: String,
                    gameType: String = "Test Game",
                    gameMode: String = "Casual",
                    status: String = "waiting") -> String {
        let record: [String: Any] = [
            "id": duelId,
            "challenger_id": challengerId,
            "opponent_id": opponentId,
            "game_type": gameType,
            "game_mode": gameMode,
            "status": status
        ]
        duels[duelId] = record
        supabase.emitDuelInsert(record: record)
        return duelId
    }

    func updateDuelStatus(duelId: String, to newStatus: String) {
        guard var record = duels[duelId] else { return }
        let old = record
        record["status"] = newStatus
        duels[duelId] = record
        supabase.emitDuelUpdate(record: record, oldRecord: old)
    }
}


