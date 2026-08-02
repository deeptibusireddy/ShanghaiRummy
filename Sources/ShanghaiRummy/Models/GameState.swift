import Foundation

/// A single-source-of-truth Codable snapshot of the entire game.
///
/// Serialize this to bytes for GameKit `matchData` and iCloud persistence.
/// All state transitions go through `TurnEngine.apply(_:to:)`.
public struct GameState: Codable, Sendable, Equatable {
    public var players: [Player]
    public var currentRound: Int          // 1...10
    public var currentTurnIndex: Int      // index into `players`
    public var dealerIndex: Int
    public var stock: [Card]              // face-down draw pile; top = last element
    public var discard: [Card]            // face-up pile; top = last element
    public var melds: [Meld]              // all melds on the table (all players)
    public var phase: Phase
    public var stockReshufflesUsed: Int   // for "exhausted twice" round end
    /// Deterministic RNG seed for this match. Shared across clients so shuffles
    /// reproduce identically.
    public var randomSeed: UInt64

    public enum Phase: String, Codable, Sendable {
        case awaitingDraw
        case awaitingMeldOrDiscard
        case roundEnded
        case gameEnded
    }

    public var currentPlayerId: UUID { players[currentTurnIndex].id }
    public var currentContract: Contract? {
        RoundSchedule.contract(forRound: currentRound)
    }
}
