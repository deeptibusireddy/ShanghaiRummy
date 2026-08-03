import Foundation

/// A single-source-of-truth Codable snapshot of the entire game.
///
/// Serialize this to bytes for GameKit `matchData` and iCloud persistence.
/// All state transitions go through `TurnEngine.apply(_:to:)`.
public struct GameState: Codable, Sendable, Equatable {
    public var players: [Player]
    /// The nth hand being played (1, 2, 3, ...). NOTE: this is NOT the
    /// contract level. Each player has their own `currentLevel`. This field
    /// just tracks how many hands have been dealt in this match.
    public var currentRound: Int
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
    /// Populated when `phase == .gameEnded`. Usually one player, but can be
    /// multiple when they finish level 10 in the same hand and tie on
    /// cumulative score.
    public var gameWinnerIds: [UUID]

    public enum Phase: String, Codable, Sendable {
        case awaitingDraw
        case awaitingMeldOrDiscard
        case roundEnded
        case gameEnded
    }

    public var currentPlayerId: UUID { players[currentTurnIndex].id }
    /// Contract for the current turn player based on their own level.
    /// Independent-contract variant: each player is on their own 1-10 track.
    public var currentContract: Contract? {
        RoundSchedule.contract(forRound: players[currentTurnIndex].currentLevel)
    }
    public func contract(forPlayer id: UUID) -> Contract? {
        guard let p = players.first(where: { $0.id == id }) else { return nil }
        return RoundSchedule.contract(forRound: p.currentLevel)
    }

    public init(
        players: [Player],
        currentRound: Int,
        currentTurnIndex: Int,
        dealerIndex: Int,
        stock: [Card],
        discard: [Card],
        melds: [Meld],
        phase: Phase,
        stockReshufflesUsed: Int,
        randomSeed: UInt64,
        gameWinnerIds: [UUID] = []
    ) {
        self.players = players
        self.currentRound = currentRound
        self.currentTurnIndex = currentTurnIndex
        self.dealerIndex = dealerIndex
        self.stock = stock
        self.discard = discard
        self.melds = melds
        self.phase = phase
        self.stockReshufflesUsed = stockReshufflesUsed
        self.randomSeed = randomSeed
        self.gameWinnerIds = gameWinnerIds
    }
}
